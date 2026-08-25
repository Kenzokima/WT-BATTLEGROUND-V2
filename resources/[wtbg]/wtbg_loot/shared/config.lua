LootConfig = {}

LootConfig.LootEnabled = true
LootConfig.PickupRange = 2.35
LootConfig.DropRange = 1.2
LootConfig.HealMoveCancel = 2.4

LootConfig.MaxAmmo = {
    rifle = 180,
    smg = 150,
    shotgun = 48,
    pistol = 90
}

LootConfig.MaxHealing = {
    bandage = 5,
    medkit = 2
}

LootConfig.MaxThrowables = {
    grenade = 3,
    molotov = 3,
    smoke = 3
}

LootConfig.BandageHeal = 25
LootConfig.BandageUseTime = 3
LootConfig.BandageMaxHealth = 175

LootConfig.MedkitHeal = 0
LootConfig.MedkitUseTime = 6

LootConfig.ArmorPlateAmount = 25
LootConfig.MaxArmor = 100

LootConfig.StartPistol = false
LootConfig.StartPistolAmmo = 24

LootConfig.TierSlots = {
    low = 3,
    medium = 6,
    high = 8
}

LootConfig.TierWeights = {
    low = {
        empty = 8,
        ammo = 26,
        heal = 16,
        armor = 6,
        weapon = 22,
        throwable = 4
    },
    medium = {
        empty = 4,
        ammo = 20,
        heal = 14,
        armor = 10,
        weapon = 28,
        throwable = 8
    },
    high = {
        empty = 0,
        ammo = 16,
        heal = 12,
        armor = 14,
        weapon = 34,
        throwable = 12
    }
}

LootConfig.TierRarity = {
    low = {
        COMMON = 78,
        UNCOMMON = 18,
        RARE = 4,
        EPIC = 0
    },
    medium = {
        COMMON = 62,
        UNCOMMON = 26,
        RARE = 9,
        EPIC = 3
    },
    high = {
        COMMON = 38,
        UNCOMMON = 36,
        RARE = 20,
        EPIC = 6
    }
}

