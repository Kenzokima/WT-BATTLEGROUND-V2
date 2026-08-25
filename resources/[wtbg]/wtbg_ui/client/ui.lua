local menuOpen = false
local screen = 'hidden'

local function nui(payload)
    SendNUIMessage(payload)
end

local function setFocus(value)
    menuOpen = value and true or false
    SetNuiFocus(menuOpen, menuOpen)
    nui({ action = 'menu', open = menuOpen })
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
    setFocus(false)
    nui({
        action = 'showMatch',
        alive = data and data.alive or 0,
        kills = data and data.kills or 0
    })
end)

RegisterNetEvent('wtbg:ui:hud', function(data)
    nui({
        action = 'hud',
        alive = data and data.alive or 0,
        kills = data and data.kills or 0
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
    setFocus(false)
    nui({
        action = 'showResult',
        isWinner = data and data.isWinner or false,
        winnerName = data and data.winnerName or nil,
        kills = data and data.kills or 0,
        placement = data and data.placement or 0,
        totalPlayers = data and data.totalPlayers or 0
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

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    setFocus(false)
    nui({ action = 'hide' })
end)
