-- ==================== KT BANQUE v7.5.0 — CLIENT/MODULES/CARD_RECOVERY ====================
-- Gestion de la récupération de carte côté client.
-- SEUL fichier chargé — le doublon client/card_recovery.lua racine est supprimé.
--
-- CORRECTIONS v7.5.0 :
--   FIX-1 : Suppression du doublon racine (client/card_recovery.lua).
--   FIX-2 : Guard complet sur account null dans statusReceived.
--   FIX-3 : tonumber() sur account.active pour comparaison fiable.
--   FIX-4 : Commande debug protégée par Config.Debug.

local RECOVERY_COST = Config and Config.CardReplaceCost or 1000

-- ──────────────────────────────────────────
-- STATUT DE LA CARTE
-- ──────────────────────────────────────────

RegisterNetEvent("kt_banque:card:statusReceived", function(account)
    -- FIX-2 : guard complet
    if not account then
        lib.notify({ description = "Aucun compte trouvé.", type = "error", duration = 3000 })
        return
    end

    -- FIX-3 : tonumber() pour comparaison fiable
    local status = tonumber(account.active) == 1 and "active" or "blocked"

    SendNUIMessage({
        action        = "showCardStatus",
        status        = status,
        accountNumber = account.iban,
        balance       = tonumber(account.balance) or 0,
        recoveryCost  = RECOVERY_COST,
        expires_at    = account.expires_at,
        meta_blocked  = account.meta_blocked  or false,
        meta_owner    = account.meta_owner    or nil
    })
end)

-- ──────────────────────────────────────────
-- RÉSULTAT DU REMPLACEMENT
-- ──────────────────────────────────────────

RegisterNetEvent("kt_banque:card:recoverResult", function(success, errorMsg)
    if not success then
        lib.notify({ description = errorMsg or "Erreur inconnue.", type = "error", duration = 3000 })
        SendNUIMessage({ action = "cardRecoverFailed", reason = errorMsg })
        return
    end

    lib.notify({
        description = ("Carte récupérée ($%d débité)"):format(RECOVERY_COST),
        type        = "success",
        duration    = 3000
    })

    SendNUIMessage({ action = "cardRecoverSuccess" })
    TriggerServerEvent("kt_banque:card:checkStatus")
end)

-- ──────────────────────────────────────────
-- NUI CALLBACK
-- ──────────────────────────────────────────

RegisterNUICallback("recoverCard", function(_, cb)
    TriggerServerEvent("kt_banque:card:recover")
    cb({})
end)

RegisterNUICallback("selfBlockCard", function(_, cb)
    TriggerServerEvent("kt_banque:card:selfBlock")
    cb({})
end)

-- ──────────────────────────────────────────
-- OUVERTURE DU MENU DE RÉCUPÉRATION
-- ──────────────────────────────────────────

function OpenCardRecovery()
    TriggerServerEvent("kt_banque:card:checkStatus")
end

-- FIX-4 : debug protégé
if Config and Config.Debug then
    RegisterCommand("testcardrecover", function()
        OpenCardRecovery()
    end, false)
end
