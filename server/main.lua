-- ==================== INITIALISATION ====================
ESX = exports["es_extended"]:getSharedObject()

-- Variables globales
local DB = Config.DB
local lastAction = {}

-- ==================== UTILITAIRES ====================
local Utils = {}

function Utils.DebugPrint(message)
    if Config.Debug then
        print(("^6[DEBUG Server]^7 %s"):format(message))
    end
end

function Utils.CheckSpam(source)
    local currentTime = GetGameTimer()
    if lastAction[source] and (currentTime - lastAction[source]) < Config.SpamDelay then
        return true
    end
    lastAction[source] = currentTime
    return false
end

function Utils.GenerateAccountId(identifier)
    return "ACC_" .. identifier:gsub(":", "_")
end

function Utils.GenerateCardNumber()
    local parts = {}
    for i = 1, 4 do
        parts[i] = string.format("%04d", math.random(1000, 9999))
    end
    return table.concat(parts, " ")
end

function Utils.ValidatePin(pin)
    if not pin then return false end
    local pinStr = tostring(pin)
    return #pinStr == 4 and pinStr:match("^%d+$") ~= nil
end

function Utils.GetPlayerCardType(source)
    for cardType, itemName in pairs(Config.BankCardItem) do
        local count = exports.ox_inventory:GetItemCount(source, itemName)
        if count > 0 then
            return cardType, itemName
        end
    end
    return nil, nil
end

-- ==================== BASE DE DONNÉES ====================
local Database = {}

function Database.GetCard(identifier)
    local result = MySQL.query.await(
        'SELECT * FROM ' .. DB.bank_cards_table .. ' WHERE identifier = ? AND active = 1 LIMIT 1',
        {identifier}
    )
    return result[1]
end

function Database.GetAccount(accountId)
    local result = MySQL.query.await(
        'SELECT * FROM ' .. DB.banking_table .. ' WHERE account_id = ? LIMIT 1',
        {accountId}
    )
    return result[1]
end

function Database.CreateAccount(identifier, pin, ownerName)
    local accountId = Utils.GenerateAccountId(identifier)
    local cardNumber = Utils.GenerateCardNumber()
    
    -- Créer le compte
    MySQL.insert.await(
        'INSERT INTO ' .. DB.banking_table .. ' (account_id, identifier, balance, owner_name, label) VALUES (?, ?, ?, ?, ?)',
        {accountId, identifier, 0, ownerName, 'Compte Personnel'}
    )
    
    -- Créer la carte
    MySQL.insert.await(
        'INSERT INTO ' .. DB.bank_cards_table .. ' (identifier, account_id, card_number, pin, card_type, active) VALUES (?, ?, ?, ?, ?, ?)',
        {identifier, accountId, cardNumber, pin, 'carte_basique', 1}
    )
    
    -- Log
    Database.InsertLog(accountId, 'account_created', 0, identifier, 'Création du compte')
    
    return accountId
end

function Database.UpdateBalance(accountId, newBalance)
    MySQL.update.await(
        'UPDATE ' .. DB.banking_table .. ' SET balance = ? WHERE account_id = ?',
        {newBalance, accountId}
    )
end

function Database.UpdateCardType(identifier, cardType)
    MySQL.update.await(
        'UPDATE ' .. DB.bank_cards_table .. ' SET card_type = ? WHERE identifier = ? AND active = 1',
        {cardType, identifier}
    )
end

function Database.InsertLog(accountId, action, amount, identifier, description)
    MySQL.insert.await(
        'INSERT INTO ' .. DB.bank_logs_table .. ' (account_id, action, amount, identifier, description) VALUES (?, ?, ?, ?, ?)',
        {accountId, action, amount or 0, identifier, description or ''}
    )
end

function Database.GetHistory(accountId, limit)
    return MySQL.query.await(
        'SELECT * FROM ' .. DB.bank_logs_table .. ' WHERE account_id = ? ORDER BY date DESC LIMIT ?',
        {accountId, limit or 20}
    )
end

-- ==================== FONCTIONS MÉTIER ====================
local Bank = {}

function Bank.GetFullAccountData(identifier)
    local card = Database.GetCard(identifier)
    if not card then return nil, "no_card" end
    
    local account = Database.GetAccount(card.account_id)
    if not account then return nil, "no_account" end
    
    local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
    local cardType = card.card_type
    if xPlayer then
        cardType = Utils.GetPlayerCardType(xPlayer.source) or card.card_type
    end
    
    local limits = Config.CardLimits[cardType] or Config.CardLimits.carte_basique
    local history = Database.GetHistory(card.account_id, 30)
    
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
            label = account.label,
            created = account.created_at
        },
        limits = limits,
        history = history
    }
end

