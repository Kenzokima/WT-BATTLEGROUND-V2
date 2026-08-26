WTBG.Zone = WTBG.Zone or {}

local zones = {}

local function now()
    return GetGameTimer()
end

local function clamp(n, lo, hi)
    if n < lo then
        return lo
    end
    if n > hi then
        return hi
    end
    return n
end

local function scaledMs(seconds)
    local scale = tonumber(ZoneConfig.TimeScale) or 1.0
    if scale <= 0 then
        scale = 1.0
    end
    return math.max(1000, math.floor((tonumber(seconds) or 1) * scale * 1000))
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function dist2(ax, ay, bx, by)
    local dx = ax - bx
    local dy = ay - by
    return math.sqrt(dx * dx + dy * dy)
end

local function bounds()
    return ZoneConfig.PlayableBounds
end

local function clampCenter(x, y, radius)
    local b = bounds()
    if not b then
        return x, y
    end
    return clamp(x, b.minX + radius, b.maxX - radius), clamp(y, b.minY + radius, b.maxY - radius)
end

local function inBounds(x, y, radius)
    local b = bounds()
    if not b then
        return true
    end
    return (x - radius) >= b.minX and (x + radius) <= b.maxX
        and (y - radius) >= b.minY and (y + radius) <= b.maxY
end

local function pickTarget(cx, cy, currentR, nextR)
    local maxDist = math.max(0.0, currentR - nextR)
    for _ = 1, 16 do
        local ang = math.random() * 6.283185307179586
        local dist = math.sqrt(math.random()) * maxDist
        local nx = cx + math.cos(ang) * dist
        local ny = cy + math.sin(ang) * dist
        if dist2(cx, cy, nx, ny) <= maxDist + 0.05 and inBounds(nx, ny, nextR) then
            return nx, ny
        end
    end
    return clampCenter(cx, cy, nextR)
end

local function phaseDef(index)
    local list = ZoneConfig.Phases or {}
    return list[index]
end

local function currentCircle(z)
    if z.state ~= 'SHRINKING' then
        return z.cx, z.cy, z.cr
    end

    local span = z.shrinkEnd - z.shrinkStart
    local t = 1.0
    if span > 0 then
        t = clamp((now() - z.shrinkStart) / span, 0.0, 1.0)
    end
    return lerp(z.sx, z.tx, t), lerp(z.sy, z.ty, t), lerp(z.sr, z.tr, t)
end

local function snapshot(z)
    local remaining
    if z.state == 'HOLDING' then
        remaining = math.max(0, z.holdEnd - now())
    elseif z.state == 'SHRINKING' then
        remaining = math.max(0, z.shrinkEnd - now())
    else
        remaining = 0
    end

    return {
        matchId = z.matchId,
        gen = z.gen,
        phase = z.phase,
        state = z.state,
        cx = z.cx,
        cy = z.cy,
        cr = z.cr,
        tx = z.tx,
        ty = z.ty,
        tr = z.tr,
        sx = z.sx,
        sy = z.sy,
        sr = z.sr,
        durationMs = remaining,
        damage = z.damage,
        final = z.final and true or false
    }
end

local function broadcast(z)
    local sources = exports.wtbg_match:GetMatchSources(z.matchId) or {}
    local payload = snapshot(z)
    for i = 1, #sources do
        local src = tonumber(sources[i])
        if src then
            TriggerClientEvent('wtbg:zone:sync', src, payload)
        end
    end
end

local function stopZone(matchId)
    local z = zones[matchId]
    if not z then
        return
    end

    local sources = exports.wtbg_match:GetMatchSources(matchId) or {}
    z.state = 'FINISHED'
    z.gen = z.gen + 1
    zones[matchId] = nil

    for i = 1, #sources do
        local src = tonumber(sources[i])
        if src then
            TriggerClientEvent('wtbg:zone:clear', src)
        end
    end
end

