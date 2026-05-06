fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Kitotake Development'
description 'Système bancaire nui complet avec gestion des comptes, cartes bancaires, dépôts, retraits et transferts d\'argent.'
version '7.4.0'

shared_scripts {
    '@kt_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua',
   
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}


ui_page 'web/dist/index.html'

files {
    'web/dist/**/*.*'
}

dependencies {
    'oxmysql',
    'kt_lib',
    'kt_inventory'
}


server_exports {
    'GetAccountBalance',
    'AddMoney',
    'RemoveMoney'
}