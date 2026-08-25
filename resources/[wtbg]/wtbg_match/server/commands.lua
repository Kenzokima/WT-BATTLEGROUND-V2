local errors = {
    invalid = 'Invalid match ID.',
    invalid_source = 'Invalid player.',
    busy = 'Please wait.',
    no_session = 'Session is not ready.',
    already_in_match = 'You are already in a match.',
    already_joined = 'You already joined this match.',
    not_in_lobby = 'You must be in the lobby.',
    not_found = 'Match does not exist.',
    not_joinable = 'That match cannot be joined.',
    full = 'That match is full.',
    not_in_match = 'You are not in a match.',
    match_ending = 'The match is already ending.',
    not_member = 'You are not in that match.',
    not_waiting = 'That match is not waiting to start.',
    not_enough_players = ('Need at least %s players to start.'):format(Config.MinPlayers)
}

local function tell(source, message)
    exports.wtbg_core:Notify(source, message)
end

local function fail(source, err)
    tell(source, errors[err] or 'Cannot do that.')
end

local function canDev(source)
    if source == 0 then
        return true
    end

    return Config.Debug or IsPlayerAceAllowed(source, Config.DevAce)
end

RegisterNetEvent('wtbg:match:create', function()
    local source = tonumber(source)
    if not source or not canDev(source) then
        if source and source > 0 then
            tell(source, 'This command is for development only.')
        end
        return
    end

    local id, err = WTBG.Match.Create(source)
    if not id then
        fail(source, err)
        return
    end

    tell(source, ('Match %s created. Waiting for players.'):format(id))
end)

RegisterNetEvent('wtbg:match:join', function(matchId)
    local source = tonumber(source)
    if not source or not canDev(source) then
        if source and source > 0 then
            tell(source, 'This command is for development only.')
        end
        return
    end

    local ok, err = WTBG.Match.Join(source, matchId)
    if not ok then
        fail(source, err)
        return
    end

    tell(source, ('Joined match %s.'):format(WTBG.ParseMatchId(matchId)))
end)

RegisterNetEvent('wtbg:match:start', function(matchId)
    local source = tonumber(source)
    if not source or not canDev(source) then
        if source and source > 0 then
            tell(source, 'This command is for development only.')
        end
        return
    end

    local ok, err = WTBG.Match.Start(source, matchId)
    if not ok then
        fail(source, err)
        return
    end

    tell(source, 'Match starting.')
end)

RegisterNetEvent('wtbg:match:leave', function()
    local source = tonumber(source)
    if not source then
        return
    end

    local ok, err = WTBG.Match.Leave(source)
    if not ok then
        fail(source, err)
        return
    end

    tell(source, 'Returned to lobby.')
end)

RegisterCommand('creatematch', function(source)
    if source == 0 then
        print('[WTBG] creatematch must be used in-game.')
        return
    end

    if not canDev(source) then
        tell(source, 'This command is for development only.')
        return
    end

    local id, err = WTBG.Match.Create(source)
    if not id then
        fail(source, err)
        return
    end

    tell(source, ('Match %s created. Waiting for players.'):format(id))
end, false)

RegisterCommand('joinmatch', function(source, args)
    if source == 0 then
        print('[WTBG] joinmatch must be used in-game.')
        return
    end

    if not canDev(source) then
        tell(source, 'This command is for development only.')
        return
    end

    local ok, err = WTBG.Match.Join(source, args[1])
    if not ok then
        fail(source, err)
        return
    end

    tell(source, ('Joined match %s.'):format(WTBG.ParseMatchId(args[1])))
end, false)

RegisterCommand('startmatch', function(source, args)
    if source == 0 then
        print('[WTBG] startmatch must be used in-game.')
        return
    end

    if not canDev(source) then
        tell(source, 'This command is for development only.')
        return
    end

    local ok, err = WTBG.Match.Start(source, args[1])
    if not ok then
        fail(source, err)
        return
    end

    tell(source, 'Match starting.')
end, false)

RegisterCommand('leavematch', function(source)
    if source == 0 then
        print('[WTBG] leavematch must be used in-game.')
        return
    end

    local ok, err = WTBG.Match.Leave(source)
    if not ok then
        fail(source, err)
        return
    end

    tell(source, 'Returned to lobby.')
end, false)

RegisterCommand('matches', function(source)
    if source ~= 0 and not canDev(source) then
        tell(source, 'This command is for development only.')
        return
    end

    local list = WTBG.Match.List()
    if #list == 0 then
        if source == 0 then
            print('[WTBG] No matches.')
        else
            tell(source, 'No matches.')
        end
        return
    end

    for i = 1, #list do
        local row = list[i]
        local line = ('#%s  %s  %s/%s  alive %s'):format(row.id, row.state, row.players, row.maxPlayers, row.alive)
        if source == 0 then
            print('[WTBG]', line)
        else
            tell(source, line)
        end
    end
end, false)
