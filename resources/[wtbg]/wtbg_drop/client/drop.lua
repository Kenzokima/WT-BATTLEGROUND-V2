local phase = nil
local route = nil
local flyStart = 0
local plane = nil
local planeReady = false
local startBlip = nil
local endBlip = nil
local planeBlip = nil
local landSent = false
local chuteSent = false
local landStable = 0
local lastHud = ''
local gen = 0
local cam = nil
local camPos = nil
local passengers = {}
local clones = {}
local hidden = {}
local seatDictReady = false
local lastSeatCheck = 0
local cloneSlots = {}
local pilot = nil
local aiFlying = false
local lookYaw = 0.0
local lookPitch = 0.0

local function clearBlips()
    if startBlip then
        RemoveBlip(startBlip)
        startBlip = nil
    end
    if endBlip then
        RemoveBlip(endBlip)
        endBlip = nil
    end
    if planeBlip then
        RemoveBlip(planeBlip)
        planeBlip = nil
    end
end

local function makeCoordBlip(x, y, sprite, colour)
    local blip = AddBlipForCoord(x, y, 40.0)
    SetBlipSprite(blip, sprite)
    SetBlipColour(blip, colour)
    SetBlipScale(blip, 0.7)
    SetBlipAsShortRange(blip, false)
    return blip
end

local function destroyCam(blend)
    lookYaw = 0.0
    lookPitch = 0.0
    camPos = nil
    if not cam or not DoesCamExist(cam) then
        RenderScriptCams(false, false, 0, true, true)
        cam = nil
        return
    end
    local ms = blend and (tonumber(DropConfig.CameraBlend) or 350) or 0
    RenderScriptCams(false, true, ms, true, true)
    DestroyCam(cam, false)
    cam = nil
end

local function deletePilot()
    if pilot and DoesEntityExist(pilot) then
        DeleteEntity(pilot)
    end
    pilot = nil
    aiFlying = false
end

local function deletePlane()
    deletePilot()
    if plane and DoesEntityExist(plane) then
        DeleteEntity(plane)
    end
    plane = nil
    planeReady = false
end

local function isolateLocal(ent)
    if not ent or ent == 0 then
        return
    end
    SetEntityAsMissionEntity(ent, true, true)
end

local function hideRemotePeds()
    local my = PlayerId()
    for _, p in ipairs(GetActivePlayers()) do
        if p ~= my then
            pcall(function()
                NetworkConcealPlayer(p, true, false)
            end)
            local ped = GetPlayerPed(p)
            if DoesEntityExist(ped) then
                SetEntityVisible(ped, false, false)
                SetEntityAlpha(ped, 0, false)
                SetEntityCollision(ped, false, false)
                hidden[GetPlayerServerId(p)] = ped
            end
        end
    end
end

local function hideForeignTitans()
    if not plane then
        return
    end
    local hash = joaat(DropConfig.PlaneModel or 'titan')
    local pool = GetGamePool('CVehicle')
    for i = 1, #pool do
        local veh = pool[i]
        if veh ~= plane and GetEntityModel(veh) == hash then
            SetEntityVisible(veh, false, false)
            SetEntityAlpha(veh, 0, false)
            pcall(function()
                NetworkConcealEntity(veh, true)
            end)
        end
    end
end

local function clearClones()
    for id, ent in pairs(clones) do
        if ent and DoesEntityExist(ent) then
            DetachEntity(ent, true, true)
            DeleteEntity(ent)
        end
        clones[id] = nil
        cloneSlots[id] = nil
    end
    for id, ped in pairs(hidden) do
        local idx = GetPlayerFromServerId(id)
        if idx ~= -1 then
            pcall(function()
                NetworkConcealPlayer(idx, false, false)
            end)
        end
        if ped and DoesEntityExist(ped) then
            SetEntityVisible(ped, true, false)
            SetEntityCollision(ped, true, true)
            ResetEntityAlpha(ped)
        end
        hidden[id] = nil
    end
end

