WTBG.Vehicle = WTBG.Vehicle or {}

local byMatch = {}
local byEntity = {}

local function usesMatch(matchId)
    local snap = exports.wtbg_match:GetMatch(tonumber(matchId))
    if not snap then
        return false, nil
    end
    if not VehicleConfig.UsesMode(snap.mode) then
        return false, snap
    end
    return true, snap
end

local function pickSpawns(matchId)
    local pts = VehicleConfig.Spawns or {}
    local want = math.min(tonumber(VehicleConfig.SpawnCount) or 10, #pts)
    local idx = {}
    for i = 1, #pts do
        idx[i] = i
    end
    local seed = matchId * 1103515245 + 12345
    for i = #idx, 2, -1 do
        seed = (seed * 1664525 + 1013904223) % 2147483647
        local j = (seed % i) + 1
        idx[i], idx[j] = idx[j], idx[i]
    end
    local out = {}
    for i = 1, want do
        out[i] = { index = idx[i], spawn = pts[idx[i]] }
    end
    return out
end

local function deleteEntity(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return
    end
    WTBG.Call(FreezeEntityPosition, entity, true)
    WTBG.Call(SetEntityAsMissionEntity, entity, true, true)
    WTBG.Call(DeleteEntity, entity)
end

local function applySpawnState(entity)
    WTBG.Call(SetEntityAsMissionEntity, entity, true, true)
    WTBG.Call(SetVehicleDoorsLocked, entity, 1)
    WTBG.Call(SetVehicleDoorsLockedForAllPlayers, entity, false)
    WTBG.Call(SetVehicleNeedsToBeHotwired, entity, false)
    WTBG.Call(SetVehicleEngineOn, entity, false, true, true)
    WTBG.Call(SetVehicleUndriveable, entity, false)
    WTBG.Call(SetVehicleCanBeUsedByFleeingPeds, entity, false)
    WTBG.Call(SetVehicleFuelLevel, entity, 100.0)
    WTBG.Call(SetVehicleOnGroundProperly, entity)
    WTBG.Call(SetEntityOrphanMode, entity, 2)
end

local function spawnType(model)
    if model == `sanchez` or model == `sanchez2` or model == `bf400` or model == `enduro` or model == `manchez` then
        return 'bike'
    end
    return 'automobile'
end

local function pickModel(slot, matchId)
    local models = VehicleConfig.Models
    if type(models) ~= 'table' or #models < 1 then
        return `draugur`
    end
    return models[((slot + matchId * 7) % #models) + 1]
end

local function createMatchVehicle(spawn, bucket, model)
    model = model or `draugur`
    local c = spawn.coords
    local heading = spawn.heading or 0.0
    local lift = spawnType(model) == 'bike' and 0.35 or 0.55
    local entity = 0
    if CreateVehicleServerSetter then
        entity = CreateVehicleServerSetter(model, spawnType(model), c.x, c.y, c.z + lift, heading)
    end
    if not entity or entity == 0 then
        entity = CreateVehicle(model, c.x, c.y, c.z + lift, heading, true, true)
    end
    if not entity or entity == 0 then
        return nil
    end

    local deadline = GetGameTimer() + 2500
    while not DoesEntityExist(entity) and GetGameTimer() < deadline do
        Wait(20)
    end
    if not DoesEntityExist(entity) then
        return nil
    end

    SetEntityRoutingBucket(entity, bucket)
    applySpawnState(entity)
    return entity
end

local function bindState(entity, matchId, vehicleId)
    local st = Entity(entity).state
    st:set('wtbgVehicle', true, true)
    st:set('wtbgMatchId', matchId, true)
    st:set('wtbgVehicleId', vehicleId, true)
end

function WTBG.Vehicle.Clear(matchId)
    matchId = tonumber(matchId)
    local pack = matchId and byMatch[matchId]
    if not pack then
        return
    end
    for id, row in pairs(pack.vehicles) do
        byEntity[row.entity] = nil
        deleteEntity(row.entity)
        pack.vehicles[id] = nil
    end
    byMatch[matchId] = nil
end

function WTBG.Vehicle.Spawn(matchId)
    matchId = tonumber(matchId)
    local ok, snap = usesMatch(matchId)
    if not ok or not snap then
        return false
    end
    if byMatch[matchId] then
        WTBG.Vehicle.Clear(matchId)
    end

    local pack = {
        matchId = matchId,
        bucket = snap.bucket,
        nextId = 1,
        vehicles = {}
    }
    byMatch[matchId] = pack

    local picks = pickSpawns(matchId)
    for i = 1, #picks do
        local pick = picks[i]
        local model = pickModel(i, matchId)
        local entity = createMatchVehicle(pick.spawn, snap.bucket, model)
        if entity then
            local id = pack.nextId
            pack.nextId = id + 1
            local row = {
                id = id,
                entity = entity,
                model = model,
                spawnIndex = pick.index,
                destroyed = false
            }
            pack.vehicles[id] = row
            byEntity[entity] = { matchId = matchId, id = id }
            bindState(entity, matchId, id)
        end
    end

    WTBG.Debug('vehicles spawned', matchId, WTBG.Count(pack.vehicles))
    return true
end

function WTBG.Vehicle.StopGameplay(matchId)
    matchId = tonumber(matchId)
    local pack = matchId and byMatch[matchId]
    if not pack then
        return
    end
    for _, row in pairs(pack.vehicles) do
        local ent = row.entity
        if ent and DoesEntityExist(ent) then
            WTBG.Call(FreezeEntityPosition, ent, true)
            WTBG.Call(SetVehicleUndriveable, ent, true)
            WTBG.Call(SetVehicleEngineOn, ent, false, true, true)
        end
    end
end

local function markRow(row, pack)
    if not row or row.destroyed then
        return
    end
    row.destroyed = true
    WTBG.Debug('vehicle destroyed', pack.matchId, row.id)
end

function WTBG.Vehicle.MarkDestroyed(matchId, vehicleId, entity)
    matchId = tonumber(matchId)
    vehicleId = tonumber(vehicleId)
    local pack = matchId and byMatch[matchId]
    if not pack then
        return false
    end
    local row = vehicleId and pack.vehicles[vehicleId]
    if not row then
        return false
    end
    if entity and entity ~= 0 and row.entity ~= entity then
        return false
    end
    markRow(row, pack)
    return true
end

function WTBG.Vehicle.Info(matchId)
    matchId = tonumber(matchId)
    local pack = matchId and byMatch[matchId]
    if not pack then
        return nil
    end
    local alive, dead = 0, 0
    for _, row in pairs(pack.vehicles) do
        if row.destroyed or not DoesEntityExist(row.entity) then
            dead = dead + 1
        else
            alive = alive + 1
        end
    end
    return {
        matchId = matchId,
        bucket = pack.bucket,
        alive = alive,
        destroyed = dead,
        total = alive + dead
    }
end

AddEventHandler('entityRemoved', function(entity)
    local ref = byEntity[entity]
    if not ref then
        return
    end
    byEntity[entity] = nil
    local pack = byMatch[ref.matchId]
    local row = pack and pack.vehicles[ref.id]
    if row then
        markRow(row, pack)
        row.entity = 0
    end
end)

CreateThread(function()
    while true do
        Wait(2500)
        for matchId, pack in pairs(byMatch) do
            for _, row in pairs(pack.vehicles) do
                if not row.destroyed then
                    local ent = row.entity
                    if not ent or ent == 0 or not DoesEntityExist(ent) then
                        markRow(row, pack)
                    elseif GetVehicleEngineHealth(ent) <= 0.0 then
                        markRow(row, pack)
                    end
                end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    local ids = {}
    for matchId in pairs(byMatch) do
        ids[#ids + 1] = matchId
    end
    for i = 1, #ids do
        WTBG.Vehicle.Clear(ids[i])
    end
    byMatch = {}
    byEntity = {}
end)
