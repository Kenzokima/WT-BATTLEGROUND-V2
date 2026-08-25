fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'wtbg_ui'
author 'WhiteTiger'
version '0.1.0'
description 'WhiteTiger Battleground V2 - interface'

dependency 'wtbg_core'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js'
}

client_scripts {
    'client/ui.lua'
}
