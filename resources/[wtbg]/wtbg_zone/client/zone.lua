local sync = nil
local recvAt = 0
local currentBlip = nil
local nextBlip = nil
local wasOutside = false

local function clearBlips()
    if currentBlip then
        RemoveBlip(currentBlip)
        currentBlip = nil
    end
    if nextBlip then
        RemoveBlip(nextBlip)
        nextBlip = nil
    end
end

local function makeRadius(x, y, radius, colour, alpha)
    if radius < 1.0 then
        return nil
    end
    local blip = AddBlipForRadius(x, y, 40.0, radius)
    SetBlipColour(blip, colour)
    SetBlipAlpha(blip, alpha)
    return blip
end

local function progress()
    if not sync then
        return 0.0
    end
    local duration = tonumber(sync.durationMs) or 0
    if duration <= 0 then
        return 1.0
    end
    return math.min(1.0, (GetGameTimer() - recvAt) / duration)
end

local function currentCircle()
    if not sync then
        return nil
    end
    if sync.state ~= 'SHRINKING' then
        return sync.cx, sync.cy, sync.cr
    end
    local t = progress()
    local sx = sync.sx or sync.cx
    local sy = sync.sy or sync.cy
    local sr = sync.sr or sync.cr
    return sx + (sync.tx - sx) * t, sy + (sync.ty - sy) * t, sr + (sync.tr - sr) * t
end

local function remainingMs()
    if not sync then
        return 0
    end
    if sync.state ~= 'HOLDING' and sync.state ~= 'SHRINKING' then
        return 0
    end
    return math.max(0, (tonumber(sync.durationMs) or 0) - (GetGameTimer() - recvAt))
end

local function isOutside()
    if GetResourceState('wtbg_drop') == 'started' then
        local ok, landed = pcall(function()
            return exports.wtbg_drop:IsLanded()
        end)
        if ok and landed == false then
            return false
        end
    end
    local cx, cy, cr = currentCircle()
    if not cx then
        return false
    end
    local coords = GetEntityCoords(PlayerPedId())
    local dx = coords.x - cx
    local dy = coords.y - cy
    return math.sqrt(dx * dx + dy * dy) > cr
end

local function pushHud()
    if not sync then
        TriggerEvent('wtbg:ui:zone', nil)
        return
    end

    local outside = isOutside()
    if outside ~= wasOutside then
        wasOutside = outside
    end

    TriggerEvent('wtbg:ui:zone', {
        phase = sync.phase,
        state = sync.state,
        remaining = math.ceil(remainingMs() / 1000),
        outside = outside,
        waiting = sync.state == 'WAITING'
    })
end

local function refreshBlips()
    clearBlips()
    if not sync or sync.state == 'FINISHED' then
        return
    end

    local cx, cy, cr = currentCircle()
    currentBlip = makeRadius(cx, cy, cr, 46, 140)

    local showNext = sync.state == 'HOLDING' or sync.state == 'WAITING' or sync.state == 'SHRINKING'
    if showNext and sync.tr and sync.tr > 2.0 then
        local same = math.abs((sync.tr or 0) - cr) < 1.0 and math.abs((sync.tx or 0) - cx) < 1.0
        if not same then
            nextBlip = makeRadius(sync.tx, sync.ty, sync.tr, 3, 110)
        end
    end
end

RegisterNetEvent('wtbg:zone:sync', function(payload)
    if type(payload) ~= 'table' then
        return
    end
    sync = payload
    recvAt = GetGameTimer()
    refreshBlips()
    pushHud()
end)

RegisterNetEvent('wtbg:zone:clear', function()
    sync = nil
    wasOutside = false
    clearBlips()
    TriggerEvent('wtbg:ui:zone', nil)
end)

RegisterNetEvent('wtbg:match:finished', function()
    sync = nil
    wasOutside = false
    clearBlips()
    TriggerEvent('wtbg:ui:zone', nil)
end)

RegisterNetEvent('wtbg:core:spawnLobby', function()
    sync = nil
    wasOutside = false
    clearBlips()
    TriggerEvent('wtbg:ui:zone', nil)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    clearBlips()
end)

CreateThread(function()
    while true do
        if not sync then
            Wait(400)
        else
            refreshBlips()
            pushHud()
            Wait(250)
        end
    end
end)
