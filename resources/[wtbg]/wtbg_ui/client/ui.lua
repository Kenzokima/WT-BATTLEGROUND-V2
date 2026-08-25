local menuOpen = false
local inviteOpen = false
local invOpen = false
local bagOpen = false
local screen = 'hidden'
local invitePartyId = nil
local combatCtx = nil
local worldCtx = nil
local lastGuide = ''
local matchPlayable = false

local function nui(payload)
    SendNUIMessage(payload)
end

local applyFocus

local function closeInventory()
    invOpen = false
    bagOpen = false
    applyFocus()
    nui({ action = 'bag', bag = nil })
end

local function isDowned()
    if GetResourceState('wtbg_combat') ~= 'started' then
        return false
    end
    local ok, value = pcall(function()
        return exports.wtbg_combat:IsDowned()
    end)
    return ok and value == true
end

local function isDeploying()
    if GetResourceState('wtbg_drop') ~= 'started' then
        return false
    end
    local ok, landed = pcall(function()
        return exports.wtbg_drop:IsLanded()
    end)
    return ok and landed == false
end

local function canUseInventory()
    if screen ~= 'match' or not matchPlayable or isDowned() or isDeploying() then
        return false
    end
    return not IsPedInAnyVehicle(PlayerPedId(), false)
end

local function pushGuide()
    if screen ~= 'match' or invOpen or bagOpen then
        return
    end
    local rows
    if combatCtx and (combatCtx.kind == 'reviveHint' or combatCtx.kind == 'revive') then
        rows = {
            { key = 'HOLD E', label = 'REVIVE' },
            { key = 'F2 / TAB', label = 'INVENTORY' }
        }
    elseif combatCtx and (combatCtx.kind == 'finishHint' or combatCtx.kind == 'finish') then
        rows = {
            { key = 'HOLD E', label = 'FINISH' },
            { key = 'F2 / TAB', label = 'INVENTORY' }
        }
    else
        rows = {
            { key = 'F2 / TAB', label = 'INVENTORY' },
            { key = 'E', label = 'INTERACT' },
            { key = '1 / 2 / 3', label = 'WEAPON' }
        }
    end
    local fp = (rows[1].key or '') .. (rows[1].label or '') .. (rows[2] and (rows[2].key .. rows[2].label) or '')
    if fp == lastGuide then
        return
    end
    lastGuide = fp
    nui({ action = 'guide', rows = rows })
end

local function pushContext()
    if screen ~= 'match' or invOpen or bagOpen then
        return
    end
    if combatCtx then
        local finish = combatCtx.kind == 'finishHint' or combatCtx.kind == 'finish'
        nui({
            action = 'context',
            show = true,
            key = 'HOLD E',
            verb = finish and 'FINISH' or 'REVIVE',
            detail = combatCtx.name or ''
        })
        pushGuide()
        return
    end
    if worldCtx then
        nui({
            action = 'context',
            show = true,
            key = 'E',
            verb = worldCtx.bag and 'OPEN' or 'PICK UP',
            detail = worldCtx.label or ''
        })
        pushGuide()
        return
    end
    nui({ action = 'context', show = false })
    pushGuide()
end

applyFocus = function()
    local focused = menuOpen or inviteOpen or invOpen or bagOpen
    SetNuiFocusKeepInput(false)
    SetNuiFocus(focused, focused)
    nui({ action = 'menu', open = menuOpen })
    nui({ action = 'inventoryOpen', open = invOpen or bagOpen })
    if invOpen or bagOpen then
        nui({ action = 'context', show = false })
        lastGuide = 'inv'
        nui({ action = 'guide', rows = {} })
    elseif screen == 'match' then
        lastGuide = ''
        pushContext()
    end
end

local function setFocus(value)
    menuOpen = value and true or false
    applyFocus()
end

local function setInviteFocus(value)
    inviteOpen = value and true or false
    applyFocus()
end

RegisterNetEvent('wtbg:ui:showLobby', function(data)
    screen = 'lobby'
    matchPlayable = false
    combatCtx = nil
    worldCtx = nil
    lastGuide = ''
    closeInventory()
    setInviteFocus(false)
    setFocus(false)
    nui({ action = 'context', show = false })
    nui({ action = 'guide', rows = {} })
    nui({
        action = 'showLobby',
        status = data and data.status or 'Lobby',
        matchId = data and data.matchId or nil,
        players = data and data.players or 0,
        maxPlayers = data and data.maxPlayers or 0
    })
end)

RegisterNetEvent('wtbg:ui:showMatch', function(data)
    screen = 'match'
    matchPlayable = true
    setInviteFocus(false)
    if invOpen or bagOpen then
        applyFocus()
    else
        setFocus(false)
    end
    nui({
        action = 'showMatch',
        alive = data and data.alive or 0,
        kills = data and data.kills or 0,
        mode = data and data.mode or nil,
        squad = data and data.squad or nil
    })
end)

