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
    { name = 'Galileo Observatory', x = -416.1642, y = 1159.0227, z = 325.8588, radius = 115.0, tier = 'high' },
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
    { name = 'Grapeseed', x = 2301.9927, y = 4883.0796, z = 41.8082, radius = 145.0, tier = 'high' }
}
