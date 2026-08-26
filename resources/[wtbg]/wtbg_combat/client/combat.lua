local reported = false
local downed = false
local inMatch = false
local eliminated = false
local myTeamId = nil
local downedPlayers = {}
local holdingTarget = nil
local holdingKind = nil
local holdGrace = 0
local hintKind = nil

local WRITHE_DICT = 'combat@damage@writhe'
local WRITHE_CLIP = 'writhe_loop'

local function useBrLoadout()
    return Config.UseBRStartingLoadout and (Config.MatchMode or 'SQUAD') ~= 'FFA'
end

local function applyLocalLoadout()
    local ped = PlayerPedId()
    if useBrLoadout() then
        RemoveAllPedWeapons(ped, true)
        local health = Config.StartingHealth or 200
        SetPedMaxHealth(ped, health)
        SetEntityMaxHealth(ped, health)
        SetEntityHealth(ped, health)
        SetPedArmour(ped, 0)
    else
        Weapons.ApplyLoadout(ped)
    end
    reported = false
    exports.wtbg_core:UnlockCombat()
end

local function resolveKiller(ped)
    local killerPed = GetPedSourceOfDeath(ped)
    if killerPed and killerPed ~= 0 and killerPed ~= ped and IsPedAPlayer(killerPed) then
        local idx = NetworkGetPlayerIndexFromPed(killerPed)
        if idx ~= -1 then
            return GetPlayerServerId(idx)
        end
    end

    return nil
end

local function reportDowned()
    if reported or downed or not inMatch then
        return
    end

    if GetResourceState('wtbg_drop') == 'started' then
        local ok, landed = pcall(function()
            return exports.wtbg_drop:IsLanded()
        end)
        if ok and landed == false then
            return
        end
    end

    reported = true
    local ped = PlayerPedId()
    TriggerServerEvent('wtbg:combat:playerDied', resolveKiller(ped), GetPedCauseOfDeath(ped))
end

local function stopHold()
    if holdingTarget then
        TriggerServerEvent('wtbg:combat:actionCancel', holdingTarget)
    end
    holdingTarget = nil
    holdingKind = nil
end

local function playerLabel(serverId)
    local idx = GetPlayerFromServerId(serverId)
    if idx == -1 then
        return 'Player'
    end
    local name = GetPlayerName(idx)
    if type(name) ~= 'string' or name == '' then
        return 'Player'
    end
    return name
end

local function setHint(kind, targetId)
    local token = kind and (kind .. ':' .. tostring(targetId or '')) or nil
    if hintKind == token then
        return
    end
    hintKind = token
    if kind then
        TriggerEvent('wtbg:ui:combatContext', {
            kind = kind,
            name = targetId and playerLabel(targetId) or nil
        })
    else
        TriggerEvent('wtbg:ui:combatContext', nil)
    end
end

local function clearDownedLocal()
    downed = false
    reported = false
    stopHold()
    setHint(nil)
    local ped = PlayerPedId()
    if DoesEntityExist(ped) then
        ClearPedTasksImmediately(ped)
        ResetEntityAlpha(ped)
        FreezeEntityPosition(ped, false)
        SetEntityInvincible(ped, false)
        SetPlayerInvincible(PlayerId(), false)
        SetPedCanBeTargetted(ped, true)
        SetPedCanRagdoll(ped, true)
    end
    TriggerEvent('wtbg:ui:bleed', nil)
end

local function applyWrithe(ped)
    if not HasAnimDictLoaded(WRITHE_DICT) then
        RequestAnimDict(WRITHE_DICT)
        return
    end

    if not IsEntityPlayingAnim(ped, WRITHE_DICT, WRITHE_CLIP, 3) then
        TaskPlayAnim(ped, WRITHE_DICT, WRITHE_CLIP, 8.0, 8.0, -1, 1, 0.0, false, false, false)
    end
end

local function enterDowned(seconds)
    downed = true
    reported = true
    inMatch = true
    stopHold()
    RequestAnimDict(WRITHE_DICT)

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then
        coords = GetOffsetFromEntityInWorldCoords(veh, 1.7, 0.0, 0.15)
        heading = GetEntityHeading(veh)
        TaskLeaveVehicle(ped, veh, 16)
        SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
        ped = PlayerPedId()
    end
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, true)

    ped = PlayerPedId()
    SetEntityHealth(ped, Config.DownedHealth or 120)
    SetPedArmour(ped, 0)
    RemoveAllPedWeapons(ped, true)
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
    SetEntityInvincible(ped, true)
    SetPlayerInvincible(PlayerId(), true)
    SetPedCanBeTargetted(ped, false)
    SetPedCanRagdoll(ped, false)
    applyWrithe(ped)
    TriggerEvent('wtbg:ui:bleed', tonumber(seconds) or Config.BleedoutTime or 30)
