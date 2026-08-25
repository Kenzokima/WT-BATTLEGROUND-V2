fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'wtbg_loot'
author 'WhiteTiger'
version '0.1.0'
description 'WhiteTiger Battleground V2 - BR inventory and world loot'

dependency 'wtbg_core'
dependency 'wtbg_match'

shared_scripts {
    '@wtbg_core/shared/config.lua',
    '@wtbg_core/shared/utils.lua',
    'shared/config.lua',
    'shared/items.lua'
}

server_scripts {
    'server/inventory.lua',
    'server/world.lua',
    'server/main.lua'
}

client_scripts {
    'client/loot.lua'
}
