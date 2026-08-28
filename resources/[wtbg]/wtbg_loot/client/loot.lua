wlocal loot = {}
local objects = {}
local inMatch = false
local nearest = nil
local healOrigin = nil
local healHp = nil
local lastVicinity = ''
local lastWorld = ''

local function loadModel(name)
    local hash = joaat(name)
    if not IsModelValid(hash) then
        hash = `prop_cs_cardbox_01`
    end
    if HasModelLoaded(hash) then
        return hash
    end
    RequestModel(hash)
    local t = GetGameTimer() + 400
    while not HasModelLoaded(hash) and GetGameTimer() < t do
        Wait(0)
    end
    return hash
end

local function deleteObject(id)
    local ent = objects[id]
    objects[id] = nil
    if ent and DoesEntityExist(ent) then
        SetEntityAsMissionEntity(ent, true, true)
        DeleteObject(ent)
    end
end

local function clearAll()
    for id, _ in pairs(objects) do
        deleteObject(id)
    end
    loot = {}
    nearest = nil
    lastVicinity = ''
    lastWorld = ''
    TriggerEvent('wtbg:ui:worldContext', nil)
    TriggerEvent('wtbg:ui:vicinity', {})
end

local function groundAt(x, y, z)
    RequestCollisionAtCoord(x, y, z)
    local probes = { z + 80.0, z + 25.0, 1000.0 }
    for i = 1, #probes do
        local found, gz = GetGroundZFor_3dCoord(x, y, probes[i], false)
        if found and gz and gz > -50.0 then
            return gz
        end
    end
    return nil
end

local function createLocal(hash, x, y, z)
    local obj
    if CreateObjectNoOffset then
        obj = CreateObjectNoOffset(hash, x, y, z, false, false, false)
    else
        obj = CreateObject(hash, x, y, z, false, false, false)
    end
    if obj and obj ~= 0 and DoesEntityExist(obj) then
        return obj
    end
    return nil
end

local function spawnObject(entry)
    local live = objects[entry.id]
    if live and DoesEntityExist(live) then
        return true
    end
    objects[entry.id] = nil

    local gz = groundAt(entry.x, entry.y, entry.z)
    if not gz then
        return false
    end

    local hash = loadModel(entry.model or 'prop_cs_cardbox_01')
    if not HasModelLoaded(hash) then
        return false
    end

    local z = gz + 0.08
    local obj = createLocal(hash, entry.x, entry.y, z)
    if not obj and hash ~= `prop_cs_cardbox_01` then
        hash = loadModel('prop_cs_cardbox_01')
        if HasModelLoaded(hash) then
            obj = createLocal(hash, entry.x, entry.y, z)
        end
    end
    if not obj then
        return false
    end

    SetEntityAsMissionEntity(obj, true, false)
    SetEntityCollision(obj, false, false)
    FreezeEntityPosition(obj, true)
    SetEntityCoordsNoOffset(obj, entry.x, entry.y, z, false, false, false)
    SetEntityLodDist(obj, 280)
    objects[entry.id] = obj
    return true
end

local STREAM = 220.0
local STREAM_DROP = 260.0
local SPAWN_PER_TICK = 4

local function deploying()
    if GetResourceState('wtbg_drop') ~= 'started' then
        return false
    end
    local ok, landed = pcall(function()
        return exports.wtbg_drop:IsLanded()
    end)
    return ok and landed == false
end

local function streamObjects(origin)
    if deploying() then
        return
    end
    local spawned = 0
    for id, entry in pairs(loot) do
        local dx = origin.x - entry.x
        local dy = origin.y - entry.y
        local d2 = dx * dx + dy * dy
        if d2 <= (STREAM * STREAM) then
            local ent = objects[id]
            if ent and not DoesEntityExist(ent) then
                objects[id] = nil
                ent = nil
            end
            if not ent and spawned < SPAWN_PER_TICK then
                if spawnObject(entry) then
                    spawned = spawned + 1
                end
            end
        elseif d2 >= (STREAM_DROP * STREAM_DROP) then
            if objects[id] then
                deleteObject(id)
            end
        end
    end
end

