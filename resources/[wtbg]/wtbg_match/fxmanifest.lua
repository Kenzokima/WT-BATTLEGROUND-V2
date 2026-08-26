fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'wtbg_match'
author 'WhiteTiger'
version '0.1.0'
description 'WhiteTiger Battleground V2 - match manager'

dependency 'wtbg_core'
dependency 'wtbg_party'

shared_scripts {
    '@wtbg_core/shared/config.lua',
    '@wtbg_core/shared/balance.lua',
    '@wtbg_core/shared/utils.lua'
}

server_scripts {
    'server/match_manager.lua',
    'server/commands.lua'
}

client_scripts {
    'client/match.lua'
}
