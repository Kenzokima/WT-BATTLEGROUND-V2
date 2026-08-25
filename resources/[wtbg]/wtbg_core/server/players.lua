WTBG.Players = {}

local players = {}
local sessionReady = {}

local function newPlayer(source)
    return {
        source = source,
        state = WTBG.PlayerStates.LOBBY,
        matchId = nil,
        teamId = nil,
        alive = true,
        name = WTBG.PlayerName(source)
    }
end

function WTBG.Players.Get(source)
    return players[source]
end

function WTBG.Players.GetState(source)
    return WTBG.CopyPlayerState(players[source])
end

function WTBG.Players.GetMatchId(source)
    local player = players[source]
    if not player then
        return nil
    end

    return player.matchId
end

function WTBG.Players.IsAlive(source)
    local player = players[source]
    return player ~= nil and player.alive == true
end

function WTBG.Players.Exists(source)
    return players[source] ~= nil
end

function WTBG.Players.Init(source)
    source = tonumber(source)
    if not source then
        return nil
    end

    local player = newPlayer(source)
    players[source] = player
    sessionReady[source] = true
    WTBG.Debug('init player', source, player.name)
    return player
end

function WTBG.Players.SetSessionState(source, state)
    local player = players[source]
    if not player then
        return false
    end

    if not WTBG.PlayerStates[state] then
        return false
    end

    player.state = state
    return true
end

function WTBG.Players.SetMatch(source, matchId, teamId)
    local player = players[source]
    if not player then
        return false
    end

    player.matchId = matchId
    player.teamId = teamId
    return true
end

function WTBG.Players.SetAlive(source, alive)
    local player = players[source]
    if not player then
        return false
    end

    player.alive = alive and true or false
    return true
end

function WTBG.Players.ClearMatch(source)
    local player = players[source]
    if not player then
        return false
    end

    player.matchId = nil
    player.teamId = nil
    player.alive = true
    player.state = WTBG.PlayerStates.LOBBY
    return true
end

function WTBG.Players.SendToLobby(source)
    source = tonumber(source)
    local player = players[source]
    if not player then
        return false
    end

    SetPlayerRoutingBucket(source, Config.LobbyBucket)
    player.matchId = nil
    player.teamId = nil
    player.alive = true
    player.state = WTBG.PlayerStates.LOBBY

    TriggerClientEvent('wtbg:core:spawnLobby', source, {
        x = Config.LobbyCoords.x,
        y = Config.LobbyCoords.y,
        z = Config.LobbyCoords.z,
        w = Config.LobbyCoords.w
    })

    TriggerClientEvent('wtbg:ui:showLobby', source, {
        status = 'Lobby',
        matchId = nil,
        players = 0,
        maxPlayers = Config.MaxPlayers
    })

    TriggerEvent('wtbg:core:returnedToLobby', source)
    WTBG.Debug('sent to lobby', source)
    return true
end

function WTBG.Players.Remove(source)
    players[source] = nil
    sessionReady[source] = nil
end

function WTBG.Players.IsSessionReady(source)
    return sessionReady[source] == true
end

function WTBG.Players.Notify(source, message)
    TriggerClientEvent('wtbg:core:notify', source, message)
end

function WTBG.Players.CanUseDev(source)
    if Config.Debug then
        return true
    end

    return IsPlayerAceAllowed(source, Config.DevAce)
end

exports('GetPlayerState', function(source)
    return WTBG.Players.GetState(tonumber(source))
end)

exports('GetPlayerMatch', function(source)
    return WTBG.Players.GetMatchId(tonumber(source))
end)

exports('IsPlayerAlive', function(source)
    return WTBG.Players.IsAlive(tonumber(source))
end)

exports('SendToLobby', function(source)
    return WTBG.Players.SendToLobby(tonumber(source))
end)

exports('SetSessionState', function(source, state)
    return WTBG.Players.SetSessionState(tonumber(source), state)
end)

exports('SetMatch', function(source, matchId, teamId)
    return WTBG.Players.SetMatch(tonumber(source), matchId, teamId)
end)

exports('SetAlive', function(source, alive)
    return WTBG.Players.SetAlive(tonumber(source), alive)
end)

exports('Notify', function(source, message)
    WTBG.Players.Notify(tonumber(source), message)
end)
