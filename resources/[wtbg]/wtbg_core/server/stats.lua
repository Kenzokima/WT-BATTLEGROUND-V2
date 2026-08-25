local packs = {}
local finalizedMatches = {}
local ASSIST_WINDOW_MS = 15000
local ASSIST_MIN_DAMAGE = 20
local MAX_HIT_DAMAGE = 400
local MAX_KILL_DISTANCE = 2000
local HEAD_COMPONENT = 20

local function emptyStats()
    return {
        kills = 0,
        deaths = 0,
        assists = 0,
        damage = 0,
        headshots = 0,
        longestKill = 0,
        placement = nil,
        won = false
    }
end

local function finitePositive(n, max)
    n = tonumber(n)
    if type(n) ~= 'number' or n ~= n or n < 0 or n == math.huge then
        return nil
    end
    if max and n > max then
        n = max
    end
    return n
end

local function getMatch(matchId)
    matchId = tonumber(matchId)
    if not matchId or GetResourceState('wtbg_match') ~= 'started' then
        return nil
    end
    local ok, snap = pcall(function()
        return exports.wtbg_match:GetMatch(matchId)
    end)
    if ok then
        return snap
    end
    return nil
end

local function playerFromPed(ped)
    if not ped or ped == 0 then
        return nil
    end
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src and GetPlayerPed(src) == ped then
            return src
        end
    end
    return nil
end

local function ensurePack(matchId, mode)
    local pack = packs[matchId]
    if pack then
        return pack
    end
    pack = {
        matchId = matchId,
        mode = mode,
        parts = {},
        contributors = {},
        finalized = false
    }
    packs[matchId] = pack
    return pack
end

local function stillOwnsSource(part, source)
    source = tonumber(source)
    if not source or not part then
        return false
    end
    local license = WTBG.GetPrimaryIdentifier(source)
    if not license then
        return false
    end
    if not WTBG.Profiles.OwnsLicense(source, license) then
        return false
    end
    if part.license and part.license ~= license then
        return false
    end
    part.license = license
    return true
end

local function attachIdentity(part, source)
    source = tonumber(source)
    if not source or not part then
        return
    end
    part.license = part.license or WTBG.GetPrimaryIdentifier(source)
    if not part.name or part.name == '' then
        part.name = WTBG.PlayerName(source)
    end
    local profile = WTBG.Profiles.GetCached(source)
    if profile and profile.persist and profile.id then
        part.profileId = profile.id
        part.persist = true
        if profile.name then
            part.name = profile.name
        end
    elseif profile and profile.license then
        part.license = part.license or profile.license
    end
end

local function initPart(pack, source, teamId)
    source = tonumber(source)
    if not source or pack.parts[source] then
        return pack.parts[source]
    end

    local part = {
        source = source,
        profileId = nil,
        license = nil,
        name = WTBG.PlayerName(source),
        teamId = tonumber(teamId),
        persist = false,
        disconnected = false,
        stats = emptyStats(),
        finalized = false
    }
    attachIdentity(part, source)
    pack.parts[source] = part
    return part
end

local function sameTeam(pack, a, b)
    local pa = pack.parts[a]
    local pb = pack.parts[b]
    if not pa or not pb or not pa.teamId or not pb.teamId then
        return false
    end
    return pa.teamId == pb.teamId
end

local function addDamage(pack, attacker, victim, amount, headshot)
    amount = finitePositive(amount, MAX_HIT_DAMAGE)
    if not amount or amount <= 0 then
        return
    end
    if attacker == victim then
        return
    end
    local ap = pack.parts[attacker]
    local vp = pack.parts[victim]
    if not ap or not vp then
        return
    end
    if sameTeam(pack, attacker, victim) then
        return
    end

    ap.stats.damage = ap.stats.damage + math.floor(amount)
    if headshot then
        ap.stats.headshots = ap.stats.headshots + 1
    end

    local bucket = pack.contributors[victim]
    if not bucket then
        bucket = {}
        pack.contributors[victim] = bucket
    end
    local row = bucket[attacker]
    if not row then
        row = { damage = 0, lastHitAt = 0 }
        bucket[attacker] = row
    end
    row.damage = row.damage + math.floor(amount)
    row.lastHitAt = GetGameTimer()
end

local function creditAssists(pack, victim, killer)
    local bucket = pack.contributors[victim]
    pack.contributors[victim] = nil
    if type(bucket) ~= 'table' then
        return
    end

    local now = GetGameTimer()
    for attacker, info in pairs(bucket) do
        if attacker ~= killer and type(info) == 'table' then
            local dmg = finitePositive(info.damage)
            local when = tonumber(info.lastHitAt) or 0
            if dmg and dmg >= ASSIST_MIN_DAMAGE and (now - when) <= ASSIST_WINDOW_MS then
                local ap = pack.parts[attacker]
                if ap and not sameTeam(pack, attacker, victim) then
                    ap.stats.assists = ap.stats.assists + 1
                end
            end
        end
    end
end

