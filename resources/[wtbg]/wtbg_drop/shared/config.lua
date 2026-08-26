DropConfig = {}

DropConfig.Enabled = true

DropConfig.Altitude = 550.0
DropConfig.RouteDuration = WTBG.Balance.Drop.RouteDuration
DropConfig.RoutePadding = 700.0
DropConfig.JumpStartDelay = WTBG.Balance.Drop.JumpStartDelay
DropConfig.AutoDropAtEnd = true
DropConfig.AutoDropWarn = WTBG.Balance.Drop.AutoDropWarn
DropConfig.ParachuteHeight = WTBG.Balance.Drop.ParachuteHeight
DropConfig.ForceParachuteHeight = WTBG.Balance.Drop.ForceParachuteHeight
DropConfig.GroundDetectionDistance = 2.75

DropConfig.PlaneModel = 'titan'
DropConfig.PilotModel = 's_m_m_pilot_01'
DropConfig.FlightPitch = -1.5
DropConfig.CruiseTurbulence = 0.28
DropConfig.JumpExitBack = 16.0
DropConfig.JumpExitDown = 4.0
DropConfig.MaxVisiblePassengers = 10

DropConfig.CameraOffset = vector3(0.0, -34.0, 14.0)
DropConfig.CameraLook = vector3(0.0, 14.0, 1.5)
DropConfig.CameraFov = 52.0
DropConfig.CameraBlend = 350
DropConfig.CameraSmoothing = 7.5

DropConfig.SeatAnim = {
    dict = 'amb@code_human_in_bus_passenger_idles@male@sit@base',
    clip = 'base'
}

-- Titan cargo benches: +Y nose, -Y ramp, +X right. z is cabin floor, not roof.
DropConfig.PassengerOffsets = {
    { x = 1.08, y = -3.4, z = 1.42, h = 90.0 },
    { x = -1.08, y = -3.4, z = 1.42, h = -90.0 },
    { x = 1.08, y = -5.2, z = 1.42, h = 90.0 },
    { x = -1.08, y = -5.2, z = 1.42, h = -90.0 },
    { x = 1.08, y = -7.0, z = 1.42, h = 90.0 },
    { x = -1.08, y = -7.0, z = 1.42, h = -90.0 },
    { x = 1.08, y = -8.8, z = 1.42, h = 90.0 },
    { x = -1.08, y = -8.8, z = 1.42, h = -90.0 },
    { x = 1.08, y = -10.6, z = 1.42, h = 90.0 },
    { x = -1.08, y = -10.6, z = 1.42, h = -90.0 }
}

DropConfig.PlayableBounds = {
    minX = -5500.0,
    maxX = 5500.0,
    minY = -4000.0,
    maxY = 8000.0
}

function DropConfig.TravelHeading(ax, ay, bx, by)
    local dx = (bx or 0.0) - (ax or 0.0)
    local dy = (by or 0.0) - (ay or 0.0)
    if dx == 0.0 and dy == 0.0 then
        return 0.0
    end
    if GetHeadingFromVector_2d then
        return GetHeadingFromVector_2d(dx, dy)
    end
    return (math.deg(math.atan(-dx, dy)) + 360.0) % 360.0
end

function DropConfig.Forward(heading)
    local rad = math.rad(heading or 0.0)
    return -math.sin(rad), math.cos(rad)
end
