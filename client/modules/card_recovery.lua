-- ==================== KT BANQUE v7.5.0 — CLIENT/MODULES/CARD_RECOVERY ====================
-- Gestion de la récupération de carte côté client.

local RECOVERY_COST = 1000

-- ──────────────────────────────────────────
-- STATUT DE LA CARTE
-- ──────────────────────────────────────────

RegisterNetEvent("kt_banque:card:statusReceived", function(account)
    if not account then
        lib.notify({ description = "Aucun compte trouvé.", type = "error", duration = 3000 })
        return
    end

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

-- DEBUG
RegisterCommand("testcardrecover", function()
    OpenCardRecovery()
end, false)
