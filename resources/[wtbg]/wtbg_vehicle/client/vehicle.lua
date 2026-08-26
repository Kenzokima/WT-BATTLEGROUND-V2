local inMatch = false
local usable = false
local grounded = {}
local reported = {}

local function deploying()
    if GetResourceState('wtbg_drop') ~= 'started' then
        return false
    end
    local ok, landed = pcall(function()
        return exports.wtbg_drop:IsLanded()
    end)
    return ok and landed == false
end

local function downed()
    if GetResourceState('wtbg_combat') ~= 'started' then
        return false
    end
    local ok, value = pcall(function()
        return exports.wtbg_combat:IsDowned()
    end)
    return ok and value == true
end

local function canUseVehicle()
    if not inMatch or not usable or deploying() or downed() then
        return false
    end
    if GetResourceState('wtbg_spectator') == 'started' then
        local ok, spec = pcall(function()
            return exports.wtbg_spectator:IsSpectating()
        end)
        if ok and spec then
            return false
        end
    end
    return true
end

local function leaveVehicle(ped)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        return
    end
    local side = GetOffsetFromEntityInWorldCoords(veh, 1.6, 0.0, 0.12)
    TaskLeaveVehicle(ped, veh, 16)
    SetEntityCoordsNoOffset(ped, side.x, side.y, side.z, false, false, false)
end

local function reportDestroyed(veh)
    if not DoesEntityExist(veh) or not NetworkGetEntityIsNetworked(veh) then
        return
    end
    local st = Entity(veh).state
    local matchId = tonumber(st.wtbgMatchId)
    local vehicleId = tonumber(st.wtbgVehicleId)
    if not st.wtbgVehicle or not matchId or not vehicleId then
        return
    end
    local key = matchId .. ':' .. vehicleId
    if reported[key] then
        return
    end
    reported[key] = true
    TriggerServerEvent('wtbg:vehicle:destroyed', matchId, vehicleId, 0)
end

RegisterNetEvent('wtbg:match:enter', function()
    inMatch = true
    usable = true
end)

RegisterNetEvent('wtbg:match:begin', function()
    inMatch = true
    usable = true
end)

RegisterNetEvent('wtbg:match:playerDied', function()
    usable = false
    leaveVehicle(PlayerPedId())
    TriggerEvent('wtbg:ui:closeInventory')
end)

RegisterNetEvent('wtbg:match:finished', function()
    inMatch = false
    usable = false
    leaveVehicle(PlayerPedId())
    TriggerEvent('wtbg:ui:closeInventory')
end)

RegisterNetEvent('wtbg:core:spawnLobby', function()
    inMatch = false
    usable = false
    grounded = {}
    reported = {}
end)

AddStateBagChangeHandler('wtbgVehicle', nil, function(bagName, _, value)
    if not value then
        return
    end
    local ent = GetEntityFromStateBagName(bagName)
    if not ent or ent == 0 or grounded[ent] then
        return
    end
    grounded[ent] = true
    SetVehicleOnGroundProperly(ent)
    SetVehicleNeedsToBeHotwired(ent, false)
    SetVehicleDoorsLocked(ent, 1)
end)

CreateThread(function()
    local wasIn = false
    while true do
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        local inside = veh ~= 0

        if inside and not wasIn then
            TriggerEvent('wtbg:ui:closeInventory')
        end
        wasIn = inside

        if not inMatch then
            Wait(400)
        else
            SetPedCanBeDraggedOut(ped, false)

            if inside then
                if not canUseVehicle() then
                    leaveVehicle(ped)
                else
                    SetVehicleNeedsToBeHotwired(veh, false)
                    SetVehicleDoorsLocked(veh, 1)
                    if GetVehicleEngineHealth(veh) <= 0.0 or IsEntityDead(veh) then
                        reportDestroyed(veh)
                        leaveVehicle(ped)
                    end
                end
            else
                if not canUseVehicle() then
                    DisableControlAction(0, 23, true)
                    DisableControlAction(0, 75, true)
                end
                local trying = GetVehiclePedIsTryingToEnter(ped)
                if trying ~= 0 then
                    if not canUseVehicle() then
                        ClearPedTasksImmediately(ped)
                    else
                        local driver = GetPedInVehicleSeat(trying, -1)
                        if driver ~= 0 and driver ~= ped and IsPedAPlayer(driver) then
                            ClearPedTasksImmediately(ped)
                        end
                    end
                end
            end
            Wait(0)
        end
    end
end)

CreateThread(function()
    while true do
        if not inMatch then
            Wait(800)
        else
            local pool = GetGamePool('CVehicle')
            local my = PlayerPedId()
            for i = 1, #pool do
                local veh = pool[i]
                if DoesEntityExist(veh) and NetworkGetEntityIsNetworked(veh) and Entity(veh).state.wtbgVehicle then
                    if GetVehicleEngineHealth(veh) <= 0.0 or IsEntityDead(veh) then
                        reportDestroyed(veh)
                    end
                    for seat = -1, 8 do
                        local occupant = GetPedInVehicleSeat(veh, seat)
                        if occupant ~= 0 and occupant ~= my and not IsPedAPlayer(occupant) then
                            TaskLeaveVehicle(occupant, veh, 16)
                        end
                    end
                end
            end
            Wait(700)
        end
    end
end)
