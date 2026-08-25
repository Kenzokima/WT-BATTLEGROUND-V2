fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'wtbg_core'
author 'WhiteTiger'
version '0.1.0'
description 'WhiteTiger Battleground V2 - core session and lobby'

shared_scripts {
    'shared/config.lua',
    'shared/utils.lua'
}

server_scripts {
    'server/players.lua',
    'server/main.lua'
}

client_scripts {
    'client/main.lua'
}