local function killDistance(killer, victim)
    local kped = GetPlayerPed(killer)
    local vped = GetPlayerPed(victim)
    if not kped or kped == 0 or not vped or vped == 0 then
        return nil
    end
    if type(GetEntityCoords) ~= 'function' then
        return nil
    end
    local ok, kc = pcall(GetEntityCoords, kped)
    local ok2, vc = pcall(GetEntityCoords, vped)
    if not ok or not ok2 or not kc or not vc then
        return nil
    end
    local dist = #(kc - vc)
    dist = finitePositive(dist, MAX_KILL_DISTANCE)
    if not dist or dist < 0.5 then
        return nil
    end
    return math.floor(dist * 100 + 0.5) / 100
end

local function remainingEffective(victim)
    local ped = GetPlayerPed(victim)
    if not ped or ped == 0 then
        return nil
    end
    local hp = WTBG.PedHealth(ped)
    local ar = WTBG.PedArmour(ped) or 0
    if not hp then
        return nil
    end
    return math.max(0, (hp - 100) + ar)
end

AddEventHandler('wtbg:match:becameActive', function(matchId)
    matchId = tonumber(matchId)
    if not matchId or finalizedMatches[matchId] then
        return
    end

    local snap = getMatch(matchId)
    local pack = ensurePack(matchId, snap and snap.mode or Config.MatchMode)
    pack.startedAt = pack.startedAt or os.time()
    if snap then
        pack.mode = snap.mode or pack.mode
        if type(snap.teams) == 'table' then
            pack.teamCount = WTBG.Count(snap.teams)
        end
    end

    if snap and type(snap.players) == 'table' then
        for src, row in pairs(snap.players) do
            initPart(pack, tonumber(src) or (row and row.source), row and row.teamId)
        end
        return
    end

    if GetResourceState('wtbg_match') == 'started' then
        local ok, sources = pcall(function()
            return exports.wtbg_match:GetMatchSources(matchId)
        end)
        if ok and type(sources) == 'table' then
            for i = 1, #sources do
                local src = tonumber(sources[i])
                local member
                if src then
                    pcall(function()
                        member = exports.wtbg_match:GetMember(src)
                    end)
                end
                initPart(pack, src, member and member.teamId)
            end
        end
    end
end)

AddEventHandler('wtbg:match:playerEliminated', function(source, matchId, _, killer)
    source = tonumber(source)
    matchId = tonumber(matchId)
    killer = tonumber(killer)
    local pack = matchId and packs[matchId]
    if not pack or pack.finalized or not source then
        return
    end

    local victim = pack.parts[source] or initPart(pack, source)
    if not victim then
        return
    end

    if victim.stats.deaths < 1 then
        victim.stats.deaths = 1
    end

    if killer and killer ~= source and pack.parts[killer] and not sameTeam(pack, killer, source) then
        local kp = pack.parts[killer]
        kp.stats.kills = kp.stats.kills + 1
        local dist = killDistance(killer, source)
        if dist and dist > kp.stats.longestKill then
            kp.stats.longestKill = dist
        end
    else
        killer = nil
    end

    creditAssists(pack, source, killer)

    local snap = getMatch(matchId)
    local row = snap and snap.players and snap.players[source]
    if row and tonumber(row.placement) then
        victim.stats.placement = tonumber(row.placement)
    end
    if row and row.teamId then
        victim.teamId = row.teamId
    end
end)

AddEventHandler('wtbg:match:playerRevived', function(target, matchId)
    target = tonumber(target)
    local pack = tonumber(matchId) and packs[tonumber(matchId)]
    if not pack or not target then
        return
    end
    pack.contributors[target] = nil
end)

local function resolvePlacement(pack, part, snap)
    local winnerTeamId = snap and snap.winnerTeamId or nil
    if winnerTeamId and part.teamId == winnerTeamId then
        return 1, true
    end
    if snap and type(snap.teams) == 'table' and part.teamId then
        local team = snap.teams[part.teamId]
        if team and tonumber(team.placement) then
            return tonumber(team.placement), false
        end
    end
    if tonumber(part.stats.placement) then
        return tonumber(part.stats.placement), false
    end
    return nil, false
end

local function utcStamp(unix)
    unix = tonumber(unix) or os.time()
    return os.date('!%Y-%m-%d %H:%M:%S', unix)
end

