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
        return
    end

    placeInLobby(source)
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
        placeInLobby(tonumber(id))
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
