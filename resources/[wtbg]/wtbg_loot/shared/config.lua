LootConfig = {}

LootConfig.LootEnabled = true
LootConfig.PickupRange = 2.35
LootConfig.DropRange = 1.2

local medical = WTBG.Balance.Medical
local ammo = WTBG.Balance.Ammo
local loot = WTBG.Balance.Loot
local combat = WTBG.Balance.Combat

LootConfig.HealMoveCancel = medical.HealMoveCancel
LootConfig.MaxAmmo = ammo.Max
LootConfig.MaxHealing = {
    bandage = 5,
    medkit = 2
}
LootConfig.MaxThrowables = {
    grenade = 3,
    molotov = 3,
    smoke = 3
}
LootConfig.BandageHeal = medical.BandageHeal
LootConfig.BandageUseTime = medical.BandageUseTime
LootConfig.BandageMaxHealth = WTBG.NativeHealth(medical.BandageMaxHealth)
LootConfig.MedkitHeal = medical.MedkitHeal
LootConfig.MedkitUseTime = medical.MedkitUseTime
LootConfig.ArmorPlateAmount = combat.ArmorPlate
LootConfig.MaxArmor = combat.MaxArmor
LootConfig.StartPistol = loot.StartPistol
LootConfig.StartPistolAmmo = loot.StartPistolAmmo

LootConfig.TierWeights = loot.TierWeights

LootConfig.MinSpacing = 12.0

LootConfig.ZoneCounts = {
    high = 48,
    medium = 30,
    low = 16
}

LootConfig.TierGuarantees = {
    high = {
        'rifle_assault',
        'rifle_assault',
        'rifle_assault',
        'rifle_assault',
        'rifle_assault',
        'rifle_assault',
        'rifle_assault',
        'rifle_assault',
        'rifle_assault',
        'rifle_assault',
        'rifle_carbine',
        'rifle_carbine',
        'rifle_carbine',
        'rifle_carbine',
        'rifle_carbine',
        'rifle_carbine',
        'rifle_carbine',
        'rifle_carbine',
        'rifle_carbine',
        'rifle_carbine',
        'grenade',
        'grenade',
        'grenade',
        'grenade',
        'molotov',
        'molotov',
        'molotov',
        'molotov'
    },
    medium = {
        'rifle_assault',
        'rifle_assault',
        'rifle_carbine',
        'rifle_carbine',
        'smg_standard',
        'smg_standard',
        'smg_micro',
        'smg_micro',
        'shotgun_pump',
        'shotgun_pump',
        'pistol_combat',
        'pistol_combat',
        'grenade',
        'grenade',
        'molotov',
        'molotov'
    },
    low = {
        'smg_standard',
        'smg_standard',
        'smg_micro',
        'smg_micro',
        'pistol_standard',
        'pistol_standard',
        'smoke',
        'smoke'
    }
}

