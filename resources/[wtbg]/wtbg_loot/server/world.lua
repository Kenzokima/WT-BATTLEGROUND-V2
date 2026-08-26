LootWorld = {}

local byId = {}
local byMatch = {}
local nextLootId = 1
local generating = false
local lastPickup = {}
local lastDrop = {}

local function nowMs()
    return GetGameTimer()
end

local function rateOk(bucket, source, ms)
    source = tonumber(source)
    local t = nowMs()
    if bucket[source] and t < bucket[source] then
        return false
    end
    bucket[source] = t + ms
    return true
end

local function publicLoot(entry)
    if not entry or entry.taken then
        return nil
    end

    local def = (not entry.bag) and LootItems[entry.itemId] or nil
    local payload = {
        id = entry.id,
        matchId = entry.matchId,
        itemId = entry.itemId,
        amount = entry.amount,
        bag = entry.bag and true or false,
        label = entry.bag and 'Loot Bag' or LootItemLabel(entry.itemId),
        model = entry.bag and 'prop_cs_heist_bag_01' or ((def and def.model) or 'prop_cs_cardbox_01'),
        kind = def and def.type or (entry.bag and 'bag' or nil),
        ammoType = def and def.ammoType or nil,
        x = entry.x,
        y = entry.y,
        z = entry.z
    }

    if entry.bag then
        payload.contents = {}
        for i = 1, #(entry.contents or {}) do
            local row = entry.contents[i]
            payload.contents[i] = {
                uid = row.uid,
                itemId = row.itemId,
                amount = row.amount,
                label = LootItemLabel(row.itemId),
                kind = LootItems[row.itemId] and LootItems[row.itemId].type or nil
            }
        end
    end

    return payload
end

local function broadcast(matchId, eventName, ...)
    local sources = exports.wtbg_match:GetMatchSources(matchId) or {}
    for i = 1, #sources do
        local src = tonumber(sources[i])
        if src then
            TriggerClientEvent(eventName, src, ...)
        end
    end
end

local function matchBucket(matchId, fallback)
    local snap = exports.wtbg_match:GetMatch(matchId)
    if snap and snap.bucket then
        return snap.bucket
    end
    return fallback
end