local function stopSeatAnim(ped)
    if not DoesEntityExist(ped) then
        return
    end
    local anim = DropConfig.SeatAnim
    if anim and IsEntityPlayingAnim(ped, anim.dict, anim.clip, 3) then
        StopAnimTask(ped, anim.dict, anim.clip, 1.0)
    end
    ClearPedTasksImmediately(ped)
end

local function detachLocal(keepFrozen)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityVelocity(ped, 0.0, 0.0, 0.0)
    stopSeatAnim(ped)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then
        TaskLeaveVehicle(ped, veh, 16)
        ClearPedTasksImmediately(ped)
    end
    if IsEntityAttached(ped) then
        DetachEntity(ped, false, true)
    end
    SetEntityVelocity(ped, 0.0, 0.0, 0.0)
    FreezeEntityPosition(ped, keepFrozen and true or false)
    SetEntityCollision(ped, true, true)
    SetEntityVisible(ped, true, false)
    SetEntityInvincible(ped, false)
    SetPlayerInvincible(PlayerId(), false)
    SetPedCanRagdoll(ped, true)
end

local function clearDrop(restore)
    phase = nil
    route = nil
    landSent = false
    chuteSent = false
    lastHud = ''
    gen = 0
    passengers = {}
    destroyCam(false)
    clearClones()
    detachLocal()
    deletePlane()
    clearBlips()
    TriggerEvent('wtbg:ui:drop', nil)
    if restore then
        exports.wtbg_core:UnlockCombat()
    end
end

local function loadModel(name)
    local hash = joaat(name)
    if not HasModelLoaded(hash) then
        RequestModel(hash)
        local t = GetGameTimer() + 5000
        while not HasModelLoaded(hash) and GetGameTimer() < t do
            Wait(0)
        end
    end
    return hash
end

local function ensureSeatDict()
    local anim = DropConfig.SeatAnim
    if not anim or seatDictReady then
        return seatDictReady
    end
    if not HasAnimDictLoaded(anim.dict) then
        RequestAnimDict(anim.dict)
        return false
    end
    seatDictReady = true
    return true
end

local function playSeat(ped)
    local anim = DropConfig.SeatAnim
    if not anim or not DoesEntityExist(ped) or not ensureSeatDict() then
        return
    end
    if not IsEntityPlayingAnim(ped, anim.dict, anim.clip, 3) then
        TaskPlayAnim(ped, anim.dict, anim.clip, 8.0, -8.0, -1, 1, 0.0, false, false, false)
    end
end

local function progress()
    if not route then
        return 0.0
    end
    if not route.flying then
        return 0.0
    end
    local span = tonumber(route.durationMs) or 1
    return math.min(1.0, math.max(0.0, (GetGameTimer() - flyStart) / span))
end

local function routeHeading()
    if not route then
        return 0.0
    end
    return DropConfig.TravelHeading(route.sx, route.sy, route.fx, route.fy)
end

local function routePosAt(t)
    t = math.min(1.0, math.max(0.0, tonumber(t) or 0.0))
    local x = route.sx + (route.fx - route.sx) * t
    local y = route.sy + (route.fy - route.sy) * t
    local z = route.sz + (route.fz - route.sz) * t
    return x, y, z, routeHeading()
end

local function routePos()
    return routePosAt(progress())
end

