LootInv = {}

local inventories = {}
local using = {}
local useToken = 0

local SLOTS = { primary = true, secondary = true, sidearm = true }

local function clamp(n, lo, hi)
    n = math.floor(tonumber(n) or 0)
    if n < lo then
        return lo
    end
    if n > hi then
        return hi
    end
    return n
end

local function emptyInv()
    return {
        primary = nil,
        secondary = nil,
        sidearm = nil,
        ammo = { rifle = 0, smg = 0, shotgun = 0, pistol = 0 },
        healing = { bandage = 0, medkit = 0 },
        armor = 0,
        throwables = { grenade = 0, molotov = 0, smoke = 0 },
        deathDropped = false
    }
end

local function defOf(itemId)
    return itemId and LootItems[itemId] or nil
end

function LootInv.CanAct(source)
    source = tonumber(source)
    if not source then
        return nil
    end

    local state = exports.wtbg_core:GetPlayerState(source)
    if not state or not state.alive or state.state ~= WTBG.PlayerStates.MATCH then
        return nil
    end

    local info = exports.wtbg_match:GetMember(source)
    if not info or info.matchState ~= WTBG.MatchStates.ACTIVE or not info.alive or info.downed then
        return nil
    end

    if GetResourceState('wtbg_drop') == 'started' then
        local ok, landed = pcall(function()
            return exports.wtbg_drop:IsPlayerLanded(source)
        end)
        if ok and landed == false then
            return nil
        end
    end

    local ped = GetPlayerPed(source)
    if ped and ped ~= 0 then
        local veh = GetVehiclePedIsIn(ped, false)
        if veh and veh ~= 0 then
            return nil
        end
    end

    return state, info
end

function LootInv.Get(source)
    source = tonumber(source)
    if not source then
        return nil
    end
    if not inventories[source] then
        inventories[source] = emptyInv()
    end
    return inventories[source]
end

function LootInv.Clear(source)
    source = tonumber(source)
    inventories[source] = nil
    LootInv.CancelUse(source)
end

function LootInv.CancelUse(source)
    source = tonumber(source)
    if not source then
        return
    end
    using[source] = nil
    TriggerClientEvent('wtbg:ui:heal', source, nil)
end

function LootInv.Snapshot(source)
    local inv = LootInv.Get(source)
    if not inv then
        return nil
    end

    local function weapon(slot)
        local id = inv[slot]
        if not id then
            return nil
        end
        local def = defOf(id)
        return {
            id = id,
            label = LootItemLabel(id),
            ammoType = def and def.ammoType or nil
        }
    end

    return {
        primary = weapon('primary'),
        secondary = weapon('secondary'),
        sidearm = weapon('sidearm'),
        ammo = {
            rifle = inv.ammo.rifle,
            smg = inv.ammo.smg,
            shotgun = inv.ammo.shotgun,
            pistol = inv.ammo.pistol
        },
        healing = {
            bandage = inv.healing.bandage,
            medkit = inv.healing.medkit
        },
        armor = inv.armor,
        throwables = {
            grenade = inv.throwables.grenade,
            molotov = inv.throwables.molotov,
            smoke = inv.throwables.smoke
        }
    }
end

function LootInv.WeaponPayload(source)
    local inv = LootInv.Get(source)
    local list = {}
    local function add(slot)
        local id = inv[slot]
        local def = defOf(id)
        if not def then
            return
        end
        list[#list + 1] = {
            weapon = def.weapon,
            ammo = inv.ammo[def.ammoType] or 0,
            slot = slot,
            ammoType = def.ammoType
        }
    end
    add('primary')
    add('secondary')
    add('sidearm')
    return {
        weapons = list,
        armor = inv.armor,
        grenade = inv.throwables.grenade,
        molotov = inv.throwables.molotov,
        smoke = inv.throwables.smoke
    }
end

function LootInv.Sync(source, applyWeapons)
    source = tonumber(source)
    if not source then
        return
    end

    TriggerClientEvent('wtbg:ui:inventory', source, LootInv.Snapshot(source))
    if applyWeapons == false then
        return
    end

    local state = exports.wtbg_core:GetPlayerState(source)
    if not state or state.state ~= WTBG.PlayerStates.MATCH then
        return
    end

    TriggerClientEvent('wtbg:loot:applyLoadout', source, LootInv.WeaponPayload(source))
end

