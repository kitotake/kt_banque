fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Kitotake Development'
description 'Système bancaire avancé avec cartes et ATM '
version '7.0.0'

shared_scripts {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua',
   
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/test.lua'
}


ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style/*.css',
    'web/js/app.js'
}

dependencies {
    'es_extended',
    'oxmysql',
    'ox_lib',
    'ox_inventory'
}


server_exports {
    'GetAccountBalance',
    'AddMoney',
    'RemoveMoney'
}