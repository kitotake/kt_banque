-- ==================== KT BANQUE v7.5.0 — SERVER/MAIN ====================
-- Point d'entrée serveur.
-- Les modules sont déjà chargés par fxmanifest dans l'ordre :
--   utils → db → bank → card_recovery → admin → main

-- ──────────────────────────────────────────
-- ÉVÉNEMENTS RÉSEAU
-- ──────────────────────────────────────────

RegisterNetEvent('bank:server:requestOpen',   function()                        Bank.Open(source)                         end)
RegisterNetEvent('bank:server:createAccount', function(pin)                     Bank.Create(source, pin)                  end)
RegisterNetEvent('bank:server:deposit',       function(amount, pinHash)         Bank.Deposit(source, amount, pinHash)     end)
RegisterNetEvent('bank:server:withdraw',      function(amount, pinHash)         Bank.Withdraw(source, amount, pinHash)    end)
RegisterNetEvent('bank:server:transfer',      function(amount, target, pinHash) Bank.Transfer(source, amount, target, pinHash) end)
RegisterNetEvent('bank:server:upgradeCard',   function(cardType)                Bank.UpgradeCard(source, cardType)        end)

-- ──────────────────────────────────────────
-- DEBUG
-- ──────────────────────────────────────────

if Config.Debug then
    RegisterCommand("ktbank_open", function(src)
        Bank.Open(src)
    end, true) -- true = ACE permission requise
end

print('^2[KT Banque]^7 Serveur principal chargé v7.5.0')
