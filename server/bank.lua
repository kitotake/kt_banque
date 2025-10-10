ESX = exports["es_extended"]:getSharedObject()
local DB = Config.DB

BankUtils = {}

-----------------------------------
-- 🛠️ UTILITAIRES BASE DE DONNÉES
-----------------------------------
function BankUtils.dbExecute(query, params)
    return MySQL.Sync.execute(query, params)
end

function BankUtils.dbFetch(query, params)
    return MySQL.Sync.fetchAll(query, params)
end

function BankUtils.dbFetchScalar(query, params)
    return MySQL.Sync.fetchScalar(query, params)
end

-----------------------------------
-- 🐛 DEBUG
-----------------------------------
function BankUtils.debugPrint(message)
    if Config.Debug then
        print(("^6[DEBUG Serveur]^7 %s"):format(message))
    end
end

-----------------------------------
-- 🔍 RÉCUPÉRER CARTE PAR IDENTIFIER
-----------------------------------
function BankUtils.getCardByIdentifier(identifier)
    local query = string.format(
        "SELECT * FROM %s WHERE identifier = ? AND active = 1 LIMIT 1",
        DB.bank_cards_table
    )
    local result = BankUtils.dbFetch(query, {identifier})
    return result[1] or nil
end

-----------------------------------
-- 🏦 RÉCUPÉRER COMPTE BANCAIRE
-----------------------------------
function BankUtils.getAccount(accountId)
    local query = string.format(
        "SELECT * FROM %s WHERE account_id = ? LIMIT 1",
        DB.banking_table
    )
    local result = BankUtils.dbFetch(query, {accountId})
    return result[1] or nil
end

-----------------------------------
-- 💳 RÉCUPÉRER TYPE DE CARTE JOUEUR
-----------------------------------
function BankUtils.getPlayerCardType(source)
    for cardType, itemName in pairs(Config.BankCardItem) do
        local count = exports.ox_inventory:GetItemCount(source, itemName)
        if count > 0 then
            return cardType, itemName
        end
    end
    return nil, nil
end

-----------------------------------
-- 📋 RÉCUPÉRER DONNÉES COMPLÈTES
-----------------------------------
function BankUtils.getFullAccountData(identifier)
    local card = BankUtils.getCardByIdentifier(identifier)
    if not card then return nil end
    
    local account = BankUtils.getAccount(card.account_id)
    if not account then return nil end
    
    local cardType, itemName = BankUtils.getPlayerCardTypeByIdentifier(identifier)
    local limits = Config.CardLimits[cardType] or Config.CardLimits.carte_basique
    
    local history = BankLogs.getHistory(card.account_id, 20)
    
    return {
        account_id = account.account_id,
        balance = account.balance,
        pin = card.pin,
        requiresPin = true,
        card_meta = {
            id = card.id,
            card_number = card.card_number,
            card_type = cardType,
            owner = account.owner_name,
            active = card.active
        },
        account_info = {
            label = account.label or "Compte Personnel",
            created = account.created_at
        },
        limits = limits,
        history = history
    }
end

function BankUtils.getPlayerCardTypeByIdentifier(identifier)
    local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
    if not xPlayer then return nil, nil end
    
    return BankUtils.getPlayerCardType(xPlayer.source)
end

-----------------------------------
-- 🎲 GÉNÉRER NUMÉRO DE CARTE
-----------------------------------
function BankUtils.generateCardNumber()
    local parts = {}
    for i = 1, 4 do
        parts[i] = string.format("%04d", math.random(0, 9999))
    end
    return table.concat(parts, " ")
end

-----------------------------------
-- 🔐 VÉRIFIER PIN
-----------------------------------
function BankUtils.verifyPin(cardId, pin)
    local query = string.format(
        "SELECT pin FROM %s WHERE id = ? AND active = 1 LIMIT 1",
        DB.bank_cards_table
    )
    local result = BankUtils.dbFetch(query, {cardId})
    
    if result[1] then
        return tostring(result[1].pin) == tostring(pin)
    end
    return false
end

-----------------------------------
-- 💰 METTRE À JOUR SOLDE
-----------------------------------
function BankUtils.updateBalance(accountId, newBalance)
    local query = string.format(
        "UPDATE %s SET balance = ? WHERE account_id = ?",
        DB.banking_table
    )
    return BankUtils.dbExecute(query, {newBalance, accountId})
end

-----------------------------------
-- 📊 RÉCUPÉRER SOLDE
-----------------------------------
function BankUtils.getBalance(accountId)
    local query = string.format(
        "SELECT balance FROM %s WHERE account_id = ?",
        DB.banking_table
    )
    return BankUtils.dbFetchScalar(query, {accountId}) or 0
