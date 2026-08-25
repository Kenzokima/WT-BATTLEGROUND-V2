local reported = false

local function applyLocalLoadout()
    local ped = PlayerPedId()
    Weapons.ApplyLoadout(ped)
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

local function reportDeath()
    if reported then
        return
    end

    reported = true
    local ped = PlayerPedId()
    local killer = resolveKiller(ped)
    local weapon = GetPedCauseOfDeath(ped)
    TriggerServerEvent('wtbg:combat:playerDied', killer, weapon)
end

RegisterNetEvent('wtbg:combat:applyLoadout', function()
    applyLocalLoadout()
end)

RegisterNetEvent('wtbg:match:begin', function()
    reported = false
    applyLocalLoadout()
end)

RegisterNetEvent('wtbg:core:spawnLobby', function()
    reported = false
end)

RegisterNetEvent('wtbg:match:enter', function()
    reported = false
end)

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then
        return
    end

    local victim = args[1]
    if victim ~= PlayerPedId() then
        return
    end

    if not IsEntityDead(victim) and not IsPedDeadOrDying(victim, true) then
        return
    end

    reportDeath()
end)

AddEventHandler('baseevents:onPlayerKilled', function(killerId)
    if reported then
        return
    end

    reported = true
    TriggerServerEvent('wtbg:combat:playerDied', tonumber(killerId), nil)
end)

AddEventHandler('baseevents:onPlayerDied', function()
    reportDeath()
end)

CreateThread(function()
    local wasDead = false

    while true do
        local ped = PlayerPedId()
        local dead = IsEntityDead(ped) or IsPedDeadOrDying(ped, true) or IsPlayerDead(PlayerId())

        if dead and not wasDead then
            reportDeath()
        end

        if not dead then
            reported = false
        end

        wasDead = dead
        Wait(200)
    end
end)