function LootInv.ApplySpawnLoadout(source)
    source = tonumber(source)
    if not source then
        return
    end

    local inv = emptyInv()
    inventories[source] = inv
    LootInv.CancelUse(source)

    if LootConfig.StartPistol then
        inv.sidearm = 'pistol_standard'
        inv.ammo.pistol = clamp(LootConfig.StartPistolAmmo or 24, 0, LootConfig.MaxAmmo.pistol)
    end

    WTBG.SetVitals(source, Config.StartingHealth or 200, 0)

    LootInv.Sync(source, true)
end

function LootInv.Give(source, itemId, amount)
    local def = defOf(itemId)
    if not def then
        return false, 'unknown'
    end

    local inv = LootInv.Get(source)
    amount = clamp(amount or def.amount or 1, 1, 999)
    local swapped = nil

    if def.type == 'weapon' then
        if not SLOTS[def.slot] then
            return false, 'slot'
        end
        if inv[def.slot] then
            swapped = { itemId = inv[def.slot], amount = 1 }
        end
        inv[def.slot] = itemId
        return true, nil, swapped
    end

    if def.type == 'ammo' then
        local key = def.ammoType
        local max = LootConfig.MaxAmmo[key]
        if not key or not max then
            return false, 'ammo'
        end
        local room = max - (inv.ammo[key] or 0)
        if room <= 0 then
            return false, 'full'
        end
        local add = math.min(amount, room)
        inv.ammo[key] = inv.ammo[key] + add
        return true, nil, nil, add
    end

    if def.type == 'heal' then
        local key = def.healId
        local max = LootConfig.MaxHealing[key]
        if not key or not max then
            return false, 'heal'
        end
        local room = max - (inv.healing[key] or 0)
        if room <= 0 then
            return false, 'full'
        end
        local add = math.min(amount, room)
        inv.healing[key] = inv.healing[key] + add
        return true, nil, nil, add
    end

    if def.type == 'armor' then
        local ped = GetPlayerPed(source)
        local cur = WTBG.PedArmour(ped) or inv.armor
        local max = LootConfig.MaxArmor or 100
        if cur >= max then
            return false, 'full'
        end
        local add = def.amount or LootConfig.ArmorPlateAmount or 25
        local nxt = math.min(max, cur + add)
        WTBG.SetVitals(source, nil, nxt)
        inv.armor = nxt
        return true
    end

    if def.type == 'throwable' then
        local key = def.throwId
        local max = LootConfig.MaxThrowables[key]
        if not key or not max then
            return false, 'throw'
        end
        local room = max - (inv.throwables[key] or 0)
        if room <= 0 then
            return false, 'full'
        end
        local add = math.min(amount, room)
        inv.throwables[key] = inv.throwables[key] + add
        return true, nil, nil, add
    end

    return false, 'type'
end

function LootInv.RemoveWeapon(source, slot)
    if not SLOTS[slot] then
        return nil
    end
    local inv = LootInv.Get(source)
    local id = inv[slot]
    if not id then
        return nil
    end
    inv[slot] = nil
    return id
end

function LootInv.RemoveAmmo(source, ammoType, amount)
    local inv = LootInv.Get(source)
    if not inv.ammo[ammoType] then
        return 0
    end
    amount = clamp(amount, 1, inv.ammo[ammoType])
    inv.ammo[ammoType] = inv.ammo[ammoType] - amount
    return amount
end

function LootInv.RemoveHeal(source, healId, amount)
    local inv = LootInv.Get(source)
    if not inv.healing[healId] then
        return 0
    end
    amount = clamp(amount, 1, inv.healing[healId])
    inv.healing[healId] = inv.healing[healId] - amount
    return amount
end

function LootInv.RemoveThrowable(source, throwId, amount)
    local inv = LootInv.Get(source)
    if not inv.throwables[throwId] then
        return 0
    end
    amount = clamp(amount, 1, inv.throwables[throwId])
    inv.throwables[throwId] = inv.throwables[throwId] - amount
    return amount
end

