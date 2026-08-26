fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'wtbg_ui'
author 'WhiteTiger'
version '0.1.0'
description 'WhiteTiger Battleground V2 - interface'

dependency 'wtbg_core'

shared_scripts {
    '@wtbg_core/shared/config.lua',
    '@wtbg_core/shared/balance.lua',
    '@wtbg_core/shared/utils.lua'
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js'
}

client_scripts {
    'client/ui.lua',
    'client/vitals.lua'
}
