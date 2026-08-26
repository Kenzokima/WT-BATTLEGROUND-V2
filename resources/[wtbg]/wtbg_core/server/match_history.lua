WTBG.History = {}

local HISTORY_DEFAULT = 10
local HISTORY_MAX = 20
local REQUEST_COOLDOWN_MS = 2000
local lastRequestAt = {}
local lastRows = {}

local INSERT_MATCH = [[
INSERT INTO wtbg_matches
    (match_id, mode, player_count, team_count, winner_team_id, duration_seconds, started_at, finished_at)
VALUES (?, ?, ?, ?, ?, ?, ?, ?)
]]

local INSERT_PLAYER = [[
INSERT INTO wtbg_match_players
    (match_db_id, match_id, profile_id, license, name, team_id, placement,
     kills, deaths, assists, damage, headshots, longest_kill, won, disconnected)
SELECT id, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
FROM wtbg_matches
WHERE match_id = ?
]]

local HISTORY_SQL = [[
SELECT
    m.match_id,
    m.mode,
    m.duration_seconds,
    m.finished_at,
    mp.team_id,
    mp.placement,
    mp.kills,
    mp.deaths,
    mp.assists,
    mp.damage,
    mp.headshots,
    mp.longest_kill,
    mp.won,
    mp.disconnected
FROM wtbg_match_players mp
JOIN wtbg_matches m ON m.id = mp.match_db_id
WHERE mp.profile_id = ?
ORDER BY m.finished_at DESC, m.id DESC
LIMIT %d
]]

local function log(...)
    print('[WTBG]', ...)
end

local function clampUInt(n)
    n = tonumber(n)
    if type(n) ~= 'number' or n ~= n or n < 0 or n == math.huge then
        return 0
    end
    return math.floor(n)
end

local function clampDist(n)
    n = tonumber(n)
    if type(n) ~= 'number' or n ~= n or n < 0 or n == math.huge then
        return 0
    end
    return math.floor(n * 100 + 0.5) / 100
end

local function sanitizeName(name)
    if type(name) ~= 'string' then
        name = 'Player'
    end
    name = name:gsub('%c', ''):sub(1, 64)
    if name == '' then
        name = 'Player'
    end
    return name
end

local function clampLimit(limit)
    limit = math.floor(tonumber(limit) or HISTORY_DEFAULT)
    if limit < 1 then
        return HISTORY_DEFAULT
    end
    if limit > HISTORY_MAX then
        return HISTORY_MAX
    end
    return limit
end

local function utcStamp(unix)
    unix = tonumber(unix) or os.time()
    return os.date('!%Y-%m-%d %H:%M:%S', unix)
end

local function sanitizeRow(row)
    if type(row) ~= 'table' then
        return nil
    end
    return {
        matchId = clampUInt(row.match_id),
        mode = type(row.mode) == 'string' and row.mode or 'SQUAD',
        placement = clampUInt(row.placement),
        kills = clampUInt(row.kills),
        deaths = clampUInt(row.deaths),
        assists = clampUInt(row.assists),
        damage = clampUInt(row.damage),
        headshots = clampUInt(row.headshots),
        longestKill = clampDist(row.longest_kill),
        won = tonumber(row.won) == 1 or row.won == true,
        disconnected = tonumber(row.disconnected) == 1 or row.disconnected == true,
        duration = clampUInt(row.duration_seconds),
        finishedAt = type(row.finished_at) == 'string' and row.finished_at or tostring(row.finished_at or ''),
        teamId = tonumber(row.team_id)
    }
end

local function notifySources(snapshot)
    if type(snapshot) ~= 'table' or type(snapshot.players) ~= 'table' then
        return
    end
    for i = 1, #snapshot.players do
        local src = tonumber(snapshot.players[i].notifySource)
        if src then
            lastRows[src] = nil
            TriggerClientEvent('wtbg:history:invalidate', src)
        end
    end
end