local function upsert(entry)
    if type(entry) ~= 'table' or not entry.id then
        return
    end
    loot[entry.id] = entry
end

local function xyDist(origin, entry)
    local dx = origin.x - entry.x
    local dy = origin.y - entry.y
    return math.sqrt(dx * dx + dy * dy)
end

local function blocked()
    if GetResourceState('wtbg_drop') == 'started' then
        local ok, landed = pcall(function()
            return exports.wtbg_drop:IsLanded()
        end)
        if ok and landed == false then
            return true
        end
    end
    if GetResourceState('wtbg_combat') == 'started' then
        local ok, value = pcall(function()
            return exports.wtbg_combat:BlockWorldInteract()
        end)
        if ok and value then
            return true
        end
    end
    if IsPedInAnyVehicle(PlayerPedId(), false) then
        return true
    end
    return false
end

local function nearbyEntries(origin, range)
    local list = {}
    for _, entry in pairs(loot) do
        local d = xyDist(origin, entry)
        if d <= range then
            list[#list + 1] = {
                id = entry.id,
                itemId = entry.itemId,
                label = entry.label,
                amount = entry.amount or 1,
                bag = entry.bag and true or false,
                kind = entry.kind,
                ammoType = entry.ammoType,
                dist = d
            }
        end
    end
    table.sort(list, function(a, b)
        return a.dist < b.dist
    end)
    return list
end

local function publishVicinity(list)
    local fp = ''
    for i = 1, #list do
        fp = fp .. tostring(list[i].id) .. ':'
    end
    if fp == lastVicinity then
        return
    end
    lastVicinity = fp
    TriggerEvent('wtbg:ui:vicinity', list)
end

local function publishWorld(entry)
    local fp = entry and (tostring(entry.id) .. ':' .. tostring(entry.amount or 0) .. (entry.bag and 'b' or '')) or ''
    if fp == lastWorld then
        return
    end
    lastWorld = fp
    if not entry then
        TriggerEvent('wtbg:ui:worldContext', nil)
        return
    end
    TriggerEvent('wtbg:ui:worldContext', {
        id = entry.id,
        label = entry.amount and (entry.label .. ' x' .. tostring(entry.amount)) or entry.label,
        amount = entry.amount,
        bag = entry.bag and true or false
    })
end

local lastSlots = {}

local function applyWeapons(payload)
    local ped = PlayerPedId()
    RemoveAllPedWeapons(ped, true)
    lastSlots = {}
    if type(payload) ~= 'table' then
        return
    end

    local weapons = payload.weapons or {}
    for i = 1, #weapons do
        local row = weapons[i]
        local hash = joaat(row.weapon)
        GiveWeaponToPed(ped, hash, 0, false, true)
        SetPedAmmo(ped, hash, tonumber(row.ammo) or 0)
        if row.slot then
            lastSlots[row.slot] = hash
        end
    end

    local grenade = tonumber(payload.grenade) or 0
    if grenade > 0 then
        GiveWeaponToPed(ped, `WEAPON_GRENADE`, grenade, false, false)
        SetPedAmmo(ped, `WEAPON_GRENADE`, grenade)
    end

    local molotov = tonumber(payload.molotov) or 0
    if molotov > 0 then
        GiveWeaponToPed(ped, `WEAPON_MOLOTOV`, molotov, false, false)
        SetPedAmmo(ped, `WEAPON_MOLOTOV`, molotov)
    end

    local smoke = tonumber(payload.smoke) or 0
    if smoke > 0 then
        GiveWeaponToPed(ped, `WEAPON_SMOKEGRENADE`, smoke, false, false)
        SetPedAmmo(ped, `WEAPON_SMOKEGRENADE`, smoke)
    end

    if weapons[1] then
        SetCurrentPedWeapon(ped, joaat(weapons[1].weapon), true)
    end

    SetPedArmour(ped, tonumber(payload.armor) or 0)
end

RegisterNetEvent('wtbg:loot:full', function(list)
    clearAll()
    inMatch = true
    if type(list) ~= 'table' then
        return
    end
    for i = 1, #list do
        upsert(list[i])
    end
end)

