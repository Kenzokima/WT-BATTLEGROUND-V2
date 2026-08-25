WTBG = WTBG or {}

WTBG.PlayerStates = {
    LOBBY = 'LOBBY',
    MATCH = 'MATCH',
    KNOCKED = 'KNOCKED',
    DEAD = 'DEAD',
    RESULT = 'RESULT'
}

WTBG.MatchStates = {
    WAITING = 'WAITING',
    STARTING = 'STARTING',
    ACTIVE = 'ACTIVE',
    FINISHED = 'FINISHED',
    CLEANUP = 'CLEANUP'
}

function WTBG.Debug(...)
    if not Config.Debug then
        return
    end

    print('[WTBG]', ...)
end

function WTBG.CopyPlayerState(player)
    if not player then
        return nil
    end

    return {
        source = player.source,
        state = player.state,
        matchId = player.matchId,
        teamId = player.teamId,
        partyId = player.partyId,
        alive = player.alive,
        name = player.name
    }
end

function WTBG.ParseMatchId(value)
    if type(value) == 'string' then
        value = value:match('^%s*(.-)%s*$')
    end

    local id = tonumber(value)
    if not id then
        return nil
    end

    id = math.floor(id)
    if id < 1 then
        return nil
    end

    return id
end

function WTBG.PlayerName(source)
    local name = GetPlayerName(source)
    if type(name) ~= 'string' or name == '' then
        return ('Player %s'):format(source)
    end

    return name
end

function WTBG.Count(tbl)
    local n = 0
    for _ in pairs(tbl) do
        n = n + 1
    end
    return n
end

function WTBG.Call(fn, ...)
    if type(fn) ~= 'function' then
        return false
    end
    local ok = pcall(fn, ...)
    return ok
end

function WTBG.PedHealth(ped)
    if type(GetEntityHealth) ~= 'function' or not ped or ped == 0 then
        return nil
    end
    local ok, hp = pcall(GetEntityHealth, ped)
    if ok and type(hp) == 'number' then
        return hp
    end
    return nil
end

function WTBG.PedArmour(ped)
    if type(GetPedArmour) ~= 'function' or not ped or ped == 0 then
        return nil
    end
    local ok, ar = pcall(GetPedArmour, ped)
    if ok and type(ar) == 'number' then
        return ar
    end
    return nil
end

function WTBG.SetVitals(source, health, armor)
    source = tonumber(source)
    if not source then
        return
    end
    local ped = GetPlayerPed(source)
    if ped and ped ~= 0 then
        if type(health) == 'number' then
            WTBG.Call(SetEntityHealth, ped, health)
        end
        if type(armor) == 'number' then
            WTBG.Call(SetPedArmour, ped, armor)
        end
    end
    if IsDuplicityVersion() then
        TriggerClientEvent('wtbg:core:setVitals', source, health, armor)
    end
end

function WTBG.UsesBRDeployment(mode)
    if not Config.UseBRStartingLoadout then
        return false
    end
    return (mode or Config.MatchMode or 'SQUAD') ~= 'FFA'
end