RegisterNetEvent('wtbg:ui:hud', function(data)
    nui({
        action = 'hud',
        alive = data and data.alive or 0,
        kills = data and data.kills or 0,
        mode = data and data.mode or nil,
        squad = data and data.squad or nil
    })
end)

RegisterNetEvent('wtbg:ui:killfeed', function(data)
    nui({
        action = 'killfeed',
        killer = data and data.killer or nil,
        victim = data and data.victim or '',
        kind = data and data.kind or 'kill'
    })
end)

local function applyBleed(seconds)
    nui({
        action = 'bleed',
        show = seconds ~= nil,
        seconds = tonumber(seconds) or 0
    })
end

local function applyPrompt(data)
    if type(data) ~= 'table' or (tonumber(data.ms) or 0) <= 0 then
        nui({ action = 'prompt', show = false })
        return
    end

    nui({
        action = 'prompt',
        show = true,
        kind = data.kind,
        ms = tonumber(data.ms) or 0
    })
end

RegisterNetEvent('wtbg:ui:bleed')
AddEventHandler('wtbg:ui:bleed', applyBleed)

RegisterNetEvent('wtbg:ui:prompt')
AddEventHandler('wtbg:ui:prompt', applyPrompt)

RegisterNetEvent('wtbg:ui:showResult', function(data)
    screen = 'result'
    combatCtx = nil
    worldCtx = nil
    lastGuide = ''
    matchPlayable = false
    closeInventory()
    setInviteFocus(false)
    setFocus(false)
    nui({
        action = 'showResult',
        isWinner = data and data.isWinner or false,
        winnerName = data and data.winnerName or nil,
        mode = data and data.mode or nil,
        kills = data and data.kills or 0,
        teamKills = data and data.teamKills or 0,
        placement = data and data.placement or 0,
        totalPlayers = data and data.totalPlayers or 0,
        totalTeams = data and data.totalTeams or 0,
        teammates = data and data.teammates or nil
    })
end)

RegisterNetEvent('wtbg:ui:party', function(data)
    nui({
        action = 'party',
        party = data
    })
end)

RegisterNetEvent('wtbg:ui:partyInvite', function(data)
    if type(data) ~= 'table' then
        invitePartyId = nil
        setInviteFocus(false)
        nui({ action = 'partyInvite', invite = nil })
        return
    end

    invitePartyId = data.partyId
    setInviteFocus(true)
    nui({
        action = 'partyInvite',
        invite = data
    })
end)

RegisterNetEvent('wtbg:core:notify', function(message)
    if type(message) ~= 'string' then
        return
    end

    nui({ action = 'notify', message = message })
end)

RegisterNetEvent('wtbg:ui:inventory', function(data)
    nui({
        action = 'inventory',
        inventory = data
    })
end)

RegisterNetEvent('wtbg:ui:bag', function(data)
    if type(data) ~= 'table' then
        bagOpen = false
        applyFocus()
        nui({ action = 'bag', bag = nil })
        return
    end

    if screen ~= 'match' then
        return
    end

    bagOpen = true
    invOpen = true
    applyFocus()
    nui({ action = 'bag', bag = data })
end)

RegisterNetEvent('wtbg:ui:heal', function(data)
    if type(data) ~= 'table' then
        nui({ action = 'heal', show = false })
        return
    end

    nui({
        action = 'heal',
        show = true,
        label = data.label,
        ms = tonumber(data.ms) or 0
    })
end)

AddEventHandler('wtbg:ui:zone', function(data)
    if type(data) ~= 'table' then
        nui({ action = 'zone', show = false })
        return
    end

    nui({
        action = 'zone',
        show = true,
        phase = tonumber(data.phase) or 1,
        state = data.state,
        remaining = tonumber(data.remaining) or 0,
        outside = data.outside and true or false,
        waiting = data.waiting and true or false
    })
end)

RegisterCommand('wtbgmenu', function()
    if screen ~= 'lobby' then
        return
    end

    setFocus(not menuOpen)
end, false)

RegisterKeyMapping('wtbgmenu', 'WTBG lobby menu', 'keyboard', 'F6')

RegisterCommand('wtbginv', function()
    if screen ~= 'match' then
        return
    end

    if invOpen or bagOpen then
        closeInventory()
        return
    end

    if not canUseInventory() then
        return
    end

    invOpen = true
    applyFocus()
end, false)

RegisterCommand('wtbginvtab', function()
    ExecuteCommand('wtbginv')
end, false)

RegisterKeyMapping('wtbginv', 'WTBG inventory', 'keyboard', 'F2')
RegisterKeyMapping('wtbginvtab', 'WTBG inventory (TAB)', 'keyboard', 'TAB')

AddEventHandler('wtbg:ui:closeInventory', closeInventory)
RegisterNetEvent('wtbg:ui:closeInventory', closeInventory)

AddEventHandler('wtbg:ui:drop', function(data)
    nui({ action = 'drop', drop = data })
end)

RegisterNetEvent('wtbg:ui:dropMember', function(playerId, phase)
    nui({ action = 'dropMember', id = tonumber(playerId), phase = phase })
end)

