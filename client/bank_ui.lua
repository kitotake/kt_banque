BankUI = {}

-----------------------------------
-- 💳 INTERFACE BANCAIRE (NUI)
-----------------------------------
RegisterCommand("openNUI", function()
    TriggerServerEvent('bank:server:requestOpen')
end)

RegisterNetEvent("bank:client:openNUI", function(payload)
    if not payload then return end
    ClientBankUtils.currentCardMeta = payload.card_meta or nil
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openBank",
        data = payload
    })
    ClientBankUtils.isUIOpen = true
    ClientBankUtils.debugPrint("Interface bancaire ouverte")
end)

RegisterNetEvent("bank:client:updateBalance", function(balance)
    if ClientBankUtils.isUIOpen then
        SendNUIMessage({
            action = "updateBalance",
            balance = balance
        })
        ClientBankUtils.debugPrint(("Balance mise à jour: $%s"):format(balance))
    end
end)

-----------------------------------
-- 🆕 EVENT: OUVRIR CRÉATION DE COMPTE
-----------------------------------
RegisterNetEvent('bank:client:openAccountCreation', function()
    ClientBankUtils.debugPrint("Ouverture interface création de compte")
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openCreate"
    })
    ClientBankUtils.isUIOpen = true
end)

-----------------------------------
-- 💳 EVENT: AFFICHER MENU ACHAT CARTE
-----------------------------------
RegisterNetEvent('bank:client:showCardPurchaseMenu', function(accountId)
    ClientBankUtils.debugPrint(("Menu achat carte - Compte ID: %s"):format(accountId))
    
    -- Créer le menu avec ox_lib
    local options = {}
    
    for cardType, limits in pairs(Config.CardLimits) do
        local cardNames = {
            carte_basique = "💳 Carte Basique",
            carte_or = "🏅 Carte Or",
            carte_dimas = "💎 Carte Diamant"
        }
        
        table.insert(options, {
            title = cardNames[cardType] or cardType,
            description = string.format("Dépôt max: $%s | Retrait max: $%s\nPrix: $%s", 
                limits.MaxDeposit, 
                limits.MaxWithdraw, 
                limits.Price
            ),
            icon = cardType == 'carte_basique' and 'credit-card' or (cardType == 'carte_or' and 'star' or 'gem'),
            onSelect = function()
                TriggerServerEvent('bank:server:purchaseCard', {
                    account_id = accountId,
                    card_type = cardType
                })
            end
        })
    end
    
    lib.registerContext({
        id = 'card_purchase_menu',
        title = '🏦 Achat de Carte Bancaire',
        options = options
    })
    
    lib.showContext('card_purchase_menu')
end)

-----------------------------------
-- 🔁 CALLBACKS NUI
-----------------------------------
RegisterNUICallback("close", function(_, cb)
    SetNuiFocus(false, false)
    ClientBankUtils.isUIOpen = false
    ClientBankUtils.currentCardMeta = nil
    BankAnimations.stopAnimation()
    ClientBankUtils.debugPrint("Interface fermée")
    cb("ok")
end)

RegisterNUICallback("createAccount", function(data, cb)
    if not ClientBankUtils.canPerformAction() then 
        BankNotifications.warning("Veuillez patienter avant de réessayer")
        return cb("spam") 
    end
    
    if not data.pin or #tostring(data.pin) ~= 4 then
        BankNotifications.error(Config.Notifications.invalid_pin)
        return cb("invalid")
    end
    
    ClientBankUtils.debugPrint(("Création compte avec PIN: %s"):format(data.pin))
    TriggerServerEvent("bank:server:createAccountOnly", data)
    cb("ok")
end)

RegisterNUICallback("deposit", function(data, cb)
    if not ClientBankUtils.canPerformAction() then 
        BankNotifications.warning("Veuillez patienter avant de réessayer")
        return cb("spam") 
    end
    
    if not ClientBankUtils.currentCardMeta then
        BankNotifications.error(Config.Notifications.no_card)
        return cb("no_card")
    end
    
    local amount = tonumber(data.amount)
    if not amount or amount <= 0 then
        BankNotifications.error("Montant invalide")
        return cb("invalid")
    end
    
    ClientBankUtils.debugPrint(("Dépôt: $%s"):format(amount))
    TriggerServerEvent("bank:server:deposit", {
        amount = amount,
        cardId = ClientBankUtils.currentCardMeta.id,
        pin = tostring(data.pin)
    })
    cb("ok")
end)

RegisterNUICallback("withdraw", function(data, cb)
    if not ClientBankUtils.canPerformAction() then 
        BankNotifications.warning("Veuillez patienter avant de réessayer")
        return cb("spam") 
    end
    
    if not ClientBankUtils.currentCardMeta then
        BankNotifications.error(Config.Notifications.no_card)
        return cb("no_card")
    end
    
    local amount = tonumber(data.amount)
    if not amount or amount <= 0 then
        BankNotifications.error("Montant invalide")
        return cb("invalid")
    end
    
    ClientBankUtils.debugPrint(("Retrait: $%s"):format(amount))
    TriggerServerEvent("bank:server:withdraw", {
        amount = amount,
        cardId = ClientBankUtils.currentCardMeta.id,
        pin = tostring(data.pin)
    })
    cb("ok")
end)

RegisterNUICallback("transfer", function(data, cb)
    if not ClientBankUtils.canPerformAction() then 
        BankNotifications.warning("Veuillez patienter avant de réessayer")
        return cb("spam") 
    end
    
    if not ClientBankUtils.currentCardMeta then
        BankNotifications.error(Config.Notifications.no_card)
        return cb("no_card")
    end
    
    local amount = tonumber(data.amount)
    if not amount or amount <= 0 or not data.target then
        BankNotifications.error("Données invalides")
        return cb("invalid")
    end
    
    ClientBankUtils.debugPrint(("Transfert: $%s vers %s"):format(amount, data.target))
    TriggerServerEvent("bank:server:transfer", {
        amount = amount,
        target = data.target,
        cardId = ClientBankUtils.currentCardMeta.id,
        pin = tostring(data.pin)
    })
    cb("ok")
end)

-----------------------------------
-- ⌨️ FERMETURE DE L'UI (ESC)
-----------------------------------
CreateThread(function()
    while true do
        Wait(0)
        if ClientBankUtils.isUIOpen and IsControlJustReleased(0, 322) then -- ESC
            SendNUIMessage({ action = "close" })
            SetNuiFocus(false, false)
            ClientBankUtils.isUIOpen = false
            ClientBankUtils.currentCardMeta = nil
            BankAnimations.stopAnimation()
            ClientBankUtils.debugPrint("Interface fermée (ESC)")
        end
    end
end)

print('^2[KT Banque]^7 Interface UI chargée')