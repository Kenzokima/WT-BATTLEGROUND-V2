fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'wtbg_drop'
author 'WhiteTiger'
version '0.1.0'
description 'WhiteTiger Battleground V2 - plane drop and parachute'

dependency 'wtbg_core'
dependency 'wtbg_match'

shared_scripts {
    '@wtbg_core/shared/config.lua',
    '@wtbg_core/shared/balance.lua',
    '@wtbg_core/shared/utils.lua',
    'shared/config.lua'
}

server_scripts {
    'server/drop.lua'
}

client_scripts {
    'client/drop.lua'
}
