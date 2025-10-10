fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Kitotake Development'

description 'Système bancaire avancé avec cartes et ATM'
version '6.4.0'

shared_scripts {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/bank_utils.lua',
    'client/bank_animations.lua',
    'client/bank_notifications.lua',
    'client/bank_pnj.lua',
    'client/bank_atm_interaction.lua',
    'client/bank_ui.lua',
    'client/bank_menu.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/bank.lua',
    'server/bank_logs.lua',
    'server/bank_accounts.lua',
    
    'server/bank_admin.lua'
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style/*.css',
    'web/js/app.js'  -- NOUVEAU (remplace tous les autres JS)
}

dependencies {
    'es_extended',
    'oxmysql',
    'ox_lib',
    'ox_inventory'
}

-- 📤 EXPORTS SERVEUR
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