local deathLock = {}
local sessions = {}
local tokenSeq = 0

local function nextToken()
    tokenSeq = tokenSeq + 1
    return tokenSeq
end

local function cfgNum(key, fallback)
    local n = tonumber(Config[key])
    if not n or n <= 0 then
        return fallback
    end
    return n
end

local function dropLanded(source)
    if GetResourceState('wtbg_drop') ~= 'started' then
        return true
    end
    local ok, landed = pcall(function()
        return exports.wtbg_drop:IsPlayerLanded(source)
    end)
    if not ok then
        return true
    end
    return landed == true
end

local function memberInfo(source)
    return exports.wtbg_match:GetMember(tonumber(source))
end

local function useBrLoadout(source)
    if not Config.UseBRStartingLoadout then
        return false
    end

    if GetResourceState('wtbg_loot') ~= 'started' then
        return false
    end

    local info = memberInfo(source)
    return info and info.mode == 'SQUAD'
end

local function applyLoadout(source)
    source = tonumber(source)
    if not source then
        return
    end

    local state = exports.wtbg_core:GetPlayerState(source)
    if not state or state.state ~= WTBG.PlayerStates.MATCH then
        return
    end

    if useBrLoadout(source) then
        exports.wtbg_loot:ApplySpawnLoadout(source)
        return
    end

    TriggerClientEvent('wtbg:combat:applyLoadout', source)
end

local function restoreLoadout(source)
    source = tonumber(source)
    if not source then
        return
    end

    if GetResourceState('wtbg_loot') == 'started' then
        exports.wtbg_loot:SyncLoadout(source)
        return
    end

    applyLoadout(source)
end

local function broadcast(matchId, eventName, ...)
    local sources = exports.wtbg_match:GetMatchSources(matchId) or {}
    for i = 1, #sources do
        local src = tonumber(sources[i])
        if src then
            TriggerClientEvent(eventName, src, ...)
        end
    end
end

local function dist(a, b)
    local pa = GetPlayerPed(a)
    local pb = GetPlayerPed(b)
    if not pa or pa == 0 or not pb or pb == 0 then
        return 999.0
    end

    return #(GetEntityCoords(pa) - GetEntityCoords(pb))
end

local function validKiller(victimInfo, killer)
    killer = tonumber(killer)
    if not killer or killer < 1 or not victimInfo or killer == victimInfo.source then
        return nil
    end

    local killerInfo = memberInfo(killer)
    if not killerInfo or killerInfo.matchId ~= victimInfo.matchId then
        return nil
    end

    if killerInfo.downed or not killerInfo.alive then
        return nil
    end

    if (not Config.FriendlyFire) and victimInfo.teamId and killerInfo.teamId and victimInfo.teamId == killerInfo.teamId then
        return nil
    end

    return killer, killerInfo
end

local function clearPrompts(session)
    if not session then
        return
    end

    if session.reviver then
        TriggerClientEvent('wtbg:ui:prompt', session.reviver, nil)
    end
    if session.finisher then
        TriggerClientEvent('wtbg:ui:prompt', session.finisher, nil)
    end
    TriggerClientEvent('wtbg:ui:prompt', session.source, nil)
    session.reviver = nil
    session.reviveToken = nil
    session.finisher = nil
    session.finishToken = nil
end

local function dropSession(source)
    local session = sessions[source]
    sessions[source] = nil
    if session then
        clearPrompts(session)
    end
    return session
end

local function eliminate(victim, killer, weapon, kind)
    local session = dropSession(victim)
    if not session then
        return false
    end

    deathLock[victim] = true
    exports.wtbg_match:SetDowned(victim, false)
    local ok = exports.wtbg_match:ReportDeath(victim, killer, weapon, kind)
    if not ok then
        deathLock[victim] = nil
        return false
    end

    TriggerClientEvent('wtbg:combat:cleared', victim)
    TriggerClientEvent('wtbg:ui:bleed', victim, nil)
    return true
end

local function revive(target)
    local session = dropSession(target)
    if not session then
        return false
    end

    deathLock[target] = nil
    exports.wtbg_core:SetSessionState(target, WTBG.PlayerStates.MATCH)
    exports.wtbg_match:SetDowned(target, false)
    broadcast(session.matchId, 'wtbg:combat:playerUp', target)
    restoreLoadout(target)
    TriggerClientEvent('wtbg:combat:revived', target, cfgNum('ReviveHealth', 140))
    TriggerClientEvent('wtbg:ui:bleed', target, nil)
    WTBG.Debug('revived', target)
    return true
