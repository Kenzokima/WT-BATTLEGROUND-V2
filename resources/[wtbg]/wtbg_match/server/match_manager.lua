WTBG.Match = {}

local matches = {}
local nextMatchId = 1001
local history = {}
local busy = {}

local function snapshot(match)
    if not match then
        return nil
    end

    local players = {}
    for source, member in pairs(match.players) do
        players[source] = {
            source = member.source,
            teamId = member.teamId,
            alive = member.alive,
            kills = member.kills,
            placement = member.placement,
            name = member.name
        }
    end

    return {
        id = match.id,
        state = match.state,
        bucket = match.bucket,
        host = match.host,
        alivePlayers = match.alivePlayers,
        winner = match.winner,
        winnerName = match.winnerName,
        createdAt = match.createdAt,
        playerCount = WTBG.Count(match.players),
        maxPlayers = Config.MaxPlayers,
        players = players
    }
end

local function getMatch(matchId)
    return matches[matchId]
end

local function foreachMember(match, fn)
    for source, member in pairs(match.players) do
        fn(source, member)
    end
end

local function recountAlive(match)
    local n = 0
    for _, member in pairs(match.players) do
        if member.alive then
            n = n + 1
        end
    end
    match.alivePlayers = n
    return n
end

local function pushHistory(entry)
    history[#history + 1] = entry
    if #history > 20 then
        table.remove(history, 1)
    end
end

local function lobbyStatus(match)
    return {
        status = ('Waiting - Match %s'):format(match.id),
        matchId = match.id,
        players = WTBG.Count(match.players),
        maxPlayers = Config.MaxPlayers,
        state = match.state
    }
end

local function hudPayload(match, member)
    return {
        alive = match.alivePlayers,
        kills = member and member.kills or 0
    }
end

local function broadcast(match, eventName, payload)
    foreachMember(match, function(source)
        TriggerClientEvent(eventName, source, payload)
    end)
end

local function updateLobbyUi(match)
    local payload = lobbyStatus(match)
    foreachMember(match, function(source)
        TriggerClientEvent('wtbg:ui:showLobby', source, payload)
    end)
end

local function updateHud(match)
    foreachMember(match, function(source, member)
        TriggerClientEvent('wtbg:ui:hud', source, hudPayload(match, member))
    end)
end

local function pickSpawn(match)
    local points = Config.MatchSpawnPoints
    local index = (match.nextSpawn % #points) + 1
    match.nextSpawn = match.nextSpawn + 1
    local point = points[index]
    return {
        x = point.x,
        y = point.y,
        z = point.z,
        w = point.w
    }, index
end

local function setBusy(source, value)
    busy[source] = value and true or nil
end

local function isBusy(source)
    return busy[source] == true
end

local function addMember(match, source)
    local member = {
        source = source,
        teamId = nil,
        alive = true,
        kills = 0,
        placement = nil,
        spawnIndex = nil,
        name = WTBG.PlayerName(source),
        joinedAt = os.time()
    }

    match.players[source] = member
    recountAlive(match)
    return member
end

local function removeMember(match, source)
    match.players[source] = nil
    recountAlive(match)
end

local function destroyMatch(matchId)
    local match = matches[matchId]
    if not match then
        return false
    end

    matches[matchId] = nil
    WTBG.Debug('destroyed match', matchId)
    return true
end

local function returnPlayersToLobby(match)
    foreachMember(match, function(source)
        exports.wtbg_core:SendToLobby(source)
    end)
end

local function findWinner(match)
    local winner = nil
    for source, member in pairs(match.players) do
        if member.alive then
            winner = source
            member.placement = 1
            break
        end
    end

    match.winner = winner
    match.winnerName = winner and match.players[winner].name or nil
    return winner
end

local function resultPayload(match, source)
    local member = match.players[source]
    local isWinner = match.winner == source

    return {
        isWinner = isWinner,
        winnerName = match.winnerName,
        kills = member and member.kills or 0,
        placement = member and member.placement or WTBG.Count(match.players),
        totalPlayers = WTBG.Count(match.players)
    }
end

local function finishMatch(match)
    if match.state ~= WTBG.MatchStates.ACTIVE then
        return false
    end

    match.state = WTBG.MatchStates.FINISHED
    findWinner(match)

    foreachMember(match, function(source, member)
        exports.wtbg_core:SetSessionState(source, WTBG.PlayerStates.RESULT)
        TriggerClientEvent('wtbg:match:finished', source)
        TriggerClientEvent('wtbg:ui:showResult', source, resultPayload(match, source))
    end)

    pushHistory({
        id = match.id,
        winner = match.winner,
        winnerName = match.winnerName,
        endedAt = os.time(),
        playerCount = WTBG.Count(match.players)
    })

    WTBG.Debug('match finished', match.id, match.winnerName or 'none')

    local matchId = match.id
    SetTimeout(Config.ResultDuration * 1000, function()
        local current = matches[matchId]
        if not current then
            return
        end

        current.state = WTBG.MatchStates.CLEANUP
        returnPlayersToLobby(current)
        destroyMatch(matchId)
    end)

    return true
end

local function preparePlayer(match, source, member)
    local spawn, spawnIndex = pickSpawn(match)
    member.spawnIndex = spawnIndex
    member.alive = true
    member.placement = nil

    SetPlayerRoutingBucket(source, match.bucket)
    exports.wtbg_core:SetMatch(source, match.id, member.teamId)
    exports.wtbg_core:SetAlive(source, true)
    exports.wtbg_core:SetSessionState(source, WTBG.PlayerStates.MATCH)

    TriggerClientEvent('wtbg:match:enter', source, spawn, Config.StartCountdown)
    TriggerClientEvent('wtbg:ui:showMatch', source, hudPayload(match, member))
end

local function abortStart(match)
    local matchId = match.id
    match.state = WTBG.MatchStates.WAITING

    foreachMember(match, function(source)
        exports.wtbg_core:Notify(source, 'Match start cancelled. Not enough players.')
        exports.wtbg_core:SendToLobby(source)
    end)

    destroyMatch(matchId)
end

function WTBG.Match.Get(matchId)
    return snapshot(getMatch(matchId))
end

function WTBG.Match.Create(source)
    source = tonumber(source)
    if not source then
        return nil, 'invalid_source'
    end

    if isBusy(source) then
        return nil, 'busy'
    end

    local player = exports.wtbg_core:GetPlayerState(source)
    if not player then
        return nil, 'no_session'
    end

    if player.matchId then
        return nil, 'already_in_match'
    end

    if player.state ~= WTBG.PlayerStates.LOBBY then
        return nil, 'not_in_lobby'
    end

    setBusy(source, true)

    local id = nextMatchId
    nextMatchId = nextMatchId + 1

    local match = {
        id = id,
        state = WTBG.MatchStates.WAITING,
        bucket = id,
        host = source,
        players = {},
        teams = {},
        alivePlayers = 0,
        winner = nil,
        winnerName = nil,
        createdAt = os.time(),
        nextSpawn = 0
    }

    SetRoutingBucketPopulationEnabled(match.bucket, false)
    matches[id] = match
    addMember(match, source)
    exports.wtbg_core:SetMatch(source, id, nil)
    updateLobbyUi(match)

    setBusy(source, false)
    WTBG.Debug('created match', id, 'host', source)
    return id, nil
end

function WTBG.Match.Join(source, matchId)
    source = tonumber(source)
    matchId = WTBG.ParseMatchId(matchId)
    if not source or not matchId then
        return false, 'invalid'
    end

    if isBusy(source) then
        return false, 'busy'
    end

    local player = exports.wtbg_core:GetPlayerState(source)
    if not player then
        return false, 'no_session'
    end

    if player.matchId then
        if player.matchId == matchId then
            return false, 'already_joined'
        end
        return false, 'already_in_match'
    end

    if player.state ~= WTBG.PlayerStates.LOBBY then
        return false, 'not_in_lobby'
    end

    local match = getMatch(matchId)
    if not match then
        return false, 'not_found'
    end

    if match.state ~= WTBG.MatchStates.WAITING then
        return false, 'not_joinable'
    end

    if WTBG.Count(match.players) >= Config.MaxPlayers then
        return false, 'full'
    end

    if match.players[source] then
        return false, 'already_joined'
    end

    setBusy(source, true)
    addMember(match, source)
    exports.wtbg_core:SetMatch(source, match.id, nil)
    updateLobbyUi(match)
    setBusy(source, false)

    WTBG.Debug('joined match', match.id, source)
    return true, nil
end

local function leaveActive(match, source)
    local member = match.players[source]
    if not member then
        return
    end

    if member.alive then
        member.alive = false
        member.placement = recountAlive(match) + 1
        exports.wtbg_core:SetAlive(source, false)
        exports.wtbg_core:SetSessionState(source, WTBG.PlayerStates.DEAD)
        updateHud(match)

        if match.alivePlayers <= 1 then
            finishMatch(match)
        end
    end

    removeMember(match, source)
end

function WTBG.Match.Leave(source)
    source = tonumber(source)
    if not source then
        return false, 'invalid'
    end

    local player = exports.wtbg_core:GetPlayerState(source)
    if not player or not player.matchId then
        return false, 'not_in_match'
    end

    local match = getMatch(player.matchId)
    if not match then
        exports.wtbg_core:SendToLobby(source)
        return true, nil
    end

    if match.state == WTBG.MatchStates.ACTIVE then
        leaveActive(match, source)
        exports.wtbg_core:SendToLobby(source)
        return true, nil
    end

    if match.state == WTBG.MatchStates.FINISHED or match.state == WTBG.MatchStates.CLEANUP then
        return false, 'match_ending'
    end

    removeMember(match, source)
    exports.wtbg_core:SendToLobby(source)

    if WTBG.Count(match.players) == 0 then
        destroyMatch(match.id)
        return true, nil
    end

    if match.host == source then
        local newHost = next(match.players)
        match.host = newHost
    end

    updateLobbyUi(match)
    return true, nil
end

function WTBG.Match.Start(source, matchId)
    source = tonumber(source)
    matchId = WTBG.ParseMatchId(matchId)

    local player = exports.wtbg_core:GetPlayerState(source)
    if not player then
        return false, 'no_session'
    end

    if not matchId then
        matchId = player.matchId
    end

    local match = getMatch(matchId)
    if not match then
        return false, 'not_found'
    end

    if not match.players[source] then
        return false, 'not_member'
    end

    if match.state ~= WTBG.MatchStates.WAITING then
        return false, 'not_waiting'
    end

    if WTBG.Count(match.players) < Config.MinPlayers then
        return false, 'not_enough_players'
    end

    match.state = WTBG.MatchStates.STARTING
    match.nextSpawn = 0
    recountAlive(match)

    foreachMember(match, function(src, member)
        preparePlayer(match, src, member)
    end)

    local id = match.id
    SetTimeout(Config.StartCountdown * 1000, function()
        local current = matches[id]
        if not current or current.state ~= WTBG.MatchStates.STARTING then
            return
        end

        if WTBG.Count(current.players) < Config.MinPlayers then
            abortStart(current)
            return
        end

        current.state = WTBG.MatchStates.ACTIVE
        current.startedAt = os.time()
        recountAlive(current)

        foreachMember(current, function(src, member)
            pcall(function()
                TriggerEvent('wtbg:match:applyLoadout', src)
            end)
            TriggerClientEvent('wtbg:match:begin', src)
            TriggerClientEvent('wtbg:ui:hud', src, hudPayload(current, member))
        end)

        WTBG.Debug('match active', current.id)
    end)

    WTBG.Debug('match starting', match.id)
    return true, nil
end

function WTBG.Match.ReportDeath(victim, killer, weapon)
    victim = tonumber(victim)
    killer = tonumber(killer)

    if not victim then
        return false, nil
    end

    local player = exports.wtbg_core:GetPlayerState(victim)
    if not player or not player.matchId then
        return false, nil
    end

    if player.state ~= WTBG.PlayerStates.MATCH or not player.alive then
        return false, nil
    end

    local match = getMatch(player.matchId)
    if not match or match.state ~= WTBG.MatchStates.ACTIVE then
        return false, nil
    end

    local member = match.players[victim]
    if not member or not member.alive then
        return false, nil
    end

    member.alive = false
    exports.wtbg_core:SetAlive(victim, false)
    exports.wtbg_core:SetSessionState(victim, WTBG.PlayerStates.DEAD)

    local alive = recountAlive(match)
    member.placement = alive + 1

    local killerMember = killer and match.players[killer] or nil
    if killer and killer ~= victim and killerMember then
        killerMember.kills = (killerMember.kills or 0) + 1
    else
        killer = nil
        killerMember = nil
    end

    local info = {
        matchId = match.id,
        victim = victim,
        victimName = member.name,
        killer = killer,
        killerName = killerMember and killerMember.name or nil,
        weapon = weapon,
        alivePlayers = match.alivePlayers,
        ended = false
    }

    updateHud(match)
    broadcast(match, 'wtbg:ui:killfeed', {
        killer = info.killerName,
        victim = info.victimName
    })

    TriggerClientEvent('wtbg:match:playerDied', victim)

    if match.alivePlayers <= 1 then
        info.ended = true
        finishMatch(match)
        info.winner = match.winner
        info.winnerName = match.winnerName
    end

    return true, info
end

function WTBG.Match.HandleDisconnect(source, state)
    source = tonumber(source)
    if not source then
        return
    end

    local matchId = state and state.matchId
    if not matchId then
        return
    end

    local match = getMatch(matchId)
    if not match then
        return
    end

    local member = match.players[source]
    if not member then
        return
    end

    if match.state == WTBG.MatchStates.ACTIVE then
        if member.alive then
            member.alive = false
            recountAlive(match)
            member.placement = match.alivePlayers + 1
            updateHud(match)
        end

        removeMember(match, source)

        if match.alivePlayers <= 1 then
            finishMatch(match)
        end

        if WTBG.Count(match.players) == 0 then
            destroyMatch(match.id)
        end
        return
    end

    removeMember(match, source)

    if match.state == WTBG.MatchStates.STARTING and WTBG.Count(match.players) < Config.MinPlayers then
        abortStart(match)
        return
    end

    if WTBG.Count(match.players) == 0 then
        destroyMatch(match.id)
        return
    end

    if match.host == source then
        match.host = next(match.players)
    end

    if match.state == WTBG.MatchStates.WAITING then
        updateLobbyUi(match)
    end
end

function WTBG.Match.List()
    local list = {}
    for id, match in pairs(matches) do
        list[#list + 1] = {
            id = id,
            state = match.state,
            players = WTBG.Count(match.players),
            maxPlayers = Config.MaxPlayers,
            alive = match.alivePlayers
        }
    end

    table.sort(list, function(a, b)
        return a.id < b.id
    end)

    return list
end

AddEventHandler('wtbg:core:playerDropped', function(source, state)
    WTBG.Match.HandleDisconnect(source, state)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    for _, id in ipairs(GetPlayers()) do
        local source = tonumber(id)
        local state = exports.wtbg_core:GetPlayerState(source)
        if state and state.matchId then
            exports.wtbg_core:SendToLobby(source)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    for _, match in pairs(matches) do
        returnPlayersToLobby(match)
    end

    matches = {}
end)

exports('GetMatch', function(matchId)
    return WTBG.Match.Get(WTBG.ParseMatchId(matchId))
end)

exports('CreateMatch', function(source)
    return WTBG.Match.Create(source)
end)

exports('JoinMatch', function(source, matchId)
    return WTBG.Match.Join(source, matchId)
end)

exports('LeaveMatch', function(source)
    return WTBG.Match.Leave(source)
end)

exports('StartMatch', function(source, matchId)
    return WTBG.Match.Start(source, matchId)
end)

exports('ReportDeath', function(victim, killer, weapon)
    return WTBG.Match.ReportDeath(victim, killer, weapon)
end)

exports('ListMatches', function()
    return WTBG.Match.List()
end)
