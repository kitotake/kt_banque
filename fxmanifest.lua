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
    -- SUPPRIMÉ : 'client/card_recovery.lua' (doublon — causait double-registration d'events)
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/modules/utils.lua',
    'server/modules/db.lua',
    'server/modules/card_manager.lua',  -- NOUVEAU : CardManager avant bank
    'server/modules/bank.lua',          -- CORRIGÉ : vraie logique métier
    'server/modules/card_recovery.lua', -- CORRIGÉ : délègue à CardManager
    'server/admin.lua',
    'server/main.lua'
    -- SUPPRIMÉ : 'server/card_recovery.lua' racine (doublon avec server/modules/card_recovery.lua)
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