local function spawnEntry(matchId, bucket, itemId, amount, x, y, z, bagContents)
    local id = nextLootId
    nextLootId = nextLootId + 1

    local contents = nil
    if bagContents then
        contents = {}
        for i = 1, #bagContents do
            contents[i] = {
                uid = i,
                itemId = bagContents[i].itemId,
                amount = bagContents[i].amount
            }
        end
    end

    local entry = {
        id = id,
        matchId = matchId,
        bucket = bucket,
        itemId = itemId,
        amount = amount or 1,
        x = x + 0.0,
        y = y + 0.0,
        z = z + 0.0,
        taken = false,
        bag = bagContents ~= nil,
        contents = contents,
        nextUid = bagContents and (#bagContents + 1) or 1
    }

    byId[id] = entry
    byMatch[matchId] = byMatch[matchId] or {}
    byMatch[matchId][id] = true

    local payload = publicLoot(entry)
    if not generating then
        broadcast(matchId, 'wtbg:loot:add', payload)
    end
    return entry
end

function LootWorld.SpawnAt(matchId, itemId, amount, coords)
    matchId = tonumber(matchId)
    if not matchId or not LootItems[itemId] or not coords then
        return nil
    end

    local snap = exports.wtbg_match:GetMatch(matchId)
    if not snap or snap.state ~= WTBG.MatchStates.ACTIVE then
        return nil
    end

    return spawnEntry(matchId, snap.bucket, itemId, amount, coords.x, coords.y, coords.z, nil)
end

local function removeEntry(entry, silent)
    if not entry or entry.taken then
        return
    end
    entry.taken = true
    byId[entry.id] = nil
    if byMatch[entry.matchId] then
        byMatch[entry.matchId][entry.id] = nil
    end
    if not silent then
        broadcast(entry.matchId, 'wtbg:loot:remove', entry.id)
    end
end

function LootWorld.ClearMatch(matchId)
    matchId = tonumber(matchId)
    local set = byMatch[matchId]
    if not set then
        return
    end

    for id, _ in pairs(set) do
        local entry = byId[id]
        if entry then
            entry.taken = true
            byId[id] = nil
        end
    end
    byMatch[matchId] = nil
    broadcast(matchId, 'wtbg:loot:clear', matchId)
end

local function weightedKey(weights)
    local total = 0
    for _, w in pairs(weights) do
        total = total + (tonumber(w) or 0)
    end
    if total <= 0 then
        return nil
    end
    local roll = math.random() * total
    local acc = 0
    for key, w in pairs(weights) do
        acc = acc + (tonumber(w) or 0)
        if roll < acc then
            return key
        end
    end
    return nil
end

local function rollItem(pool, tier)
    local ids = LootPools[pool]
    if not ids or #ids == 0 then
        return nil
    end
    if tier ~= 'high' and tier ~= 'low' then
        tier = 'medium'
    end

    local total = 0
    local weights = {}
    for i = 1, #ids do
        local def = LootItems[ids[i]]
        local configured = def and def.spawnWeight
        local w
        if type(configured) == 'table' then
            w = tonumber(configured[tier]) or 0
        else
            w = tonumber(configured) or 1
        end
        if w < 0 then
            w = 0
        end
        weights[i] = w
        total = total + w
    end
    if total <= 0 then
        return nil
    end
    local roll = math.random() * total
    local acc = 0
    for i = 1, #ids do
        acc = acc + weights[i]
        if roll < acc then
            return ids[i]
        end
    end
    return ids[#ids]
end

local function scatterZone(zone)
    local points = {}
    local radius = tonumber(zone.radius) or 80.0
    local spacing = tonumber(LootConfig.MinSpacing) or 14.0
    local minSq = spacing * spacing
    local counts = LootConfig.ZoneCounts or {}
    local n = tonumber(zone.count) or counts[zone.tier] or 12
    n = math.floor(n)
    if n < 1 then
        return points
    end

    local tries = 0
    local cap = n * 14
    while #points < n and tries < cap do
        tries = tries + 1
        local ang = math.random() * 6.283185307179586
        local rad = math.sqrt(math.random()) * radius
        local x = zone.x + math.cos(ang) * rad
        local y = zone.y + math.sin(ang) * rad
        local ok = true
        for i = 1, #points do
            local dx = points[i].x - x
            local dy = points[i].y - y
            if dx * dx + dy * dy < minSq then
                ok = false
                break
            end
        end
        if ok then
            points[#points + 1] = {
                x = x,
                y = y,
                z = zone.z,
                tier = zone.tier
            }
        end
    end

    local guarantees = LootConfig.TierGuarantees and LootConfig.TierGuarantees[zone.tier]
    if type(guarantees) == 'table' then
        for i = 1, math.min(#points, #guarantees) do
            if LootItems[guarantees[i]] then
                points[i].itemId = guarantees[i]
            end
        end
    end
    return points
end

function LootWorld.Ensure(matchId, bucket)
    matchId = tonumber(matchId)
    if not matchId then
        return
    end
    if byMatch[matchId] then
        return
    end
    LootWorld.Generate(matchId, bucket)
end

function LootWorld.Generate(matchId, bucket)
    matchId = tonumber(matchId)
    if not LootConfig.LootEnabled or not matchId then
        return
    end

    LootWorld.ClearMatch(matchId)
    bucket = bucket or matchBucket(matchId, matchId)
    generating = true
    math.randomseed(GetGameTimer() + matchId * 17)

    local ammoFor = {
        rifle = 'ammo_rifle',
        smg = 'ammo_smg',
        shotgun = 'ammo_shotgun',
        pistol = 'ammo_pistol'
    }

    local zones = LootConfig.Zones
    local points = {}
    if type(zones) == 'table' then
        for i = 1, #zones do
            local scattered = scatterZone(zones[i])
            for j = 1, #scattered do
                points[#points + 1] = scattered[j]
            end
        end
    end
    if #points == 0 then
        points = LootConfig.SpawnPoints or {}
    end
    for i = 1, #points do
        local pt = points[i]
        local tier = pt.tier
        if tier ~= 'high' and tier ~= 'low' then
            tier = 'medium'
        end
        local itemId = pt.itemId
        if not LootItems[itemId] then
            local cats = LootConfig.TierWeights[tier] or LootConfig.TierWeights.medium
            local cat = weightedKey(cats)
            if cat and cat ~= 'empty' then
                itemId = rollItem(cat, tier)
            else
                itemId = nil
            end
        end
        local def = itemId and LootItems[itemId]
        if def then
            spawnEntry(matchId, bucket, itemId, def.amount or 1, pt.x, pt.y, pt.z, nil)
            if def.type == 'weapon' then
                local ammoId = ammoFor[def.ammoType]
                local ammoDef = ammoId and LootItems[ammoId]
                if ammoDef then
                    spawnEntry(matchId, bucket, ammoId, ammoDef.amount or 1, pt.x + 1.35, pt.y + 0.9, pt.z, nil)
                end
            end
        end
    end

    generating = false
    local spawned = 0
    local set = byMatch[matchId]
    if set then
        for _ in pairs(set) do
            spawned = spawned + 1
        end
    end
    WTBG.Debug('loot generated', matchId, spawned)
end

local SYNC_BATCH = 32
local syncGen = {}

function LootWorld.FullSync(source, matchId)
    source = tonumber(source)
    matchId = tonumber(matchId)
    if not source then
        return
    end

    syncGen[source] = (syncGen[source] or 0) + 1
    local gen = syncGen[source]

    CreateThread(function()
        if syncGen[source] ~= gen then
            return
        end
        local set = byMatch[matchId]
        TriggerClientEvent('wtbg:loot:full', source, {})
        if not set then
            return
        end

        local batch = {}
        local sent = 0
        for id, _ in pairs(set) do
            if syncGen[source] ~= gen then
                return
            end
            local payload = publicLoot(byId[id])
            if payload then
                batch[#batch + 1] = payload
                if #batch >= SYNC_BATCH then
                    TriggerClientEvent('wtbg:loot:batch', source, batch)
                    batch = {}
                    sent = sent + 1
                    if sent % 6 == 0 then
                        Wait(0)
                    end
                end
            end
        end
        if syncGen[source] ~= gen then
            return
        end
        if #batch > 0 then
            TriggerClientEvent('wtbg:loot:batch', source, batch)
        end
    end)
end

local function playerCoords(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then
        return nil
    end
    return GetEntityCoords(ped)
end

local function inRange(source, entry)
    local coords = playerCoords(source)
    if not coords then
        return false
    end
    local range = LootConfig.PickupRange or 2.35
    local dx = coords.x - entry.x
    local dy = coords.y - entry.y
    return (dx * dx + dy * dy) <= (range * range)
end

local function sameContext(source, info, entry)
    if not info or not entry then
        return false
    end
    if entry.taken or entry.matchId ~= info.matchId then
        return false
    end
    if GetPlayerRoutingBucket(source) ~= entry.bucket then
        return false
    end
    return true
end

function LootWorld.Pickup(source, lootId)
    source = tonumber(source)
    lootId = tonumber(lootId)
    if not source or not lootId then
        return
    end
    if not rateOk(lastPickup, source, 120) then
        return
    end

    local _, info = LootInv.CanAct(source)
    if not info then
        return
    end

    local entry = byId[lootId]
    if not entry or not sameContext(source, info, entry) or not inRange(source, entry) then
        return
    end

    if entry.bag then
        TriggerClientEvent('wtbg:ui:bag', source, publicLoot(entry))
        return
    end

    -- taken is set before grant so a second pickup in the same tick cannot succeed
    entry.taken = true
    local ok, reason, swapped, consumed = LootInv.Give(source, entry.itemId, entry.amount)
    if not ok then
        entry.taken = false
        if reason == 'full' then
            exports.wtbg_core:Notify(source, 'No room')
        end
        return
    end

    byId[entry.id] = nil
    if byMatch[entry.matchId] then
        byMatch[entry.matchId][entry.id] = nil
    end
    broadcast(entry.matchId, 'wtbg:loot:remove', entry.id)

    local used = consumed or entry.amount
    if used < entry.amount then
        LootWorld.SpawnAt(entry.matchId, entry.itemId, entry.amount - used, vector3(entry.x, entry.y, entry.z))
    end

    if swapped then
        LootWorld.SpawnAt(entry.matchId, swapped.itemId, swapped.amount, playerCoords(source))
    end

    LootInv.Sync(source, true)
    if consumed and consumed < entry.amount then
        WTBG.Debug('partial loot', source, entry.itemId, consumed)
    end
end

function LootWorld.TakeFromBag(source, lootId, uid)
    source = tonumber(source)
    lootId = tonumber(lootId)
    uid = tonumber(uid)
    if not source or not lootId or not uid then
        return
    end
    if not rateOk(lastPickup, source, 120) then
        return
    end

    local _, info = LootInv.CanAct(source)
    if not info then
        return
    end

    local entry = byId[lootId]
    if not entry or not entry.bag or not sameContext(source, info, entry) or not inRange(source, entry) then
        return
    end

    local idx
    for i = 1, #entry.contents do
        if entry.contents[i].uid == uid then
            idx = i
            break
        end
    end
    if not idx then
        return
    end

    local row = entry.contents[idx]
    table.remove(entry.contents, idx)

    local ok, reason, swapped, consumed = LootInv.Give(source, row.itemId, row.amount)
    if not ok then
        table.insert(entry.contents, idx, row)
        if reason == 'full' then
            exports.wtbg_core:Notify(source, 'No room')
        end
        TriggerClientEvent('wtbg:ui:bag', source, publicLoot(entry))
        return
    end

    local used = consumed or row.amount
    if used < row.amount then
        entry.contents[#entry.contents + 1] = {
            uid = entry.nextUid,
            itemId = row.itemId,
            amount = row.amount - used
        }
        entry.nextUid = entry.nextUid + 1
    end

    if swapped then
        entry.contents[#entry.contents + 1] = {
            uid = entry.nextUid,
            itemId = swapped.itemId,
            amount = swapped.amount
        }
        entry.nextUid = entry.nextUid + 1
    end

    LootInv.Sync(source, true)

    if #entry.contents == 0 then
        removeEntry(entry)
        TriggerClientEvent('wtbg:ui:bag', source, nil)
        return
    end

    broadcast(entry.matchId, 'wtbg:loot:add', publicLoot(entry))
    TriggerClientEvent('wtbg:ui:bag', source, publicLoot(entry))
end

function LootWorld.Drop(source, kind, key, amount)
    source = tonumber(source)
    local _, info = LootInv.CanAct(source)
    if not info then
        return
    end
    if not rateOk(lastDrop, source, 200) then
        return
    end

    local coords = playerCoords(source)
    if not coords then
        return
    end

    local itemId, qty
    if kind == 'weapon' then
        itemId = LootInv.RemoveWeapon(source, key)
        qty = itemId and 1 or 0
    elseif kind == 'ammo' then
        qty = LootInv.RemoveAmmo(source, key, amount)
        if qty > 0 then
            itemId = 'ammo_' .. key
            if not LootItems[itemId] then
                LootInv.Get(source).ammo[key] = (LootInv.Get(source).ammo[key] or 0) + qty
                return
            end
        end
    elseif kind == 'heal' then
        qty = LootInv.RemoveHeal(source, key, amount)
        itemId = key
    elseif kind == 'throwable' then
        qty = LootInv.RemoveThrowable(source, key, amount)
        itemId = key
    else
        return
    end

    if not itemId or not qty or qty < 1 then
        return
    end

    LootWorld.SpawnAt(info.matchId, itemId, qty, coords)
    LootInv.Sync(source, true)
end

function LootWorld.DropDeath(source, matchId, matchState)
    source = tonumber(source)
    matchId = tonumber(matchId)
    if matchState ~= WTBG.MatchStates.ACTIVE then
        return
    end
    if LootInv.HasDeathDropped(source) then
        return
    end

    local snap = exports.wtbg_match:GetMatch(matchId)
    if not snap or snap.state ~= WTBG.MatchStates.ACTIVE then
        LootInv.TakeAllForDeath(source)
        LootInv.Sync(source, false)
        return
    end

    local coords = playerCoords(source)
    local ped = GetPlayerPed(source)
    if ped and ped ~= 0 then
        local veh = GetVehiclePedIsIn(ped, false)
        if veh and veh ~= 0 then
            local ok, side = pcall(GetOffsetFromEntityInWorldCoords, veh, 2.2, 0.0, 0.1)
            if ok and side then
                coords = side
            end
        end
    end
    local contents = LootInv.TakeAllForDeath(source)
    LootInv.Sync(source, false)
    if not contents or not coords then
        return
    end

    spawnEntry(matchId, snap.bucket, '_bag', 1, coords.x, coords.y, coords.z + 0.15, contents)
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    byId = {}
    byMatch = {}
end)