local function routeDistance()
    if not route then
        return 1.0
    end
    local dx = (route.fx or 0.0) - (route.sx or 0.0)
    local dy = (route.fy or 0.0) - (route.sy or 0.0)
    local dz = (route.fz or 0.0) - (route.sz or 0.0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function cruiseSpeed(veh)
    local dist = routeDistance()
    local sec = math.max(1.0, (tonumber(route and route.durationMs) or 80000) / 1000.0)
    local needed = dist / sec
    local modelMax = 72.0
    if veh and DoesEntityExist(veh) then
        local ok, v = pcall(GetVehicleModelMaxSpeed, GetEntityModel(veh))
        if ok and type(v) == 'number' and v > 10.0 then
            modelMax = v
        end
    end
    local cap = tonumber(DropConfig.MaxCruiseSpeed)
    if cap and cap > 0.0 then
        return math.max(40.0, math.min(cap, needed))
    end
    -- Stay close to GTA Titan cruise; modest boost so the drop still covers ground.
    return math.max(40.0, math.min(needed, modelMax * 1.25))
end

local function keepEngineRunning(veh, speed)
    if not veh or not DoesEntityExist(veh) then
        return
    end
    SetVehicleEngineOn(veh, true, true, false)
    SetVehicleUndriveable(veh, false)
    SetVehicleKeepEngineOnWhenAbandoned(veh, true)
    if speed and speed > 1.0 then
        pcall(function()
            SetVehicleForwardSpeed(veh, speed)
        end)
    end
    pcall(function()
        SetVehicleCurrentRpm(veh, 0.92)
    end)
end

local function applyPlanePose(veh)
    if not veh or not route then
        return
    end
    local x, y, z, h = routePos()
    local pitch = tonumber(DropConfig.FlightPitch) or -1.5
    FreezeEntityPosition(veh, true)
    SetEntityCollision(veh, false, false)
    SetEntityCoordsNoOffset(veh, x, y, z, false, false, false)
    SetEntityRotation(veh, pitch, 0.0, h, 2, true)
    keepEngineRunning(veh)
end

local function ensurePilot(veh)
    if not veh or not DoesEntityExist(veh) then
        return nil
    end
    if pilot and DoesEntityExist(pilot) and IsPedInVehicle(pilot, veh, false) then
        return pilot
    end
    if pilot and DoesEntityExist(pilot) then
        DeleteEntity(pilot)
    end
    pilot = nil

    local hash = joaat(DropConfig.PilotModel or 's_m_m_pilot_01')
    if not HasModelLoaded(hash) then
        RequestModel(hash)
        return nil
    end

    local ped = CreatePedInsideVehicle(veh, 26, hash, -1, false, false)
    if not ped or ped == 0 then
        local c = GetEntityCoords(veh)
        ped = CreatePed(26, hash, c.x, c.y, c.z, GetEntityHeading(veh), false, false)
        if ped and ped ~= 0 then
            SetPedIntoVehicle(ped, veh, -1)
        end
    end
    if not ped or ped == 0 then
        return nil
    end

    isolateLocal(ped)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityInvincible(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedCanBeDraggedOut(ped, false)
    SetPedFleeAttributes(ped, 0, false)
    SetPedKeepTask(ped, true)
    SetDriverAbility(ped, 1.0)
    SetDriverAggressiveness(ped, 0.0)
    SetEntityVisible(ped, true, false)
    SetModelAsNoLongerNeeded(hash)
    pilot = ped
    return ped
end

local function taskFlyToEnd(driver, veh, speed)
    if not driver or not veh or not route then
        return
    end
    local h = routeHeading()
    ClearPedTasks(driver)
    pcall(function()
        TaskPlaneMission(driver, veh, 0, 0, route.fx, route.fy, route.fz, 4, speed, 1.0, h, 2000.0, 80.0)
    end)
end

local function beginCruise()
    if aiFlying or not plane or not DoesEntityExist(plane) or not route then
        return
    end
    local driver = ensurePilot(plane)
    if not driver then
        return
    end

    local speed = cruiseSpeed(plane)
    local h = routeHeading()
    local fx, fy = DropConfig.Forward(h)
    pcall(function()
        SetVehicleLandingGear(plane, 3)
        SetPlaneTurbulenceMultiplier(plane, tonumber(DropConfig.CruiseTurbulence) or 0.28)
        SetVehicleCheatPowerIncrease(plane, 8.0)
        ModifyVehicleTopSpeed(plane, speed * 1.2)
        SetPlaneMinHeightAboveTerrain(plane, 80)
        SetVehicleGravity(plane, true)
    end)
    SetEntityCollision(plane, true, true)
    SetEntityInvincible(plane, true)
    SetEntityHasGravity(plane, true)
    keepEngineRunning(plane)
    SetVehicleForwardSpeed(plane, speed)
    SetEntityVelocity(plane, fx * speed, fy * speed, 0.0)
    FreezeEntityPosition(plane, false)
    taskFlyToEnd(driver, plane, speed)
    aiFlying = true
end

local function maintainCruise(veh)
    if not veh or not route then
        return
    end

    FreezeEntityPosition(veh, false)
    SetEntityCollision(veh, true, true)
    SetEntityHasGravity(veh, true)
    keepEngineRunning(veh)
    pcall(function()
        SetVehicleLandingGear(veh, 3)
        SetVehicleGravity(veh, true)
    end)

    local speed = cruiseSpeed(veh)
    local driver = ensurePilot(veh)
    if driver and not IsPedInVehicle(driver, veh, false) then
        SetPedIntoVehicle(driver, veh, -1)
        taskFlyToEnd(driver, veh, speed)
    end

    local current = GetEntitySpeed(veh)
    local c = GetEntityCoords(veh)
    local vel = GetEntityVelocity(veh)
    -- Stall / dive recovery only. Do not drive the plane every frame.
    if current < 16.0 then
        local h = GetEntityHeading(veh)
        local fx, fy = DropConfig.Forward(h)
        SetVehicleForwardSpeed(veh, speed)
        SetEntityVelocity(veh, fx * speed, fy * speed, math.max(vel.z, -2.0))
    elseif vel.z < -14.0 and c.z < (route.sz - 30.0) then
        SetEntityVelocity(veh, vel.x, vel.y, -4.0)
    end

    if c.z < 90.0 then
        local x, y, z, h = routePos()
        SetEntityCoordsNoOffset(veh, x, y, z, false, false, false)
        SetEntityHeading(veh, h)
        SetVehicleForwardSpeed(veh, speed)
        aiFlying = false
    end
end

local function ensurePlane()
    if plane and DoesEntityExist(plane) then
        return plane
    end
    if pilot and DoesEntityExist(pilot) then
        DeleteEntity(pilot)
    end
    pilot = nil
    aiFlying = false

    local hash = loadModel(DropConfig.PlaneModel or 'titan')
    if not HasModelLoaded(hash) then
        return nil
    end
    local x, y, z, h = routePos()
    plane = CreateVehicle(hash, x, y, z, h, false, false)
    if not plane or plane == 0 then
        plane = nil
        return nil
    end
    isolateLocal(plane)
    SetEntityCollision(plane, false, false)
    SetEntityInvincible(plane, true)
    SetEntityProofs(plane, true, true, true, true, true, true, true, true)
    FreezeEntityPosition(plane, true)
    keepEngineRunning(plane)
    SetVehRadioStation(plane, 'OFF')
    SetVehicleKeepEngineOnWhenAbandoned(plane, true)
    pcall(function()
        SetVehicleLandingGear(plane, 3)
    end)
    SetEntityLodDist(plane, 800)
    SetModelAsNoLongerNeeded(hash)
    RequestModel(joaat(DropConfig.PilotModel or 's_m_m_pilot_01'))
    SetEntityCoordsNoOffset(plane, x, y, z, false, false, false)
    SetEntityHeading(plane, h)
    ensurePilot(plane)
    if cam then
        DestroyCam(cam, false)
        cam = nil
    end
    planeReady = true
    return plane
end

local function offsets()
    return DropConfig.PassengerOffsets or {}
end

local function slotFor(serverId)
    local mine = GetPlayerServerId(PlayerId())
    local list = passengers
    if #list == 0 then
        return serverId == mine and 1 or nil
    end
    for i = 1, #list do
        if list[i] == serverId then
            return i
        end
    end
    return nil
end

local function attachPassenger(ent, slot, key)
    local veh = plane
    local seats = offsets()
    if not veh or not seats[slot] then
        return
    end
    if key and cloneSlots[key] == slot and IsEntityAttachedToEntity(ent, veh) then
        playSeat(ent)
        return
    end
    local off = seats[slot]
    if IsEntityAttachedToEntity(ent, veh) then
        DetachEntity(ent, false, false)
    end
    AttachEntityToEntity(ent, veh, 0, off.x, off.y, off.z, 0.0, 0.0, off.h or 0.0, false, false, false, true, 2, true)
    SetEntityCollision(ent, false, false)
    if key then
        cloneSlots[key] = slot
    end
    playSeat(ent)
end

local function updateChaseCam()
    if not plane or not DoesEntityExist(plane) then
        return
    end
    if not cam or not DoesCamExist(cam) then
        cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        SetCamFov(cam, tonumber(DropConfig.CameraFov) or 52.0)
        SetCamActive(cam, true)
        RenderScriptCams(true, false, 0, true, true)
        camPos = nil
    end
    local mx = GetDisabledControlNormal(0, 1)
    local my = GetDisabledControlNormal(0, 2)
    lookYaw = lookYaw - mx * 7.0
    if lookYaw > 120.0 then
        lookYaw = 120.0
    elseif lookYaw < -120.0 then
        lookYaw = -120.0
    end
    lookPitch = lookPitch - my * 5.0
    if lookPitch > 28.0 then
        lookPitch = 28.0
    elseif lookPitch < -40.0 then
        lookPitch = -40.0
    end
    local planePos = GetEntityCoords(plane)
    local planeHeading = GetEntityHeading(plane)
    local off = DropConfig.CameraOffset or vector3(0.0, -34.0, 14.0)
    local look = DropConfig.CameraLook or vector3(0.0, 14.0, 1.5)
    local orbitHeading = planeHeading + lookYaw
    local orbitFx, orbitFy = DropConfig.Forward(orbitHeading)
    local orbitRad = math.rad(orbitHeading)
    local rightX, rightY = math.cos(orbitRad), math.sin(orbitRad)
    local distance = math.abs(off.y)
    local desiredX = planePos.x - orbitFx * distance + rightX * off.x
    local desiredY = planePos.y - orbitFy * distance + rightY * off.x
    local desiredZ = planePos.z + off.z + lookPitch * 0.18

    if not camPos then
        camPos = vector3(desiredX, desiredY, desiredZ)
    else
        local smoothing = tonumber(DropConfig.CameraSmoothing) or 7.5
        local alpha = 1.0 - math.exp(-smoothing * math.max(GetFrameTime(), 0.001))
        camPos = vector3(
            camPos.x + (desiredX - camPos.x) * alpha,
            camPos.y + (desiredY - camPos.y) * alpha,
            camPos.z + (desiredZ - camPos.z) * alpha
        )
    end

    local planeFx, planeFy = DropConfig.Forward(planeHeading)
    SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
    PointCamAtCoord(
        cam,
        planePos.x + planeFx * look.y,
        planePos.y + planeFy * look.y,
        planePos.z + look.z
    )
end

local function attachLocal()
    local veh = ensurePlane()
    local ped = PlayerPedId()
    if not veh or not DoesEntityExist(ped) then
        return
    end
    if GetVehiclePedIsIn(ped, false) ~= 0 then
        TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16)
    end
    local slot = slotFor(GetPlayerServerId(PlayerId())) or 1
    local seats = offsets()
    if #seats > 0 and slot > #seats then
        slot = ((slot - 1) % #seats) + 1
    end
    attachPassenger(ped, slot, 'local')
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetPlayerInvincible(PlayerId(), true)
    SetPedCanRagdoll(ped, false)
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
end

local function hideRemote(serverId)
    if serverId == GetPlayerServerId(PlayerId()) then
        return
    end
    local idx = GetPlayerFromServerId(serverId)
    if idx == -1 then
        return
    end
    local ped = GetPlayerPed(idx)
    if not DoesEntityExist(ped) then
        return
    end
    SetEntityVisible(ped, false, false)
    SetEntityCollision(ped, false, false)
    hidden[serverId] = ped
end

local function makeClone(serverId, slot)
    if clones[serverId] and DoesEntityExist(clones[serverId]) then
        attachPassenger(clones[serverId], slot, serverId)
        return
    end
    local idx = GetPlayerFromServerId(serverId)
    if idx == -1 then
        return
    end
    local src = GetPlayerPed(idx)
    if not DoesEntityExist(src) or not plane then
        return
    end
    local ok, clone = pcall(ClonePed, src, false, false, true)
    if not ok or not clone or clone == 0 then
        ok, clone = pcall(ClonePed, src, GetEntityHeading(src), false, false)
    end
    if not ok or not clone or clone == 0 then
        return
    end
    isolateLocal(clone)
    SetEntityVisible(clone, true, false)
    ResetEntityAlpha(clone)
    SetEntityInvincible(clone, true)
    SetBlockingOfNonTemporaryEvents(clone, true)
    SetPedCanRagdoll(clone, false)
    clones[serverId] = clone
    hideRemote(serverId)
    attachPassenger(clone, slot, serverId)
end

local function refreshPassengers()
    if phase ~= 'PLANE' or not plane then
        return
    end
    local mine = GetPlayerServerId(PlayerId())
    local maxVis = tonumber(DropConfig.MaxVisiblePassengers) or 8
    local shown = { [mine] = true }
    local n = 1
    for i = 1, #passengers do
        local id = passengers[i]
        if id ~= mine and n < maxVis then
            local slot = slotFor(id)
            if slot and slot <= #offsets() then
                makeClone(id, slot)
                shown[id] = true
                n = n + 1
            end
        end
    end
    for id, ent in pairs(clones) do
        if not shown[id] then
            if ent and DoesEntityExist(ent) then
                DeleteEntity(ent)
            end
            clones[id] = nil
            cloneSlots[id] = nil
        end
    end
end

local function setupBlips()
    clearBlips()
    if not route then
        return
    end
    startBlip = makeCoordBlip(route.sx, route.sy, 1, 0)
    endBlip = makeCoordBlip(route.fx, route.fy, 1, 5)
    planeBlip = makeCoordBlip(route.sx, route.sy, 307, 3)
    SetBlipRotation(planeBlip, math.floor(routeHeading()))
end

local function pushHud(force)
    local payload
    if phase == 'PLANE' then
        local left = 0
        if route and route.flying then
            left = math.max(0, math.ceil((tonumber(route.durationMs) - (GetGameTimer() - flyStart)) / 1000))
        end
        payload = {
            phase = 'PLANE',
            key = 'SPACE',
            label = 'JUMP',
            autoDrop = left
        }
    elseif phase == 'FREEFALL' then
        payload = { phase = 'FREEFALL', key = 'SPACE', label = 'PARACHUTE' }
    elseif phase == 'PARACHUTE' then
        payload = { phase = 'PARACHUTE' }
    end

    local fp = payload and (payload.phase .. tostring(payload.autoDrop or '') .. (payload.label or '')) or ''
    if not force and fp == lastHud then
        return
    end
    lastHud = fp
    TriggerEvent('wtbg:ui:drop', payload)
end

local function agl()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local found, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z, false)
    if found then
        return c.z - gz
    end
    return GetEntityHeightAboveGround(ped)
end

local function giveChute()
    local ped = PlayerPedId()
    if not HasPedGotWeapon(ped, `GADGET_PARACHUTE`, false) then
        GiveWeaponToPed(ped, `GADGET_PARACHUTE`, 1, false, true)
    end
end

local function blockCombat()
    DisablePlayerFiring(PlayerId(), true)
    DisableControlAction(0, 24, true)
    DisableControlAction(0, 25, true)
    DisableControlAction(0, 30, true)
    DisableControlAction(0, 31, true)
    DisableControlAction(0, 32, true)
    DisableControlAction(0, 33, true)
    DisableControlAction(0, 34, true)
    DisableControlAction(0, 35, true)
    DisableControlAction(0, 37, true)
    DisableControlAction(0, 44, true)
    DisableControlAction(0, 45, true)
    DisableControlAction(0, 140, true)
    DisableControlAction(0, 141, true)
    DisableControlAction(0, 142, true)
    DisableControlAction(0, 257, true)
    DisableControlAction(0, 263, true)
    DisableControlAction(0, 264, true)
    HideHudComponentThisFrame(19)
end

local function releasePose(data)
    local current = progress()
    local lo = tonumber(data.releaseMinProgress) or 0.0
    local hi = tonumber(data.releaseMaxProgress) or 1.0
    local accepted = math.min(hi, math.max(lo, current))
    local back = tonumber(data.exitBack) or tonumber(DropConfig.JumpExitBack) or 16.0
    local down = tonumber(data.exitDown) or tonumber(DropConfig.JumpExitDown) or 4.0

    if plane and DoesEntityExist(plane) and accepted == current then
        local c = GetOffsetFromEntityInWorldCoords(plane, 0.0, -back, -down)
        return c.x, c.y, c.z, GetEntityHeading(plane)
    end

    local x, y, z, h = routePosAt(accepted)
    local fx, fy = DropConfig.Forward(h)
    return x - fx * back, y - fy * back, z - down, h
end

local function beginFreefall(data)
    local x, y, z, heading = releasePose(data)
    phase = 'FREEFALL'
    landSent = false
    chuteSent = false
    landStable = 0
    destroyCam(true)
    clearClones()
    detachLocal(true)
    deletePlane()
    local ped = PlayerPedId()
    RequestCollisionAtCoord(x, y, z)
    SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
    SetEntityHeading(ped, heading)
    SetEntityVelocity(ped, 0.0, 0.0, 0.0)
    FreezeEntityPosition(ped, false)
    SetEntityVelocity(ped, 0.0, 0.0, -8.0)
    giveChute()
    pcall(function()
        TaskSkyDive(ped, true)
    end)
    pushHud(true)
end

RegisterNetEvent('wtbg:drop:board', function(data)
    if type(data) ~= 'table' then
        return
    end
    clearDrop(false)
    route = data
    gen = tonumber(data.gen) or 0
    phase = 'PLANE'
    landSent = false
    chuteSent = false
    seatDictReady = false
    TriggerEvent('wtbg:ui:closeInventory')
    DoScreenFadeOut(120)
    Wait(160)
    local ped = PlayerPedId()
    RemoveAllPedWeapons(ped, true)
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
    local hp = Config.StartingHealth or 200
    SetPedMaxHealth(ped, hp)
    SetEntityMaxHealth(ped, hp)
    SetEntityHealth(ped, hp)
    SetPedArmour(ped, 0)
    setupBlips()
    RequestModel(joaat(DropConfig.PilotModel or 's_m_m_pilot_01'))
    attachLocal()
    updateChaseCam()
    DoScreenFadeIn(220)
    pushHud(true)
end)

RegisterNetEvent('wtbg:drop:go', function(data)
    if type(data) ~= 'table' then
        return
    end
    if route and tonumber(data.matchId) ~= tonumber(route.matchId) then
        return
    end
    route = data
    gen = tonumber(data.gen) or gen
    flyStart = GetGameTimer()
    if phase ~= 'PLANE' then
        phase = 'PLANE'
    end
    route.flying = true
    setupBlips()
    attachLocal()
    updateChaseCam()
    beginCruise()
    hideForeignTitans()
    hideRemotePeds()
    pushHud(true)
end)

RegisterNetEvent('wtbg:drop:passengers', function(list)
    passengers = type(list) == 'table' and list or {}
    if phase == 'PLANE' then
        refreshPassengers()
        attachLocal()
    end
end)

RegisterNetEvent('wtbg:drop:jump', function(data)
    if type(data) ~= 'table' or phase ~= 'PLANE' then
        return
    end
    beginFreefall(data)
end)

RegisterNetEvent('wtbg:drop:phase', function(nextPhase)
    if nextPhase == 'PARACHUTE' and (phase == 'FREEFALL' or phase == 'PARACHUTE') then
        phase = 'PARACHUTE'
        pushHud(true)
    end
end)

RegisterNetEvent('wtbg:drop:landed', function()
    phase = 'LANDED'
    landSent = true
    destroyCam(false)
    clearClones()
    detachLocal()
    deletePlane()
    clearBlips()
    local ped = PlayerPedId()
    RemoveWeaponFromPed(ped, `GADGET_PARACHUTE`)
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
    exports.wtbg_core:UnlockCombat()
    TriggerEvent('wtbg:ui:drop', { phase = 'LANDED' })
    SetTimeout(900, function()
        if phase == 'LANDED' then
            phase = nil
            lastHud = ''
            TriggerEvent('wtbg:ui:drop', nil)
        end
    end)
end)

RegisterNetEvent('wtbg:drop:clear', function()
    clearDrop(true)
end)

RegisterNetEvent('wtbg:match:finished', function()
    clearDrop(true)
end)

RegisterNetEvent('wtbg:core:spawnLobby', function()
    clearDrop(true)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    clearDrop(true)
end)

CreateThread(function()
    while true do
        if phase == 'PLANE' and route then
            ensureSeatDict()
            local veh = ensurePlane()
            if veh then
                if route.flying then
                    beginCruise()
                    maintainCruise(veh)
                else
                    applyPlanePose(veh)
                    ensurePilot(veh)
                end
                attachLocal()
                updateChaseCam()
                hideForeignTitans()
                hideRemotePeds()
                if GetGameTimer() > lastSeatCheck + 1500 then
                    lastSeatCheck = GetGameTimer()
                    if not IsPedInAnyVehicle(PlayerPedId(), false) then
                        playSeat(PlayerPedId())
                    end
                    refreshPassengers()
                end
            end
            local px, py, pz, ph = routePos()
            if plane and DoesEntityExist(plane) then
                local c = GetEntityCoords(plane)
                px, py, pz = c.x, c.y, c.z
                ph = GetEntityHeading(plane)
            end
            if planeBlip then
                SetBlipCoords(planeBlip, px, py, pz)
                SetBlipRotation(planeBlip, math.floor(ph))
            end
            DisableControlAction(0, 22, true)
            DisableControlAction(0, 23, true)
            DisableControlAction(0, 75, true)
            DisableControlAction(0, 71, true)
            DisableControlAction(0, 72, true)
            DisableControlAction(0, 63, true)
            DisableControlAction(0, 64, true)
            DisableControlAction(0, 59, true)
            DisableControlAction(0, 60, true)
            DisableControlAction(0, 61, true)
            DisableControlAction(0, 62, true)
            DisableControlAction(0, 87, true)
            DisableControlAction(0, 88, true)
            DisableControlAction(0, 107, true)
            DisableControlAction(0, 108, true)
            DisableControlAction(0, 109, true)
            DisableControlAction(0, 110, true)
            DisableControlAction(0, 111, true)
            DisableControlAction(0, 112, true)
            EnableControlAction(0, 1, true)
            EnableControlAction(0, 2, true)
            EnableControlAction(0, 0, true)
            blockCombat()
            if route.flying and IsDisabledControlJustPressed(0, 22) then
                local elapsed = GetGameTimer() - flyStart
                if elapsed >= (tonumber(route.jumpDelayMs) or 0) then
                    TriggerServerEvent('wtbg:drop:requestJump', {
                        gen = gen,
                        progress = progress()
                    })
                end
            end
            pushHud(false)
            Wait(0)
        elseif phase == 'FREEFALL' or phase == 'PARACHUTE' then
            blockCombat()
            giveChute()
            local ped = PlayerPedId()
            local chute = GetPedParachuteState(ped)
            if phase == 'FREEFALL' and chute >= 1 and chute <= 2 and not chuteSent then
                chuteSent = true
                TriggerServerEvent('wtbg:drop:parachute')
                phase = 'PARACHUTE'
                pushHud(true)
            end
            if phase == 'FREEFALL' and agl() <= (tonumber(DropConfig.ForceParachuteHeight) or 92.0) then
                ForcePedToOpenParachute(ped)
            end

            local height = agl()
            local falling = IsPedInParachuteFreeFall(ped) or IsPedFalling(ped)
            local opening = chute == 1 or chute == 2
            local speed = GetEntitySpeed(ped)
            local grounded = (height <= (tonumber(DropConfig.GroundDetectionDistance) or 2.75)
                and not falling and not opening and speed < 12.0)
                or IsEntityInWater(ped)
            if grounded then
                landStable = landStable + 1
            else
                landStable = 0
            end
            if not landSent and landStable >= 8 then
                landSent = true
                TriggerServerEvent('wtbg:drop:landed')
            end
            pushHud(false)
            Wait(0)
        else
            Wait(400)
        end
    end
end)

exports('IsLanded', function()
    return phase == nil or phase == 'LANDED'
end)

exports('GetPhase', function()
    return phase
end)
