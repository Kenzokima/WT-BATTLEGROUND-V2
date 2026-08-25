local function validAmount(value)
    local n = tonumber(value)
    if not n then
        return nil
    end
    n = math.floor(n)
    if n < 1 or n > 999 then
        return nil
    end
    return n
end

AddEventHandler('wtbg:match:starting', function(matchId, bucket)
    LootWorld.Generate(matchId, bucket)
end)

AddEventHandler('wtbg:match:becameActive', function(matchId, bucket)
    LootWorld.Ensure(matchId, bucket)
    local snap = exports.wtbg_match:GetMatch(matchId)
    if snap and WTBG.UsesBRDeployment(snap.mode) and GetResourceState('wtbg_drop') == 'started' then
        return
    end
    local sources = exports.wtbg_match:GetMatchSources(matchId) or {}
    for i = 1, #sources do
        LootWorld.FullSync(sources[i], matchId)
    end
end)

AddEventHandler('wtbg:drop:playerLanded', function(source, matchId)
    LootWorld.FullSync(source, matchId)
end)

AddEventHandler('wtbg:match:serverFinished', function(matchId)
    matchId = tonumber(matchId)
    local sources = exports.wtbg_match:GetMatchSources(matchId) or {}
    for i = 1, #sources do
        LootInv.CancelUse(sources[i])
    end
    LootWorld.ClearMatch(matchId)
end)

AddEventHandler('wtbg:match:destroyed', function(matchId)
    LootWorld.ClearMatch(matchId)
end)

AddEventHandler('wtbg:match:playerEliminated', function(source, matchId, matchState)
    LootInv.CancelUse(source)
    LootWorld.DropDeath(source, matchId, matchState)
end)

AddEventHandler('wtbg:match:playerDowned', function(source)
    LootInv.CancelUse(source)
end)

AddEventHandler('wtbg:core:returnedToLobby', function(source)
    LootInv.Clear(source)
    TriggerClientEvent('wtbg:loot:clear', source, nil)
    TriggerClientEvent('wtbg:ui:inventory', source, nil)
    TriggerClientEvent('wtbg:ui:bag', source, nil)
    TriggerClientEvent('wtbg:ui:heal', source, nil)
end)

AddEventHandler('wtbg:core:playerDropped', function(source)
    LootInv.Clear(source)
end)

RegisterNetEvent('wtbg:loot:pickup', function(lootId)
    LootWorld.Pickup(source, lootId)
end)

RegisterNetEvent('wtbg:loot:bagTake', function(lootId, uid)
    LootWorld.TakeFromBag(source, lootId, uid)
end)

RegisterNetEvent('wtbg:loot:drop', function(kind, key, amount)
    if type(kind) ~= 'string' or type(key) ~= 'string' then
        return
    end
    LootWorld.Drop(source, kind, key, validAmount(amount) or 1)
end)

RegisterNetEvent('wtbg:loot:use', function(itemId)
    if type(itemId) ~= 'string' then
        return
    end
    LootInv.BeginUse(source, itemId)
end)

RegisterNetEvent('wtbg:loot:cancelUse', function()
    LootInv.ClientCancelUse(source)
end)