LootConfig.SpawnPoints = {}
do
    local pois = {
        { -1037.5, -2737.8, 13.8, 'high' },
        { -1336.0, -2668.0, 13.9, 'high' },
        { -879.0, -2494.0, 13.9, 'medium' },
        { 123.0, -2470.0, 6.0, 'medium' },
        { 814.0, -2982.0, 5.9, 'medium' },
        { -250.0, -2030.0, 30.0, 'medium' },
        { 105.0, -1937.0, 20.8, 'medium' },
        { 215.0, -1646.0, 29.8, 'medium' },
        { 253.0, -1400.0, 30.5, 'medium' },
        { 195.7, -933.0, 30.7, 'medium' },
        { 428.0, -981.0, 30.7, 'high' },
        { 307.0, -595.0, 43.3, 'high' },
        { 390.0, -770.0, 29.3, 'medium' },
        { -526.0, -874.0, 25.0, 'medium' },
        { 44.0, -411.0, 39.9, 'medium' },
        { -1845.0, -1225.0, 13.0, 'medium' },
        { -1218.0, -1513.0, 4.4, 'medium' },
        { -1108.0, -845.0, 19.3, 'medium' },
        { -880.0, -50.0, 38.0, 'medium' },
        { -1284.0, -339.0, 36.8, 'medium' },
        { -1053.0, -466.0, 36.6, 'medium' },
        { 300.0, 180.0, 104.4, 'medium' },
        { 924.0, 47.0, 81.1, 'high' },
        { 1143.0, -390.0, 67.0, 'medium' },
        { 870.0, -180.0, 78.0, 'medium' },
        { -565.0, 276.0, 83.0, 'medium' },
        { 812.0, -1103.0, 25.2, 'medium' },
        { 1137.0, -1488.0, 34.7, 'medium' },
        { 1391.0, -2075.0, 52.0, 'medium' },
        { 910.0, -2277.0, 30.5, 'medium' },
        { -47.0, -785.0, 44.2, 'high' },
        { 10.0, -661.0, 33.4, 'high' },
        { 105.0, -744.0, 45.8, 'high' },
        { -128.0, -584.0, 32.2, 'high' },
        { -775.0, 312.0, 85.7, 'medium' },
        { -1346.0, 59.0, 55.2, 'low' },
        { -1388.0, -586.0, 30.2, 'medium' },
        { 412.0, -2020.0, 23.0, 'medium' },
        { -164.0, -214.0, 49.5, 'medium' },
        { 50.0, -400.0, 39.9, 'medium' },
        { -182.4, 6225.8, 31.5, 'medium' },
        { -112.2, 6468.1, 31.6, 'medium' },
        { -448.1, 6015.8, 31.3, 'high' },
        { 1684.8, 4818.6, 42.0, 'medium' },
        { 1961.3, 3749.4, 32.3, 'medium' },
        { 1850.2, 3679.8, 34.3, 'medium' },
        { 1747.5, 3273.7, 41.2, 'medium' },
        { 1692.4, 3585.6, 35.6, 'medium' },
        { 1391.6, 3600.2, 35.0, 'medium' },
        { 578.9, 2677.2, 41.8, 'medium' },
        { 2678.4, 3279.6, 55.2, 'medium' },
        { 1845.4, 2586.2, 45.7, 'high' },
        { 1724.2, 2542.4, 45.56, 'high' },
        { 1768.6, 2586.8, 45.56, 'high' },
        { 1693.4, 2564.2, 45.56, 'high' },
        { 1746.8, 2622.0, 45.56, 'high' },
        { 1668.2, 2604.6, 45.56, 'high' },
        { 1788.4, 2552.2, 45.56, 'high' },
        { -2361.3, 3243.7, 32.8, 'high' },
        { -3174.6, 1086.2, 20.8, 'medium' },
        { -2194.9, 4288.7, 49.2, 'medium' },
        { 1702.4, 6426.2, 32.8, 'medium' },
        { 90.4, 6360.2, 31.2, 'medium' },
        { 2550.8, 382.4, 108.6, 'medium' },
        { 2535.2, -383.8, 92.9, 'high' },
        { 3533.6, 3668.4, 28.1, 'high' },
        { 2748.1, 3472.4, 55.2, 'medium' },
        { 2465.4, 1573.8, 32.7, 'low' },
        { 2333.2, 2570.4, 46.7, 'low' },
        { 736.4, 2583.1, 79.6, 'low' },
        { 1990.2, 3052.4, 47.2, 'medium' },
        { 2121.5, 4796.2, 41.1, 'medium' },
        { 452.8, 5571.6, 781.2, 'low' },
        { 1578.4, 6449.2, 24.9, 'medium' },
        { -773.6, 5594.2, 33.6, 'medium' },
        { 247.6, 222.4, 106.3, 'medium' },
        { -1095.4, 2704.8, 18.9, 'low' },
        { 1141.2, 2663.8, 38.0, 'medium' },
        { 543.9, 2670.4, 42.2, 'medium' },
        { 1694.2, 4922.8, 42.1, 'medium' },
        { -3242.4, 1001.6, 12.8, 'medium' },
        { -3043.1, 595.2, 7.6, 'low' },
        { 2581.4, 420.6, 108.5, 'medium' },
        { 179.4, 6625.1, 31.7, 'medium' },
        { -70.2, -1761.4, 29.3, 'medium' },
        { 264.8, -1261.2, 29.3, 'medium' },
        { -723.4, -935.2, 19.2, 'medium' },
        { 1159.6, -326.4, 69.2, 'medium' },
        { 373.2, 326.8, 103.6, 'medium' },
        { -1820.6, 790.4, 138.2, 'medium' },
        { 78.4, 3705.2, 41.1, 'low' },
        { 1309.2, 4362.4, 41.6, 'low' },
        { 2353.6, 3133.8, 48.2, 'low' },
        { -1822.4, 2975.2, 32.8, 'high' },
        { 1662.4, 1.2, 166.1, 'low' },
        { -411.2, 1172.6, 325.6, 'high' },
        { 1208.4, 2658.2, 37.8, 'medium' },
        { -2072.6, -317.4, 13.3, 'medium' },
        { 29.6, -2666.8, 6.0, 'low' },
        { 1130.2, -982.6, 46.4, 'medium' },
        { -1487.4, -379.2, 40.2, 'medium' },
        { 2564.8, 2591.6, 38.1, 'low' },
        { 1981.2, 3052.8, 47.2, 'medium' },
        { -2555.4, 2314.2, 33.2, 'low' },
        { 1532.6, 1702.4, 109.7, 'low' },
        { 641.8, 277.4, 103.3, 'medium' },
        { -1391.8, -326.4, 39.0, 'medium' }
    }
    local offs = {
        { 0.0, 0.0 },
        { 2.2, 1.8 },
        { -2.0, 2.2 },
        { 1.6, -2.4 },
        { 4.0, 0.4 },
        { -3.6, -1.4 },
        { 5.2, 2.8 },
        { -4.8, 3.2 }
    }
    local n = 0
    for i = 1, #pois do
        local poi = pois[i]
        local tier = poi[4] or 'medium'
        local slots = (LootConfig.TierSlots and LootConfig.TierSlots[tier]) or #offs
        if slots > #offs then
            slots = #offs
        end
        for j = 1, slots do
            n = n + 1
            LootConfig.SpawnPoints[n] = {
                x = poi[1] + offs[j][1],
                y = poi[2] + offs[j][2],
                z = poi[3],
                tier = tier
            }
        end
    end

    local function onLand(x, y)
        if x < -3300.0 or x > 4200.0 or y < -3400.0 or y > 7400.0 then
            return false
        end
        if y < -3000.0 and x < -1500.0 then
            return false
        end
        if x < -3050.0 and y < 900.0 then
            return false
        end
        if x > 1000.0 and x < 2150.0 and y > 3850.0 and y < 4320.0 then
            return false
        end
        return true
    end

    local step = 520.0
    for x = -3000.0, 4000.0, step do
        for y = -3200.0, 7200.0, step do
            if onLand(x, y) then
                n = n + 1
                LootConfig.SpawnPoints[n] = {
                    x = x,
                    y = y,
                    z = 45.0,
                    tier = 'low'
                }
            end
        end
    end
end
