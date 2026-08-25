local function placeInLobby(source)
    if not WTBG.Players.Exists(source) then
        WTBG.Players.Init(source)
    end

    WTBG.Players.SendToLobby(source)
end

RegisterNetEvent('wtbg:core:sessionReady', function()
    local source = tonumber(source)
    if not source or source < 1 then
        return
    end

    if WTBG.Players.Exists(source) then
        local player = WTBG.Players.Get(source)
        if player and (player.state == WTBG.PlayerStates.LOBBY or not player.matchId) then
            WTBG.Players.SendToLobby(source)
        end
        WTBG.Profiles.BeginLoad(source)
        return
    end

    placeInLobby(source)
    WTBG.Profiles.BeginLoad(source)
end)

AddEventHandler('playerDropped', function()
    local source = tonumber(source)
    if not source then
        return
    end

    local state = WTBG.Players.GetState(source)
    WTBG.Players.Remove(source)
    TriggerEvent('wtbg:core:playerDropped', source, state)
    WTBG.Debug('player dropped', source)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    for _, id in ipairs(GetPlayers()) do
        local source = tonumber(id)
        placeInLobby(source)
        WTBG.Profiles.BeginLoad(source)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    for _, id in ipairs(GetPlayers()) do
        local source = tonumber(id)
        SetPlayerRoutingBucket(source, Config.LobbyBucket)
    end
end)

local function canDev(source)
    if source == 0 then
        return true
    end
    return Config.Debug or IsPlayerAceAllowed(source, Config.DevAce)
end

RegisterCommand('balanceinfo', function(source)
    if not canDev(source) then
        return
    end
    local b = WTBG.Balance
    local msg = ('%s  HP=%s armor=%s bleed=%ss revive=%ss finish=%ss kit=%ss bandage=%ss plane=%ss veh=%s zoneScale=%s result=%ss'):format(
        b.Preset,
        b.Combat.Health,
        b.Combat.MaxArmor,
        b.Combat.BleedoutTime,
        b.Combat.ReviveTime,
        b.Combat.FinishTime,
        b.Medical.MedkitUseTime,
        b.Medical.BandageUseTime,
        b.Drop.RouteDuration,
        b.Vehicle.SpawnCount,
        b.Zone.TimeScale,
        b.Match.ResultDuration
    )
    if source == 0 then
        print('[WTBG]', msg)
    else
        WTBG.Players.Notify(source, msg)
    end
end, false)

local function printProfile(source)
    if source == 0 then
        print('[WTBG] profileinfo requires a player')
        return
    end
    if not canDev(source) then
        return
    end
    local stats = WTBG.Profiles.GetStats(source)
    local profile = WTBG.Profiles.Get(source)
    if not stats then
        WTBG.Players.Notify(source, 'Profile not loaded')
        return
    end
    local msg = ('%s  %s  matches=%s wins=%s kills=%s deaths=%s kd=%s dmg=%s place=%s persist=%s'):format(
        stats.name or '?',
        profile and profile.license or 'no-license',
        stats.matches,
        stats.wins,
        stats.kills,
        stats.deaths,
        stats.kd,
        stats.damage,
        stats.avgPlacement,
        tostring(stats.persist)
    )
    WTBG.Players.Notify(source, msg)
    WTBG.Debug(msg)
end

RegisterCommand('profileinfo', function(source)
    printProfile(source)
end, false)

RegisterCommand('statsinfo', function(source)
    printProfile(source)
end, false)
