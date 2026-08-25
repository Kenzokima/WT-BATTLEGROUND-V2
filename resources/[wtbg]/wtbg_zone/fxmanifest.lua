fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'wtbg_zone'
author 'WhiteTiger'
version '0.1.0'
description 'WhiteTiger Battleground V2 - shrinking zone'

dependency 'wtbg_core'
dependency 'wtbg_match'
dependency 'wtbg_combat'

shared_scripts {
    '@wtbg_core/shared/config.lua',
    '@wtbg_core/shared/utils.lua',
    'shared/config.lua'
}

server_scripts {
    'server/zone_manager.lua',
    'server/main.lua'
}

client_scripts {
    'client/zone.lua'
}
