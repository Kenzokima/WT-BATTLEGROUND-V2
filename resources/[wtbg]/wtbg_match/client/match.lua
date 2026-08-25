local frozen = false
local inMatch = false
local isDead = false

local function stripWeapons(ped)
    RemoveAllPedWeapons(ped, true)
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
end

local function setFrozen(value)
    frozen = value and true or false
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, frozen)
    SetEntityInvincible(ped, frozen)
end

local function teleport(coords)
    local ped = PlayerPedId()
    local heading = coords.w or 0.0
    local x, y, z = coords.x + 0.0, coords.y + 0.0, coords.z + 0.0

    RequestCollisionAtCoord(x, y, z)
    NetworkResurrectLocalPlayer(x, y, z, heading, true, true)
    SetEntityCoordsNoOffset(PlayerPedId(), x, y, z, false, false, false)
    SetEntityHeading(PlayerPedId(), heading)

    local timeout = GetGameTimer() + 4000
    while not HasCollisionLoadedAroundEntity(PlayerPedId()) and GetGameTimer() < timeout do
        RequestCollisionAtCoord(x, y, z)
        Wait(50)
    end

    ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
    SetEntityHeading(ped, heading)
    ClearPedBloodDamage(ped)
    local health = Config.StartingHealth or 200
    SetPedMaxHealth(ped, health)
    SetEntityMaxHealth(ped, health)
    SetEntityHealth(ped, health)
    SetPedArmour(ped, 0)
    stripWeapons(ped)
end

RegisterNetEvent('wtbg:match:enter', function(coords, _countdown)
    if type(coords) ~= 'table' then
        return
    end

    inMatch = true
    isDead = false
    DoScreenFadeOut(150)
    Wait(200)
    teleport(coords)
    setFrozen(true)
    DoScreenFadeIn(250)
end)

RegisterNetEvent('wtbg:match:begin', function()
    inMatch = true
    isDead = false
    setFrozen(false)
end)

RegisterNetEvent('wtbg:match:playerDied', function()
    isDead = true
    setFrozen(false)
end)

RegisterNetEvent('wtbg:match:finished', function()
    isDead = false
    inMatch = false
    setFrozen(true)
end)

RegisterNetEvent('wtbg:core:spawnLobby', function()
    inMatch = false
    isDead = false
    setFrozen(false)
end)

CreateThread(function()
    while true do
        if inMatch and isDead then
            local ped = PlayerPedId()
            if not IsEntityDead(ped) and not IsPedDeadOrDying(ped, true) then
                stripWeapons(ped)
                FreezeEntityPosition(ped, true)
                SetEntityInvincible(ped, true)
                SetEntityAlpha(ped, 80, false)
            end
            Wait(400)
        else
            Wait(800)
        end
    end
end)
