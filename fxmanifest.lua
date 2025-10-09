fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Kitotake'
description 'Système bancaire avancé avec cartes et NUI'
version '5.1.0'

shared_scripts {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/bank.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/bank.lua'
}

-- Page principale (point d'entrée unique)
ui_page 'web/index.html'

-- Tous les fichiers web
files {
    'web/index.html',
    'web/create.html',
    'web/atm.html',
    'web/style/*.css',
    'web/js/*.js'
}

-- Exports serveur
server_exports {
    'AdminDeactivateCard',
    'AdminReprintPin',
    'AdminCreateCardForPlayer',
    'AdminGetAccountInfo',
    'AdminSetBalance'
}

dependencies {
    'es_extended',
    'oxmysql',
    'ox_inventory',
    'ox_lib'
}