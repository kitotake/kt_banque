-- kt_banque/client/card_recovery.lua

local RECOVERY_COST = 1000

-- Statut reçu → affiche dans la NUI
RegisterNetEvent("kt_banque:card:statusReceived", function(account)
    if not account then
        Notifications.send("Aucun compte trouvé.", "error")
        return
    end

    SendNUIMessage({
        action        = "showCardStatus",
        status        = account.status,         -- "active" ou "blocked"
        accountNumber = account.account_number,
        balance       = account.balance,
        recoveryCost  = RECOVERY_COST,
    })
end)

-- Résultat de la récupération
RegisterNetEvent("kt_banque:card:recoverResult", function(success, errorMsg)
    if not success then
        Notifications.send(errorMsg or "Erreur inconnue.", "error")
        -- Mettre à jour la NUI pour refléter l'échec
        SendNUIMessage({ action = "cardRecoverFailed", reason = errorMsg })
        return
    end

    Notifications.send(
        string.format("Carte récupérée avec succès. $%d débités.", RECOVERY_COST),
        "success"
    )
    SendNUIMessage({ action = "cardRecoverSuccess" })

    -- Rafraîchir le statut affiché
    TriggerServerEvent("kt_banque:card:checkStatus")
end)

-- NUI Callback : joueur confirme la récupération depuis l'interface
RegisterNUICallback("recoverCard", function(_, cb)
    TriggerServerEvent("kt_banque:card:recover")
    cb({ ok = true })
end)

-- Ouvre le menu (à appeler depuis ton point d'interaction kt_banque)
function OpenCardRecovery()
    TriggerServerEvent("kt_banque:card:checkStatus")
end