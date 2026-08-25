fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'wtbg_combat'
author 'WhiteTiger'
version '0.1.0'
description 'WhiteTiger Battleground V2 - combat and loadout'

dependency 'wtbg_core'
dependency 'wtbg_match'

shared_scripts {
    '@wtbg_core/shared/config.lua',
    '@wtbg_core/shared/utils.lua',
    'shared/weapons.lua'
}

server_scripts {
    'server/combat.lua'
}

client_scripts {
    'client/combat.lua'
}
