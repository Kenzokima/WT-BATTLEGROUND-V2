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

AddEventHandler('wtbg:match:starting', function(matchId)
    WTBG.Vehicle.Spawn(matchId)
end)

AddEventHandler('wtbg:match:serverFinished', function(matchId)
    WTBG.Vehicle.StopGameplay(matchId)
end)

AddEventHandler('wtbg:match:destroyed', function(matchId)
    WTBG.Vehicle.Clear(matchId)
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
        if row.state == WTBG.MatchStates.STARTING or row.state == WTBG.MatchStates.ACTIVE then
            WTBG.Vehicle.Spawn(row.id)
        end
    end
end)

RegisterNetEvent('wtbg:vehicle:destroyed', function(matchId, vehicleId, netId)
    local src = tonumber(source)
    if not src then
        return
    end
    matchId = tonumber(matchId)
    vehicleId = tonumber(vehicleId)
    netId = tonumber(netId)
    local info = exports.wtbg_match:GetMember(src)
    if not info or info.matchId ~= matchId then
        return
    end
    local entity = 0
    if netId and netId > 0 then
        entity = NetworkGetEntityFromNetworkId(netId)
    end
    if entity and entity ~= 0 and DoesEntityExist(entity) then
        if GetEntityRoutingBucket(entity) ~= info.bucket then
            return
        end
        local st = Entity(entity).state
        if st.wtbgMatchId ~= matchId or st.wtbgVehicleId ~= vehicleId then
            return
        end
        if GetVehicleEngineHealth(entity) > 0.0 then
            local dead = false
            pcall(function()
                dead = IsEntityDead(entity)
            end)
            if not dead then
                return
            end
        end
    end
    WTBG.Vehicle.MarkDestroyed(matchId, vehicleId, entity ~= 0 and entity or nil)
end)

RegisterCommand('vehinfo', function(source)
    if not canDev(source) then
        return
    end
    local matchId = source == 0 and nil or matchOf(source)
    if not matchId then
        print('[WTBG] vehinfo: join a match')
        return
    end
    local info = WTBG.Vehicle.Info(matchId)
    local msg = info and ('VEH %s alive=%s destroyed=%s bucket=%s'):format(
        info.matchId, info.alive, info.destroyed, info.bucket
    ) or 'No vehicles'
    if source == 0 then
        print('[WTBG]', msg)
    else
        exports.wtbg_core:Notify(source, msg)
    end
end, false)

RegisterCommand('vehregen', function(source)
    if not canDev(source) then
        return
    end
    local matchId = source == 0 and nil or matchOf(source)
    if not matchId then
        return
    end
    local snap = exports.wtbg_match:GetMatch(matchId)
    if not snap or (snap.state ~= WTBG.MatchStates.STARTING and snap.state ~= WTBG.MatchStates.ACTIVE) then
        return
    end
    WTBG.Vehicle.Clear(matchId)
    WTBG.Vehicle.Spawn(matchId)
    if source > 0 then
        exports.wtbg_core:Notify(source, 'Vehicles regenerated')
    end
end, false)