RegisterNetEvent('wtbg:loot:batch', function(list)
    inMatch = true
    if type(list) ~= 'table' then
        return
    end
    for i = 1, #list do
        upsert(list[i])
    end
end)

RegisterNetEvent('wtbg:loot:add', function(entry)
    upsert(entry)
end)

RegisterNetEvent('wtbg:loot:remove', function(id)
    id = tonumber(id)
    if not id then
        return
    end
    loot[id] = nil
    deleteObject(id)
    if nearest and nearest.id == id then
        nearest = nil
    end
end)

RegisterNetEvent('wtbg:loot:clear', function()
    clearAll()
end)

RegisterNetEvent('wtbg:loot:applyLoadout', function(payload)
    applyWeapons(payload)
end)

RegisterNetEvent('wtbg:match:begin', function()
    inMatch = true
end)

RegisterNetEvent('wtbg:match:finished', function()
    inMatch = false
    clearAll()
    healOrigin = nil
    healHp = nil
end)

RegisterNetEvent('wtbg:core:spawnLobby', function()
    inMatch = false
    clearAll()
    healOrigin = nil
    healHp = nil
end)

RegisterNetEvent('wtbg:ui:heal', function(data)
    if data and data.ms then
        local ped = PlayerPedId()
        healOrigin = GetEntityCoords(ped)
        healHp = GetEntityHealth(ped)
    else
        healOrigin = nil
        healHp = nil
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    clearAll()
end)

CreateThread(function()
    local range = tonumber(LootConfig.PickupRange) or 2.35
    while true do
        if not inMatch then
            nearest = nil
            Wait(400)
        else
            local origin = GetEntityCoords(PlayerPedId())
            streamObjects(origin)
            local best, bestDist, bestBag, bagDist = nil, range, nil, range
            for _, entry in pairs(loot) do
                local d = xyDist(origin, entry)
                if d < range then
                    if entry.bag and d < bagDist then
                        bestBag = entry
                        bagDist = d
                    elseif d < bestDist then
                        best = entry
                        bestDist = d
                    end
                end
            end
            nearest = bestBag or best
            local around = nearbyEntries(origin, range)
            publishVicinity(around)

            if healOrigin then
                local ped = PlayerPedId()
                local hp = GetEntityHealth(ped)
                local cancel = false
                if healHp and hp + 1 < healHp then
                    cancel = true
                elseif IsPedSprinting(ped) or IsPedJumping(ped) then
                    cancel = true
                elseif #(GetEntityCoords(ped) - healOrigin) > (LootConfig.HealMoveCancel or 2.4) then
                    cancel = true
                end
                if cancel then
                    healOrigin = nil
                    healHp = nil
                    TriggerServerEvent('wtbg:loot:cancelUse')
                else
                    healHp = hp
                end
            end

            if nearest and not blocked() and not IsNuiFocused() then
                publishWorld(nearest)
                if IsControlJustPressed(0, 38) or IsDisabledControlJustPressed(0, 38) then
                    TriggerServerEvent('wtbg:loot:pickup', nearest.id)
                end
                Wait(0)
            else
                publishWorld(nil)
                Wait(200)
            end
        end
    end
end)

local function selectSlot(slot)
    if not inMatch then
        return
    end
    local hash = lastSlots[slot]
    if hash then
        SetCurrentPedWeapon(PlayerPedId(), hash, true)
    end
end

RegisterCommand('wtbgslot1', function()
    selectSlot('primary')
end, false)
RegisterCommand('wtbgslot2', function()
    selectSlot('secondary')
end, false)
RegisterCommand('wtbgslot3', function()
    selectSlot('sidearm')
end, false)

RegisterKeyMapping('wtbgslot1', 'WTBG primary', 'keyboard', '1')
RegisterKeyMapping('wtbgslot2', 'WTBG secondary', 'keyboard', '2')
RegisterKeyMapping('wtbgslot3', 'WTBG sidearm', 'keyboard', '3')

CreateThread(function()
    while true do
        if inMatch then
            DisableControlAction(0, 157, true)
            DisableControlAction(0, 158, true)
            DisableControlAction(0, 160, true)
            Wait(0)
        else
            Wait(400)
        end
    end
end)
