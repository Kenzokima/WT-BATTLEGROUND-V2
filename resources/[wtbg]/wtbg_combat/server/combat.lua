local deathLock = {}

local function applyLoadout(source)
    source = tonumber(source)
    if not source then
        return
    end

    local state = exports.wtbg_core:GetPlayerState(source)
    if not state or state.state ~= WTBG.PlayerStates.MATCH then
        return
    end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then
        TriggerClientEvent('wtbg:combat:applyLoadout', source)
        return
    end

    pcall(function()
        Weapons.ApplyLoadout(ped)
    end)
    TriggerClientEvent('wtbg:combat:applyLoadout', source)
end

AddEventHandler('wtbg:match:applyLoadout', function(source)
    deathLock[source] = nil
    applyLoadout(source)
end)

RegisterNetEvent('wtbg:combat:playerDied', function(killerId, weapon)
    local victim = tonumber(source)
    if not victim then
        return
    end

    if deathLock[victim] then
        return
    end

    local state = exports.wtbg_core:GetPlayerState(victim)
    if not state then
        return
    end

    if state.state ~= WTBG.PlayerStates.MATCH or not state.alive then
        return
    end

    deathLock[victim] = true

    local killer = tonumber(killerId)
    if killer then
        if killer == victim then
            killer = nil
        else
            local killerState = exports.wtbg_core:GetPlayerState(killer)
            if not killerState or killerState.matchId ~= state.matchId then
                killer = nil
            end
        end
    end

    local ok = exports.wtbg_match:ReportDeath(victim, killer, weapon)
    if not ok then
        deathLock[victim] = nil
    end
end)

AddEventHandler('wtbg:core:playerDropped', function(source)
    deathLock[source] = nil
end)

AddEventHandler('wtbg:core:returnedToLobby', function(source)
    deathLock[source] = nil
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    deathLock = {}
end)

exports('ApplyLoadout', applyLoadout)