end

-----------------------------------
-- 🎫 EVENTS - DEMANDE OUVERTURE
-----------------------------------
RegisterNetEvent('bank:server:requestOpen', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    -- Vérifier possession carte
    if Config.RequireCard then
        local cardType, itemName = BankUtils.getPlayerCardType(src)
        if not cardType then
            TriggerClientEvent('bank:client:notify', src, 'error', Config.Notifications.no_card)
            return
        end
    end
    
    -- Récupérer les données
    local data = BankUtils.getFullAccountData(xPlayer.identifier)
    if not data then
        TriggerClientEvent('bank:client:notify', src, 'error', 'Aucun compte trouvé')
        return
    end
    
    BankUtils.debugPrint(("Ouverture compte pour %s (Solde: $%s)"):format(xPlayer.identifier, data.balance))
    TriggerClientEvent('bank:client:receiveAccountData', src, data)
end)

-----------------------------------
-- 🔍 VÉRIFIER COMPTE EXISTANT
-----------------------------------
RegisterNetEvent('bank:server:checkExistingAccount', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local card = BankUtils.getCardByIdentifier(xPlayer.identifier)
    
    if card then
        TriggerClientEvent('bank:client:notify', src, 'warning', 'Vous possédez déjà un compte bancaire')
    else
        TriggerClientEvent('bank:client:openCreate', src)
    end
end)

-----------------------------------
-- ✨ CRÉER UN COMPTE
-----------------------------------
RegisterNetEvent('bank:server:createAccount', function(pin)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    -- Vérifier si déjà un compte
    local existingCard = BankUtils.getCardByIdentifier(xPlayer.identifier)
    if existingCard then
        TriggerClientEvent('bank:client:notify', src, 'error', 'Vous possédez déjà un compte')
        return
    end
    
    -- Vérifier le PIN
    if not pin or #tostring(pin) ~= 4 then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Notifications.invalid_pin)
        return
    end
    
    -- Créer le compte
    local accountId = "ACC_" .. xPlayer.identifier:gsub(":", "_")
    local cardNumber = BankUtils.generateCardNumber()
    
    -- Insérer compte
    local query1 = string.format(
        "INSERT INTO %s (account_id, identifier, balance, owner_name, label) VALUES (?, ?, ?, ?, ?)",
        DB.banking_table
    )
    BankUtils.dbExecute(query1, {accountId, xPlayer.identifier, 0, xPlayer.getName(), "Compte Personnel"})
    
    -- Insérer carte
    local query2 = string.format(
        "INSERT INTO %s (identifier, account_id, card_number, pin, card_type, active) VALUES (?, ?, ?, ?, ?, ?)",
        DB.bank_cards_table
    )
    BankUtils.dbExecute(query2, {xPlayer.identifier, accountId, cardNumber, pin, 'carte_basique', 1})
    
    -- Donner la carte basique
    exports.ox_inventory:AddItem(src, Config.BankCardItem.carte_basique, 1)
    
    -- Log
    BankLogs.insert(accountId, 'account_created', 0, xPlayer.identifier, 'Création du compte bancaire')
    
    BankUtils.debugPrint(("Compte créé pour %s - PIN: %s"):format(xPlayer.identifier, pin))
    TriggerClientEvent('bank:client:notify', src, 'success', Config.Notifications.card_created)
    TriggerClientEvent('bank:client:forceClose', src)
end)

-----------------------------------
-- 💰 DÉPÔT
-----------------------------------
RegisterNetEvent('bank:server:deposit', function(amount, cardId, pin)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    amount = tonumber(amount)
    if not amount or amount <= 0 then
        TriggerClientEvent('bank:client:notify', src, 'error', 'Montant invalide')
        return
    end
    
    -- Vérifier le cash
    if xPlayer.getMoney() < amount then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Notifications.insufficient_cash)
        return
    end
    
    -- Récupérer la carte
    local card = BankUtils.getCardByIdentifier(xPlayer.identifier)
    if not card then
        TriggerClientEvent('bank:client:notify', src, 'error', 'Carte bancaire introuvable')
        return
    end
    
    -- Vérifier limites
    local cardType, _ = BankUtils.getPlayerCardType(src)
    local limits = Config.CardLimits[cardType] or Config.CardLimits.carte_basique
    
    if amount > limits.MaxDeposit then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Notifications.limit_exceeded)
        return
    end
    
    -- Effectuer le dépôt
    local currentBalance = BankUtils.getBalance(card.account_id)
    local newBalance = currentBalance + amount
    
    BankUtils.updateBalance(card.account_id, newBalance)
    xPlayer.removeMoney(amount)
    
    -- Log
    BankLogs.insert(card.account_id, 'deposit', amount, xPlayer.identifier, ("Dépôt de $%s"):format(amount))
    
    TriggerClientEvent('bank:client:updateBalance', src, newBalance)
    TriggerClientEvent('bank:client:notify', src, 'success', string.format(Config.Notifications.deposit_success, amount))
    
    BankUtils.debugPrint(("Dépôt: %s a déposé $%s"):format(xPlayer.identifier, amount))
