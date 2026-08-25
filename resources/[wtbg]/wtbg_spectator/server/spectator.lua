local spectators = {}
local lastStep = {}

local function nowMs()
    return GetGameTimer()
end

local function spectatorInfo(source)
    source = tonumber(source)
    if not source then
        return nil
    end

    local info = exports.wtbg_match:GetMember(source)
    if not info or info.matchState ~= WTBG.MatchStates.ACTIVE or info.alive then
        return nil
    end

    local state = exports.wtbg_core:GetPlayerState(source)
    if not state or state.state ~= WTBG.PlayerStates.DEAD then
        return nil
    end

    if GetPlayerRoutingBucket(source) ~= info.bucket then
        return nil
    end

    return info
end

local function candidates(matchId, teamId, selfSrc)
    local snap = exports.wtbg_match:GetMatch(matchId)
    if not snap or type(snap.players) ~= 'table' then
        return {}
    end

    local standing = {}
    local down = {}
    for key, row in pairs(snap.players) do
        local src = tonumber(row.source) or tonumber(key)
        if src and src ~= selfSrc and row.teamId == teamId and row.alive == true then
            if GetPlayerRoutingBucket(src) == snap.bucket then
                local item = {
                    id = src,
                    name = row.name or WTBG.PlayerName(src),
                    downed = row.downed == true,
                    kills = tonumber(row.kills) or 0
                }
                if item.downed then
                    down[#down + 1] = item
                else
                    standing[#standing + 1] = item
                end
            end
        end
    end

    table.sort(standing, function(a, b)
        return a.id < b.id
    end)
    table.sort(down, function(a, b)
        return a.id < b.id
    end)
    for i = 1, #down do
        standing[#standing + 1] = down[i]
    end
    return standing
end

local function payloadOf(entry)
    return {
        target = entry.id,
        name = entry.name,
        downed = entry.downed and true or false,
        kills = entry.kills
    }
end

local function stop(source)
    source = tonumber(source)
    if not source then
        return
    end
    if spectators[source] then
        spectators[source] = nil
    end
    TriggerClientEvent('wtbg:spec:stop', source)
end

local function tryStart(source)
    source = tonumber(source)
    if not source then
        return
    end

    local info = spectatorInfo(source)
    if not info then
        if spectators[source] then
            stop(source)
        end
        return
    end

    local list = candidates(info.matchId, info.teamId, source)
    if #list == 0 then
        if spectators[source] then
            stop(source)
        end
        return
    end

    local prefer = spectators[source] and spectators[source].target
    local pick = list[1]
    if prefer then
        for i = 1, #list do
            if list[i].id == prefer then
                pick = list[i]
                break
            end
        end
    end

    local existed = spectators[source] ~= nil
    spectators[source] = {
        matchId = info.matchId,
        target = pick.id
    }
    TriggerClientEvent(existed and 'wtbg:spec:update' or 'wtbg:spec:start', source, payloadOf(pick))
end

local function refreshMatch(matchId)
    matchId = tonumber(matchId)
    if not matchId then
        return
    end
    for src, row in pairs(spectators) do
        if row.matchId == matchId then
            tryStart(src)
        end
    end
end

local function stopMatch(matchId)
    matchId = tonumber(matchId)
    if not matchId then
        return
    end
    for src, row in pairs(spectators) do
        if row.matchId == matchId then
            stop(src)
        end
    end
end

local function step(source, dir)
    source = tonumber(source)
    dir = tonumber(dir) == -1 and -1 or 1
    if not source then
        return
    end

    local t = nowMs()
    if lastStep[source] and t < lastStep[source] then
        return
    end
    lastStep[source] = t + 180

    if not spectators[source] then
        tryStart(source)
        return
    end

    local info = spectatorInfo(source)
    if not info then
        stop(source)
        return
    end

    local list = candidates(info.matchId, info.teamId, source)
    if #list == 0 then
        stop(source)
        return
    end

    local idx = 1
    local current = spectators[source].target
    for i = 1, #list do
        if list[i].id == current then
            idx = i
            break
        end
    end
    idx = idx + dir
    if idx < 1 then
        idx = #list
    elseif idx > #list then
        idx = 1
    end

    local pick = list[idx]
    spectators[source] = {
        matchId = info.matchId,
        target = pick.id
    }
    TriggerClientEvent('wtbg:spec:update', source, payloadOf(pick))
end

AddEventHandler('wtbg:match:playerEliminated', function(source, matchId)
    tryStart(source)
    refreshMatch(matchId)
end)

AddEventHandler('wtbg:match:playerDowned', function(_, matchId)
    refreshMatch(matchId)
end)

AddEventHandler('wtbg:match:playerRevived', function(_, matchId)
    refreshMatch(matchId)
end)

AddEventHandler('wtbg:match:serverFinished', function(matchId)
    stopMatch(matchId)
end)

AddEventHandler('wtbg:match:destroyed', function(matchId)
    stopMatch(matchId)
end)

AddEventHandler('wtbg:core:returnedToLobby', function(source)
    stop(source)
end)

AddEventHandler('wtbg:core:playerDropped', function(source)
    source = tonumber(source)
    if not source then
        return
    end
    local row = spectators[source]
    spectators[source] = nil
    lastStep[source] = nil
    if row then
        refreshMatch(row.matchId)
        return
    end
    for src, spec in pairs(spectators) do
        if spec.target == source then
            tryStart(src)
        end
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    if GetResourceState('wtbg_match') ~= 'started' then
        return
    end
    for _, id in ipairs(GetPlayers()) do
        tryStart(tonumber(id))
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    for src, _ in pairs(spectators) do
        TriggerClientEvent('wtbg:spec:stop', src)
    end
    spectators = {}
end)

RegisterNetEvent('wtbg:spec:next', function()
    step(source, 1)
end)

RegisterNetEvent('wtbg:spec:prev', function()
    step(source, -1)
end)

RegisterNetEvent('wtbg:spec:request', function()
    tryStart(source)
end)

exports('IsSpectating', function(source)
    source = tonumber(source)
    return source and spectators[source] ~= nil
end)
