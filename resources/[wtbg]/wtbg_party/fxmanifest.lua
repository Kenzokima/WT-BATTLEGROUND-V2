fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'wtbg_party'
author 'WhiteTiger'
version '0.2.0'
description 'WhiteTiger Battleground V2 - party and squad membership'

dependency 'wtbg_core'

shared_scripts {
    '@wtbg_core/shared/config.lua',
    '@wtbg_core/shared/balance.lua',
    '@wtbg_core/shared/utils.lua'
}

server_scripts {
    'server/party_manager.lua',
    'server/commands.lua'
}

client_scripts {
    'client/party.lua'
}
