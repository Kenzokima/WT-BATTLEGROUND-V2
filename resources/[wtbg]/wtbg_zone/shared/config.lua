ZoneConfig = {}

ZoneConfig.Enabled = true

-- Full GTA V land mass (Los Santos + Blaine County). Ocean is outside the first circle.
ZoneConfig.InitialCenter = vector2(250.0, 2000.0)
ZoneConfig.InitialRadius = 5200.0

ZoneConfig.PlayableBounds = {
    minX = -5500.0,
    maxX = 5500.0,
    minY = -4000.0,
    maxY = 8000.0
}

ZoneConfig.TimeScale = WTBG.Balance.Zone.TimeScale
ZoneConfig.DamageTick = 1.0

ZoneConfig.FinalHold = 45
ZoneConfig.FinalDamageScale = 1.35
ZoneConfig.FinalDamageCap = 40

ZoneConfig.Phases = {
    { hold = 110, shrink = 70, radius = 3400.0, damage = 2 },
    { hold = 80, shrink = 60, radius = 2200.0, damage = 3 },
    { hold = 65, shrink = 50, radius = 1400.0, damage = 5 },
    { hold = 50, shrink = 45, radius = 850.0, damage = 8 },
    { hold = 40, shrink = 35, radius = 420.0, damage = 12 },
    { hold = 28, shrink = 22, radius = 140.0, damage = 18 }
}

do
    local prev = ZoneConfig.InitialRadius
    for i = 1, #ZoneConfig.Phases do
        local radius = ZoneConfig.Phases[i].radius
        if not radius or radius >= prev then
            print(('[WTBG] balance: zone radius must decrease (phase %s)'):format(i))
        end
        prev = radius
    end
end
