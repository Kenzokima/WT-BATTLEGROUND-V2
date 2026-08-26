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
local passengers = {}
local clones = {}
local hidden = {}
local seatDictReady = false
local lastSeatCheck = 0
local cloneSlots = {}
local pilot = nil
local aiFlying = false
local planeCamReady = false

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
    if not cam then
        RenderScriptCams(false, false, 0, true, true)
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
    if not NetworkGetEntityIsNetworked(ent) then
        return
    end
    local nid = NetworkGetNetworkIdFromEntity(ent)
    if not nid or nid == 0 then
        return
    end
    SetNetworkIdCanMigrate(nid, false)
    SetNetworkIdExistsOnAllMachines(nid, false)
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

local function detachLocal()
    local ped = PlayerPedId()
    stopSeatAnim(ped)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then
        TaskLeaveVehicle(ped, veh, 16)
    end
    if IsEntityAttached(ped) then
        DetachEntity(ped, true, true)
    end
    FreezeEntityPosition(ped, false)
    SetEntityCollision(ped, true, true)
    SetEntityVisible(ped, true, false)
    SetEntityInvincible(ped, false)
    SetPlayerInvincible(PlayerId(), false)
    SetPedCanRagdoll(ped, true)
    planeCamReady = false
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

local function routePos()
    local t = progress()
    local x = route.sx + (route.fx - route.sx) * t
    local y = route.sy + (route.fy - route.sy) * t
    local z = route.sz + (route.fz - route.sz) * t
    return x, y, z, routeHeading()
end

local function applyPlanePose(veh)
    if not veh or not route then
        return
    end
    local x, y, z, h = routePos()
    local pitch = tonumber(DropConfig.FlightPitch) or -5.0
    FreezeEntityPosition(veh, true)
    SetEntityCollision(veh, false, false)
    SetEntityCoordsNoOffset(veh, x, y, z, false, false, false)
    SetEntityRotation(veh, pitch, 0.0, h, 2, true)
    SetVehicleEngineOn(veh, true, true, false)
end

local function cruiseSpeed()
    if not route then
        return 55.0
    end
    local dx = (route.fx or 0.0) - (route.sx or 0.0)
    local dy = (route.fy or 0.0) - (route.sy or 0.0)
    local dz = (route.fz or 0.0) - (route.sz or 0.0)
    local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
    local sec = math.max(1.0, (tonumber(route.durationMs) or 25000) / 1000.0)
    return math.max(42.0, dist / sec)
end

local function beginCruise()
    if aiFlying or not plane or not DoesEntityExist(plane) or not route then
        return
    end
    local x, y, z, h = routePos()
    local pitch = tonumber(DropConfig.FlightPitch) or -5.0
    local speed = cruiseSpeed()
    local fx, fy = DropConfig.Forward(h)
    FreezeEntityPosition(plane, false)
    SetEntityCollision(plane, false, false)
    SetEntityHasGravity(plane, false)
    SetVehicleEngineOn(plane, true, true, false)
    pcall(function()
        SetVehicleLandingGear(plane, 3)
        SetPlaneTurbulenceMultiplier(plane, 0.0)
        SetVehicleGravity(plane, false)
    end)
    SetEntityCoordsNoOffset(plane, x, y, z, false, false, false)
    SetEntityRotation(plane, pitch, 0.0, h, 2, true)
    SetEntityVelocity(plane, fx * speed, fy * speed, 0.0)
    aiFlying = true
end

local function flyAlongRoute(veh)
    if not veh or not route then
        return
    end
    local x, y, z, h = routePos()
    local pitch = tonumber(DropConfig.FlightPitch) or -5.0
    local speed = cruiseSpeed()
    local fx, fy = DropConfig.Forward(h)
    local c = GetEntityCoords(veh)
    FreezeEntityPosition(veh, false)
    SetEntityCollision(veh, false, false)
    SetEntityHasGravity(veh, false)
    SetVehicleEngineOn(veh, true, true, false)
    SetEntityRotation(veh, pitch, 0.0, h, 2, true)
    local k = 2.4
    SetEntityVelocity(veh, fx * speed + (x - c.x) * k, fy * speed + (y - c.y) * k, (z - c.z) * k)
end

local function ensurePlane()
    if plane and DoesEntityExist(plane) then
        return plane
    end
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
    SetVehicleEngineOn(plane, true, true, false)
    SetVehRadioStation(plane, 'OFF')
    SetVehicleKeepEngineOnWhenAbandoned(plane, true)
    pcall(function()
        SetVehicleLandingGear(plane, 3)
    end)
    SetEntityLodDist(plane, 800)
    SetModelAsNoLongerNeeded(hash)
    SetEntityCoordsNoOffset(plane, x, y, z, false, false, false)
    SetEntityHeading(plane, h)
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

local function applyPlaneCam()
    if planeCamReady then
        return
    end
    pcall(function()
        SetCamViewModeForContext(1, 2)
        SetCamViewModeForContext(4, 2)
        SetFollowVehicleCamViewMode(2)
    end)
    planeCamReady = true
end

local function attachLocal()
    local veh = ensurePlane()
    local ped = PlayerPedId()
    if not veh or not DoesEntityExist(ped) then
        return
    end
    if GetVehiclePedIsIn(ped, false) == veh then
        SetEntityInvincible(ped, true)
        SetPlayerInvincible(PlayerId(), true)
        SetPedCanRagdoll(ped, false)
        SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
        applyPlaneCam()
        return
    end
    if IsEntityAttached(ped) then
        DetachEntity(ped, true, true)
    end
    FreezeEntityPosition(ped, false)
    local seats = { 0, 1, 2, 3, -1 }
    for i = 1, #seats do
        SetPedIntoVehicle(ped, veh, seats[i])
        if GetVehiclePedIsIn(ped, false) == veh then
            break
        end
    end
    if GetVehiclePedIsIn(ped, false) == veh then
        SetEntityInvincible(ped, true)
        SetPlayerInvincible(PlayerId(), true)
        SetPedCanRagdoll(ped, false)
        SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
        applyPlaneCam()
        return
    end
    local slot = slotFor(GetPlayerServerId(PlayerId())) or 1
    if slot > #offsets() then
        slot = 1
    end
    attachPassenger(ped, slot, 'local')
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetPlayerInvincible(PlayerId(), true)
    SetPedCanRagdoll(ped, false)
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
    pcall(function()
        SetFollowPedCamViewMode(2)
    end)
end

local function ensureCam()
    if cam then
        destroyCam(false)
        return
    end
    RenderScriptCams(false, false, 0, true, true)
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

local function beginFreefall(data)
    phase = 'FREEFALL'
    landSent = false
    chuteSent = false
    landStable = 0
    destroyCam(true)
    clearClones()
    detachLocal()
    deletePlane()
    local ped = PlayerPedId()
    RequestCollisionAtCoord(data.x, data.y, data.z)
    SetEntityCoordsNoOffset(ped, data.x, data.y, data.z, false, false, false)
    SetEntityHeading(ped, data.heading or routeHeading())
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
    attachLocal()
    ensureCam()
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
    ensureCam()
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
                    flyAlongRoute(veh)
                else
                    applyPlanePose(veh)
                end
                attachLocal()
                ensureCam()
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
                    TriggerServerEvent('wtbg:drop:requestJump')
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
