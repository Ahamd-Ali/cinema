fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fv_mdt'
author 'Five Dev'
description 'Fv_MDT - Mobile Data Terminal for CFW Core (full permission system)'
version '1.0.0'

shared_scripts {
    'config.lua',
    'shared/bridge.lua',
    'shared/permissions.lua',
}

client_scripts {
    'client/main.lua',
    'client/nui.lua',
}

server_scripts {
    'server/utils.lua',
    'server/db.lua',
    'server/main.lua',
    'server/callbacks.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
}

dependencies {
    -- adjust to match your CFW core resource name (see config.lua -> Config.Core)
    'oxmysql',
}
