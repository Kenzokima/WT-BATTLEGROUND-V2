local menuOpen = false
local inviteOpen = false
local screen = 'hidden'
local invitePartyId = nil

local function nui(payload)
    SendNUIMessage(payload)
end

local function applyFocus()
    local focused = menuOpen or inviteOpen
    SetNuiFocus(focused, focused)
    nui({ action = 'menu', open = menuOpen })
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
    setFocus(false)
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
    setInviteFocus(false)
    setFocus(false)
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
        victim = data and data.victim or ''
    })
end)

RegisterNetEvent('wtbg:ui:showResult', function(data)
    screen = 'result'
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

RegisterCommand('wtbgmenu', function()
    if screen ~= 'lobby' then
        return
    end

    setFocus(not menuOpen)
end, false)

RegisterKeyMapping('wtbgmenu', 'WTBG lobby menu', 'keyboard', 'F6')

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

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    setInviteFocus(false)
    setFocus(false)
    nui({ action = 'hide' })
end)
