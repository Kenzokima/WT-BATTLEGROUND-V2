-- Custom vitals HUD (armor / health) menggantikan bar native di bawah minimap.

-- Posisi & ukuran minimap dalam koordinat layar 0..1 (memperhitungkan safezone & aspect ratio).
local function getMinimapAnchor()
    local safezone = GetSafeZoneSize()
    local aspectRatio = GetAspectRatio(0)
    local resX, resY = GetActiveScreenResolution()
    local xScale = 1.0 / resX
    local yScale = 1.0 / resY

    local width = xScale * (resX / (4 * aspectRatio))
    local height = yScale * (resY / 5.674)
    local leftX = xScale * (resX * (0.05 * (math.abs(safezone - 1.0) * 10)))
    local bottomY = 1.0 - yScale * (resY * (0.05 * (math.abs(safezone - 1.0) * 10)))

    return {
        leftX = leftX,
        topY = bottomY - height,
        width = width,
        height = height
    }
end

-- Sembunyikan health/armor bar native yang menempel di minimap.
local function hideNativeHealthBar()
    local minimap = RequestScaleformMovie('minimap')
    if HasScaleformMovieLoaded(minimap) then
        BeginScaleformMovieMethod(minimap, 'SETUP_HEALTH_ARMOUR')
        ScaleformMovieMethodAddParamInt(3)
        EndScaleformMovieMethod()
    end
end

CreateThread(function()
    while true do
        hideNativeHealthBar()
        Wait(5000)
    end
end)

-- Kirim nilai vitals ke NUI.
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

-- Kirim anchor minimap ke NUI (hanya saat berubah).
CreateThread(function()
    local last = nil
    while true do
        local anchor = getMinimapAnchor()
        if not last
            or math.abs(anchor.leftX - last.leftX) > 0.0005
            or math.abs(anchor.topY - last.topY) > 0.0005
            or math.abs(anchor.width - last.width) > 0.0005 then
            last = anchor
            SendNUIMessage({
                action = 'vitalsAnchor',
                leftX = anchor.leftX,
                topY = anchor.topY,
                width = anchor.width,
                height = anchor.height
            })
        end
        Wait(1000)
    end
end)