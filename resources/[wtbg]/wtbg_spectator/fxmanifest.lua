fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'wtbg_spectator'
author 'WhiteTiger'
version '0.1.0'
description 'WhiteTiger Battleground V2 - teammate spectator'

dependency 'wtbg_core'
dependency 'wtbg_match'

shared_scripts {
    '@wtbg_core/shared/config.lua',
    '@wtbg_core/shared/balance.lua',
    '@wtbg_core/shared/utils.lua'
}

server_scripts {
    'server/spectator.lua'
}

client_scripts {
    'client/spectator.lua'
}