local function validZone(z, gen)
    return z and z.gen == gen and z.state ~= 'FINISHED' and zones[z.matchId] == z
end

local scheduleHold, scheduleShrink, beginHold, beginShrink, finishShrink, scheduleTick

local function targetRadius(z)
    local def = phaseDef(z.phase)
    if def and def.radius then
        return def.radius
    end
    return z.cr
end

beginHold = function(z, keepTarget)
    if z.state == 'FINISHED' then
        return
    end

    local def = phaseDef(z.phase)
    if not def then
        z.final = true
        def = phaseDef(#(ZoneConfig.Phases or {})) or { hold = ZoneConfig.FinalHold, damage = 15, radius = z.cr }
    end

    z.state = 'HOLDING'
    z.cx, z.cy, z.cr = currentCircle(z)
    z.sx, z.sy, z.sr = z.cx, z.cy, z.cr
    z.damage = def.damage or 1

    if z.final then
        z.tx, z.ty, z.tr = z.cx, z.cy, z.cr
        z.holdEnd = now() + scaledMs(ZoneConfig.FinalHold or 20)
    else
        if not keepTarget then
            local r = targetRadius(z)
            z.tx, z.ty = pickTarget(z.cx, z.cy, z.cr, r)
            z.tr = r
        end
        z.holdEnd = now() + scaledMs(def.hold)
    end

    broadcast(z)
    scheduleHold(z)
end

beginShrink = function(z)
    if z.state == 'FINISHED' or z.final then
        return
    end

    local def = phaseDef(z.phase)
    if not def then
        return
    end

    z.cx, z.cy, z.cr = currentCircle(z)
    z.sx, z.sy, z.sr = z.cx, z.cy, z.cr
    z.state = 'SHRINKING'
    z.shrinkStart = now()
    z.shrinkEnd = z.shrinkStart + scaledMs(def.shrink)
    broadcast(z)
    scheduleShrink(z)
end

finishShrink = function(z)
    if z.state == 'FINISHED' then
        return
    end

    z.cx, z.cy, z.cr = z.tx, z.ty, z.tr
    z.sx, z.sy, z.sr = z.cx, z.cy, z.cr

    local last = #(ZoneConfig.Phases or {})
    if z.phase >= last then
        z.final = true
        beginHold(z)
        return
    end

    z.phase = z.phase + 1
    beginHold(z)
end

scheduleHold = function(z)
    local gen = z.gen
    local wait = math.max(0, z.holdEnd - now())
    SetTimeout(wait, function()
        if not validZone(z, gen) or z.state ~= 'HOLDING' then
            return
        end
        if z.final then
            z.finalHot = true
            broadcast(z)
            return
        end
        beginShrink(z)
    end)
end

scheduleShrink = function(z)
    local gen = z.gen
    local wait = math.max(0, z.shrinkEnd - now())
    SetTimeout(wait, function()
        if not validZone(z, gen) or z.state ~= 'SHRINKING' then
            return
        end
        finishShrink(z)
    end)
end

local function matchActive(matchId)
    local snap = exports.wtbg_match:GetMatch(matchId)
    return snap and snap.state == WTBG.MatchStates.ACTIVE
end

local function tickDamage(z)
    if z.state == 'WAITING' or z.state == 'FINISHED' then
        return
    end
    if not matchActive(z.matchId) then
        return
    end

    local cx, cy, cr = currentCircle(z)
    z.cx, z.cy, z.cr = cx, cy, cr

    local dmg = z.damage or 1
    if z.finalHot then
        dmg = math.min(ZoneConfig.FinalDamageCap or 40, dmg * (ZoneConfig.FinalDamageScale or 1.35))
        z.damage = dmg
    end

    if GetResourceState('wtbg_combat') ~= 'started' then
        return
    end

    local sources = exports.wtbg_match:GetMatchSources(z.matchId) or {}
    for i = 1, #sources do
        local src = tonumber(sources[i])
        if src then
            local info = exports.wtbg_match:GetMember(src)
            if info and info.matchId == z.matchId and info.matchState == WTBG.MatchStates.ACTIVE and info.alive then
                local ped = GetPlayerPed(src)
                if ped and ped ~= 0 then
                    local coords = GetEntityCoords(ped)
                    if dist2(coords.x, coords.y, cx, cy) > cr then
                        exports.wtbg_combat:ApplyZoneDamage(src, dmg)
                    end
                end
            end
        end
    end
end

scheduleTick = function(z)
    local gen = z.gen
    local ms = math.max(250, math.floor((tonumber(ZoneConfig.DamageTick) or 1.0) * 1000))
    SetTimeout(ms, function()
        if not validZone(z, gen) then
            return
        end
        tickDamage(z)
        scheduleTick(z)
    end)
end

local function createZone(matchId)
    matchId = tonumber(matchId)
    if not ZoneConfig.Enabled or not matchId then
        return nil
    end

    local existing = zones[matchId]
    if existing then
        return existing
    end

    local c = ZoneConfig.InitialCenter
    local r = ZoneConfig.InitialRadius or 250.0
    local cx, cy = clampCenter(c.x, c.y, r)
    local z = {
        matchId = matchId,
        gen = 1,
        phase = 1,
        state = 'WAITING',
        cx = cx,
        cy = cy,
        cr = r,
        sx = cx,
        sy = cy,
        sr = r,
        tx = cx,
        ty = cy,
        tr = r,
        damage = (phaseDef(1) and phaseDef(1).damage) or 1,
        final = false,
        finalHot = false
    }
    local firstR = targetRadius(z)
    z.tx, z.ty = pickTarget(cx, cy, r, firstR)
    z.tr = firstR
    zones[matchId] = z
    broadcast(z)
    return z
end

function WTBG.Zone.Preview(matchId)
    return createZone(matchId)
end

function WTBG.Zone.Start(matchId)
    local z = createZone(matchId)
    if not z then
        return false
    end
    if z.state ~= 'WAITING' then
        return true
    end
    math.randomseed(now() + matchId * 31)
    beginHold(z, true)
    scheduleTick(z)
    WTBG.Debug('zone started', matchId)
    return true
end

function WTBG.Zone.Stop(matchId)
    matchId = tonumber(matchId)
    if not matchId then
        return
    end
    stopZone(matchId)
end

function WTBG.Zone.Sync(source, matchId)
    local z = zones[tonumber(matchId)]
    if not z then
        TriggerClientEvent('wtbg:zone:clear', source, matchId)
        return
    end
    TriggerClientEvent('wtbg:zone:sync', source, snapshot(z))
end

function WTBG.Zone.ForceNext(matchId)
    local z = zones[tonumber(matchId)]
    if not z or z.state == 'FINISHED' or z.state == 'WAITING' then
        return false
    end
    z.gen = z.gen + 1
    if z.state == 'HOLDING' then
        if z.final then
            z.finalHot = true
            broadcast(z)
            scheduleTick(z)
            return true
        end
        beginShrink(z)
    elseif z.state == 'SHRINKING' then
        finishShrink(z)
    end
    scheduleTick(z)
    return true
end

function WTBG.Zone.Info(matchId)
    local z = zones[tonumber(matchId)]
    if not z then
        return nil
    end
    local cx, cy, cr = currentCircle(z)
    return {
        matchId = z.matchId,
        phase = z.phase,
        state = z.state,
        radius = cr,
        centerX = cx,
        centerY = cy,
        targetRadius = z.tr,
        damage = z.damage,
        final = z.final,
        remainingMs = snapshot(z).durationMs
    }
end

exports('ForceNext', function(matchId)
    return WTBG.Zone.ForceNext(matchId)
end)

exports('GetInfo', function(matchId)
    return WTBG.Zone.Info(matchId)
end)