end

local function nearestDowned(maxDist)
    local origin = GetEntityCoords(PlayerPedId())
    local bestId, bestDist = nil, maxDist
    local myId = GetPlayerServerId(PlayerId())

    for _, player in ipairs(GetActivePlayers()) do
        local sid = tonumber(GetPlayerServerId(player))
        if sid and sid ~= myId and downedPlayers[sid] then
            local ped = GetPlayerPed(player)
            if DoesEntityExist(ped) then
                local d = #(origin - GetEntityCoords(ped))
                if d < bestDist then
                    bestId = sid
                    bestDist = d
                end
            end
        end
    end

    return bestId
end

local function isHoldingInteract()
    return IsControlPressed(0, 38) or IsDisabledControlPressed(0, 38)
        or IsControlPressed(0, 51) or IsDisabledControlPressed(0, 51)
end

RegisterNetEvent('wtbg:combat:applyLoadout', function()
    applyLocalLoadout()
end)

RegisterNetEvent('wtbg:match:begin', function()
    inMatch = true
    reported = false
    eliminated = false
    downedPlayers = {}
    clearDownedLocal()
    if not useBrLoadout() then
        applyLocalLoadout()
    else
        RemoveAllPedWeapons(PlayerPedId(), true)
        local airborne = false
        if GetResourceState('wtbg_drop') == 'started' then
            local ok, landed = pcall(function()
                return exports.wtbg_drop:IsLanded()
            end)
            airborne = ok and landed == false
        end
        if not airborne then
            exports.wtbg_core:UnlockCombat()
        end
    end
end)

RegisterNetEvent('wtbg:match:enter', function()
    inMatch = true
    reported = false
    eliminated = false
    downedPlayers = {}
    clearDownedLocal()
end)

RegisterNetEvent('wtbg:match:setTeam', function(teamId)
    myTeamId = tonumber(teamId)
end)

RegisterNetEvent('wtbg:core:spawnLobby', function()
    inMatch = false
    eliminated = false
    myTeamId = nil
    downedPlayers = {}
    clearDownedLocal()
end)

RegisterNetEvent('wtbg:match:finished', function()
    inMatch = false
    eliminated = false
    downedPlayers = {}
    clearDownedLocal()
end)

RegisterNetEvent('wtbg:match:playerDied', function()
    eliminated = true
    stopHold()
    setHint(nil)
end)

RegisterNetEvent('wtbg:combat:knock', function(seconds)
    TriggerEvent('wtbg:ui:closeInventory')
    enterDowned(seconds)
end)

RegisterNetEvent('wtbg:combat:playerDowned', function(playerId, teamId)
    local id = tonumber(playerId)
    if id then
        downedPlayers[id] = { teamId = tonumber(teamId) }
    end
end)

RegisterNetEvent('wtbg:combat:playerUp', function(playerId)
    local id = tonumber(playerId)
    if id then
        downedPlayers[id] = nil
    end
    if id == GetPlayerServerId(PlayerId()) then
        clearDownedLocal()
    end
end)

RegisterNetEvent('wtbg:combat:revived', function(health)
    clearDownedLocal()
    if not useBrLoadout() then
        applyLocalLoadout()
    end
    local hp = tonumber(health)
    if hp and hp > 0 then
        SetEntityHealth(PlayerPedId(), hp)
    end
    exports.wtbg_core:UnlockCombat()
end)

RegisterNetEvent('wtbg:combat:cleared', function()
    downedPlayers[GetPlayerServerId(PlayerId())] = nil
    clearDownedLocal()
end)

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then
        return
    end

    local victim = args[1]
    if victim ~= PlayerPedId() or downed then
        return
    end

    if not IsEntityDead(victim) and not IsPedDeadOrDying(victim, true) then
        return
    end

    reportDowned()
end)

AddEventHandler('baseevents:onPlayerKilled', function(killerId)
    if downed or reported then
        return
    end

    reported = true
    TriggerServerEvent('wtbg:combat:playerDied', tonumber(killerId), nil)
end)

AddEventHandler('baseevents:onPlayerDied', function()
    reportDowned()
end)

