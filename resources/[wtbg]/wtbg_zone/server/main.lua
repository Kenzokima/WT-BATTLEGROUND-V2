AddEventHandler('wtbg:match:starting', function(matchId)
    WTBG.Zone.Preview(matchId)
end)

AddEventHandler('wtbg:match:becameActive', function(matchId)
    if GetResourceState('wtbg_drop') == 'started' then
        local ok, uses = pcall(function()
            return exports.wtbg_drop:UsesMatch(matchId)
        end)
        if ok and uses then
            return
        end
    end
    WTBG.Zone.Start(matchId)
end)

AddEventHandler('wtbg:drop:groundPhase', function(matchId)
    WTBG.Zone.Start(matchId)
end)

AddEventHandler('wtbg:match:serverFinished', function(matchId)
    WTBG.Zone.Stop(matchId)
end)

AddEventHandler('wtbg:match:destroyed', function(matchId)
    WTBG.Zone.Stop(matchId)
end)

AddEventHandler('wtbg:core:returnedToLobby', function(source)
    TriggerClientEvent('wtbg:zone:clear', source)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    if GetResourceState('wtbg_match') ~= 'started' then
        return
    end

    local list = exports.wtbg_match:ListMatches() or {}
    for i = 1, #list do
        local row = list[i]
        if row.state == WTBG.MatchStates.STARTING then
            WTBG.Zone.Preview(row.id)
        elseif row.state == WTBG.MatchStates.ACTIVE then
            WTBG.Zone.Start(row.id)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    if GetResourceState('wtbg_match') ~= 'started' then
        return
    end

    local ok, list = pcall(function()
        return exports.wtbg_match:ListMatches()
    end)
    if not ok or type(list) ~= 'table' then
        return
    end
    for i = 1, #list do
        WTBG.Zone.Stop(list[i].id)
    end
end)

local function canDev(source)
    if source == 0 then
        return true
    end
    return Config.Debug or IsPlayerAceAllowed(source, Config.DevAce)
end

local function matchOf(source)
    local info = exports.wtbg_match:GetMember(source)
    return info and info.matchId or nil
end

RegisterCommand('zoneinfo', function(source)
    if not canDev(source) then
        return
    end

    local matchId = source == 0 and nil or matchOf(source)
    if not matchId then
        print('[WTBG] zoneinfo: join a match')
        return
    end

    local info = WTBG.Zone.Info(matchId)
    if not info then
        exports.wtbg_core:Notify(source, 'No zone')
        return
    end

    local msg = ('ZONE %s %s r=%.0f dmg=%.1f %sms'):format(
        info.phase,
        info.state,
        info.radius,
        info.damage,
        info.remainingMs
    )
    if source == 0 then
        print('[WTBG]', msg)
    else
        exports.wtbg_core:Notify(source, msg)
    end
end, false)

RegisterCommand('zonenext', function(source)
    if not canDev(source) then
        return
    end

    local matchId = source == 0 and nil or matchOf(source)
    if not matchId then
        return
    end

    if WTBG.Zone.ForceNext(matchId) then
        exports.wtbg_core:Notify(source, 'Zone advanced')
    end
end, false)
