WTBG = WTBG or {}

WTBG.PlayerStates = {
    LOBBY = 'LOBBY',
    MATCH = 'MATCH',
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
