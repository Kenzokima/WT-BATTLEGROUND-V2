local spawned = false

local function disableAutoSpawn()
    pcall(function()
        exports.spawnmanager:setAutoSpawn(false)
    end)

    pcall(function()
        exports.spawnmanager:setAutoSpawnCallback(function()
            local coords = Config.LobbyCoords
            exports.spawnmanager:spawnPlayer({
                x = coords.x,
                y = coords.y,
                z = coords.z,
                heading = coords.w,
                model = Config.PedModel or 'mp_m_freemode_01',
                skipFade = true
            }, function()
                WTBG.EnsureFreemodePed()
            end)
        end)
        exports.spawnmanager:setAutoSpawn(false)
    end)
end

local function stripWeapons(ped)
    RemoveAllPedWeapons(ped, true)
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
end

local function restoreVitality(ped)
    local health = Config.StartingHealth or 200
    SetPedMaxHealth(ped, health)
    SetEntityMaxHealth(ped, health)
    SetEntityHealth(ped, health)
    SetPedArmour(ped, 0)
    ClearPedBloodDamage(ped)
    ClearPlayerWantedLevel(PlayerId())
    SetPlayerWantedLevel(PlayerId(), 0, false)
    SetPlayerWantedLevelNow(PlayerId(), false)
end

local function teleport(coords, heading)
    local ped = PlayerPedId()
    local x, y, z = coords.x, coords.y, coords.z

    RequestCollisionAtCoord(x, y, z)
    SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
    SetEntityHeading(ped, heading or 0.0)
    NetworkResurrectLocalPlayer(x, y, z, heading or 0.0, true, true)

    local timeout = GetGameTimer() + 4000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
        RequestCollisionAtCoord(x, y, z)
        Wait(50)
    end

    ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
    SetEntityHeading(ped, heading or 0.0)
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    restoreVitality(ped)
    stripWeapons(ped)
end

local function spawnLobby(coords)
    DoScreenFadeOut(0)
    disableAutoSpawn()
    WTBG.EnsureFreemodePed()

    local heading = coords.w or coords.heading or 0.0
    teleport(coords, heading)
    WTBG.EnsureFreemodePed()
    WTBG.UnlockCombat()

    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    DoScreenFadeIn(400)
    spawned = true
end

CreateThread(function()
    disableAutoSpawn()

    while not NetworkIsSessionStarted() do
        Wait(100)
    end

    while not DoesEntityExist(PlayerPedId()) do
        Wait(100)
    end

    WTBG.EnsureFreemodePed()
    Wait(250)
    TriggerServerEvent('wtbg:core:sessionReady')
end)

CreateThread(function()
    local expected = WTBG.ExpectedPedModel()
    while true do
        Wait(1000)
        local ped = PlayerPedId()
        if DoesEntityExist(ped) and GetEntityModel(ped) ~= expected then
            WTBG.EnsureFreemodePed()
        end
    end
end)

CreateThread(function()
    SetMaxWantedLevel(0)
    SetCreateRandomCops(false)
    SetCreateRandomCopsNotOnScenarios(false)
    SetCreateRandomCopsOnScenarios(false)
    SetGarbageTrucks(false)
    SetRandomBoats(false)
    SetRandomTrains(false)
    SetDispatchCopsForPlayer(PlayerId(), false)
    DistantCopCarSirens(false)

    for i = 1, 15 do
        EnableDispatchService(i, false)
    end

    while true do
        SetPedDensityMultiplierThisFrame(0.0)
        SetScenarioPedDensityMultiplierThisFrame(0.0, 0.0)
        SetVehicleDensityMultiplierThisFrame(0.15)
        SetRandomVehicleDensityMultiplierThisFrame(0.0)
        SetParkedVehicleDensityMultiplierThisFrame(0.2)
        SetMaxWantedLevel(0)
        Wait(0)
    end
end)

RegisterNetEvent('wtbg:core:spawnLobby', function(coords)
    if type(coords) ~= 'table' then
        return
    end

    spawnLobby(coords)
end)

RegisterNetEvent('wtbg:core:notify', function(message)
    if type(message) ~= 'string' then
        return
    end

    TriggerEvent('chat:addMessage', {
        color = { 196, 48, 38 },
        args = { 'WTBG', message }
    })
end)

AddEventHandler('playerSpawned', function()
    CreateThread(function()
        Wait(0)
        WTBG.EnsureFreemodePed()
    end)
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    disableAutoSpawn()
    if spawned then
        TriggerServerEvent('wtbg:core:sessionReady')
    end
end)