function LootInv.TakeAllForDeath(source)
    local inv = LootInv.Get(source)
    if inv.deathDropped then
        return nil
    end
    inv.deathDropped = true

    local contents = {}
    local function push(itemId, amount)
        if not itemId or amount < 1 then
            return
        end
        contents[#contents + 1] = { itemId = itemId, amount = amount }
    end

    push(inv.primary, 1)
    push(inv.secondary, 1)
    push(inv.sidearm, 1)
    if inv.ammo.rifle > 0 then push('ammo_rifle', inv.ammo.rifle) end
    if inv.ammo.smg > 0 then push('ammo_smg', inv.ammo.smg) end
    if inv.ammo.shotgun > 0 then push('ammo_shotgun', inv.ammo.shotgun) end
    if inv.ammo.pistol > 0 then push('ammo_pistol', inv.ammo.pistol) end
    if inv.healing.bandage > 0 then push('bandage', inv.healing.bandage) end
    if inv.healing.medkit > 0 then push('medkit', inv.healing.medkit) end
    if inv.throwables.grenade > 0 then push('grenade', inv.throwables.grenade) end
    if inv.throwables.molotov > 0 then push('molotov', inv.throwables.molotov) end
    if inv.throwables.smoke > 0 then push('smoke', inv.throwables.smoke) end

    inv.primary = nil
    inv.secondary = nil
    inv.sidearm = nil
    inv.ammo = { rifle = 0, smg = 0, shotgun = 0, pistol = 0 }
    inv.healing = { bandage = 0, medkit = 0 }
    inv.throwables = { grenade = 0, molotov = 0, smoke = 0 }

    if #contents == 0 then
        return nil
    end
    return contents
end

function LootInv.HasDeathDropped(source)
    local inv = inventories[tonumber(source)]
    return inv and inv.deathDropped == true
end

local function pedCoords(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then
        return nil
    end
    return GetEntityCoords(ped)
end

function LootInv.BeginUse(source, itemId)
    local state, info = LootInv.CanAct(source)
    if not state then
        return false
    end

    if using[source] then
        return false
    end

    local def = defOf(itemId)
    if not def or def.type ~= 'heal' then
        return false
    end

    local inv = LootInv.Get(source)
    if (inv.healing[def.healId] or 0) < 1 then
        return false
    end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then
        return false
    end

    local health = GetEntityHealth(ped)
    local maxHealth = Config.StartingHealth or 200
    if def.healId == 'bandage' then
        local cap = LootConfig.BandageMaxHealth or 175
        if health >= cap then
            exports.wtbg_core:Notify(source, 'Already healthy enough')
            return false
        end
    elseif health >= maxHealth then
        exports.wtbg_core:Notify(source, 'Already at full health')
        return false
    end

    local coords = GetEntityCoords(ped)
    local duration = def.healId == 'medkit' and (LootConfig.MedkitUseTime or 6) or (LootConfig.BandageUseTime or 3)
    useToken = useToken + 1
    local token = useToken
    using[source] = {
        token = token,
        itemId = itemId,
        matchId = info.matchId,
        x = coords.x,
        y = coords.y,
        z = coords.z
    }

    TriggerClientEvent('wtbg:ui:heal', source, {
        label = def.healId == 'medkit' and 'USING MEDKIT' or 'USING BANDAGE',
        ms = duration * 1000
    })

    SetTimeout(duration * 1000, function()
        local session = using[source]
        if not session or session.token ~= token then
            return
        end
        using[source] = nil

        local still, stillInfo = LootInv.CanAct(source)
        if not still or stillInfo.matchId ~= session.matchId then
            TriggerClientEvent('wtbg:ui:heal', source, nil)
            return
        end

        local now = pedCoords(source)
        if not now or #(now - vector3(session.x, session.y, session.z)) > (LootConfig.HealMoveCancel or 2.4) then
            TriggerClientEvent('wtbg:ui:heal', source, nil)
            exports.wtbg_core:Notify(source, 'Heal cancelled')
            return
        end

        local taken = LootInv.RemoveHeal(source, def.healId, 1)
        if taken < 1 then
            TriggerClientEvent('wtbg:ui:heal', source, nil)
            return
        end

        local p = GetPlayerPed(source)
        if not p or p == 0 then
            return
        end

        local cur = WTBG.PedHealth(p) or 100
        local nxt
        if def.healId == 'medkit' then
            local healTo = tonumber(LootConfig.MedkitHeal) or 0
            nxt = healTo > 0 and healTo or (Config.StartingHealth or 200)
        else
            nxt = math.min(LootConfig.BandageMaxHealth or 175, cur + (LootConfig.BandageHeal or 25))
        end
        WTBG.SetVitals(source, math.max(cur, nxt), nil)
        TriggerClientEvent('wtbg:ui:heal', source, nil)
        LootInv.Sync(source, false)
    end)

    return true
end

function LootInv.ClientCancelUse(source)
    source = tonumber(source)
    if using[source] then
        LootInv.CancelUse(source)
    end
end

exports('ApplySpawnLoadout', function(source)
    LootInv.ApplySpawnLoadout(tonumber(source))
end)

exports('SyncLoadout', function(source)
    LootInv.Sync(tonumber(source), true)
end)
