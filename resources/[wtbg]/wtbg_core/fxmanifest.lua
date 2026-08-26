fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'wtbg_core'
author 'WhiteTiger'
version '0.1.0'
description 'WhiteTiger Battleground V2 - core session, lobby, and player profiles'

dependency 'oxmysql'

shared_scripts {
    'shared/config.lua',
    'shared/balance.lua',
    'shared/utils.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/players.lua',
    'server/profiles.lua',
    'server/match_history.lua',
    'server/stats.lua',
    'server/main.lua'
}

client_scripts {
    'client/appearance.lua',
    'client/main.lua'
}
