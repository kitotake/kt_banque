-- ==================== KT BANQUE v7.5.0 — SERVER/MAIN ====================
-- Point d'entrée serveur.
-- Les modules sont déjà chargés par fxmanifest dans l'ordre :
--   utils → db → bank → card_recovery → admin → main
--
-- CORRECTIONS :
--   FIX-1 : Guard source valide avant de passer aux handlers Bank.*
--   FIX-2 : Vérification que le joueur est connecté avant traitement.
--   FIX-3 : Commande debug protégée par Config.Debug ET ACE.

-- ──────────────────────────────────────────
-- HELPER : vérifie que le joueur est toujours connecté
-- ──────────────────────────────────────────
local function isConnected(src)
    return GetPlayerEndpoint(tostring(src)) ~= nil
end

-- ──────────────────────────────────────────
-- ÉVÉNEMENTS RÉSEAU
-- FIX-1 : capture de source au début de chaque handler
-- ──────────────────────────────────────────

RegisterNetEvent('bank:server:requestOpen', function()
    local src = source
    if not isConnected(src) then return end
    Bank.Open(src)
end)

RegisterNetEvent('bank:server:createAccount', function(pin)
    local src = source
    if not isConnected(src) then return end
    Bank.Create(src, pin)
end)

RegisterNetEvent('bank:server:deposit', function(amount, pinHash)
    local src = source
    if not isConnected(src) then return end
    -- FIX-2 : validation basique avant d'appeler la logique métier
    amount = tonumber(amount)
    if not amount or amount <= 0 then return end
    Bank.Deposit(src, amount, pinHash)
end)

RegisterNetEvent('bank:server:withdraw', function(amount, pinHash)
    local src = source
    if not isConnected(src) then return end
    amount = tonumber(amount)
    if not amount or amount <= 0 then return end
    Bank.Withdraw(src, amount, pinHash)
end)

RegisterNetEvent('bank:server:transfer', function(amount, target, pinHash)
    local src = source
    if not isConnected(src) then return end
    amount = tonumber(amount)
    if not amount or amount <= 0 then return end
    if not target or tostring(target) == "" then return end
    Bank.Transfer(src, amount, tostring(target), pinHash)
end)

RegisterNetEvent('bank:server:upgradeCard', function(cardType)
    local src = source
    if not isConnected(src) then return end
    if not cardType or cardType == "" then return end
    Bank.UpgradeCard(src, cardType)
end)

-- ──────────────────────────────────────────
-- DEBUG
-- FIX-3 : double protection — Config.Debug ET ACE admin
-- ──────────────────────────────────────────

if Config.Debug then
    RegisterCommand("ktbank_open", function(src)
        if src ~= 0 and not IsPlayerAceAllowed(src, Config.AdminAce) then
            return
        end
        Bank.Open(src)
    end, true)

    RegisterCommand("ktbank_debug_uid", function(src, args)
        if src ~= 0 and not IsPlayerAceAllowed(src, Config.AdminAce) then
            return
        end
        local targetSrc = tonumber(args[1]) or src
        local uid = Union.GetCharacterUniqueId(targetSrc)
        print(('[KT Banque DEBUG] src=%d uid=%s'):format(targetSrc, tostring(uid)))
        if src ~= 0 then
            TriggerClientEvent('bank:client:notify', src, 'info',
                ('UID src %d : %s'):format(targetSrc, tostring(uid)))
        end
    end, true)
end

-- ──────────────────────────────────────────
-- NETTOYAGE À L'ARRÊT
-- ──────────────────────────────────────────

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    -- Nettoyage éventuel (logs, etc.)
    print('^3[KT Banque]^7 Ressource arrêtée proprement.')
end)

print('^2[KT Banque]^7 Serveur principal chargé v7.5.0')