LootItems = {
    rifle_carbine = {
        type = 'weapon',
        slot = 'primary',
        weapon = 'WEAPON_CARBINERIFLE',
        ammoType = 'rifle',
        rarity = 'COMMON',
        label = 'Carbine Rifle',
        model = 'w_ar_carbinerifle'
    },
    rifle_assault = {
        type = 'weapon',
        slot = 'primary',
        weapon = 'WEAPON_ASSAULTRIFLE',
        ammoType = 'rifle',
        rarity = 'UNCOMMON',
        label = 'Assault Rifle',
        model = 'w_ar_assaultrifle'
    },
    smg_standard = {
        type = 'weapon',
        slot = 'secondary',
        weapon = 'WEAPON_SMG',
        ammoType = 'smg',
        rarity = 'COMMON',
        label = 'SMG',
        model = 'w_sb_smg'
    },
    smg_micro = {
        type = 'weapon',
        slot = 'secondary',
        weapon = 'WEAPON_MICROSMG',
        ammoType = 'smg',
        rarity = 'UNCOMMON',
        label = 'Micro SMG',
        model = 'w_sb_microsmg'
    },
    shotgun_pump = {
        type = 'weapon',
        slot = 'secondary',
        weapon = 'WEAPON_PUMPSHOTGUN',
        ammoType = 'shotgun',
        rarity = 'RARE',
        label = 'Pump Shotgun',
        model = 'w_sg_pumpshotgun'
    },
    pistol_standard = {
        type = 'weapon',
        slot = 'sidearm',
        weapon = 'WEAPON_PISTOL',
        ammoType = 'pistol',
        rarity = 'COMMON',
        label = 'Pistol',
        model = 'w_pi_pistol'
    },
    pistol_combat = {
        type = 'weapon',
        slot = 'sidearm',
        weapon = 'WEAPON_COMBATPISTOL',
        ammoType = 'pistol',
        rarity = 'UNCOMMON',
        label = 'Combat Pistol',
        model = 'w_pi_combatpistol'
    },
    ammo_rifle = {
        type = 'ammo',
        ammoType = 'rifle',
        amount = 30,
        rarity = 'COMMON',
        label = 'Rifle Ammo',
        model = 'prop_ld_ammo_pack_01'
    },
    ammo_smg = {
        type = 'ammo',
        ammoType = 'smg',
        amount = 30,
        rarity = 'COMMON',
        label = 'SMG Ammo',
        model = 'prop_ld_ammo_pack_01'
    },
    ammo_shotgun = {
        type = 'ammo',
        ammoType = 'shotgun',
        amount = 8,
        rarity = 'UNCOMMON',
        label = 'Shotgun Ammo',
        model = 'prop_ld_ammo_pack_01'
    },
    ammo_pistol = {
        type = 'ammo',
        ammoType = 'pistol',
        amount = 24,
        rarity = 'COMMON',
        label = 'Pistol Ammo',
        model = 'prop_ld_ammo_pack_01'
    },
    bandage = {
        type = 'heal',
        healId = 'bandage',
        amount = 1,
        rarity = 'COMMON',
        label = 'Bandage',
        model = 'prop_ld_health_pack'
    },
    medkit = {
        type = 'heal',
        healId = 'medkit',
        amount = 1,
        rarity = 'UNCOMMON',
        label = 'Medkit',
        model = 'prop_ld_health_pack'
    },
    armor_plate = {
        type = 'armor',
        amount = 25,
        rarity = 'UNCOMMON',
        label = 'Armor Plate',
        model = 'prop_bodyarmour_02'
    },
    grenade = {
        type = 'throwable',
        throwId = 'grenade',
        weapon = 'WEAPON_GRENADE',
        amount = 1,
        rarity = 'UNCOMMON',
        label = 'Grenade',
        model = 'w_ex_grenadefrag'
    },
    smoke = {
        type = 'throwable',
        throwId = 'smoke',
        weapon = 'WEAPON_SMOKEGRENADE',
        amount = 1,
        rarity = 'COMMON',
        label = 'Smoke Grenade',
        model = 'w_ex_grenadesmoke'
    },
    molotov = {
        type = 'throwable',
        throwId = 'molotov',
        weapon = 'WEAPON_MOLOTOV',
        amount = 1,
        rarity = 'UNCOMMON',
        label = 'Molotov',
        model = 'w_ex_molotov'
    }
}

LootPools = {
    weapon = { 'rifle_carbine', 'rifle_assault', 'smg_standard', 'smg_micro', 'shotgun_pump', 'pistol_standard', 'pistol_combat' },
    ammo = { 'ammo_rifle', 'ammo_smg', 'ammo_shotgun', 'ammo_pistol' },
    heal = { 'bandage', 'medkit' },
    armor = { 'armor_plate' },
    throwable = { 'grenade', 'molotov', 'smoke' }
}

function LootItemLabel(itemId)
    local def = LootItems[itemId]
    return def and def.label or itemId
end
