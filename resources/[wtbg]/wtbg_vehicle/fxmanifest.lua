fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'wtbg_vehicle'
author 'WhiteTiger'
version '0.1.0'
description 'WhiteTiger Battleground V2 - match Draugur vehicles'

dependency 'wtbg_core'
dependency 'wtbg_match'

shared_scripts {
    '@wtbg_core/shared/config.lua',
    '@wtbg_core/shared/utils.lua',
    'shared/config.lua'
}

server_scripts {
    'server/vehicle_manager.lua',
    'server/main.lua'
}

client_scripts {
    'client/vehicle.lua'
}