local function persistAttempt(snapshot, attempt)
    if not WTBG.DB.Available() or type(MySQL.transaction) ~= 'function' then
        log('match history save failed matchId=' .. tostring(snapshot.matchId))
        return
    end

    local queries = {
        {
            query = INSERT_MATCH,
            values = {
                snapshot.matchId,
                snapshot.mode,
                snapshot.playerCount,
                snapshot.teamCount,
                snapshot.winnerTeamId,
                snapshot.durationSeconds,
                snapshot.startedAt,
                snapshot.finishedAt
            }
        }
    }

    for i = 1, #snapshot.players do
        local p = snapshot.players[i]
        queries[#queries + 1] = {
            query = INSERT_PLAYER,
            values = {
                snapshot.matchId,
                p.profileId,
                p.license,
                p.name,
                p.teamId,
                p.placement,
                p.kills,
                p.deaths,
                p.assists,
                p.damage,
                p.headshots,
                p.longestKill,
                p.won and 1 or 0,
                p.disconnected and 1 or 0,
                snapshot.matchId
            }
        }
    end

    MySQL.transaction(queries, function(success)
        if success then
            WTBG.Debug('history persisted match=' .. snapshot.matchId, 'players=' .. #snapshot.players)
            notifySources(snapshot)
            return
        end

        MySQL.single('SELECT id FROM wtbg_matches WHERE match_id = ? LIMIT 1', { snapshot.matchId }, function(row)
            if row and row.id then
                WTBG.Debug('history already exists match=' .. snapshot.matchId)
                return
            end
            if attempt < 2 then
                SetTimeout(750, function()
                    persistAttempt(snapshot, attempt + 1)
                end)
                return
            end
            log('match history save failed matchId=' .. tostring(snapshot.matchId))
        end)
    end)
end

function WTBG.History.Persist(snapshot)
    if type(snapshot) ~= 'table' then
        return
    end
    snapshot.matchId = tonumber(snapshot.matchId)
    if not snapshot.matchId then
        return
    end
    if type(snapshot.players) ~= 'table' or #snapshot.players < 1 then
        return
    end

    snapshot.mode = type(snapshot.mode) == 'string' and snapshot.mode:sub(1, 24) or 'SQUAD'
    snapshot.playerCount = clampUInt(snapshot.playerCount)
    snapshot.teamCount = clampUInt(snapshot.teamCount)
    snapshot.winnerTeamId = tonumber(snapshot.winnerTeamId)
    snapshot.durationSeconds = clampUInt(snapshot.durationSeconds)
    snapshot.startedAt = type(snapshot.startedAt) == 'string' and snapshot.startedAt or utcStamp(os.time())
    snapshot.finishedAt = type(snapshot.finishedAt) == 'string' and snapshot.finishedAt or utcStamp(os.time())

    local players = {}
    for i = 1, #snapshot.players do
        local p = snapshot.players[i]
        p.profileId = tonumber(p.profileId)
        p.license = type(p.license) == 'string' and p.license:sub(1, 64) or nil
        if p.profileId and p.license then
            p.name = sanitizeName(p.name)
            p.teamId = tonumber(p.teamId)
            p.placement = clampUInt(p.placement)
            p.kills = clampUInt(p.kills)
            p.deaths = clampUInt(p.deaths)
            p.assists = clampUInt(p.assists)
            p.damage = clampUInt(p.damage)
            p.headshots = clampUInt(p.headshots)
            p.longestKill = clampDist(p.longestKill)
            p.won = p.won and true or false
            p.disconnected = p.disconnected and true or false
            players[#players + 1] = p
        end
    end
    snapshot.players = players
    if #players < 1 then
        return
    end

    persistAttempt(snapshot, 0)
end

function WTBG.History.GetRecent(source, limit, cb)
    source = tonumber(source)
    if type(cb) ~= 'function' then
        return
    end
    if not source then
        cb(nil, 'invalid')
        return
    end

    local profile = WTBG.Profiles.GetCached(source)
    if not profile or not profile.persist or not profile.id then
        cb(nil, 'no_profile')
        return
    end

    if not WTBG.DB.Available() then
        cb(nil, 'unavailable')
        return
    end

    limit = clampLimit(limit)
    local now = GetGameTimer()
    local cached = lastRows[source]
    if cached and lastRequestAt[source] and (now - lastRequestAt[source]) < REQUEST_COOLDOWN_MS then
        cb(cached, nil)
        return
    end
    lastRequestAt[source] = now

    local sql = HISTORY_SQL:format(limit)
    MySQL.query(sql, { profile.id }, function(rows)
        if type(rows) ~= 'table' then
            cb(nil, 'unavailable')
            return
        end
        local list = {}
        for i = 1, #rows do
            local item = sanitizeRow(rows[i])
            if item then
                list[#list + 1] = item
            end
        end
        lastRows[source] = list
        WTBG.Debug('history query source=' .. source, 'count=' .. #list)
        cb(list, nil)
    end)
end

AddEventHandler('wtbg:core:playerDropped', function(source)
    source = tonumber(source)
    if source then
        lastRows[source] = nil
        lastRequestAt[source] = nil
    end
end)

exports('GetRecentMatchHistory', function(source, limit, cb)
    WTBG.History.GetRecent(tonumber(source), limit, cb)
end)

RegisterNetEvent('wtbg:history:request', function()
    local source = tonumber(source)
    if not source then
        return
    end
    WTBG.History.GetRecent(source, HISTORY_DEFAULT, function(rows, err)
        TriggerClientEvent('wtbg:history:self', source, {
            rows = rows,
            error = err
        })
    end)
end)
