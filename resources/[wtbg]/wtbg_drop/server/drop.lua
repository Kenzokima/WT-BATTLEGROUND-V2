WTBG.Drop = WTBG.Drop or {}

local deployments = {}
local byPlayer = {}

local function usesDrop(mode)
    return DropConfig.Enabled and WTBG.UsesBRDeployment(mode)
end

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

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function pickRoute(matchId)
    local b = DropConfig.PlayableBounds
    local pad = tonumber(DropConfig.RoutePadding) or 55.0
    local alt = tonumber(DropConfig.Altitude) or 275.0
    local cx = (b.minX + b.maxX) * 0.5
    local cy = (b.minY + b.maxY) * 0.5
    local west, east = b.minX - pad, b.maxX + pad
    local south, north = b.minY - pad, b.maxY + pad

    local options = {
        { west, cy, east, cy },
        { east, cy, west, cy },
        { cx, south, cx, north },
        { cx, north, cx, south },
        { west, north, east, south },
        { east, south, west, north }
    }
    local row = options[(matchId % #options) + 1]
    return {
        sx = row[1] + 0.0,
        sy = row[2] + 0.0,
        sz = alt,
        fx = row[3] + 0.0,
        fy = row[4] + 0.0,
        fz = alt,
        heading = DropConfig.TravelHeading(row[1], row[2], row[3], row[4])
    }
end

local function progressOf(dep)
    if not dep.startedAt then
        return 0.0
    end
    local span = dep.durationMs
    if span <= 0 then
        return 1.0
    end
    return clamp((now() - dep.startedAt) / span, 0.0, 1.0)
end

local function planePos(dep)
    local t = progressOf(dep)
    return lerp(dep.sx, dep.fx, t), lerp(dep.sy, dep.fy, t), lerp(dep.sz, dep.fz, t), dep.heading
end

local function routePayload(dep, flying)
    return {
        matchId = dep.matchId,
        gen = dep.gen,
        sx = dep.sx,
        sy = dep.sy,
        sz = dep.sz,
        fx = dep.fx,
        fy = dep.fy,
        fz = dep.fz,
        heading = dep.heading,
        durationMs = dep.durationMs,
        jumpDelayMs = dep.jumpDelayMs,
        flying = flying and true or false,
        autoWarn = tonumber(DropConfig.AutoDropWarn) or 5.0
    }
end

local function validDep(dep, gen)
    return dep and deployments[dep.matchId] == dep and dep.gen == gen
end

local function setPlayer(dep, source, state)
    local row = dep.players[source]
    if not row then
        row = { state = state, jumped = false }
        dep.players[source] = row
    end
    row.state = state
    byPlayer[source] = { matchId = dep.matchId, gen = dep.gen }
    for src, _ in pairs(dep.players) do
        TriggerClientEvent('wtbg:ui:dropMember', src, source, state)
    end
end

local function passengerIds(dep, teamId)
    local list = {}
    for src, row in pairs(dep.players) do
        if row.state == 'PLANE' and (teamId == nil or row.teamId == teamId) then
            list[#list + 1] = src
        end
    end
    table.sort(list)
    return list
end

local function syncPassengers(dep)
    for src, row in pairs(dep.players) do
        if row.state == 'PLANE' then
            local list = passengerIds(dep, row.teamId)
            TriggerClientEvent('wtbg:drop:passengers', src, list)
        end
    end
end

local function broadcast(dep, eventName, ...)
    for src, _ in pairs(dep.players) do
        TriggerClientEvent(eventName, src, ...)
    end
end

local function stripServer(source)
    WTBG.SetVitals(source, Config.StartingHealth or 200, 0)
    local ped = GetPlayerPed(source)
    if ped and ped ~= 0 then
        WTBG.Call(RemoveAllPedWeapons, ped, true)
    end
end

local function applyGroundLoadout(source)
    if GetResourceState('wtbg_combat') ~= 'started' then
        return
    end
    TriggerEvent('wtbg:match:applyLoadout', source)
end

local function removePlayer(source, recover)
    local ref = byPlayer[source]
    byPlayer[source] = nil
    if not ref then
        TriggerClientEvent('wtbg:drop:clear', source)
        return
    end

    local dep = deployments[ref.matchId]
    if dep then
        dep.players[source] = nil
    end

    TriggerClientEvent('wtbg:drop:clear', source)
    if recover then
        local spawn = Config.MatchSpawnPoints and Config.MatchSpawnPoints[1]
        if spawn then
            local ped = GetPlayerPed(source)
            if ped and ped ~= 0 then
                SetEntityCoords(ped, spawn.x, spawn.y, spawn.z, false, false, false, false)
            end
        end
    end
end

local function releaseJump(dep, source, auto)
    local row = dep.players[source]
    if not row or row.state ~= 'PLANE' then
        return false
    end

    local x, y, z, h = planePos(dep)
    local back = tonumber(DropConfig.JumpExitBack) or 16.0
    local down = tonumber(DropConfig.JumpExitDown) or 4.0
    local fx, fy = DropConfig.Forward(h)
    x = x - fx * back
    y = y - fy * back
    z = z - down
    row.jumped = true
    setPlayer(dep, source, 'FREEFALL')
    syncPassengers(dep)

    TriggerClientEvent('wtbg:drop:jump', source, {
        matchId = dep.matchId,
        gen = dep.gen,
        x = x,
        y = y,
        z = z,
        heading = h,
        exitBack = back,
        exitDown = down,
        auto = auto and true or false,
        forceHeight = tonumber(DropConfig.ForceParachuteHeight) or 92.0,
        groundDist = tonumber(DropConfig.GroundDetectionDistance) or 2.75
    })
    return true
end

local function autoDrop(dep, gen)
    if not validDep(dep, gen) then
        return
    end

    for src, row in pairs(dep.players) do
        if row.state == 'PLANE' then
            releaseJump(dep, src, true)
        end
    end

    if dep.groundStarted then
        return
    end
    dep.groundStarted = true
    TriggerEvent('wtbg:drop:groundPhase', dep.matchId)
end

local function startFlight(dep)
    if dep.startedAt then
        return
    end

    dep.startedAt = now()
    dep.endsAt = dep.startedAt + dep.durationMs
    dep.jumpAfter = dep.startedAt + dep.jumpDelayMs
    broadcast(dep, 'wtbg:drop:go', routePayload(dep, true))

    local gen = dep.gen
    SetTimeout(dep.durationMs, function()
        if DropConfig.AutoDropAtEnd == false then
            return
        end
        autoDrop(dep, gen)
    end)
end

function WTBG.Drop.UsesMatch(matchId)
    local snap = exports.wtbg_match:GetMatch(tonumber(matchId))
    return snap and usesDrop(snap.mode) or false
end

function WTBG.Drop.GetPlayerState(source)
    source = tonumber(source)
    local ref = source and byPlayer[source]
    if not ref then
        return nil
    end
    local dep = deployments[ref.matchId]
    local row = dep and dep.players[source]
    if not row then
        return nil
    end
    return row.state
end

function WTBG.Drop.IsPlayerLanded(source)
    local state = WTBG.Drop.GetPlayerState(tonumber(source))
    if not state then
        return true
    end
    return state == 'LANDED'
end

function WTBG.Drop.Prepare(matchId)
    matchId = tonumber(matchId)
    if not matchId or not WTBG.Drop.UsesMatch(matchId) then
        return false
    end

    local snap = exports.wtbg_match:GetMatch(matchId)
    if not snap then
        return false
    end

    local prev = deployments[matchId]
    local gen = (prev and prev.gen or 0) + 1
    local route = pickRoute(matchId)
    local duration = math.max(8, math.floor((tonumber(DropConfig.RouteDuration) or 25) * 1000))
    local jumpDelay = math.max(0, math.floor((tonumber(DropConfig.JumpStartDelay) or 2) * 1000))

    local dep = {
        matchId = matchId,
        gen = gen,
        bucket = snap.bucket,
        sx = route.sx,
        sy = route.sy,
        sz = route.sz,
        fx = route.fx,
        fy = route.fy,
        fz = route.fz,
        heading = route.heading,
        durationMs = duration,
        jumpDelayMs = jumpDelay,
        startedAt = nil,
        endsAt = nil,
        jumpAfter = nil,
        finished = false,
        groundStarted = false,
        players = {}
    }
    deployments[matchId] = dep

    local sources = exports.wtbg_match:GetMatchSources(matchId) or {}
    for i = 1, #sources do
        local src = tonumber(sources[i])
        if src then
            local member = snap.players and (snap.players[src] or snap.players[tostring(src)])
            dep.players[src] = {
                state = 'PLANE',
                jumped = false,
                teamId = member and member.teamId or nil
            }
            byPlayer[src] = { matchId = matchId, gen = gen }
        end
    end

    for src, _ in pairs(dep.players) do
        stripServer(src)
        TriggerClientEvent('wtbg:ui:closeInventory', src)
        TriggerClientEvent('wtbg:drop:board', src, routePayload(dep, false))
        for other, row in pairs(dep.players) do
            TriggerClientEvent('wtbg:ui:dropMember', src, other, row.state)
        end
    end
    syncPassengers(dep)

    WTBG.Debug('drop prepared', matchId, 'gen', gen)
    return true
end

function WTBG.Drop.Start(matchId)
    matchId = tonumber(matchId)
    local dep = deployments[matchId]
    if not dep then
        if not WTBG.Drop.Prepare(matchId) then
            return false
        end
        dep = deployments[matchId]
    end
    startFlight(dep)
    WTBG.Debug('drop flight', matchId)
    return true
end

function WTBG.Drop.Stop(matchId)
    matchId = tonumber(matchId)
    local dep = deployments[matchId]
    if not dep then
        return
    end

    dep.finished = true
    dep.gen = dep.gen + 1
    for src, _ in pairs(dep.players) do
        byPlayer[src] = nil
        TriggerClientEvent('wtbg:drop:clear', src)
    end
    deployments[matchId] = nil
end

AddEventHandler('wtbg:match:starting', function(matchId)
    WTBG.Drop.Prepare(matchId)
end)

AddEventHandler('wtbg:match:becameActive', function(matchId)
    WTBG.Drop.Start(matchId)
end)

AddEventHandler('wtbg:match:serverFinished', function(matchId)
    WTBG.Drop.Stop(matchId)
end)

AddEventHandler('wtbg:match:destroyed', function(matchId)
    WTBG.Drop.Stop(matchId)
end)

AddEventHandler('wtbg:match:playerEliminated', function(source)
    removePlayer(source, false)
end)

AddEventHandler('wtbg:core:returnedToLobby', function(source)
    removePlayer(source, false)
end)

AddEventHandler('wtbg:core:playerDropped', function(source)
    removePlayer(source, false)
end)

RegisterNetEvent('wtbg:drop:requestJump', function()
    local source = tonumber(source)
    local ref = source and byPlayer[source]
    if not ref then
        return
    end

    local dep = deployments[ref.matchId]
    local row = dep and dep.players[source]
    if not dep or not row or row.state ~= 'PLANE' or row.jumped then
        return
    end

    local info = exports.wtbg_match:GetMember(source)
    if not info or info.matchId ~= dep.matchId or info.matchState ~= WTBG.MatchStates.ACTIVE or not info.alive then
        return
    end

    if not dep.startedAt or now() < dep.jumpAfter then
        return
    end

    if dep.endsAt and now() > dep.endsAt + 1500 then
        return
    end

    releaseJump(dep, source, false)
end)

RegisterNetEvent('wtbg:drop:parachute', function()
    local source = tonumber(source)
    local ref = source and byPlayer[source]
    if not ref then
        return
    end

    local dep = deployments[ref.matchId]
    local row = dep and dep.players[source]
    if not row or row.state ~= 'FREEFALL' then
        return
    end

    local info = exports.wtbg_match:GetMember(source)
    if not info or info.matchId ~= dep.matchId or not info.alive then
        return
    end

    setPlayer(dep, source, 'PARACHUTE')
    TriggerClientEvent('wtbg:drop:phase', source, 'PARACHUTE')
end)

RegisterNetEvent('wtbg:drop:landed', function()
    local source = tonumber(source)
    local ref = source and byPlayer[source]
    if not ref then
        return
    end

    local dep = deployments[ref.matchId]
    local row = dep and dep.players[source]
    if not row or (row.state ~= 'FREEFALL' and row.state ~= 'PARACHUTE') then
        return
    end

    local info = exports.wtbg_match:GetMember(source)
    if not info or info.matchId ~= dep.matchId or info.matchState ~= WTBG.MatchStates.ACTIVE or not info.alive or info.downed then
        return
    end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then
        return
    end

    local coords = GetEntityCoords(ped)
    local b = DropConfig.PlayableBounds
    if coords.z > (DropConfig.Altitude or 260.0) - 40.0 then
        return
    end
    if coords.x < b.minX - 180.0 or coords.x > b.maxX + 180.0 or coords.y < b.minY - 180.0 or coords.y > b.maxY + 180.0 then
        return
    end

    setPlayer(dep, source, 'LANDED')
    byPlayer[source] = { matchId = dep.matchId, gen = dep.gen }
    TriggerClientEvent('wtbg:drop:landed', source)
    TriggerEvent('wtbg:drop:playerLanded', source, dep.matchId)
    applyGroundLoadout(source)
end)

local function canDev(source)
    if source == 0 then
        return true
    end
    return Config.Debug or IsPlayerAceAllowed(source, Config.DevAce)
end

RegisterCommand('dropinfo', function(source)
    if not canDev(source) then
        return
    end
    if source == 0 then
        print('[WTBG] dropinfo: use in-game')
        return
    end
    local state = WTBG.Drop.GetPlayerState(source) or 'NONE'
    local ref = byPlayer[source]
    local dep = ref and deployments[ref.matchId]
    local pct = dep and math.floor(progressOf(dep) * 100) or 0
    exports.wtbg_core:Notify(source, ('DROP %s %s%%'):format(state, pct))
end, false)

RegisterCommand('dropforce', function(source)
    if not canDev(source) or source == 0 then
        return
    end
    local ref = byPlayer[source]
    local dep = ref and deployments[ref.matchId]
    local row = dep and dep.players[source]
    if row and row.state == 'PLANE' then
        releaseJump(dep, source, true)
        return
    end
    if row and (row.state == 'FREEFALL' or row.state == 'PARACHUTE') then
        setPlayer(dep, source, 'LANDED')
        TriggerClientEvent('wtbg:drop:landed', source)
        TriggerEvent('wtbg:drop:playerLanded', source, dep.matchId)
        applyGroundLoadout(source)
    end
end, false)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    if GetResourceState('wtbg_match') ~= 'started' then
        return
    end

    local list = exports.wtbg_match:ListMatches() or {}
    for i = 1, #list do
        local row = list[i]
        if row.state == WTBG.MatchStates.ACTIVE and usesDrop(row.mode) then
            local sources = exports.wtbg_match:GetMatchSources(row.id) or {}
            local spawn = Config.MatchSpawnPoints and Config.MatchSpawnPoints[1]
            for n = 1, #sources do
                local src = tonumber(sources[n])
                if src then
                    TriggerClientEvent('wtbg:drop:clear', src)
                    if spawn then
                        local ped = GetPlayerPed(src)
                        if ped and ped ~= 0 then
                            SetEntityCoords(ped, spawn.x, spawn.y, spawn.z, false, false, false, false)
                        end
                    end
                    applyGroundLoadout(src)
                end
            end
            TriggerEvent('wtbg:drop:groundPhase', row.id)
            WTBG.Debug('drop recovered match', row.id)
        elseif row.state == WTBG.MatchStates.STARTING and usesDrop(row.mode) then
            WTBG.Drop.Prepare(row.id)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    for matchId, _ in pairs(deployments) do
        WTBG.Drop.Stop(matchId)
    end
end)

exports('StartDeployment', function(matchId)
    return WTBG.Drop.Start(tonumber(matchId))
end)

exports('StopDeployment', function(matchId)
    WTBG.Drop.Stop(tonumber(matchId))
end)

exports('GetDeployment', function(matchId)
    local dep = deployments[tonumber(matchId)]
    if not dep then
        return nil
    end
    return {
        matchId = dep.matchId,
        flying = dep.startedAt ~= nil,
        progress = progressOf(dep),
        groundStarted = dep.groundStarted and true or false
    }
end)

exports('GetPlayerDropState', function(source)
    return WTBG.Drop.GetPlayerState(source)
end)

exports('IsPlayerLanded', function(source)
    return WTBG.Drop.IsPlayerLanded(source)
end)

exports('UsesMatch', function(matchId)
    return WTBG.Drop.UsesMatch(matchId)
end)
