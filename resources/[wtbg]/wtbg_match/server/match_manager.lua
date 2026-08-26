WTBG.Match = {}

local matches = {}
local nextMatchId = 1001
local history = {}
local busy = {}

local function matchMode()
    local mode = Config.MatchMode or 'SQUAD'
    if mode == 'FFA' then
        return 'FFA'
    end
    return 'SQUAD'
end

local function isSoloTest(match)
    return Config.Debug == true
        and Config.AllowSoloTest == true
        and match ~= nil
        and WTBG.Count(match.players) == 1
end

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
            downed = member.downed == true,
            kills = member.kills,
            placement = member.placement,
            name = member.name
        }
    end

    local teams = {}
    for id, team in pairs(match.teams) do
        teams[id] = {
            id = team.id,
            alivePlayers = team.alivePlayers,
            eliminated = team.eliminated,
            kills = team.kills,
            placement = team.placement,
            playerCount = WTBG.Count(team.players)
        }
    end

    return {
        id = match.id,
        state = match.state,
        mode = match.mode,
        bucket = match.bucket,
        host = match.host,
        alivePlayers = match.alivePlayers,
        aliveTeams = match.aliveTeams,
        winner = match.winner,
        winnerName = match.winnerName,
        winnerTeamId = match.winnerTeamId,
        createdAt = match.createdAt,
        playerCount = WTBG.Count(match.players),
        maxPlayers = Config.MaxPlayers,
        players = players,
        teams = teams
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

local function isStanding(member)
    return member and member.alive == true and member.downed ~= true
end

local function recountAlive(match)
    local n = 0
    for _, member in pairs(match.players) do
        if isStanding(member) then
            n = n + 1
        end
    end
    match.alivePlayers = n
    return n
end

local function recountAliveTeams(match)
    local n = 0
    for _, team in pairs(match.teams) do
        local standing = 0
        for src, _ in pairs(team.players) do
            if isStanding(match.players[src]) then
                standing = standing + 1
            end
        end
        team.alivePlayers = standing
        team.eliminated = standing <= 0
        if not team.eliminated then
            n = n + 1
        end
    end
    match.aliveTeams = n
    return n
end

local function creditKill(match, killerSource)
    killerSource = tonumber(killerSource)
    if not match or not killerSource then
        return false
    end

    local killerMember = match.players[killerSource]
    if not killerMember then
        return false
    end

    killerMember.kills = (killerMember.kills or 0) + 1
    local team = match.teams[killerMember.teamId]
    if team then
        team.kills = (team.kills or 0) + 1
    end
    return true
end

local function creditDownedTeam(match, team)
    if not team then
        return
    end

    for src, _ in pairs(team.players) do
        local mate = match.players[src]
        if mate and mate.downed and mate.downedBy and not mate.killCredited then
            if creditKill(match, mate.downedBy) then
                mate.killCredited = true
            end
        end
    end
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
        state = match.state,
        mode = match.mode
    }
end

local function squadList(match, member)
    if not match or not member or match.mode ~= 'SQUAD' then
        return nil
    end

    local team = match.teams[member.teamId]
    if not team then
        return nil
    end

    local list = {}
    for src, _ in pairs(team.players) do
        local mate = match.players[src]
        if mate then
            list[#list + 1] = {
                source = src,
                name = mate.name,
                alive = mate.alive == true,
                downed = mate.downed == true
            }
        end
    end

    table.sort(list, function(a, b)
        return a.source < b.source
    end)

    return list
end

