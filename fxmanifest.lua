fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'Kakarot - IRP Edit'
description 'Player inventory system providing a variety of features for storing and managing items'
version '2.0.4'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'locales/en.lua',
    'locales/*.lua',
    'config/*.lua',
}

client_scripts {
    'client/main.lua',
    'client/drops.lua',
    'client/vehicles.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/performance.lua',
    'server/main.lua',
    'server/functions.lua',
    'server/backpacks.lua',
    'server/commands.lua',
    'server/markedbills.lua',
    'server/maintenance.lua',
}
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/main.css',
    'html/app.js',
    'html/images/*.png',
}

dependency 'qb-weapons'

exports {
    'HasItem'
}

server_exports {
    'HasItem'
}
