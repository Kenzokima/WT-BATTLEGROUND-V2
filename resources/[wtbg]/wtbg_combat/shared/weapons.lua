Weapons = {}

function Weapons.Hash(name)
    if type(name) ~= 'string' then
        return nil
    end

    return joaat(name)
end

function Weapons.ApplyLoadout(ped)
    if not ped or ped == 0 then
        return false
    end

    RemoveAllPedWeapons(ped, true)

    local loadout = Config.Loadout or {}
    for i = 1, #loadout do
        local item = loadout[i]
        local hash = Weapons.Hash(item.weapon)
        if hash then
            GiveWeaponToPed(ped, hash, item.ammo or 0, false, true)
        end
    end

    if loadout[1] then
        local primary = Weapons.Hash(loadout[1].weapon)
        if primary then
            SetCurrentPedWeapon(ped, primary, true)
        end
    end

    local health = Config.StartingHealth or 200
    if not IsDuplicityVersion() then
        SetPedMaxHealth(ped, health)
    end
    SetEntityMaxHealth(ped, health)
    SetEntityHealth(ped, health)
    SetPedArmour(ped, Config.StartingArmor or 0)
    return true
end