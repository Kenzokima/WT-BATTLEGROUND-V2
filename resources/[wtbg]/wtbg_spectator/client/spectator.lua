local active = false
local targetId = nil
local cam = nil
local missingSince = 0
local lastSwitch = 0

local BLOCK = {
    21, 22, 23, 24, 25, 30, 31, 32, 33, 34, 35, 36, 37, 38, 44, 45,
    47, 58, 75, 140, 141, 142, 143, 257, 263, 264
}

local function resolvePed(serverId)
    local idx = GetPlayerFromServerId(serverId)
    if not idx or idx == -1 then
        return 0
    end
    local ped = GetPlayerPed(idx)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return 0
    end
    return ped
end

local function hideLocal(hide)
    local ped = PlayerPedId()
    if not ped or ped == 0 then
        return
    end
    SetEntityVisible(ped, not hide, false)
    SetEntityCollision(ped, not hide, not hide)
    FreezeEntityPosition(ped, hide)
    SetEntityInvincible(ped, hide)
    SetPlayerInvincible(PlayerId(), hide)
    SetPedCanBeTargetted(ped, not hide)
    WTBG.Call(NetworkSetEntityInvisibleToNetwork, ped, hide)
    if hide then
        ClearPedTasksImmediately(ped)
    end
end

local function destroyCam()
    ClearFocus()
    if cam and DoesCamExist(cam) then
        RenderScriptCams(false, true, 180, true, true)
        DestroyCam(cam, false)
    end
    cam = nil
end

local function ensureCam()
    if cam and DoesCamExist(cam) then
        return cam
    end
    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(cam, 58.0)
    return cam
end

local function follow(ped)
    local c = GetOffsetFromEntityInWorldCoords(ped, 0.0, -4.6, 1.22)
    SetCamCoord(cam, c.x, c.y, c.z)
    PointCamAtEntity(cam, ped, 0.0, 0.0, 0.42, true)
    SetFocusEntity(ped)
end

local function clearSpectator()
    active = false
    targetId = nil
    missingSince = 0
    destroyCam()
    hideLocal(false)
    TriggerEvent('wtbg:ui:spectator', nil)
end

local function applyHud(data)
    TriggerEvent('wtbg:ui:spectator', {
        show = true,
        target = data.target,
        name = data.name,
        downed = data.downed and true or false,
        kills = tonumber(data.kills) or 0
    })
end

local function beginFollow(data, blend)
    if type(data) ~= 'table' or not tonumber(data.target) then
        return
    end
    active = true
    targetId = tonumber(data.target)
    missingSince = 0
    hideLocal(true)
    ensureCam()
    local ped = resolvePed(targetId)
    if ped ~= 0 then
        follow(ped)
    end
    RenderScriptCams(true, true, blend or 220, true, true)
    applyHud(data)
end

RegisterNetEvent('wtbg:spec:start', function(data)
    beginFollow(data, 240)
end)

RegisterNetEvent('wtbg:spec:update', function(data)
    if type(data) ~= 'table' or not tonumber(data.target) then
        return
    end
    local nextId = tonumber(data.target)
    if not active then
        beginFollow(data, 220)
        return
    end
    applyHud(data)
    if targetId == nextId then
        ensureCam()
        local currentPed = resolvePed(targetId)
        if currentPed ~= 0 then
            missingSince = 0
            follow(currentPed)
            RenderScriptCams(true, true, 120, true, true)
        end
        return
    end
    targetId = nextId
    missingSince = 0
    ensureCam()
    local ped = resolvePed(targetId)
    if ped ~= 0 then
        follow(ped)
        RenderScriptCams(true, true, 200, true, true)
    end
end)

RegisterNetEvent('wtbg:spec:stop', function()
    clearSpectator()
end)

RegisterNetEvent('wtbg:match:finished', function()
    clearSpectator()
end)

RegisterNetEvent('wtbg:core:spawnLobby', function()
    clearSpectator()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    clearSpectator()
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    TriggerServerEvent('wtbg:spec:request')
end)

RegisterCommand('wtbgspecnext', function()
    if not active then
        return
    end
    TriggerServerEvent('wtbg:spec:next')
end, false)

RegisterCommand('wtbgspecprev', function()
    if not active then
        return
    end
    TriggerServerEvent('wtbg:spec:prev')
end, false)

RegisterKeyMapping('wtbgspecprev', 'WTBG spectate previous', 'keyboard', 'LEFT')
RegisterKeyMapping('wtbgspecnext', 'WTBG spectate next', 'keyboard', 'RIGHT')

CreateThread(function()
    while true do
        if not active or not targetId then
            Wait(400)
        else
            for i = 1, #BLOCK do
                DisableControlAction(0, BLOCK[i], true)
            end
            DisableControlAction(0, 106, true)

            local ped = resolvePed(targetId)
            if ped ~= 0 then
                missingSince = 0
                if not cam or not DoesCamExist(cam) then
                    ensureCam()
                    RenderScriptCams(true, false, 0, true, true)
                end
                follow(ped)
            else
                local t = GetGameTimer()
                if missingSince == 0 then
                    missingSince = t
                elseif t - missingSince >= 2500 and t - lastSwitch >= 2500 then
                    lastSwitch = t
                    missingSince = t
                    TriggerServerEvent('wtbg:spec:next')
                end
            end
            Wait(0)
        end
    end
end)

exports('IsSpectating', function()
    return active
end)
