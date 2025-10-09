

fx_version 'cerulean'
game 'gta5'

author 'Kitotake'
description 'Banque avec carte et NUI'
version '4.0.0'


shared_script 'config.lua'
client_scripts {
    'client/bank.lua'
}
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/bank.lua'
}

ui_page 'web/index.html'
files {
    'web/index.html',
    'web/style/*.css',
    'web/js/*.js'
}

export 'AdminDeactivateCard'
export 'AdminReprintPin'
export 'AdminCreateCardForPlayer'


--   local ok = exports['kt_banque']:AdminDeactivateCard(cardId)
--   local info = exports['kt_banque']:AdminCreateCardForPlayer("steam:1100001...", "carte_or", "Pseudo Joueur")
