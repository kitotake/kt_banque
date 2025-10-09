-- fxmanifest.lua
fx_version 'cerulean'
game 'gta5'

author 'kitotake'
description 'the banque'
version '1.0.0'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/script.js'
}


client_scripts {
    'client/bank.lua'
}

server_scripts {
    
    'server/bank.lua'
}


server_exports {
    'AdminDeactivateCard',
    'AdminReprintPin',
    'AdminCreateCardForPlayer'
  }
  

--   local ok = exports['kt_banque']:AdminDeactivateCard(cardId)
--   local info = exports['kt_banque']:AdminCreateCardForPlayer("steam:1100001...", "carte_or", "Pseudo Joueur")