local function buildHistorySnapshot(pack, snap)
    local finishedAt = os.time()
    local startedAt = tonumber(pack.startedAt) or finishedAt
    local teams = {}
    local players = {}
    local seen = {}

    for _, part in pairs(pack.parts) do
        if part.teamId then
            teams[part.teamId] = true
        end
        local profileId = tonumber(part.profileId)
        if profileId and part.license and not seen[profileId] then
            seen[profileId] = true
            local liveSource = tonumber(part.source)
            if not stillOwnsSource(part, liveSource) then
                liveSource = nil
            end
            players[#players + 1] = {
                profileId = profileId,
                license = part.license,
                name = part.name,
                teamId = tonumber(part.teamId),
                placement = tonumber(part.stats.placement) or 0,
                kills = part.stats.kills or 0,
                deaths = part.stats.deaths or 0,
                assists = part.stats.assists or 0,
                damage = part.stats.damage or 0,
                headshots = part.stats.headshots or 0,
                longestKill = part.stats.longestKill or 0,
                won = part.stats.won and true or false,
                disconnected = part.disconnected and true or false,
                notifySource = liveSource
            }
        end
    end

    local teamCount = tonumber(pack.teamCount)
    if not teamCount or teamCount < 1 then
        teamCount = WTBG.Count(teams)
    end

    return {
        matchId = pack.matchId,
        mode = pack.mode or (snap and snap.mode) or Config.MatchMode or 'SQUAD',
        startedAt = utcStamp(startedAt),
        finishedAt = utcStamp(finishedAt),
        durationSeconds = math.max(0, finishedAt - startedAt),
        winnerTeamId = snap and tonumber(snap.winnerTeamId) or nil,
        playerCount = WTBG.Count(pack.parts),
        teamCount = teamCount,
        players = players
    }
end

local function finalizeMatch(matchId)
    matchId = tonumber(matchId)
    if not matchId or finalizedMatches[matchId] then
        return
    end

    local pack = packs[matchId]
    if not pack or pack.finalized then
        finalizedMatches[matchId] = true
        return
    end

    finalizedMatches[matchId] = true
    pack.finalized = true

    local snap = getMatch(matchId)
    if snap and snap.mode then
        pack.mode = snap.mode
    end

    local brTop3 = (pack.mode or Config.MatchMode) == 'SQUAD'

    for source, part in pairs(pack.parts) do
        if not part.finalized then
            part.finalized = true
            local liveSource = tonumber(part.source or source)
            if stillOwnsSource(part, liveSource) then
                attachIdentity(part, liveSource)
            end

            local placement, won = resolvePlacement(pack, part, snap)
            part.stats.placement = placement
            part.stats.won = won and true or false
        end
    end

    local snapshot = buildHistorySnapshot(pack, snap)

    for i = 1, #snapshot.players do
        local row = snapshot.players[i]
        local top3 = 0
        if brTop3 and row.placement > 0 and row.placement <= 3 then
            top3 = 1
        end
        WTBG.Profiles.ApplyMatchResult(
            row.notifySource,
            row.license,
            row.profileId,
            {
                kills = row.kills,
                deaths = row.deaths,
                assists = row.assists,
                damage = row.damage,
                headshots = row.headshots,
                longestKill = row.longestKill,
                placement = row.placement,
                won = row.won,
                top3 = top3
            },
            row.name
        )
    end

    if WTBG.History and WTBG.History.Persist then
        WTBG.History.Persist(snapshot)
    end

    WTBG.Debug('match stats finalized', matchId)
    pack.contributors = {}
    packs[matchId] = nil

    SetTimeout(60000, function()
        finalizedMatches[matchId] = nil
    end)
end

AddEventHandler('wtbg:match:serverFinished', function(matchId)
    finalizeMatch(matchId)
end)

AddEventHandler('wtbg:core:playerDropped', function(source, state)
    source = tonumber(source)
    local matchId = state and tonumber(state.matchId)
    local pack = matchId and packs[matchId]
    if not pack or pack.finalized or not source then
        return
    end
    local part = pack.parts[source]
    if part then
        part.disconnected = true
    end
end)

AddEventHandler('wtbg:match:destroyed', function(matchId)
    matchId = tonumber(matchId)
    if not matchId then
        return
    end
    if finalizedMatches[matchId] then
        packs[matchId] = nil
        return
    end
    packs[matchId] = nil
end)

-- OneSync damage path. Headshot = hitComponent 20. Zone damage never arrives here.
AddEventHandler('weaponDamageEvent', function(sender, data)
    local attacker = tonumber(sender)
    if not attacker or type(data) ~= 'table' then
        return
    end

    local state = WTBG.Players.Get(attacker)
    local matchId = state and state.matchId
    local pack = matchId and packs[matchId]
    if not pack or pack.finalized then
        return
    end

    local netId = tonumber(data.hitGlobalId) or 0
    if netId <= 0 then
        return
    end

    local entity
    if type(NetworkGetEntityFromNetworkId) == 'function' then
        local ok, ent = pcall(NetworkGetEntityFromNetworkId, netId)
        if ok then
            entity = ent
        end
    end
    local victim = playerFromPed(entity)
    if not victim or victim == attacker then
        return
    end
    if not pack.parts[attacker] or not pack.parts[victim] then
        return
    end

    local amount = finitePositive(data.weaponDamage, MAX_HIT_DAMAGE)
    if not amount then
        return
    end

    local remain = remainingEffective(victim)
    if remain then
        amount = math.min(amount, math.max(1, remain))
    end

    local headshot = tonumber(data.hitComponent) == HEAD_COMPONENT
    addDamage(pack, attacker, victim, amount, headshot)
end)
