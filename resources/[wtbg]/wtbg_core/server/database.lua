WTBG.DB = {
    ready = false
}

local schemaTried = false
local SCHEMA_FILES = {
    'sql/001_players.sql',
    'sql/002_match_history.sql'
}

local function log(...)
    print('[WTBG]', ...)
end

function WTBG.DB.Available()
    return WTBG.DB.ready == true
end

local function splitStatements(sql)
    local list = {}
    for chunk in string.gmatch(sql .. ';', '(.-);') do
        local stmt = chunk:gsub('^%s+', ''):gsub('%s+$', '')
        if stmt ~= '' then
            list[#list + 1] = stmt
        end
    end
    return list
end

local function runStatements(stmts, index, done)
    if index > #stmts then
        done(true)
        return
    end
    MySQL.query(stmts[index], {}, function()
        runStatements(stmts, index + 1, done)
    end)
end

local function applyFile(path, done)
    local sql = LoadResourceFile(GetCurrentResourceName(), path)
    if type(sql) ~= 'string' or sql == '' then
        log('schema file missing', path)
        done(false)
        return
    end
    runStatements(splitStatements(sql), 1, done)
end

local function applySchema()
    if schemaTried then
        return
    end
    schemaTried = true

    local i = 0
    local function nextFile()
        i = i + 1
        if i > #SCHEMA_FILES then
            WTBG.DB.ready = true
            WTBG.Debug('player schema ready')
            TriggerEvent('wtbg:core:dbReady')
            return
        end
        applyFile(SCHEMA_FILES[i], function(ok)
            if not ok then
                WTBG.DB.ready = false
                return
            end
            nextFile()
        end)
    end

    nextFile()
end

CreateThread(function()
    local waits = 0
    while GetResourceState('oxmysql') ~= 'started' and waits < 100 do
        Wait(100)
        waits = waits + 1
    end

    if GetResourceState('oxmysql') ~= 'started' then
        log('oxmysql not started — profile persistence disabled')
        return
    end

    if type(MySQL) ~= 'table' or type(MySQL.ready) ~= 'function' then
        log('oxmysql MySQL API missing — profile persistence disabled')
        return
    end

    MySQL.ready(function()
        applySchema()
    end)
end)