CreateThread(function()
    local wasDead = false

    while true do
        local ped = PlayerPedId()
        local dead = IsEntityDead(ped) or IsPedDeadOrDying(ped, true) or IsPlayerDead(PlayerId())

        if dead and not wasDead and not downed and not eliminated then
            local spectating = false
            if GetResourceState('wtbg_spectator') == 'started' then
                local ok, spec = pcall(function()
                    return exports.wtbg_spectator:IsSpectating()
                end)
                spectating = ok and spec
            end
            if not spectating then
                reportDowned()
            end
        end

        if not dead and not downed and not eliminated then
            reported = false
        end

        wasDead = dead
        Wait(200)
    end
end)

CreateThread(function()
    while true do
        if downed then
            local ped = PlayerPedId()
            applyWrithe(ped)
            DisablePlayerFiring(PlayerId(), true)
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 22, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 30, true)
            DisableControlAction(0, 31, true)
            DisableControlAction(0, 32, true)
            DisableControlAction(0, 33, true)
            DisableControlAction(0, 34, true)
            DisableControlAction(0, 35, true)
            DisableControlAction(0, 44, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            SetEntityInvincible(ped, true)
            Wait(0)
        else
            Wait(400)
        end
    end
end)

CreateThread(function()
    local range = tonumber(Config.ReviveRange) or 4.0

    while true do
        local skip = not inMatch or downed or eliminated
        if not skip and GetResourceState('wtbg_spectator') == 'started' then
            local ok, spec = pcall(function()
                return exports.wtbg_spectator:IsSpectating()
            end)
            if ok and spec then
                skip = true
            end
        end
        if not skip and GetResourceState('wtbg_drop') == 'started' then
            local ok, landed = pcall(function()
                return exports.wtbg_drop:IsLanded()
            end)
            if ok and landed == false then
                skip = true
            end
        end

        if skip then
            if holdingTarget then
                stopHold()
            end
            setHint(nil)
            Wait(400)
        else
            local target = nearestDowned(range)
            if target then
                DisableControlAction(0, 38, true)
                DisableControlAction(0, 51, true)
                local info = downedPlayers[target]
                local kind = (myTeamId and info and tonumber(info.teamId) == myTeamId) and 'reviveHint' or 'finishHint'
                setHint(kind, target)

                local holding = isHoldingInteract()
                if holding then
                    holdGrace = GetGameTimer() + 400
                    local action = kind == 'reviveHint' and 'revive' or 'finish'
                    if holdingTarget ~= target or holdingKind ~= action then
                        if holdingTarget then
                            TriggerServerEvent('wtbg:combat:actionCancel', holdingTarget)
                        end
                        holdingTarget = target
                        holdingKind = action
                        if action == 'revive' then
                            TriggerServerEvent('wtbg:combat:reviveStart', target)
                        else
                            TriggerServerEvent('wtbg:combat:finishStart', target)
                        end
                    end
                elseif holdingTarget and GetGameTimer() > holdGrace then
                    stopHold()
                end
                Wait(0)
            else
                if holdingTarget and GetGameTimer() > holdGrace then
                    stopHold()
                end
                setHint(nil)
                Wait(200)
            end
        end
    end
end)

exports('IsDowned', function()
    return downed
end)

exports('BlockWorldInteract', function()
    if downed or not inMatch or eliminated then
        return true
    end

    if GetResourceState('wtbg_spectator') == 'started' then
        local ok, spec = pcall(function()
            return exports.wtbg_spectator:IsSpectating()
        end)
        if ok and spec then
            return true
        end
    end

    if GetResourceState('wtbg_drop') == 'started' then
        local ok, landed = pcall(function()
            return exports.wtbg_drop:IsLanded()
        end)
        if ok and landed == false then
            return true
        end
    end

    local range = tonumber(Config.ReviveRange) or 4.0
    return nearestDowned(range) ~= nil
end)

local feelByHash

local function weaponFeel(hash)
    if not feelByHash then
        feelByHash = {}
        local rows = WTBG.Balance and WTBG.Balance.WeaponFeel or {}
        for name, row in pairs(rows) do
            feelByHash[joaat(name)] = row
        end
    end
    return feelByHash[hash]
end

CreateThread(function()
    while true do
        if inMatch and not downed and not eliminated then
            local ped = PlayerPedId()
            local _, hash = GetCurrentPedWeapon(ped, true)
            local feel = weaponFeel(hash)
            if feel and feel.recoil then
                local amp = feel.recoil
                if IsPedSprinting(ped) or IsPedJumping(ped) then
                    amp = amp * 1.35
                end
                WTBG.Call(SetWeaponRecoilShakeAmplitude, hash, amp)
            end
            Wait(0)
        else
            Wait(400)
        end
    end
end)