AddEventHandler('wtbg:ui:combatContext', function(data)
    combatCtx = type(data) == 'table' and data or nil
    pushContext()
end)

AddEventHandler('wtbg:ui:worldContext', function(data)
    worldCtx = type(data) == 'table' and data or nil
    pushContext()
end)

AddEventHandler('wtbg:ui:vicinity', function(list)
    nui({ action = 'vicinity', list = type(list) == 'table' and list or {} })
end)

RegisterNetEvent('wtbg:match:playerDied', function()
    matchPlayable = false
    closeInventory()
end)

RegisterNetEvent('wtbg:match:finished', function()
    matchPlayable = false
    combatCtx = nil
    worldCtx = nil
    lastGuide = ''
    closeInventory()
    nui({ action = 'context', show = false })
    nui({ action = 'guide', rows = {} })
end)

RegisterNUICallback('pickupLoot', function(data, cb)
    if not canUseInventory() or type(data) ~= 'table' then
        cb({ ok = false })
        return
    end
    TriggerServerEvent('wtbg:loot:pickup', tonumber(data.lootId))
    cb({ ok = true })
end)

RegisterNUICallback('closeMenu', function(_, cb)
    setFocus(false)
    cb({ ok = true })
end)

RegisterNUICallback('createMatch', function(_, cb)
    TriggerServerEvent('wtbg:match:create')
    cb({ ok = true })
end)

RegisterNUICallback('joinMatch', function(data, cb)
    local matchId = data and data.matchId
    TriggerServerEvent('wtbg:match:join', matchId)
    cb({ ok = true })
end)

RegisterNUICallback('startMatch', function(_, cb)
    TriggerServerEvent('wtbg:match:start')
    cb({ ok = true })
end)

RegisterNUICallback('leaveMatch', function(_, cb)
    TriggerServerEvent('wtbg:match:leave')
    setFocus(false)
    cb({ ok = true })
end)

RegisterNUICallback('acceptInvite', function(data, cb)
    local partyId = (data and data.partyId) or invitePartyId
    TriggerServerEvent('wtbg:party:accept', partyId)
    invitePartyId = nil
    setInviteFocus(false)
    cb({ ok = true })
end)

RegisterNUICallback('declineInvite', function(data, cb)
    local partyId = (data and data.partyId) or invitePartyId
    TriggerServerEvent('wtbg:party:decline', partyId)
    invitePartyId = nil
    setInviteFocus(false)
    cb({ ok = true })
end)

RegisterNUICallback('closeInventory', function(_, cb)
    invOpen = false
    bagOpen = false
    applyFocus()
    nui({ action = 'bag', bag = nil })
    cb({ ok = true })
end)

RegisterNUICallback('closeBag', function(_, cb)
    bagOpen = false
    applyFocus()
    cb({ ok = true })
end)

RegisterNUICallback('dropItem', function(data, cb)
    if not canUseInventory() or type(data) ~= 'table' then
        cb({ ok = false })
        return
    end
    TriggerServerEvent('wtbg:loot:drop', data.kind, data.key, tonumber(data.amount) or 1)
    cb({ ok = true })
end)

RegisterNUICallback('useItem', function(data, cb)
    if not canUseInventory() or type(data) ~= 'table' then
        cb({ ok = false })
        return
    end
    TriggerServerEvent('wtbg:loot:use', data.itemId)
    cb({ ok = true })
end)

RegisterNUICallback('bagTake', function(data, cb)
    if not canUseInventory() or type(data) ~= 'table' then
        cb({ ok = false })
        return
    end
    TriggerServerEvent('wtbg:loot:bagTake', tonumber(data.lootId), tonumber(data.uid))
    cb({ ok = true })
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    setInviteFocus(false)
    setFocus(false)
    matchPlayable = false
    invOpen = false
    bagOpen = false
    nui({ action = 'hide' })
end)

CreateThread(function()
    while true do
        if screen == 'match' then
            DisableControlAction(0, 37, true)
            HideHudComponentThisFrame(19)
            if invOpen or bagOpen then
                DisablePlayerFiring(PlayerId(), true)
                DisableControlAction(0, 24, true)
                DisableControlAction(0, 25, true)
                DisableControlAction(0, 68, true)
                DisableControlAction(0, 69, true)
                DisableControlAction(0, 70, true)
                DisableControlAction(0, 91, true)
                DisableControlAction(0, 92, true)
                DisableControlAction(0, 140, true)
                DisableControlAction(0, 141, true)
                DisableControlAction(0, 142, true)
                DisableControlAction(0, 257, true)
                DisableControlAction(0, 263, true)
                DisableControlAction(0, 264, true)
                DisableControlAction(0, 14, true)
                DisableControlAction(0, 15, true)
                DisableControlAction(0, 16, true)
                DisableControlAction(0, 17, true)
            end
            Wait(0)
        else
            Wait(400)
        end
    end
end)