local function hudPayload(match, member)
    return {
        alive = match.alivePlayers,
        kills = member and member.kills or 0,
        mode = match.mode,
        teamId = member and member.teamId or nil,
        squad = squadList(match, member)
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

local function createTeam(match)
    local id = match.nextTeamId
    match.nextTeamId = id + 1
    local team = {
        id = id,
        players = {},
        alivePlayers = 0,
        eliminated = false,
        kills = 0,
        placement = nil
    }
    match.teams[id] = team
    return team
end

local function addMember(match, source, teamId)
    local member = {
        source = source,
        teamId = teamId,
        alive = true,
        downed = false,
        downedBy = nil,
        killCredited = false,
        kills = 0,
        placement = nil,
        spawnIndex = nil,
        name = WTBG.PlayerName(source),
        joinedAt = os.time()
    }

    match.players[source] = member
    local team = match.teams[teamId]
    if team then
        team.players[source] = true
    end
    recountAlive(match)
    recountAliveTeams(match)
    return member
end

local function removeFromTeam(match, source, member)
    if not member then
        return
    end

    local team = match.teams[member.teamId]
    if not team then
        return
    end

    team.players[source] = nil
    if WTBG.Count(team.players) == 0 then
        match.teams[member.teamId] = nil
    end
    recountAliveTeams(match)
end

local function removeMember(match, source)
    local member = match.players[source]
    match.players[source] = nil
    removeFromTeam(match, source, member)
    recountAlive(match)
end

local function destroyMatch(matchId)
    local match = matches[matchId]
    if not match then
        return false
    end

    matches[matchId] = nil
    TriggerEvent('wtbg:match:destroyed', matchId)
    WTBG.Debug('destroyed match', matchId)
    return true
end

local function returnPlayersToLobby(match)
    foreachMember(match, function(source)
        exports.wtbg_core:SendToLobby(source)
    end)
end

local function shouldEnd(match)
    return recountAliveTeams(match) <= 1
end

local function findWinner(match)
    recountAliveTeams(match)
    local winnerTeam = nil
    for _, team in pairs(match.teams) do
        if not team.eliminated then
            winnerTeam = team
            break
        end
    end

    match.winnerTeamId = winnerTeam and winnerTeam.id or nil
    match.winner = nil
    match.winnerName = nil

    if winnerTeam then
        winnerTeam.placement = 1
        local names = {}
        for src, _ in pairs(winnerTeam.players) do
            local member = match.players[src]
            if member then
                member.placement = 1
                if member.alive then
                    match.winner = src
                end
                names[#names + 1] = member.name
            end
        end

        if match.mode == 'SQUAD' then
            match.winnerName = ('TEAM %s'):format(winnerTeam.id)
        else
            match.winnerName = winnerTeam and match.winner and match.players[match.winner].name or names[1]
        end
    end

    return match.winnerTeamId
end

local function resultPayload(match, source)
    local member = match.players[source]
    local team = member and match.teams[member.teamId] or nil
    local isWinner = member and match.winnerTeamId ~= nil and member.teamId == match.winnerTeamId

    return {
        isWinner = isWinner and true or false,
        winnerName = match.winnerName,
        winnerTeamId = match.winnerTeamId,
        mode = match.mode,
        kills = member and member.kills or 0,
        teamKills = team and team.kills or 0,
        placement = (team and team.placement) or (member and member.placement) or WTBG.Count(match.teams),
        totalPlayers = WTBG.Count(match.players),
        totalTeams = WTBG.Count(match.teams),
        teammates = squadList(match, member)
    }
end

local function finishMatch(match)
    if match.state ~= WTBG.MatchStates.ACTIVE then
        return false
    end

    match.state = WTBG.MatchStates.FINISHED
    findWinner(match)
    TriggerEvent('wtbg:match:serverFinished', match.id)

    foreachMember(match, function(source)
        exports.wtbg_core:SetSessionState(source, WTBG.PlayerStates.RESULT)
        TriggerClientEvent('wtbg:match:finished', source)
        TriggerClientEvent('wtbg:ui:showResult', source, resultPayload(match, source))
    end)

    pushHistory({
        id = match.id,
        winner = match.winner,
        winnerName = match.winnerName,
        winnerTeamId = match.winnerTeamId,
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

local function markEliminated(match, source, killer)
    local member = match.players[source]
    if not member or not member.alive then
        return false
    end

    member.alive = false
    member.downed = false
    exports.wtbg_core:SetAlive(source, false)
    exports.wtbg_core:SetSessionState(source, WTBG.PlayerStates.DEAD)

    recountAlive(match)
    recountAliveTeams(match)

    local team = match.teams[member.teamId]
    if team then
        if team.eliminated and not team.placement then
            team.placement = match.aliveTeams + 1
        end
        member.placement = team.placement or (match.alivePlayers + 1)
    else
        member.placement = match.alivePlayers + 1
    end

    TriggerEvent('wtbg:match:playerEliminated', source, match.id, match.state, tonumber(killer))

    return true
end

local function useDrop(match)
    if GetResourceState('wtbg_drop') ~= 'started' then
        return false
    end
    local ok, uses = pcall(function()
        return exports.wtbg_drop:UsesMatch(match.id)
    end)
    return ok and uses == true
end

local function preparePlayer(match, source, member)
    local spawn, spawnIndex = pickSpawn(match)
    member.spawnIndex = spawnIndex
    member.alive = true
    member.downed = false
    member.downedBy = nil
    member.killCredited = false
    member.placement = nil

    SetPlayerRoutingBucket(source, match.bucket)
    exports.wtbg_core:SetMatch(source, match.id, member.teamId)
    exports.wtbg_core:SetAlive(source, true)
    exports.wtbg_core:SetSessionState(source, WTBG.PlayerStates.MATCH)

    TriggerClientEvent('wtbg:match:setTeam', source, member.teamId, Config.FriendlyFire and true or false)
    TriggerClientEvent('wtbg:ui:showMatch', source, hudPayload(match, member))

    if useDrop(match) then
        return
    end

    TriggerClientEvent('wtbg:match:enter', source, spawn, Config.StartCountdown)
end

local function abortStart(match)
    local matchId = match.id
    match.state = WTBG.MatchStates.WAITING

    foreachMember(match, function(source)
        exports.wtbg_core:Notify(source, 'Match start cancelled. Not enough teams.')
        exports.wtbg_core:SendToLobby(source)
    end)

    destroyMatch(matchId)
end

local function resolveJoiners(source)
    if GetResourceState('wtbg_party') ~= 'started' then
        return { source }
    end

    local party = exports.wtbg_party:GetPlayerParty(source)
    if not party then
        return { source }
    end

    if party.leader ~= source then
        return nil, 'not_party_leader'
    end

    local list = {}
    for i = 1, #party.members do
        list[i] = party.members[i].source
    end
    return list
end

local function validateJoiners(match, joiners)
    if #joiners < 1 then
        return false, 'invalid'
    end

    if WTBG.Count(match.players) + #joiners > Config.MaxPlayers then
        return false, 'full'
    end

    for i = 1, #joiners do
        local src = joiners[i]
        if isBusy(src) then
            return false, 'busy'
        end

        if not GetPlayerName(src) then
            return false, 'party_member_offline'
        end

        local state = exports.wtbg_core:GetPlayerState(src)
        if not state then
            return false, 'no_session'
        end

        if state.matchId then
            return false, 'already_in_match'
        end

        if state.state ~= WTBG.PlayerStates.LOBBY then
            return false, 'not_in_lobby'
        end

        if match.players[src] then
            return false, 'already_joined'
        end
    end

    return true, nil
end

local function addJoiners(match, joiners)
    if match.mode == 'SQUAD' then
        local team = createTeam(match)
        for i = 1, #joiners do
            addMember(match, joiners[i], team.id)
            exports.wtbg_core:SetMatch(joiners[i], match.id, team.id)
        end
        return
    end

    for i = 1, #joiners do
        local team = createTeam(match)
        addMember(match, joiners[i], team.id)
        exports.wtbg_core:SetMatch(joiners[i], match.id, team.id)
    end
end

function WTBG.Match.Get(matchId)
    return snapshot(getMatch(matchId))
end

function WTBG.Match.Create(source)
    source = tonumber(source)
    if not source then
        return nil, 'invalid_source'
    end

    local joiners, err = resolveJoiners(source)
    if not joiners then
        return nil, err
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

    local id = nextMatchId
    nextMatchId = nextMatchId + 1

    local match = {
        id = id,
        state = WTBG.MatchStates.WAITING,
        mode = matchMode(),
        bucket = id,
        host = source,
        players = {},
        teams = {},
        alivePlayers = 0,
        aliveTeams = 0,
        nextTeamId = 1,
        winner = nil,
        winnerName = nil,
        winnerTeamId = nil,
        createdAt = os.time(),
        nextSpawn = 0
    }

    local ok, joinErr = validateJoiners(match, joiners)
    if not ok then
        return nil, joinErr
    end

    for i = 1, #joiners do
        setBusy(joiners[i], true)
    end

    SetRoutingBucketPopulationEnabled(match.bucket, false)
    matches[id] = match
    addJoiners(match, joiners)
    updateLobbyUi(match)

    for i = 1, #joiners do
        setBusy(joiners[i], false)
    end

    WTBG.Debug('created match', id, 'host', source, 'mode', match.mode)
    return id, nil
end

function WTBG.Match.Join(source, matchId)
    source = tonumber(source)
    matchId = WTBG.ParseMatchId(matchId)
    if not source or not matchId then
        return false, 'invalid'
    end

    local joiners, err = resolveJoiners(source)
    if not joiners then
        return false, err
    end

    local match = getMatch(matchId)
    if not match then
        return false, 'not_found'
    end

    if match.state ~= WTBG.MatchStates.WAITING then
        return false, 'not_joinable'
    end

    local ok, joinErr = validateJoiners(match, joiners)
    if not ok then
        return false, joinErr
    end

    for i = 1, #joiners do
        setBusy(joiners[i], true)
    end

    addJoiners(match, joiners)
    updateLobbyUi(match)

    for i = 1, #joiners do
        setBusy(joiners[i], false)
    end

    WTBG.Debug('joined match', match.id, source, 'group', #joiners)
    return true, nil
end

local function leaveActive(match, source)
    local member = match.players[source]
    if not member then
        return
    end

    if member.alive then
        markEliminated(match, source)
        updateHud(match)
        if shouldEnd(match) then
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
        match.host = next(match.players)
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

    if WTBG.Count(match.players) < Config.MinPlayers and not isSoloTest(match) then
        return false, 'not_enough_players'
    end

    recountAliveTeams(match)
    if match.aliveTeams < 2 and not isSoloTest(match) then
        return false, 'not_enough_teams'
    end

    match.state = WTBG.MatchStates.STARTING
    match.nextSpawn = 0
    recountAlive(match)
    recountAliveTeams(match)

    foreachMember(match, function(src, member)
        preparePlayer(match, src, member)
    end)

    TriggerEvent('wtbg:match:starting', match.id, match.bucket)

    local id = match.id
    SetTimeout(Config.StartCountdown * 1000, function()
        local current = matches[id]
        if not current or current.state ~= WTBG.MatchStates.STARTING then
            return
        end

        recountAliveTeams(current)
        if (WTBG.Count(current.players) < Config.MinPlayers or current.aliveTeams < 2)
            and not isSoloTest(current) then
            abortStart(current)
            return
        end

        current.state = WTBG.MatchStates.ACTIVE
        current.startedAt = os.time()
        recountAlive(current)
        recountAliveTeams(current)
        TriggerEvent('wtbg:match:becameActive', current.id, current.bucket)

        foreachMember(current, function(src, member)
            if not useDrop(current) then
                pcall(function()
                    TriggerEvent('wtbg:match:applyLoadout', src)
                end)
            end
            TriggerClientEvent('wtbg:match:begin', src)
            TriggerClientEvent('wtbg:match:setTeam', src, member.teamId, Config.FriendlyFire and true or false)
            TriggerClientEvent('wtbg:ui:hud', src, hudPayload(current, member))
        end)

        WTBG.Debug('match active', current.id)
    end)

    WTBG.Debug('match starting', match.id)
    return true, nil
end

function WTBG.Match.ReportDeath(victim, killer, weapon, kind)
    victim = tonumber(victim)
    killer = tonumber(killer)

    if not victim then
        return false, nil
    end

    local player = exports.wtbg_core:GetPlayerState(victim)
    if not player or not player.matchId then
        return false, nil
    end

    if not player.alive then
        return false, nil
    end

    if player.state ~= WTBG.PlayerStates.MATCH and player.state ~= WTBG.PlayerStates.KNOCKED then
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

    local killerMember = killer and match.players[killer] or nil
    if member.killCredited then
        killerMember = killer and match.players[killer] or killerMember
    elseif killer and killer ~= victim and killerMember then
        local sameTeam = member.teamId ~= nil and member.teamId == killerMember.teamId
        if sameTeam then
            killer = nil
            killerMember = nil
        else
            creditKill(match, killer)
            member.killCredited = true
            member.downedBy = killer
        end
    else
        killer = nil
        killerMember = nil
    end

    markEliminated(match, victim, killer)

    local info = {
        matchId = match.id,
        victim = victim,
        victimName = member.name,
        killer = killer,
        killerName = killerMember and killerMember.name or nil,
        weapon = weapon,
        alivePlayers = match.alivePlayers,
        aliveTeams = match.aliveTeams,
        ended = false
    }

    updateHud(match)
    broadcast(match, 'wtbg:ui:killfeed', {
        killer = info.killerName,
        victim = info.victimName,
        kind = kind or 'kill'
    })

    TriggerClientEvent('wtbg:match:playerDied', victim)

    if shouldEnd(match) then
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
            markEliminated(match, source)
            updateHud(match)
        end

        removeMember(match, source)

        if shouldEnd(match) then
            finishMatch(match)
        end

        if WTBG.Count(match.players) == 0 then
            destroyMatch(match.id)
        end
        return
    end

    removeMember(match, source)

    recountAliveTeams(match)
    if match.state == WTBG.MatchStates.STARTING
        and (WTBG.Count(match.players) < Config.MinPlayers or match.aliveTeams < 2)
        and not isSoloTest(match) then
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
            mode = match.mode,
            players = WTBG.Count(match.players),
            maxPlayers = Config.MaxPlayers,
            alive = match.alivePlayers,
            aliveTeams = match.aliveTeams
        }
    end

    table.sort(list, function(a, b)
        return a.id < b.id
    end)

    return list
end

function WTBG.Match.SetDowned(source, downed, killer)
    source = tonumber(source)
    if not source then
        return false
    end

    local player = exports.wtbg_core:GetPlayerState(source)
    if not player or not player.matchId then
        return false
    end

    local match = getMatch(player.matchId)
    if not match then
        return false
    end

    local member = match.players[source]
    if not member or not member.alive then
        return false
    end

    member.downed = downed and true or false
    if member.downed then
        member.downedBy = tonumber(killer)
        TriggerEvent('wtbg:match:playerDowned', source, match.id)
    else
        member.downedBy = nil
    end

    recountAlive(match)
    recountAliveTeams(match)

    if member.downed then
        local team = match.teams[member.teamId]
        if team and team.eliminated then
            if not team.placement then
                team.placement = match.aliveTeams + 1
                member.placement = team.placement
            end
            creditDownedTeam(match, team)
        end
    end

    updateHud(match)

    if member.downed and match.state == WTBG.MatchStates.ACTIVE and shouldEnd(match) then
        finishMatch(match)
    end

    return true
end

function WTBG.Match.GetMember(source)
    source = tonumber(source)
    if not source then
        return nil
    end

    local player = exports.wtbg_core:GetPlayerState(source)
    if not player or not player.matchId then
        return nil
    end

    local match = getMatch(player.matchId)
    if not match then
        return nil
    end

    local member = match.players[source]
    if not member then
        return nil
    end

    return {
        matchId = match.id,
        matchState = match.state,
        mode = match.mode,
        bucket = match.bucket,
        teamId = member.teamId,
        alive = member.alive == true,
        downed = member.downed == true,
        name = member.name
    }
end

function WTBG.Match.GetMatchSources(matchId)
    local match = getMatch(tonumber(matchId))
    if not match then
        return {}
    end

    local list = {}
    for src, _ in pairs(match.players) do
        list[#list + 1] = tonumber(src)
    end
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

exports('ReportDeath', function(victim, killer, weapon, kind)
    return WTBG.Match.ReportDeath(victim, killer, weapon, kind)
end)

exports('SetDowned', function(source, downed, killer)
    return WTBG.Match.SetDowned(tonumber(source), downed, killer)
end)

exports('GetMember', function(source)
    return WTBG.Match.GetMember(tonumber(source))
end)

exports('GetMatchSources', function(matchId)
    return WTBG.Match.GetMatchSources(matchId)
end)

exports('ListMatches', function()
    return WTBG.Match.List()
end)
