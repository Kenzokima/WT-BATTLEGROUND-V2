-- Custom vitals HUD (armor / health) di bawah-tengah layar.

local HEALTH_ARMOUR_HIDDEN = 3

local minimapScaleform = nil

local function ensureMinimapScaleform()
    if minimapScaleform and HasScaleformMovieLoaded(minimapScaleform) then
        return minimapScaleform
    end

    local handle = RequestScaleformMovie('minimap')
    local deadline = GetGameTimer() + 5000
    while not HasScaleformMovieLoaded(handle) and GetGameTimer() < deadline do
        Wait(50)
    end

    if not HasScaleformMovieLoaded(handle) then
        return nil
    end

    minimapScaleform = handle
    return handle
end

-- Bar health/armor native menempel di scaleform minimap. Request handle-nya harus
-- dipakai ulang: request berulang-ulang bikin minimap ikut hilang.
local function hideNativeVitalBars()
    local handle = ensureMinimapScaleform()
    if not handle then
        return
    end

    BeginScaleformMovieMethod(handle, 'SETUP_HEALTH_ARMOUR')
    ScaleformMovieMethodAddParamInt(HEALTH_ARMOUR_HIDDEN)
    EndScaleformMovieMethod()
end

-- Ped baru (spawn / respawn) mereset state minimap, jadi hide-nya diulang di situ saja.
CreateThread(function()
    local lastPed = nil
    while true do
        local ped = PlayerPedId()
        if ped ~= lastPed then
            lastPed = ped
            DisplayRadar(true)
            hideNativeVitalBars()
        end
        Wait(1000)
    end
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local maxHealth = GetEntityMaxHealth(ped)
        local rawHealth = GetEntityHealth(ped)

        -- Konvensi GTA: ped "sekarat" di health 100, jadi range efektif = 100..maxHealth.
        local hpMax = math.max(1, maxHealth - 100)
        local hp = math.max(0, rawHealth - 100)

        SendNUIMessage({
            action = 'vitals',
            health = hp,
            maxHealth = hpMax,
            armor = GetPedArmour(ped),
            maxArmor = 100
        })

        Wait(200)
    end
end)
