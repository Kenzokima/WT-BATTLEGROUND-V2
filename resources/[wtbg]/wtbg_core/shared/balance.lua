WTBG = WTBG or {}

WTBG.Balance = {
    Preset = 'DEFAULT',

    Combat = {
        Health = 100,
        NativeOffset = 100,
        MaxArmor = 100,
        ArmorPlate = 25,
        BleedoutTime = 30,
        ReviveTime = 6,
        FinishTime = 2.5,
        ReviveRange = 4.0,
        FinishRange = 3.5,
        ReviveHealth = 50,
        DownedHealth = 20
    },

    Medical = {
        BandageHeal = 25,
        BandageUseTime = 3,
        BandageMaxHealth = 75,
        MedkitHeal = 0,
        MedkitUseTime = 6,
        HealMoveCancel = 2.4
    },

    Ammo = {
        Pickup = { rifle = 30, smg = 30, shotgun = 8, pistol = 24 },
        Max = { rifle = 210, smg = 180, shotgun = 48, pistol = 96 }
    },

    Loot = {
        StartPistol = false,
        StartPistolAmmo = 24,
        TierWeights = {
            low = { empty = 6, ammo = 28, heal = 18, armor = 6, weapon = 24, throwable = 4 },
            medium = { empty = 3, ammo = 24, heal = 16, armor = 10, weapon = 26, throwable = 7 },
            high = { empty = 0, ammo = 18, heal = 14, armor = 12, weapon = 32, throwable = 10 }
        }
    },

    Match = {
        StartCountdown = 5,
        ResultDuration = 6,
        KillfeedMs = 5000
    },

    Drop = {
        RouteDuration = 80,
        JumpStartDelay = 3.0,
        ParachuteHeight = 120.0,
        ForceParachuteHeight = 92.0,
        AutoDropWarn = 5.0
    },

    Zone = {
        TimeScale = 1.0
    },

    Vehicle = {
        SpawnCount = 40
    },

    WeaponFeel = {
        WEAPON_CARBINERIFLE = { recoil = 0.42 },
        WEAPON_ASSAULTRIFLE = { recoil = 0.70 },
        WEAPON_SMG = { recoil = 0.38 },
        WEAPON_MICROSMG = { recoil = 0.86 },
        WEAPON_PUMPSHOTGUN = { recoil = 1.15 },
        WEAPON_PISTOL = { recoil = 0.48 },
        WEAPON_COMBATPISTOL = { recoil = 0.56 }
    }
}

function WTBG.NativeHealth(gameplayHp)
    local combat = WTBG.Balance.Combat
    local offset = combat.NativeOffset or 100
    local max = combat.Health or 100
    local n = tonumber(gameplayHp) or 0
    if n < 0 then
        n = 0
    elseif n > max then
        n = max
    end
    return math.floor(offset + n + 0.5)
end

function WTBG.GameplayHealth(nativeHp)
    local offset = (WTBG.Balance.Combat and WTBG.Balance.Combat.NativeOffset) or 100
    return math.max(0, (tonumber(nativeHp) or offset) - offset)
end

do
    if WTBG.Balance.Preset == 'FAST_TEST' then
        WTBG.Balance.Zone.TimeScale = 0.4
        WTBG.Balance.Drop.RouteDuration = 28
        WTBG.Balance.Drop.JumpStartDelay = 2.0
        WTBG.Balance.Match.ResultDuration = 4
    end

    local combat = WTBG.Balance.Combat
    local medical = WTBG.Balance.Medical
    local match = WTBG.Balance.Match

    Config.StartingHealth = WTBG.NativeHealth(combat.Health)
    Config.StartingArmor = 0
    Config.MaxArmor = combat.MaxArmor
    Config.BleedoutTime = combat.BleedoutTime
    Config.ReviveTime = combat.ReviveTime
    Config.FinishTime = combat.FinishTime
    Config.ReviveRange = combat.ReviveRange
    Config.FinishRange = combat.FinishRange
    Config.ReviveHealth = WTBG.NativeHealth(combat.ReviveHealth)
    Config.DownedHealth = WTBG.NativeHealth(combat.DownedHealth)
    Config.StartCountdown = match.StartCountdown
    Config.ResultDuration = match.ResultDuration
    Config.KillfeedMs = match.KillfeedMs
    Config.BandageMaxHealth = WTBG.NativeHealth(medical.BandageMaxHealth)
end

local function warnBalance(msg)
    print(('[WTBG] balance: %s'):format(msg))
end

do
    local b = WTBG.Balance
    if (b.Combat.ReviveTime or 0) <= 0 then
        warnBalance('ReviveTime must be > 0')
    end
    if (b.Combat.FinishTime or 0) <= 0 then
        warnBalance('FinishTime must be > 0')
    end
    if (b.Combat.BleedoutTime or 0) <= 0 then
        warnBalance('BleedoutTime must be > 0')
    end
    if (b.Medical.BandageUseTime or 0) <= 0 or (b.Medical.MedkitUseTime or 0) <= 0 then
        warnBalance('heal use time must be > 0')
    end
    for kind, cap in pairs(b.Ammo.Max) do
        local pick = b.Ammo.Pickup[kind] or 0
        if cap < pick then
            warnBalance(('ammo max < pickup (%s)'):format(kind))
        end
    end
    if Config.Debug then
        print(('[WTBG] balance %s  hp=%s armor=%s bleed=%ss revive=%ss finish=%ss plane=%ss veh=%s zoneScale=%s'):format(
            b.Preset,
            b.Combat.Health,
            b.Combat.MaxArmor,
            b.Combat.BleedoutTime,
            b.Combat.ReviveTime,
            b.Combat.FinishTime,
            b.Drop.RouteDuration,
            b.Vehicle.SpawnCount,
            b.Zone.TimeScale
        ))
    end
end
