-- ==================== KT BANQUE v7.5.0 — SERVER/MAIN ====================
-- Point d'entrée serveur.
-- Ordre de chargement (fxmanifest) :
--   utils → db → card_manager → bank → card_recovery → admin → main
--
-- CORRECTIONS v7.5.0 :
--   FIX-1 : Guard source valide + isConnected avant traitement.
--   FIX-2 : Validation basique des paramètres avant dispatch aux handlers.
--   FIX-3 : Commandes debug protégées par Config.Debug ET ACE admin.

-- ──────────────────────────────────────────
-- HELPER : joueur toujours connecté ?
-- ──────────────────────────────────────────

local function isConnected(src)
    return GetPlayerEndpoint(tostring(src)) ~= nil
end

-- ──────────────────────────────────────────
-- ÉVÉNEMENTS RÉSEAU
-- ──────────────────────────────────────────

RegisterNetEvent('bank:server:requestOpen', function()
    local src = source
    if not isConnected(src) then return end
    Bank.Open(src)
end)

RegisterNetEvent('bank:server:createAccount', function(pin)
    local src = source
    if not isConnected(src) then return end
    if not pin or tostring(pin) == "" then return end
    Bank.Create(src, tostring(pin))
end)

RegisterNetEvent('bank:server:deposit', function(amount, pinHash)
    local src = source
    if not isConnected(src) then return end
    amount = tonumber(amount)
    if not amount or amount <= 0 then return end
    if not pinHash or tostring(pinHash) == "" then return end
    Bank.Deposit(src, amount, tostring(pinHash))
end)

RegisterNetEvent('bank:server:withdraw', function(amount, pinHash)
    local src = source
    if not isConnected(src) then return end
    amount = tonumber(amount)
    if not amount or amount <= 0 then return end
    if not pinHash or tostring(pinHash) == "" then return end
    Bank.Withdraw(src, amount, tostring(pinHash))
end)

RegisterNetEvent('bank:server:transfer', function(amount, target, pinHash)
    local src = source
    if not isConnected(src) then return end
    amount = tonumber(amount)
    if not amount or amount <= 0 then return end
    if not target or tostring(target) == "" then return end
    if not pinHash or tostring(pinHash) == "" then return end
    Bank.Transfer(src, amount, tostring(target), tostring(pinHash))
end)

RegisterNetEvent('bank:server:upgradeCard', function(cardType)
    local src = source
    if not isConnected(src) then return end
    if not cardType or cardType == "" then return end
    Bank.UpgradeCard(src, cardType)
end)

-- ──────────────────────────────────────────
-- DEBUG — double protection Config.Debug ET ACE
-- ──────────────────────────────────────────

if Config.Debug then
    RegisterCommand("ktbank_open", function(src)
        if src ~= 0 and not IsPlayerAceAllowed(src, Config.AdminAce) then return end
        Bank.Open(src ~= 0 and src or 1)
    end, true)

    RegisterCommand("ktbank_debug_uid", function(src, args)
        if src ~= 0 and not IsPlayerAceAllowed(src, Config.AdminAce) then return end
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
-- NETTOYAGE
-- ──────────────────────────────────────────

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    print('^3[KT Banque]^7 Ressource arrêtée proprement.')
end)

print('^2[KT Banque]^7 Serveur principal chargé v7.5.0')