function Bank.Deposit(source, amount, pin)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false, "player_not_found" end
    
    -- Anti-spam
    if Utils.CheckSpam(source) then return false, "spam" end
    
    -- Validation
    amount = tonumber(amount)
    if not amount or amount <= 0 then return false, "invalid_amount" end
    
    -- Vérifier cash
    if xPlayer.getMoney() < amount then return false, "insufficient_cash" end
    
    -- Récupérer compte
    local card = Database.GetCard(xPlayer.identifier)
    if not card then return false, "no_card" end
    
    -- Vérifier limites
    local cardType = Utils.GetPlayerCardType(source) or card.card_type
    local limits = Config.CardLimits[cardType]
    if amount > limits.MaxDeposit then return false, "limit_exceeded" end
    
    -- Récupérer solde actuel
    local account = Database.GetAccount(card.account_id)
    local newBalance = account.balance + amount
    
    -- Transaction
    Database.UpdateBalance(card.account_id, newBalance)
    xPlayer.removeMoney(amount)
    Database.InsertLog(card.account_id, 'deposit', amount, xPlayer.identifier, 'Dépôt espèces')
    
    Utils.DebugPrint(("Dépôt: %s a déposé $%s"):format(xPlayer.identifier, amount))
    return true, newBalance
end

function Bank.Withdraw(source, amount, pin)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false, "player_not_found" end
    
    -- Anti-spam
    if Utils.CheckSpam(source) then return false, "spam" end
    
    -- Validation
    amount = tonumber(amount)
    if not amount or amount <= 0 then return false, "invalid_amount" end
    
    -- Récupérer compte
    local card = Database.GetCard(xPlayer.identifier)
    if not card then return false, "no_card" end
    
    local account = Database.GetAccount(card.account_id)
    if account.balance < amount then return false, "insufficient_balance" end
    
    -- Vérifier limites
    local cardType = Utils.GetPlayerCardType(source) or card.card_type
    local limits = Config.CardLimits[cardType]
    if amount > limits.MaxWithdraw then return false, "limit_exceeded" end
    
    -- Transaction
    local newBalance = account.balance - amount
    Database.UpdateBalance(card.account_id, newBalance)
    xPlayer.addMoney(amount)
    Database.InsertLog(card.account_id, 'withdraw', amount, xPlayer.identifier, 'Retrait espèces')
    
    Utils.DebugPrint(("Retrait: %s a retiré $%s"):format(xPlayer.identifier, amount))
    return true, newBalance
end

function Bank.Transfer(source, amount, targetAccountId, pin)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false, "player_not_found" end
    
    -- Anti-spam
    if Utils.CheckSpam(source) then return false, "spam" end
    
    -- Validation
    amount = tonumber(amount)
    if not amount or amount <= 0 then return false, "invalid_amount" end
    
    -- Récupérer compte émetteur
    local senderCard = Database.GetCard(xPlayer.identifier)
    if not senderCard then return false, "no_card" end
    
    local senderAccount = Database.GetAccount(senderCard.account_id)
    if senderAccount.balance < amount then return false, "insufficient_balance" end
    
    -- Vérifier qu'on ne transfère pas à soi-même
    if senderCard.account_id == targetAccountId then return false, "same_account" end
    
    -- Récupérer compte destinataire
    local targetAccount = Database.GetAccount(targetAccountId)
    if not targetAccount then return false, "target_not_found" end
    
    -- Transaction
    local newSenderBalance = senderAccount.balance - amount
    local newTargetBalance = targetAccount.balance + amount
    
    Database.UpdateBalance(senderCard.account_id, newSenderBalance)
    Database.UpdateBalance(targetAccountId, newTargetBalance)
    
    Database.InsertLog(senderCard.account_id, 'transfer_out', amount, xPlayer.identifier, 
        'Transfert vers ' .. targetAccountId)
    Database.InsertLog(targetAccountId, 'transfer_in', amount, targetAccount.identifier,
        'Transfert reçu de ' .. senderCard.account_id)
    
    -- Notifier le destinataire si en ligne
    local targetPlayer = ESX.GetPlayerFromIdentifier(targetAccount.identifier)
    if targetPlayer then
        TriggerClientEvent('bank:client:notify', targetPlayer.source, 'success',
            string.format("Vous avez reçu $%s", amount))
    end
    
    Utils.DebugPrint(("Transfert: %s -> %s ($%s)"):format(senderCard.account_id, targetAccountId, amount))
    return true, newSenderBalance
end

-- ==================== EVENTS ====================

-- Ouverture interface
RegisterNetEvent('bank:server:requestOpen', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    -- Vérifier carte si requis
    if Config.RequireCard then
        local cardType = Utils.GetPlayerCardType(src)
        if not cardType then
            TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang.no_card)
            return
        end
    end
    
    local data, error = Bank.GetFullAccountData(xPlayer.identifier)
    if not data then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang[error] or Config.Lang.no_account)
        return
    end
    
    TriggerClientEvent('bank:client:receiveAccountData', src, data)
end)

