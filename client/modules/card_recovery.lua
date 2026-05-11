-- ==================== KT BANQUE v7.5.0 — CLIENT/MODULES/CARD_RECOVERY ====================
-- Gestion de la récupération de carte côté client.
-- SUPPRESSION du fichier racine client/card_recovery.lua (doublon).
-- Ce fichier est le SEUL à être chargé (via fxmanifest client_scripts).
--
-- CORRECTIONS :
--   FIX-1 : Suppression du doublon (client/card_recovery.lua racine ignoré).
--   FIX-2 : Guard sur account null dans statusReceived.
--   FIX-3 : tonumber() sur account.active pour comparaison fiable.

local RECOVERY_COST = 1000

-- ──────────────────────────────────────────
-- STATUT DE LA CARTE
-- ──────────────────────────────────────────

RegisterNetEvent("kt_banque:card:statusReceived", function(account)
    -- FIX-2 : guard complet sur account
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
        expires_at    = account.expires_at
    })
end)

-- ──────────────────────────────────────────
-- RÉSULTAT DE LA RÉCUPÉRATION
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

-- ──────────────────────────────────────────
-- OUVERTURE DU MENU DE RÉCUPÉRATION
-- ──────────────────────────────────────────

function OpenCardRecovery()
    TriggerServerEvent("kt_banque:card:checkStatus")
end

-- Debug uniquement si Config.Debug activé
if Config and Config.Debug then
    RegisterCommand("testcardrecover", function()
        OpenCardRecovery()
    end, false)
end