end

local function knock(victim, killer, weapon)
    victim = tonumber(victim)
    if not victim or sessions[victim] or deathLock[victim] then
        return false
    end

    local state = exports.wtbg_core:GetPlayerState(victim)
    if not state or state.state ~= WTBG.PlayerStates.MATCH or not state.alive then
        return false
    end

    local info = memberInfo(victim)
    if not info or info.matchState ~= WTBG.MatchStates.ACTIVE or not info.alive or info.downed then
        return false
    end

    if not dropLanded(victim) then
        return false
    end

    info.source = victim
    local killerInfo
    killer, killerInfo = validKiller(info, killer)
    local bleed = cfgNum('BleedoutTime', 25)
    local t = nextToken()

    sessions[victim] = {
        source = victim,
        token = t,
        killer = killer,
        weapon = weapon,
        matchId = info.matchId,
        teamId = info.teamId,
        bleedEnds = GetGameTimer() + math.floor(bleed * 1000)
    }

    exports.wtbg_core:SetSessionState(victim, WTBG.PlayerStates.KNOCKED)
    exports.wtbg_match:SetDowned(victim, true, killer)

    local after = memberInfo(victim)
    if not sessions[victim] or not after or after.matchState ~= WTBG.MatchStates.ACTIVE then
        return true
    end

    broadcast(info.matchId, 'wtbg:combat:playerDowned', victim, info.teamId, bleed)
    broadcast(info.matchId, 'wtbg:ui:killfeed', {
        killer = killerInfo and killerInfo.name or nil,
        victim = info.name,
        kind = 'down'
    })
    TriggerClientEvent('wtbg:ui:bleed', victim, bleed)
    TriggerClientEvent('wtbg:combat:knock', victim, bleed)

    SetTimeout(math.floor(bleed * 1000), function()
        local current = sessions[victim]
        if not current or current.token ~= t then
            return
        end

        eliminate(victim, current.killer, current.weapon, 'bleed')
    end)

    WTBG.Debug('knocked', victim, 'by', killer)
    return true
end

AddEventHandler('wtbg:match:applyLoadout', function(source)
    deathLock[source] = nil
    applyLoadout(source)
end)

RegisterNetEvent('wtbg:combat:playerDied', function(killerId, weapon)
    local victim = tonumber(source)
    if not victim or sessions[victim] then
        return
    end

    knock(victim, killerId, weapon)
end)

RegisterNetEvent('wtbg:combat:reviveStart', function(targetId)
    local medic = tonumber(source)
    local target = tonumber(targetId)
    if not medic or not target or medic == target then
        return
    end

    local session = sessions[target]
    if not session or session.reviver or session.finisher then
        return
    end

    local medicInfo = memberInfo(medic)
    local targetInfo = memberInfo(target)
    if not medicInfo or not targetInfo or medicInfo.matchId ~= targetInfo.matchId then
        return
    end

    if medicInfo.matchState ~= WTBG.MatchStates.ACTIVE or medicInfo.mode == 'FFA' then
        return
    end

    if medicInfo.downed or not medicInfo.alive then
        return
    end

    if not dropLanded(medic) then
        return
    end

    if not targetInfo.downed or not targetInfo.alive then
        return
    end

    if not medicInfo.teamId or medicInfo.teamId ~= targetInfo.teamId then
        return
    end

    if dist(medic, target) > cfgNum('ReviveRange', 4.0) then
        return
    end

    local t = nextToken()
    session.reviver = medic
    session.reviveToken = t
    local ms = math.floor(cfgNum('ReviveTime', 6) * 1000)
    TriggerClientEvent('wtbg:ui:prompt', medic, { kind = 'revive', ms = ms })
    TriggerClientEvent('wtbg:ui:prompt', target, { kind = 'beingRevived', ms = ms })

    SetTimeout(ms, function()
        local current = sessions[target]
        if not current or current.reviveToken ~= t or current.reviver ~= medic then
            return
        end

        if dist(medic, target) > cfgNum('ReviveRange', 4.0) then
            current.reviver = nil
            current.reviveToken = nil
            TriggerClientEvent('wtbg:ui:prompt', medic, nil)
            TriggerClientEvent('wtbg:ui:prompt', target, nil)
            return
        end

        revive(target)
    end)
end)