end)

-----------------------------------
-- 💵 RETRAIT
-----------------------------------
RegisterNetEvent('bank:server:withdraw', function(amount, cardId, pin)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    amount = tonumber(amount)
    if not amount or amount <= 0 then
        TriggerClientEvent('bank:client:notify', src, 'error', 'Montant invalide')
        return
    end
    
    -- Récupérer la carte
    local card = BankUtils.getCardByIdentifier(xPlayer.identifier)
    if not card then
        TriggerClientEvent('bank:client:notify', src, 'error', 'Carte bancaire introuvable')
        return
    end
    
    -- Vérifier limites
    local cardType, _ = BankUtils.getPlayerCardType(src)
    local limits = Config.CardLimits[cardType] or Config.CardLimits.carte_basique
    
    if amount > limits.MaxWithdraw then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Notifications.limit_exceeded)
        return
    end
    
    -- Vérifier solde
    local currentBalance = BankUtils.getBalance(card.account_id)
    if currentBalance < amount then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Notifications.insufficient_balance)
        return
    end
    
    -- Effectuer le retrait
    local newBalance = currentBalance - amount
    
    BankUtils.updateBalance(card.account_id, newBalance)
    xPlayer.addMoney(amount)
    
    -- Log
    BankLogs.insert(card.account_id, 'withdraw', amount, xPlayer.identifier, ("Retrait de $%s"):format(amount))
    
    TriggerClientEvent('bank:client:updateBalance', src, newBalance)
    TriggerClientEvent('bank:client:notify', src, 'success', string.format(Config.Notifications.withdraw_success, amount))
    
    BankUtils.debugPrint(("Retrait: %s a retiré $%s"):format(xPlayer.identifier, amount))
end)

-----------------------------------
-- 🔄 TRANSFERT
-----------------------------------
RegisterNetEvent('bank:server:transfer', function(amount, target, cardId, pin)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    amount = tonumber(amount)
    if not amount or amount <= 0 then
        TriggerClientEvent('bank:client:notify', src, 'error', 'Montant invalide')
        return
    end
    
    -- Récupérer la carte de l'émetteur
    local card = BankUtils.getCardByIdentifier(xPlayer.identifier)
    if not card then
        TriggerClientEvent('bank:client:notify', src, 'error', 'Carte bancaire introuvable')
        return
    end
    
    -- Vérifier solde
    local currentBalance = BankUtils.getBalance(card.account_id)
    if currentBalance < amount then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Notifications.insufficient_balance)
        return
    end
    
    -- Trouver le destinataire
    local targetPlayer = ESX.GetPlayerFromId(tonumber(target))
    local targetIdentifier = nil
    
    if targetPlayer then
        targetIdentifier = targetPlayer.identifier
    else
        -- Rechercher par account_id ou identifier
        local query = string.format(
            "SELECT identifier FROM %s WHERE account_id = ? OR identifier = ? LIMIT 1",
            DB.banking_table
        )
        local result = BankUtils.dbFetch(query, {target, target})
        if result[1] then
            targetIdentifier = result[1].identifier
        end
    end
    
    if not targetIdentifier then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Notifications.target_not_found)
        return
    end
    
    -- Récupérer le compte destinataire
    local targetCard = BankUtils.getCardByIdentifier(targetIdentifier)
    if not targetCard then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Notifications.target_not_found)
        return
    end
    
    -- Effectuer le transfert
    local newBalance = currentBalance - amount
    local targetBalance = BankUtils.getBalance(targetCard.account_id)
    local newTargetBalance = targetBalance + amount
    
    BankUtils.updateBalance(card.account_id, newBalance)
    BankUtils.updateBalance(targetCard.account_id, newTargetBalance)
    
    -- Logs
    BankLogs.insert(card.account_id, 'transfer_out', amount, xPlayer.identifier, 
        ("Transfert vers %s"):format(targetCard.account_id))
    BankLogs.insert(targetCard.account_id, 'transfer_in', amount, targetIdentifier, 
        ("Transfert reçu de %s"):format(card.account_id))
    
    -- Notifications
    TriggerClientEvent('bank:client:updateBalance', src, newBalance)
    TriggerClientEvent('bank:client:notify', src, 'success', 
        string.format(Config.Notifications.transfer_success, amount))
    
    if targetPlayer then
        TriggerClientEvent('bank:client:notify', targetPlayer.source, 'success', 
            ("Vous avez reçu un transfert de $%s"):format(amount))
    end
    
    BankUtils.debugPrint(("Transfert: %s -> %s ($%s)"):format(xPlayer.identifier, targetIdentifier, amount))
