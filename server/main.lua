-- ==================== KT BANQUE v7.5.0 — SERVER/MAIN ====================
-- Point d'entrée serveur.
-- Les modules sont déjà chargés par fxmanifest dans l'ordre :
--   utils → db → bank → card_manager → card_recovery → admin → main

-- ──────────────────────────────────────────
-- ÉVÉNEMENTS RÉSEAU
-- ──────────────────────────────────────────

RegisterNetEvent('bank:server:requestOpen', function()
    print(('[BANK DEBUG] requestOpen triggered by source %s'):format(source))
    Bank.Open(source)
end)

RegisterNetEvent('bank:server:createAccount', function(pin)
    print(('[BANK DEBUG] createAccount triggered by source %s | pin: %s'):format(source, tostring(pin)))
    Bank.Create(source, pin)
end)

RegisterNetEvent('bank:server:deposit', function(amount, pinHash)
    print(('[BANK DEBUG] deposit triggered by source %s | amount: %s | pinHash: %s'):format(
        source,
        tostring(amount),
        tostring(pinHash)
    ))
    Bank.Deposit(source, amount, pinHash)
end)

RegisterNetEvent('bank:server:withdraw', function(amount, pinHash)
    print(('[BANK DEBUG] withdraw triggered by source %s | amount: %s | pinHash: %s'):format(
        source,
        tostring(amount),
        tostring(pinHash)
    ))
    Bank.Withdraw(source, amount, pinHash)
end)

RegisterNetEvent('bank:server:transfer', function(amount, target, pinHash)
    print(('[BANK DEBUG] transfer triggered by source %s | amount: %s | target: %s | pinHash: %s'):format(
        source,
        tostring(amount),
        tostring(target),
        tostring(pinHash)
    ))
    Bank.Transfer(source, amount, target, pinHash)
end)

RegisterNetEvent('bank:server:upgradeCard', function(cardType)
    print(('[BANK DEBUG] upgradeCard triggered by source %s | cardType: %s'):format(
        source,
        tostring(cardType)
    ))
    Bank.UpgradeCard(source, cardType)
end)

RegisterNetEvent('bank:server:replaceCard', function()
    print(('[BANK DEBUG] replaceCard triggered by source %s'):format(source))
    Bank.ReplaceCard(source)
end)
-- ──────────────────────────────────────────
-- DEBUG
-- ──────────────────────────────────────────

if Config.Debug then
    RegisterCommand("ktbank_open", function(src)
        Bank.Open(src)
    end, true)

    -- Debug : forcer un statut de compte
    RegisterCommand("ktbank_setstatus", function(src, args)
        local uid    = args[1]
        local status = args[2]
        if uid and status then
            DB.SetAccountStatus(uid, status)
            print(("[KT Banque] DEBUG — Compte %s → %s"):format(uid, status))
        end
    end, true)

    -- Debug : bloquer la carte d'un joueur
    RegisterCommand("ktbank_blockcard", function(src, args)
        local targetSrc = tonumber(args[1]) or src
        local uid       = Union.GetCharacterUniqueId(targetSrc)
        if uid then
            CardManager.AdminBlockCard(src, targetSrc, uid, "Debug block")
            print(("[KT Banque] DEBUG — Carte bloquée pour src=%d"):format(targetSrc))
        end
    end, true)
end

print('^2[KT Banque]^7 Serveur principal chargé v7.5.0')