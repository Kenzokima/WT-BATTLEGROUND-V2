LootItems = {
    rifle_carbine = {
        type = 'weapon',
        slot = 'primary',
        weapon = 'WEAPON_CARBINERIFLE',
        ammoType = 'rifle',
        spawnWeight = { low = 0, medium = 8, high = 20 },
        label = 'Carbine Rifle',
        model = 'w_ar_carbinerifle'
    },
    rifle_assault = {
        type = 'weapon',
        slot = 'primary',
        weapon = 'WEAPON_ASSAULTRIFLE',
        ammoType = 'rifle',
        spawnWeight = { low = 0, medium = 6, high = 20 },
        label = 'Assault Rifle',
        model = 'w_ar_assaultrifle'
    },
    smg_standard = {
        type = 'weapon',
        slot = 'secondary',
        weapon = 'WEAPON_SMG',
        ammoType = 'smg',
        spawnWeight = { low = 5, medium = 7, high = 8 },
        label = 'SMG',
        model = 'w_sb_smg'
    },
    smg_micro = {
        type = 'weapon',
        slot = 'secondary',
        weapon = 'WEAPON_MICROSMG',
        ammoType = 'smg',
        spawnWeight = { low = 8, medium = 7, high = 5 },
        label = 'Micro SMG',
        model = 'w_sb_microsmg'
    },
    shotgun_pump = {
        type = 'weapon',
        slot = 'secondary',
        weapon = 'WEAPON_PUMPSHOTGUN',
        ammoType = 'shotgun',
        spawnWeight = { low = 2, medium = 5, high = 8 },
        label = 'Pump Shotgun',
        model = 'w_sg_pumpshotgun'
    },
    pistol_standard = {
        type = 'weapon',
        slot = 'sidearm',
        weapon = 'WEAPON_PISTOL',
        ammoType = 'pistol',
        spawnWeight = { low = 18, medium = 10, high = 3 },
        label = 'Pistol',
        model = 'w_pi_pistol'
    },
    pistol_combat = {
        type = 'weapon',
        slot = 'sidearm',
        weapon = 'WEAPON_COMBATPISTOL',
        ammoType = 'pistol',
        spawnWeight = { low = 10, medium = 8, high = 4 },
        label = 'Combat Pistol',
        model = 'w_pi_combatpistol'
    },
    ammo_rifle = {
        type = 'ammo',
        ammoType = 'rifle',
        amount = WTBG.Balance.Ammo.Pickup.rifle,
        spawnWeight = { low = 2, medium = 8, high = 16 },
        label = 'Rifle Ammo',
        model = 'prop_ld_ammo_pack_01'
    },
    ammo_smg = {
        type = 'ammo',
        ammoType = 'smg',
        amount = WTBG.Balance.Ammo.Pickup.smg,
        spawnWeight = { low = 5, medium = 8, high = 9 },
        label = 'SMG Ammo',
        model = 'prop_ld_ammo_pack_01'
    },
    ammo_shotgun = {
        type = 'ammo',
        ammoType = 'shotgun',
        amount = WTBG.Balance.Ammo.Pickup.shotgun,
        spawnWeight = { low = 3, medium = 5, high = 6 },
        label = 'Shotgun Ammo',
        model = 'prop_ld_ammo_pack_01'
    },
    ammo_pistol = {
        type = 'ammo',
        ammoType = 'pistol',
        amount = WTBG.Balance.Ammo.Pickup.pistol,
        spawnWeight = { low = 12, medium = 8, high = 4 },
        label = 'Pistol Ammo',
        model = 'prop_ld_ammo_pack_01'
    },
    bandage = {
        type = 'heal',
        healId = 'bandage',
        amount = 1,
        spawnWeight = { low = 16, medium = 12, high = 8 },
        label = 'Bandage',
        model = 'prop_ld_health_pack'
    },
    medkit = {
        type = 'heal',
        healId = 'medkit',
        amount = 1,
        spawnWeight = { low = 2, medium = 6, high = 10 },
        label = 'Medkit',
        model = 'prop_ld_health_pack'
    },
    armor_plate = {
        type = 'armor',
        amount = WTBG.Balance.Combat.ArmorPlate,
        label = 'Armor Plate',
        model = 'prop_bodyarmour_02'
    },
    grenade = {
        type = 'throwable',
        throwId = 'grenade',
        weapon = 'WEAPON_GRENADE',
        amount = 1,
        spawnWeight = { low = 0, medium = 5, high = 12 },
        label = 'Grenade',
        model = 'w_ex_grenadefrag'
    },
    smoke = {
        type = 'throwable',
        throwId = 'smoke',
        weapon = 'WEAPON_SMOKEGRENADE',
        amount = 1,
        spawnWeight = { low = 10, medium = 8, high = 5 },
        label = 'Smoke Grenade',
        model = 'w_ex_grenadesmoke'
    },
    molotov = {
        type = 'throwable',
        throwId = 'molotov',
        weapon = 'WEAPON_MOLOTOV',
        amount = 1,
        spawnWeight = { low = 0, medium = 4, high = 10 },
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