RegisterNetEvent('wtbg:combat:finishStart', function(targetId)
    local finisher = tonumber(source)
    local target = tonumber(targetId)
    if not finisher or not target or finisher == target then
        return
    end

    local session = sessions[target]
    if not session or session.finisher then
        return
    end

    local finisherInfo = memberInfo(finisher)
    local targetInfo = memberInfo(target)
    if not finisherInfo or not targetInfo or finisherInfo.matchId ~= targetInfo.matchId then
        return
    end

    if finisherInfo.matchState ~= WTBG.MatchStates.ACTIVE then
        return
    end

    if finisherInfo.downed or not finisherInfo.alive then
        return
    end

    if not dropLanded(finisher) then
        return
    end

    if not targetInfo.downed or not targetInfo.alive then
        return
    end

    if finisherInfo.teamId and targetInfo.teamId and finisherInfo.teamId == targetInfo.teamId and not Config.FriendlyFire then
        return
    end

    if dist(finisher, target) > cfgNum('FinishRange', 3.5) then
        return
    end

    if session.reviver then
        TriggerClientEvent('wtbg:ui:prompt', session.reviver, nil)
        session.reviver = nil
        session.reviveToken = nil
    end

    local t = nextToken()
    session.finisher = finisher
    session.finishToken = t
    local ms = math.floor(cfgNum('FinishTime', 2) * 1000)
    TriggerClientEvent('wtbg:ui:prompt', finisher, { kind = 'finish', ms = ms })
    TriggerClientEvent('wtbg:ui:prompt', target, { kind = 'beingFinished', ms = ms })

    SetTimeout(ms, function()
        local current = sessions[target]
        if not current or current.finishToken ~= t or current.finisher ~= finisher then
            return
        end

        if dist(finisher, target) > cfgNum('FinishRange', 3.5) then
            current.finisher = nil
            current.finishToken = nil
            TriggerClientEvent('wtbg:ui:prompt', finisher, nil)
            TriggerClientEvent('wtbg:ui:prompt', target, nil)
            return
        end

        eliminate(target, finisher, nil, 'kill')
    end)
end)

RegisterNetEvent('wtbg:combat:actionCancel', function(targetId)
    local actor = tonumber(source)
    local target = tonumber(targetId)
    if not actor or not target then
        return
    end

    local session = sessions[target]
    if not session then
        return
    end

    if session.reviver == actor then
        session.reviver = nil
        session.reviveToken = nil
        TriggerClientEvent('wtbg:ui:prompt', actor, nil)
        TriggerClientEvent('wtbg:ui:prompt', target, nil)
    end

    if session.finisher == actor then
        session.finisher = nil
        session.finishToken = nil
        TriggerClientEvent('wtbg:ui:prompt', actor, nil)
        TriggerClientEvent('wtbg:ui:prompt', target, nil)
    end
end)

AddEventHandler('wtbg:match:serverFinished', function(matchId)
    matchId = tonumber(matchId)
    for src, session in pairs(sessions) do
        if session.matchId == matchId then
            dropSession(src)
        end
    end
end)

AddEventHandler('wtbg:core:playerDropped', function(source)
    deathLock[source] = nil
    dropSession(source)
end)

AddEventHandler('wtbg:core:returnedToLobby', function(source)
    deathLock[source] = nil
    dropSession(source)
    TriggerClientEvent('wtbg:combat:cleared', source)
    TriggerClientEvent('wtbg:ui:bleed', source, nil)
    TriggerClientEvent('wtbg:ui:prompt', source, nil)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    deathLock = {}
    sessions = {}
end)

local LIVE_HP_FLOOR = 101

exports('ApplyLoadout', applyLoadout)

exports('ApplyZoneDamage', function(source, amount)
    source = tonumber(source)
    amount = tonumber(amount)
    if not source or not amount or amount <= 0 then
        return false
    end

    local session = sessions[source]
    if session then
        session.bleedEnds = (session.bleedEnds or GetGameTimer()) - math.floor(amount * 1000)
        local left = (session.bleedEnds - GetGameTimer()) / 1000
        if left <= 0 then
            return eliminate(source, session.killer, session.weapon, 'bleed')
        end
        TriggerClientEvent('wtbg:ui:bleed', source, math.ceil(left))
        return true
    end

    local state = exports.wtbg_core:GetPlayerState(source)
    if not state or not state.alive or state.state ~= WTBG.PlayerStates.MATCH then
        return false
    end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then
        return false
    end

    local hp = WTBG.PedHealth(ped)
    if not hp then
        return false
    end
    if hp - amount < LIVE_HP_FLOOR then
        return knock(source, nil, 'ZONE')
    end

    WTBG.SetVitals(source, hp - amount, nil)
    return true
end)
