WTBG.Profiles = {}

local bySource = {}
local byLicense = {}
local SAVE_INTERVAL_MS = 5 * 60 * 1000

local UPDATE_SQL = [[
UPDATE wtbg_players
SET
    name = ?,
    matches = ?,
    wins = ?,
    kills = ?,
    deaths = ?,
    assists = ?,
    damage = ?,
    headshots = ?,
    top3 = ?,
    total_placement = ?,
    longest_kill = ?,
    xp = ?,
    level = ?,
    last_seen_at = CURRENT_TIMESTAMP
WHERE id = ?
]]

local INCREMENT_SQL = [[
UPDATE wtbg_players
SET
    name = ?,
    matches = matches + ?,
    wins = wins + ?,
    kills = kills + ?,
    deaths = deaths + ?,
    assists = assists + ?,
    damage = damage + ?,
    headshots = headshots + ?,
    top3 = top3 + ?,
    total_placement = total_placement + ?,
    longest_kill = GREATEST(longest_kill, ?),
    last_seen_at = CURRENT_TIMESTAMP
WHERE id = ?
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

function WTBG.GetPrimaryIdentifier(source)
    source = tonumber(source)
    if not source then
        return nil
    end

    local ids = GetPlayerIdentifiers(source)
    if type(ids) ~= 'table' then
        return nil
    end

    local license, license2
    for i = 1, #ids do
        local id = ids[i]
        if type(id) == 'string' then
            if id:sub(1, 9) == 'license2:' then
                license2 = id
            elseif id:sub(1, 8) == 'license:' then
                license = id
            end
        end
    end

    return license or license2
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

local function roundN(n, places)
    n = tonumber(n) or 0
    if n ~= n or n == math.huge or n == -math.huge then
        return 0
    end
    local m = 10 ^ (places or 0)
    return math.floor(n * m + 0.5) / m
end

local function derived(row)
    local matches = clampUInt(row.matches)
    local wins = clampUInt(row.wins)
    local kills = clampUInt(row.kills)
    local deaths = clampUInt(row.deaths)
    local kd = deaths > 0 and (kills / deaths) or kills
    local winRate = matches > 0 and ((wins / matches) * 100) or 0
    local avgPlacement = matches > 0 and (clampUInt(row.total_placement) / matches) or 0

    return {
        name = row.name,
        level = clampUInt(row.level),
        xp = clampUInt(row.xp),
        matches = matches,
        wins = wins,
        kills = kills,
        deaths = deaths,
        assists = clampUInt(row.assists),
        damage = clampUInt(row.damage),
        headshots = clampUInt(row.headshots),
        top3 = clampUInt(row.top3),
        longestKill = clampDist(row.longest_kill),
        kd = roundN(kd, 2),
        winRate = roundN(winRate, 1),
        avgPlacement = roundN(avgPlacement, 1),
        persist = row.persist == true,
        status = row.status
    }
end

local function copyProfile(row)
    if not row then
        return nil
    end

    return {
        id = row.id,
        license = row.license,
        name = row.name,
        level = clampUInt(row.level),
        xp = clampUInt(row.xp),
        matches = clampUInt(row.matches),
        wins = clampUInt(row.wins),
        kills = clampUInt(row.kills),
        deaths = clampUInt(row.deaths),
        assists = clampUInt(row.assists),
        damage = clampUInt(row.damage),
        headshots = clampUInt(row.headshots),
        top3 = clampUInt(row.top3),
        total_placement = clampUInt(row.total_placement),
        longest_kill = clampDist(row.longest_kill),
        persist = row.persist == true,
        status = row.status
    }
end

local function ephemeral(source, license, status)
    local name = sanitizeName(WTBG.PlayerName(source))
    return {
        source = source,
        id = nil,
        license = license,
        name = name,
        level = 1,
        xp = 0,
        matches = 0,
        wins = 0,
        kills = 0,
        deaths = 0,
        assists = 0,
        damage = 0,
        headshots = 0,
        top3 = 0,
        total_placement = 0,
        longest_kill = 0,
        persist = false,
        status = status or 'failed',
        dirty = false,
        saving = false,
        loaded = status == 'loaded'
    }
end

local function fromRow(source, row, persist)
    return {
        source = source,
        id = tonumber(row.id),
        license = row.license,
        name = sanitizeName(row.name),
        level = clampUInt(row.level),
        xp = clampUInt(row.xp),
        matches = clampUInt(row.matches),
        wins = clampUInt(row.wins),
        kills = clampUInt(row.kills),
        deaths = clampUInt(row.deaths),
        assists = clampUInt(row.assists),
        damage = clampUInt(row.damage),
        headshots = clampUInt(row.headshots),
        top3 = clampUInt(row.top3),
        total_placement = clampUInt(row.total_placement),
        longest_kill = clampDist(row.longest_kill),
        persist = persist == true,
        status = 'loaded',
        dirty = false,
        saving = false,
        loaded = true
    }
end

local function cache(source, profile)
    bySource[source] = profile
    if profile.persist and profile.license then
        byLicense[profile.license] = source
    end
end

local function pushSelf(source)
    local profile = bySource[source]
    if not profile then
        return
    end
    TriggerClientEvent('wtbg:profile:self', source, derived(profile))
end

local function saveAbsolute(profile, cb)
    if not profile or not profile.persist or not profile.id or not WTBG.DB.Available() then
        if cb then
            cb(false)
        end
        return
    end

    MySQL.update(UPDATE_SQL, {
        sanitizeName(profile.name),
        clampUInt(profile.matches),
        clampUInt(profile.wins),
        clampUInt(profile.kills),
        clampUInt(profile.deaths),
        clampUInt(profile.assists),
        clampUInt(profile.damage),
        clampUInt(profile.headshots),
        clampUInt(profile.top3),
        clampUInt(profile.total_placement),
        clampDist(profile.longest_kill),
        clampUInt(profile.xp),
        math.max(1, clampUInt(profile.level)),
        profile.id
    }, function(affected)
        if cb then
            cb(affected ~= false)
        end
    end)
end

local function enqueueSave(profile)
    if not profile or not profile.persist or not profile.id then
        return
    end
    if not WTBG.DB.Available() then
        profile.dirty = true
        return
    end
    if profile.saving then
        profile.dirty = true
        return
    end

    profile.saving = true
    profile.dirty = false
    saveAbsolute(profile, function(ok)
        profile.saving = false
        if not ok then
            profile.dirty = true
            log('profile save failed', profile.license)
            return
        end
        if profile.dirty then
            enqueueSave(profile)
        end
    end)
end

local function placeLoaded(source, row, created)
    local profile = fromRow(source, row, true)
    local currentName = sanitizeName(WTBG.PlayerName(source))
    if profile.name ~= currentName then
        profile.name = currentName
        profile.dirty = true
    end
    cache(source, profile)
    if created then
        WTBG.Debug('profile created', source, profile.license)
    else
        WTBG.Debug('profile loaded', source, profile.license)
    end
    enqueueSave(profile)
    pushSelf(source)
end

local function insertProfile(source, license, name)
    MySQL.insert('INSERT INTO wtbg_players (license, name) VALUES (?, ?)', { license, name }, function(id)
        local current = bySource[source]
        if not current or current.status ~= 'loading' then
            return
        end

        local function accept(row, created)
            if type(row) ~= 'table' or not row.id then
                log('profile create failed', license)
                cache(source, ephemeral(source, license, 'failed'))
                return
            end
            placeLoaded(source, row, created)
        end

        if id then
            MySQL.single('SELECT * FROM wtbg_players WHERE id = ? LIMIT 1', { id }, function(row)
                current = bySource[source]
                if not current or current.status ~= 'loading' then
                    return
                end
                accept(row, true)
            end)
            return
        end

        MySQL.single('SELECT * FROM wtbg_players WHERE license = ? LIMIT 1', { license }, function(row)
            current = bySource[source]
            if not current or current.status ~= 'loading' then
                return
            end
            if type(row) == 'table' and row.id then
                accept(row, false)
                return
            end
            log('profile create failed', license)
            cache(source, ephemeral(source, license, 'failed'))
        end)
    end)
end

local function loadFromDb(source, license)
    local name = sanitizeName(WTBG.PlayerName(source))
    MySQL.single('SELECT * FROM wtbg_players WHERE license = ? LIMIT 1', { license }, function(row)
        local current = bySource[source]
        if not current or current.status ~= 'loading' then
            return
        end
        if type(row) == 'table' and row.id then
            placeLoaded(source, row, false)
            return
        end
        insertProfile(source, license, name)
    end)
end

function WTBG.Profiles.BeginLoad(source)
    source = tonumber(source)
    if not source then
        return
    end

    local existing = bySource[source]
    if existing and (existing.status == 'loading' or existing.status == 'loaded') then
        return
    end

    local license = WTBG.GetPrimaryIdentifier(source)
    if not license then
        log('no canonical license for', source, '- ephemeral profile')
        cache(source, ephemeral(source, nil, 'failed'))
        return
    end

    if #license > 64 then
        log('license too long for', source)
        cache(source, ephemeral(source, nil, 'failed'))
        return
    end

    local owner = byLicense[license]
    if owner and owner ~= source then
        log('duplicate license session', license, 'owner', owner, 'rejected', source)
        cache(source, ephemeral(source, license, 'loaded'))
        WTBG.Players.Notify(source, 'Profile already active on another session.')
        return
    end

    local placeholder = ephemeral(source, license, 'loading')
    placeholder.persist = false
    placeholder.loaded = false
    byLicense[license] = source
    cache(source, placeholder)

    SetTimeout(15000, function()
        local profile = bySource[source]
        if profile and profile.status == 'loading' then
            log('profile load timed out', source)
            cache(source, ephemeral(source, license, 'failed'))
        end
    end)

    if not WTBG.DB.Available() then
        log('DB unavailable — ephemeral profile for', source)
        cache(source, ephemeral(source, license, 'failed'))
        return
    end

    loadFromDb(source, license)
end

function WTBG.Profiles.OwnsLicense(source, license)
    source = tonumber(source)
    return source and license and byLicense[license] == source
end

function WTBG.Profiles.GetCached(source)
    return bySource[tonumber(source)]
end

function WTBG.Profiles.Get(source)
    return copyProfile(bySource[tonumber(source)])
end

function WTBG.Profiles.GetStats(source)
    local profile = bySource[tonumber(source)]
    if not profile then
        return nil
    end
    return derived(profile)
end

function WTBG.Profiles.IsLoaded(source)
    local profile = bySource[tonumber(source)]
    return profile ~= nil and profile.status == 'loaded'
end

function WTBG.Profiles.ApplyMatchResult(source, license, profileId, deltas, name)
    source = tonumber(source)
    profileId = tonumber(profileId)
    deltas = type(deltas) == 'table' and deltas or {}

    local addMatches = 1
    local addWins = deltas.won and 1 or 0
    local addKills = clampUInt(deltas.kills)
    local addDeaths = clampUInt(deltas.deaths)
    local addAssists = clampUInt(deltas.assists)
    local addDamage = clampUInt(deltas.damage)
    local addHeadshots = clampUInt(deltas.headshots)
    local addTop3 = clampUInt(deltas.top3)
    local addPlacement = clampUInt(deltas.placement)
    local longest = clampDist(deltas.longestKill)
    name = sanitizeName(name or (source and WTBG.PlayerName(source)) or 'Player')

    local profile = source and bySource[source] or nil
    if profile and profile.persist and profile.id and profile.license == license then
        profile.name = name
        profile.matches = clampUInt(profile.matches) + addMatches
        profile.wins = clampUInt(profile.wins) + addWins
        profile.kills = clampUInt(profile.kills) + addKills
        profile.deaths = clampUInt(profile.deaths) + addDeaths
        profile.assists = clampUInt(profile.assists) + addAssists
        profile.damage = clampUInt(profile.damage) + addDamage
        profile.headshots = clampUInt(profile.headshots) + addHeadshots
        profile.top3 = clampUInt(profile.top3) + addTop3
        profile.total_placement = clampUInt(profile.total_placement) + addPlacement
        profile.longest_kill = math.max(clampDist(profile.longest_kill), longest)
        profile.dirty = true
        enqueueSave(profile)
        pushSelf(source)
        return
    end

    if not WTBG.DB.Available() then
        return
    end

    if not profileId then
        WTBG.Debug('skip match persist — no profile id', license)
        return
    end

    MySQL.update(INCREMENT_SQL, {
        name,
        addMatches,
        addWins,
        addKills,
        addDeaths,
        addAssists,
        addDamage,
        addHeadshots,
        addTop3,
        addPlacement,
        longest,
        profileId
    }, function(affected)
        if affected == false then
            log('disconnected profile save failed', license or profileId)
        end
    end)
end

function WTBG.Profiles.HandleDrop(source)
    source = tonumber(source)
    local profile = source and bySource[source]
    if not profile then
        return
    end

    if profile.persist and profile.dirty then
        local snapshot = copyProfile(profile)
        snapshot.persist = true
        snapshot.id = profile.id
        snapshot.saving = false
        snapshot.dirty = false
        saveAbsolute(snapshot)
    end

    if profile.license and byLicense[profile.license] == source then
        byLicense[profile.license] = nil
    end
    bySource[source] = nil
end

function WTBG.Profiles.FlushAll()
    for _, profile in pairs(bySource) do
        if profile.persist and profile.dirty and profile.id then
            saveAbsolute(profile)
        end
    end
end

AddEventHandler('wtbg:core:dbReady', function()
    for _, id in ipairs(GetPlayers()) do
        local source = tonumber(id)
        local profile = bySource[source]
        if source and (not profile or profile.status == 'failed' or profile.status == 'loading') then
            if profile then
                bySource[source] = nil
            end
            WTBG.Profiles.BeginLoad(source)
        end
    end
end)

AddEventHandler('wtbg:core:playerDropped', function(source)
    WTBG.Profiles.HandleDrop(source)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    WTBG.Profiles.FlushAll()
end)

CreateThread(function()
    while true do
        Wait(SAVE_INTERVAL_MS)
        for _, profile in pairs(bySource) do
            if profile.persist and profile.dirty then
                enqueueSave(profile)
            end
        end
    end
end)

exports('GetPrimaryIdentifier', function(source)
    return WTBG.GetPrimaryIdentifier(tonumber(source))
end)

exports('GetProfile', function(source)
    return WTBG.Profiles.Get(tonumber(source))
end)

exports('GetStats', function(source)
    return WTBG.Profiles.GetStats(tonumber(source))
end)

exports('IsProfileLoaded', function(source)
    return WTBG.Profiles.IsLoaded(tonumber(source))
end)

RegisterNetEvent('wtbg:profile:request', function()
    local source = tonumber(source)
    if not source then
        return
    end
    local stats = WTBG.Profiles.GetStats(source)
    TriggerClientEvent('wtbg:profile:self', source, stats)
end)