-- The fourth value supplied with these locations was a heading, not a radius.
-- Loot is scattered across each configured area and regenerated every match.
LootConfig.Zones = {
    { name = 'Galileo Observatory', x = -416.1642, y = 1159.0227, z = 325.8588, radius = 30.0, tier = 'high' },
    { name = 'LSIA', x = -1013.0196, y = -2592.7754, z = 39.0279, radius = 150.0, tier = 'high' },
    { name = 'Davis', x = -151.2568, y = -1912.6422, z = 72.5392, radius = 110.0, tier = 'medium' },
    { name = 'Vinewood Hills East', x = -108.3010, y = 901.4701, z = 236.2196, radius = 95.0, tier = 'medium' },
    { name = 'La Puerta', x = -1074.5723, y = -1706.2258, z = 70.7310, radius = 105.0, tier = 'medium' },
    { name = 'Grand Senora East', x = 1053.5579, y = 2319.6716, z = 45.5072, radius = 115.0, tier = 'medium' },
    { name = 'Pacific Bluffs', x = -1865.2634, y = -347.4938, z = 70.7165, radius = 100.0, tier = 'medium' },
    { name = 'Kortz Center', x = -2251.8330, y = 274.7086, z = 187.9664, radius = 105.0, tier = 'high' },
    { name = 'La Fuente Blanca', x = 1449.7562, y = 1107.9541, z = 114.3141, radius = 140.0, tier = 'high' },
    { name = 'Pacific Coast', x = -2892.5625, y = 24.7460, z = 19.9958, radius = 110.0, tier = 'medium' },
    { name = 'Vinewood Bowl', x = 668.5258, y = 613.6404, z = 128.8770, radius = 105.0, tier = 'medium' },
    { name = 'Marlowe Vineyard', x = -1902.2994, y = 2035.7970, z = 140.7473, radius = 165.0, tier = 'high' },
    { name = 'Stab City', x = 66.7066, y = 3709.6785, z = 39.7530, radius = 105.0, tier = 'medium' },
    { name = 'Rockford Hills', x = -1084.0247, y = -498.8400, z = 50.6336, radius = 100.0, tier = 'medium' },
    { name = 'Harmony', x = 595.4205, y = 2785.7988, z = 42.1918, radius = 130.0, tier = 'high' },
    { name = 'Bolingbroke Penitentiary', x = 1694.9219, y = 2590.8022, z = 51.4126, radius = 155.0, tier = 'high' },
    { name = 'Senora Industrial', x = 2395.2368, y = 3089.8286, z = 48.1529, radius = 115.0, tier = 'medium' },
    { name = 'Davis Quartz', x = 2842.8811, y = 2833.9072, z = 51.7149, radius = 90.0, tier = 'low' },
    { name = 'Palmer-Taylor', x = 2699.1538, y = 1532.1342, z = 24.6884, radius = 120.0, tier = 'medium' },
    { name = 'Tataviam Mountains', x = 2517.1863, y = -383.8938, z = 93.1360, radius = 115.0, tier = 'medium' },
    { name = 'Mission Row', x = 438.8802, y = -984.4261, z = 51.1955, radius = 105.0, tier = 'high' },
    { name = 'Humane Labs', x = 3519.9880, y = 3724.1621, z = 36.6390, radius = 165.0, tier = 'high' },
    { name = 'Grapeseed', x = 2301.9927, y = 4883.0796, z = 41.8082, radius = 145.0, tier = 'high' },
    { name = 'GalileoHigh1', x = -432.21649169922, y = 1145.9630126953, z = 325.90222167969, radius = 30.0, tier = 'high' },
    { name = 'GalileoHigh2', x = -420.14608764648, y = 1099.1281738281, z = 332.53521728516, radius = 30.0, tier = 'high' },
    { name = 'CARGO1', x = 977.208984375, y = -3061.3850097656, z = 5.900755405426, radius = 30.0, tier = 'high' },
    { name = 'CARGO2', x = 881.99468994141, y = -3059.4091796875, z = 5.9007544517517, radius = 30.0, tier = 'high' },
    { name = 'BANDARAr', x = -929.66119384766, y = -2643.0603027344, z = 39.096199035645, radius = 30.0, tier = 'high' },
    { name = 'BANDARAr', x = -973.67645263672, y = -2703.8217773438, z = 13.866111755371, radius = 30.0, tier = 'high' },
    { name = 'BANDARAkir', x = -1016.6567382812, y = -2603.3059082031, z = 39.100719451904, radius = 30.0, tier = 'high' },
    { name = 'BANDARAkir', x = -1042.4293212891, y = -2660.6950683594, z = 13.83074760437, radius = 30.0, tier = 'high' },
    { name = 'CARNAVAL', x = -1838.9396972656, y = -1226.2075195312, z = 13.017269134521, radius = 30.0, tier = 'high' },
    { name = 'CARNAVAL', x = -1589.0173339844, y = -1024.7662353516, z = 13.017997741699, radius = 30.0, tier = 'high' },
    { name = 'KAMPUS', x = -2249.9641113281, y = 265.21377563477, z = 174.61549377441, radius = 30.0, tier = 'high' },
    { name = 'KAMPUS', x = -2210.1875, y = 264.50872802734, z = 198.10260009766, radius = 30.0, tier = 'high' },
    { name = 'KAMPUS', x = -2287.5363769531, y = 290.75860595703, z = 194.60479736328, radius = 30.0, tier = 'high' },
    { name = 'KAMPUS', x = -2333.7687988281, y = 280.37124633789, z = 169.46440124512, radius = 30.0, tier = 'high' },
    { name = 'KAMPUS', x = -2299.7309570312, y = 379.62551879883, z = 174.46647644043, radius = 30.0, tier = 'high' },
    { name = 'LB', x = 1453.6611328125, y = 1115.6451416016, z = 114.33385467529, radius = 50.0, tier = 'high' },
    { name = 'KANPOLATAS', x = 445.76019287109, y = -990.87322998047, z = 43.691032409668, radius = 30.0, tier = 'high' },
    { name = 'KANPOBWH', x = 427.89462280273, y = -981.74829101562, z = 30.710163116455, radius = 30.0, tier = 'high' },
    { name = 'KANPOBWH', x = 427.25036621094, y = -1021.2086181641, z = 28.927038192749, radius = 30.0, tier = 'high' },
    { name = 'FEDERAL', x = 1710.8295898438, y = 2537.0229492188, z = 45.563297271729, radius = 30.0, tier = 'high' },
    { name = 'FEDERAL', x = 1674.2440185547, y = 2656.9768066406, z = 45.564220428467, radius = 30.0, tier = 'high' },
    { name = 'FEDERAL', x = 1788.1691894531, y = 2686.6901855469, z = 55.190273284912, radius = 30.0, tier = 'high' },
    { name = 'FEDERAL', x = 1722.5368652344, y = 2710.5490722656, z = 55.181705474854, radius = 30.0, tier = 'high' },
    { name = 'FEDERAL', x = 1759.2498779297, y = 2494.6928710938, z = 55.148914337158, radius = 30.0, tier = 'high' },
    { name = 'FEDERAL', x = 1695.2542724609, y = 2454.9509277344, z = 55.185718536377, radius = 30.0, tier = 'high' },
    { name = 'FEDERAL', x = 1610.3245849609, y = 2482.8120117188, z = 56.319965362549, radius = 30.0, tier = 'high' },
    { name = 'FEDERAL', x = 1640.5947265625, y = 2675.576171875, z = 55.193214416504, radius = 30.0, tier = 'high' },
    { name = 'TOKOBAJUSS', x = 603.39404296875, y = 2738.5439453125, z = 41.970813751221, radius = 30.0, tier = 'high' },
    { name = 'TOKOBAJUSS', x = 601.55694580078, y = 2799.2478027344, z = 41.911571502686, radius = 30.0, tier = 'high' },
    { name = 'TOKOBAJUSS', x = 610.63684082031, y = 2768.3024902344, z = 48.539283752441, radius = 30.0, tier = 'high' },
    { name = 'RUMGUR', x = -1907.3012695312, y = 2042.9031982422, z = 140.73376464844, radius = 30.0, tier = 'high' },
    { name = 'RUMGUR', x = -1888.3637695312, y = 2087.681640625, z = 141.00831604004, radius = 30.0, tier = 'high' },
    { name = 'HUMLAB', x = 3564.416015625, y = 3773.9018554688, z = 29.919822692871, radius = 30.0, tier = 'high' },
    { name = 'HUMLAB', x = 3552.4304199219, y = 3718.8696289062, z = 37.352298736572, radius = 30.0, tier = 'high' },
    { name = 'HUMLAB', x = 3468.0322265625, y = 3685.5258789062, z = 33.401458740234, radius = 30.0, tier = 'high' },
    { name = 'GRBSD', x = 2309.4108886719, y = 4859.4936523438, z = 41.806266784668, radius = 30.0, tier = 'high' },
    { name = 'GRBSD', x = 2334.3745117188, y = 4891.1235351562, z = 41.814182281494, radius = 30.0, tier = 'high' },
    { name = 'GRBSD', x = 2296.9660644531, y = 4898.0454101562, z = 41.203983306885, radius = 30.0, tier = 'high' },
    { name = 'PALETO', x = 74.801780700684, y = 6532.8208007812, z = 31.677865982056, radius = 50.0, tier = 'high' },
    { name = 'CANIBAL', x = -1111.2821044922, y = 4886.2236328125, z = 215.39389038086, radius = 30.0, tier = 'high' },
    { name = 'CANIBAL', x = -1071.5340576172, y = 4927.2514648438, z = 212.81803894043, radius = 30.0, tier = 'high' },
    { name = 'LOWW', x = 912.15954589844, y = -2248.5031738281, z = 30.555643081665, radius = 30.0, tier = 'medium' },
    { name = 'LOWW', x = 954.03594970703, y = -1780.7406005859, z = 31.281101226807, radius = 30.0, tier = 'medium' },
    { name = 'LOWW', x = -199.56317138672, y = -2011.7279052734, z = 27.620378494263, radius = 30.0, tier = 'medium' },
    { name = 'LOWW', x = -1093.89453125, y = -1639.4685058594, z = 4.3983955383301, radius = 30.0, tier = 'medium' },
    { name = 'LOWW', x = -1190.798828125, y = -505.32272338867, z = 35.558849334717, radius = 30.0, tier = 'medium' },
    { name = 'LOWW', x = -376.38226318359, y = -125.4759979248, z = 38.576438903809, radius = 30.0, tier = 'medium' },
    { name = 'LOWW', x = -361.09521484375, y = -92.949195861816, z = 45.659797668457, radius = 30.0, tier = 'medium' },
    { name = 'LOWW', x = 321.14059448242, y = -211.20547485352, z = 54.099464416504, radius = 30.0, tier = 'medium' },
    { name = 'LOWW', x = 1358.9622802734, y = -575.08221435547, z = 74.381103515625, radius = 30.0, tier = 'medium' },
    { name = 'LOWW', x = 647.96075439453, y = 611.68444824219, z = 128.90174865723, radius = 30.0, tier = 'medium' },
    { name = 'LOWW', x = 696.73980712891, y = 533.69952392578, z = 129.80276489258, radius = 30.0, tier = 'medium' },
    { name = 'LOWW', x = 1066.884765625, y = 2360.1157226562, z = 43.883785247803, radius = 30.0, tier = 'medium' },
    { name = 'LOWW', x = 1114.7165527344, y = 2665.2749023438, z = 38.01819229126, radius = 30.0, tier = 'medium' },
    { name = 'LOWW', x = 1993.3665771484, y = 3069.4187011719, z = 47.039360046387, radius = 30.0, tier = 'medium' },
    { name = 'LOWW', x = 2405.8684082031, y = 3093.7648925781, z = 48.198448181152, radius = 30.0, tier = 'medium' },
    { name = 'LOWW', x = -84.288261413574, y = 886.61376953125, z = 235.95501708984, radius = 30.0, tier = 'medium' },
    { name = 'LOWW', x = -102.52223205566, y = 964.88012695312, z = 233.12284851074, radius = 30.0, tier = 'medium' },
    { name = 'LOWW', x = -102.52223205566, y = 964.88012695312, z = 233.12284851074, radius = 30.0, tier = 'medium' },
    { name = 'LOWW', x = -154.66857910156, y = 927.61480712891, z = 235.66706848145, radius = 30.0, tier = 'medium' },
    { name = 'LOWW', x = 2707.3369140625, y = 1364.4689941406, z = 24.518133163452, radius = 30.0, tier = 'medium' },
    { name = 'LOWW', x = 1699.1496582031, y = 4800.2836914062, z = 41.813770294189, radius = 30.0, tier = 'medium' },
    { name = 'LOWW', x = -578.34558105469, y = 5324.0063476562, z = 70.222389221191, radius = 30.0, tier = 'medium' },
    { name = 'LOWW', x = -685.80749511719, y = 5821.2958984375, z = 17.347131729126, radius = 30.0, tier = 'medium' },
    { name = 'LOWW', x = -473.3883972168, y = 5985.94921875, z = 31.327304840088, radius = 30.0, tier = 'medium' },
    { name = 'LOWW', x = -189.43473815918, y = 6287.3056640625, z = 31.501735687256, radius = 30.0, tier = 'medium' },
    { name = 'LOWW', x = 65.492050170898, y = 3710.3879394531, z = 39.742622375488, radius = 30.0, tier = 'medium' },
    { name = 'LOWW', x = -3031.0886230469, y = 104.29775238037, z = 11.607434272766, radius = 30.0, tier = 'medium' },
    { name = 'LOWW', x = -3025.0688476562, y = 47.313488006592, z = 10.111448287964, radius = 30.0, tier = 'medium' }
}
