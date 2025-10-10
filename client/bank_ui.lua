BankUI = {}

-----------------------------------
-- 🎨 OUVRIR L'INTERFACE BANCAIRE
-----------------------------------
function BankUI.open(data)
    ClientBankUtils.debugPrint("Ouverture interface bancaire")
    ClientBankUtils.isUIOpen = true
    
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openBank',
        data = data
    })
end

-----------------------------------
-- 🔐 OUVRIR CRÉATION DE COMPTE
-----------------------------------
function BankUI.openCreate()
    ClientBankUtils.debugPrint("Ouverture création de compte")
    ClientBankUtils.isUIOpen = true
    
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openCreate'
    })
end

-----------------------------------
-- 💰 METTRE À JOUR LE SOLDE
-----------------------------------
function BankUI.updateBalance(newBalance)
    SendNUIMessage({
        action = 'updateBalance',
        balance = newBalance
    })
end

-----------------------------------
-- ❌ FERMER L'INTERFACE
-----------------------------------
function BankUI.close()
    ClientBankUtils.debugPrint("Fermeture interface bancaire")
    ClientBankUtils.isUIOpen = false
    
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'close'
    })
    
    -- Arrêter l'animation ATM
    BankAnimations.stopAnimation()
end

-----------------------------------
-- 📥 CALLBACKS NUI
-----------------------------------

-- Fermeture UI
RegisterNUICallback('close', function(data, cb)
    BankUI.close()
    cb('ok')
end)

-- Validation PIN
RegisterNUICallback('validatePin', function(data, cb)
    TriggerServerEvent('bank:server:validatePin', data.pin, data.cardId)
    cb('ok')
end)

-- Création de compte
RegisterNUICallback('createAccount', function(data, cb)
    if not data.pin or #data.pin ~= 4 then
        ClientBankUtils.notify('error', 'Le PIN doit contenir 4 chiffres')
        cb('error')
        return
    end
    
    TriggerServerEvent('bank:server:createAccount', data.pin)
    cb('ok')
end)

-- Dépôt
RegisterNUICallback('deposit', function(data, cb)
    if not data.amount or data.amount <= 0 then
        ClientBankUtils.notify('error', 'Montant invalide')
        cb('error')
        return
    end
    
    TriggerServerEvent('bank:server:deposit', data.amount, data.cardId, data.pin)
    cb('ok')
end)

-- Retrait
RegisterNUICallback('withdraw', function(data, cb)
    if not data.amount or data.amount <= 0 then
        ClientBankUtils.notify('error', 'Montant invalide')
        cb('error')
        return
    end
    
    TriggerServerEvent('bank:server:withdraw', data.amount, data.cardId, data.pin)
    cb('ok')
end)

-- Transfert
RegisterNUICallback('transfer', function(data, cb)
    if not data.amount or data.amount <= 0 then
        ClientBankUtils.notify('error', 'Montant invalide')
        cb('error')
        return
    end
    
    if not data.target or data.target == '' then
        ClientBankUtils.notify('error', 'Destinataire invalide')
        cb('error')
        return
    end
    
    TriggerServerEvent('bank:server:transfer', data.amount, data.target, data.cardId, data.pin)
    cb('ok')
end)

-----------------------------------
-- 🔄 EVENTS SERVEUR
-----------------------------------

-- Réception données compte
RegisterNetEvent('bank:client:receiveAccountData', function(data)
    ClientBankUtils.currentAccount = data
    BankUI.open(data)
end)

-- Mise à jour solde
RegisterNetEvent('bank:client:updateBalance', function(newBalance)
    if ClientBankUtils.currentAccount then
        ClientBankUtils.currentAccount.balance = newBalance
    end
    BankUI.updateBalance(newBalance)
end)

-- Fermeture forcée
RegisterNetEvent('bank:client:forceClose', function()
    BankUI.close()
end)

-- Ouverture création compte
RegisterNetEvent('bank:client:openCreate', function()
    BankUI.openCreate()
end)

-- Notifications
RegisterNetEvent('bank:client:notify', function(type, message)
    ClientBankUtils.notify(type, message)
end)

print('^2[KT Banque]^7 Interface NUI chargée')