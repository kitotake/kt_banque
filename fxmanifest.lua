fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Kitotake Development'
description 'Système bancaire NUI complet — cartes avec métadonnées, blocage compte.'
version '7.5.0'

shared_scripts {
    '@kt_lib/init.lua',
    'shared/config/config.lua',
    'shared/locales/fr.lua'
}

client_scripts {
    'client/modules/animation.lua',
    'client/modules/ui.lua',
    'client/modules/atm.lua',
    'client/modules/npc.lua',
    'client/modules/card_recovery.lua',
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/modules/utils.lua',
    'server/modules/db.lua',
    'server/modules/card_manager.lua',  -- ← NOUVEAU : avant bank
    'server/modules/bank.lua',
    'server/modules/card_recovery.lua',
    'server/admin.lua',
    'server/main.lua'
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
    'GetAccountInfo',
    'GetAllAccountsTotal',
    'AddMoney',
    'RemoveMoney',
    'Transfer',
    'SetAccountStatus',
    'BlockCard',
    'ValidateAccountAccess'
}