-- Vérifier compte existant
RegisterNetEvent('bank:server:checkExistingAccount', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local card = Database.GetCard(xPlayer.identifier)
    if card then
        TriggerClientEvent('bank:client:notify', src, 'warning', Config.Lang.account_exists)
    else
        TriggerClientEvent('bank:client:openCreate', src)
    end
end)

-- Création compte
RegisterNetEvent('bank:server:createAccount', function(pin)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    -- Vérifier si compte existe déjà
    local existingCard = Database.GetCard(xPlayer.identifier)
    if existingCard then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang.account_exists)
        return
    end
    
    -- Valider PIN
    if not Utils.ValidatePin(pin) then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang.invalid_pin)
        return
    end
    
    -- Créer compte
    local accountId = Database.CreateAccount(xPlayer.identifier, pin, xPlayer.getName())
    
    -- Donner carte basique
    exports.ox_inventory:AddItem(src, Config.BankCardItem.carte_basique, 1)
    
    TriggerClientEvent('bank:client:notify', src, 'success', Config.Lang.account_created)
    TriggerClientEvent('bank:client:forceClose', src)
    
    Utils.DebugPrint(("Compte créé pour %s"):format(xPlayer.identifier))
end)

-- Dépôt
RegisterNetEvent('bank:server:deposit', function(amount, cardId, pin)
    local src = source
    local success, result = Bank.Deposit(src, amount, pin)
    
    if success then
        TriggerClientEvent('bank:client:updateBalance', src, result)
        TriggerClientEvent('bank:client:notify', src, 'success', 
            string.format(Config.Lang.deposit_success, amount))
    else
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang[result] or "Erreur")
    end
end)

-- Retrait
RegisterNetEvent('bank:server:withdraw', function(amount, cardId, pin)
    local src = source
    local success, result = Bank.Withdraw(src, amount, pin)
    
    if success then
        TriggerClientEvent('bank:client:updateBalance', src, result)
        TriggerClientEvent('bank:client:notify', src, 'success',
            string.format(Config.Lang.withdraw_success, amount))
    else
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang[result] or "Erreur")
    end
end)

-- Transfert
RegisterNetEvent('bank:server:transfer', function(amount, target, cardId, pin)
    local src = source
    local success, result = Bank.Transfer(src, amount, target, pin)
    
    if success then
        TriggerClientEvent('bank:client:updateBalance', src, result)
        TriggerClientEvent('bank:client:notify', src, 'success',
            string.format(Config.Lang.transfer_success, amount))
    else
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang[result] or "Erreur")
    end
end)

-- Amélioration carte
RegisterNetEvent('bank:server:upgradeCard', function(newCardType)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    -- Vérifier type de carte valide
    if not Config.CardLimits[newCardType] then
        TriggerClientEvent('bank:client:notify', src, 'error', 'Type de carte invalide')
        return
    end
    
    local price = Config.CardLimits[newCardType].Price
    local card = Database.GetCard(xPlayer.identifier)
    if not card then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang.no_account)
        return
    end
    
    local account = Database.GetAccount(card.account_id)
    if account.balance < price then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang.insufficient_balance)
        return
    end
    
    -- Retirer ancienne carte
    for oldType, oldItem in pairs(Config.BankCardItem) do
        exports.ox_inventory:RemoveItem(src, oldItem, 1)
    end
    
    -- Ajouter nouvelle carte
    exports.ox_inventory:AddItem(src, Config.BankCardItem[newCardType], 1)
    
    -- Débiter et mettre à jour
    local newBalance = account.balance - price
    Database.UpdateBalance(card.account_id, newBalance)
    Database.UpdateCardType(xPlayer.identifier, newCardType)
    Database.InsertLog(card.account_id, 'card_issued', price, xPlayer.identifier,
        'Amélioration carte: ' .. newCardType)
    
    TriggerClientEvent('bank:client:notify', src, 'success', Config.Lang.card_upgraded)
    Utils.DebugPrint(("Carte améliorée pour %s: %s"):format(xPlayer.identifier, newCardType))
end)

-- ==================== EXPORTS ====================
exports('GetAccountBalance', function(identifier)
    local card = Database.GetCard(identifier)
    if not card then return 0 end
    local account = Database.GetAccount(card.account_id)
    return account and account.balance or 0
end)

exports('AddMoney', function(identifier, amount)
    local card = Database.GetCard(identifier)
    if not card then return false end
    local account = Database.GetAccount(card.account_id)
    if not account then return false end
    local newBalance = account.balance + amount
    Database.UpdateBalance(card.account_id, newBalance)
    return true
end)

exports('RemoveMoney', function(identifier, amount)
    local card = Database.GetCard(identifier)
    if not card then return false end
    local account = Database.GetAccount(card.account_id)
    if not account or account.balance < amount then return false end
    local newBalance = account.balance - amount
    Database.UpdateBalance(card.account_id, newBalance)
    return true
end)

print('^2[KT Banque]^7 Serveur chargé avec succès')