end)

-----------------------------------
-- 💳 VÉRIFIER COMPTE EN ATTENTE
-----------------------------------
RegisterNetEvent('bank:server:checkPendingAccount', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local card = BankUtils.getCardByIdentifier(xPlayer.identifier)
    
    if not card then
        TriggerClientEvent('bank:client:notify', src, 'error', 'Vous devez d\'abord créer un compte bancaire')
        return
    end
    
    -- Menu achat carte avec ox_lib
    local options = {
        {
            title = '💳 Carte Basique',
            description = ('Prix: $%s | Dépôt max: $%s | Retrait max: $%s'):format(
                Config.CardLimits.carte_basique.Price,
                Config.CardLimits.carte_basique.MaxDeposit,
                Config.CardLimits.carte_basique.MaxWithdraw
            ),
            icon = 'credit-card',
            disabled = true,
            metadata = {'Vous possédez déjà cette carte'}
        },
        {
            title = '💎 Carte Or',
            description = ('Prix: $%s | Dépôt max: $%s | Retrait max: $%s'):format(
                Config.CardLimits.carte_or.Price,
                Config.CardLimits.carte_or.MaxDeposit,
                Config.CardLimits.carte_or.MaxWithdraw
            ),
            icon = 'gem',
            onSelect = function()
                TriggerEvent('bank:server:purchaseCard', 'carte_or')
            end
        },
        {
            title = '💠 Carte Diamant',
            description = ('Prix: $%s | Dépôt max: $%s | Retrait max: $%s'):format(
                Config.CardLimits.carte_dimas.Price,
                Config.CardLimits.carte_dimas.MaxDeposit,
                Config.CardLimits.carte_dimas.MaxWithdraw
            ),
            icon = 'crown',
            onSelect = function()
                TriggerEvent('bank:server:purchaseCard', 'carte_dimas')
            end
        }
    }
    
    TriggerClientEvent('ox_lib:registerContext', src, {
        id = 'bank_card_purchase',
        title = '🏦 Améliorer ma Carte',
        options = options
    })
    
    TriggerClientEvent('ox_lib:showContext', src, 'bank_card_purchase')
end)

-----------------------------------
-- 🛒 ACHAT CARTE
-----------------------------------
RegisterNetEvent('bank:server:purchaseCard', function(cardType)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local price = Config.CardLimits[cardType].Price
    local itemName = Config.BankCardItem[cardType]
    
    if not price or not itemName then
        TriggerClientEvent('bank:client:notify', src, 'error', 'Type de carte invalide')
        return
    end
    
    -- Vérifier l'argent
    local currentBalance = BankUtils.getBalance("ACC_" .. xPlayer.identifier:gsub(":", "_"))
    if currentBalance < price then
        TriggerClientEvent('bank:client:notify', src, 'error', 'Solde insuffisant')
        return
    end
    
    -- Retirer ancienne carte
    for oldCardType, oldItemName in pairs(Config.BankCardItem) do
        exports.ox_inventory:RemoveItem(src, oldItemName, 1)
    end
    
    -- Ajouter nouvelle carte
    exports.ox_inventory:AddItem(src, itemName, 1)
    
    -- Débiter le compte
    local newBalance = currentBalance - price
    BankUtils.updateBalance("ACC_" .. xPlayer.identifier:gsub(":", "_"), newBalance)
    
    -- Mettre à jour le type de carte dans la DB
    local query = string.format(
        "UPDATE %s SET card_type = ? WHERE identifier = ?",
        DB.bank_cards_table
    )
    BankUtils.dbExecute(query, {cardType, xPlayer.identifier})
    
    -- Log
    BankLogs.insert("ACC_" .. xPlayer.identifier:gsub(":", "_"), 'card_issued', price, 
        xPlayer.identifier, ("Achat carte %s"):format(cardType))
    
    TriggerClientEvent('bank:client:notify', src, 'success', 
        ('Carte %s achetée avec succès !'):format(cardType))
    
    BankUtils.debugPrint(("%s a acheté une carte %s"):format(xPlayer.identifier, cardType))
end)

print('^2[KT Banque]^7 Système bancaire chargé')