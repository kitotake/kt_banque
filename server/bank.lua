ESX = exports["es_extended"]:getSharedObject()
local oxmysql = exports.oxmysql
local DB = Config.DB

-- Helpers pour requêtes synchrones
local function dbFetch(query, params)
    local p = promise.new()
    oxmysql:query(query, params or {}, function(result)
        p:resolve(result)
    end)
    return Citizen.Await(p)
end

local function dbExecute(query, params)
    local p = promise.new()
    oxmysql:execute(query, params or {}, function(affected)
        p:resolve(affected)
    end)
    return Citizen.Await(p)
end

local function dbInsert(query, params)
    local p = promise.new()
    oxmysql:insert(query, params or {}, function(insertId)
        p:resolve(insertId)
    end)
    return Citizen.Await(p)
end

-- Génération IBAN-like unique
local function generateIBANLike()
    local function randDigits(n)
        local s = ""
        for i = 1, n do
            s = s .. tostring(math.random(0, 9))
        end
        return s
    end
    
    for attempt = 1, 10 do
        local bankCode = randDigits(5)
        local account = randDigits(11)
        local checksum = randDigits(2)
        local iban = string.format("FR%s %s %s", checksum, bankCode, account)
        
        local query = string.format("SELECT ID FROM %s WHERE label = ? LIMIT 1", DB.banking_table)
        local exists = dbFetch(query, {iban})
        
        if not exists or #exists == 0 then
            return iban
        end
    end
    
    return "FR" .. tostring(math.random(10000000, 99999999))
end

-- Génération numéro de carte unique
local function generateCardNumber()
    for attempt = 1, 10 do
        local cardNum = string.format("%08d%04d", math.random(40000000, 49999999), math.random(1000, 9999))
        
        local query = string.format("SELECT id FROM %s WHERE card_number = ? LIMIT 1", DB.bank_cards_table)
        local exists = dbFetch(query, {cardNum})
        
        if not exists or #exists == 0 then
            return cardNum
        end
    end
    
    return tostring(os.time()) .. tostring(math.random(1000, 9999))
end

-- Récupérer carte depuis inventaire
local function getCardFromInventory(source)
    for cardType, itemName in pairs(Config.BankCardItem) do
        local items = exports.ox_inventory:Search(source, 'slots', itemName)
        
        if items then
            for _, item in pairs(items) do
                if item.metadata and (item.metadata.id or item.metadata.account_id) then
                    item.card_type = cardType
                    item.item_name = itemName
                    return item
                end
            end
        end
    end
    return nil
end

-- Récupérer carte depuis DB
local function getCardFromDB(cardId)
    if not cardId then return nil end
    
    local query = string.format("SELECT * FROM %s WHERE id = ? AND active = 1 LIMIT 1", DB.bank_cards_table)
    local result = dbFetch(query, {cardId})
    
    if result and result[1] then
        return result[1]
    end
    return nil
end

-- Récupérer compte
local function getAccount(accountId)
    if not accountId then return nil end
    
    local query = string.format("SELECT * FROM %s WHERE ID = ? LIMIT 1", DB.banking_table)
    local result = dbFetch(query, {accountId})
    
    if result and result[1] then
        return result[1]
    end
    return nil
end

-- Insérer log
local function insertLog(accountId, action, amount, identifier, description)
    local query = string.format(
        "INSERT INTO %s (account_id, action, amount, identifier, description) VALUES (?, ?, ?, ?, ?)",
        DB.bank_logs_table
    )
    dbExecute(query, {accountId, action, amount or 0, identifier, description})
end

-- Obtenir limites selon type de carte
local function getLimitsForCardType(cardType)
    return Config.CardLimits[cardType] or Config.CardLimits["carte_basique"]
end

-- Valider PIN
local function validatePinAndGetCard(cardId, pin)
    local card = getCardFromDB(cardId)
    if not card then
        return nil, Config.Notifications.no_card
    end
    
    if tostring(card.pin) ~= tostring(pin) then
        return nil, Config.Notifications.incorrect_pin
    end
    
    return card, nil
end





-- Event: Créer un compte
RegisterNetEvent('bank:server:createAccount', function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local pin = tostring(data.pin or "0000")
    local chosenType = tostring(data.card_type or "carte_basique")
    
    -- Validation PIN
    if #pin ~= 4 or not tonumber(pin) then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = Config.Notifications.invalid_pin
        })
        return
    end
    
    -- Vérifier si le joueur peut payer
    local limits = Config.CardLimits[chosenType]
    if not limits then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "Type de carte invalide"
        })
        return
    end
    
    local price = limits.Price or 0
    if price > 0 then
        local playerMoney = exports.ox_inventory:Search(src, 'count', 'money')
        if playerMoney < price then
            TriggerClientEvent('ox_lib:notify', src, {
                type = 'error',
                description = string.format("Fonds insuffisants. Prix: $%s", price)
            })
            return
        end
        exports.ox_inventory:RemoveItem(src, 'money', price)
    end
    
    -- Créer compte
    local accountNumber = generateIBANLike()
    local insertAccQuery = string.format(
        "INSERT INTO %s (identifier, type, amount, balance, label, time) VALUES (?, ?, ?, ?, ?, ?)",
        DB.banking_table
    )
    local accId = dbInsert(insertAccQuery, {
        xPlayer.identifier,
        'personal',
        0,
        0,
        accountNumber,
        os.time()
    })
    
    if not accId then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = Config.Notifications.error
        })
        return
    end
    
    -- Créer carte
    local cardNum = generateCardNumber()
    local insertCardQuery = string.format(
        "INSERT INTO %s (account_id, identifier, owner_name, card_number, pin, active, card_type) VALUES (?, ?, ?, ?, ?, ?, ?)",
        DB.bank_cards_table
    )
    local cardId = dbInsert(insertCardQuery, {
        accId,
        xPlayer.identifier,
        xPlayer.getName(),
        cardNum,
        pin,
        1,
        chosenType
    })
    
    if not cardId then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = Config.Notifications.error
        })
        return
    end
    
    -- Ajouter carte à l'inventaire
    local metadata = {
        id = cardId,
        account_id = accId,
        owner = xPlayer.getName(),
        card_number = cardNum,
        card_type = chosenType,
        account_number = accountNumber
    }
    
    local success = exports.ox_inventory:AddItem(src, Config.BankCardItem[chosenType], 1, metadata)
    
    if success then
        insertLog(accId, "account_created", 0, xPlayer.identifier, "Création de compte")
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'success',
            description = Config.Notifications.card_created
        })
    else
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "Erreur lors de l'ajout de la carte"
        })
    end
end)

-- Event: Ouvrir interface
RegisterNetEvent('bank:server:requestOpen', function()
    local src = source
    local cardItem = getCardFromInventory(src)
    
    if not cardItem then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = Config.Notifications.no_card
        })
        return
    end
    
    local dbCard = nil
    if cardItem.metadata and cardItem.metadata.id then
        dbCard = getCardFromDB(cardItem.metadata.id)
    end
    
    if not dbCard then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "Carte invalide ou désactivée"
        })
        return
    end
    
    local account = getAccount(dbCard.account_id)
    if not account then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "Compte introuvable"
        })
        return
    end
    
    -- Récupérer historique
    local logsQuery = string.format(
        "SELECT action, amount, identifier, description, date FROM %s WHERE account_id = ? ORDER BY date DESC LIMIT 30",
        DB.bank_logs_table
    )
    local logs = dbFetch(logsQuery, {dbCard.account_id}) or {}
    
    local limits = getLimitsForCardType(dbCard.card_type)
    
    local payload = {
        balance = account.balance or 0,
        label = account.label or "Personnel",
        history = logs,
        limits = limits,
        card_meta = {
            id = dbCard.id,
            account_id = dbCard.account_id,
            owner = dbCard.owner_name,
            last4 = tostring(dbCard.card_number):sub(-4),
            card_type = dbCard.card_type or "carte_basique"
        }
    }
    
    TriggerClientEvent('bank:client:openNUI', src, payload)
end)

-- Event: Dépôt
RegisterNetEvent('bank:server:deposit', function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local amount = tonumber(data.amount)
    local cardId = tonumber(data.cardId)
    local pin = tostring(data.pin)
    
    if not amount or amount <= 0 then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "Montant invalide"
        })
        return
    end
    
    local cardRow, err = validatePinAndGetCard(cardId, pin)
    if not cardRow then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = err
        })
        return
    end
    
    local limits = getLimitsForCardType(cardRow.card_type)
    if amount > limits.MaxDeposit then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = string.format("Limite de dépôt: $%s", limits.MaxDeposit)
        })
        return
    end
    
    local playerMoney = xPlayer.getMoney()
    if playerMoney < amount then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = Config.Notifications.insufficient_cash
        })
        return
    end
    
    -- Transaction
    local updateQuery = string.format("UPDATE %s SET balance = balance + ? WHERE ID = ?", DB.banking_table)
    dbExecute(updateQuery, {amount, cardRow.account_id})
    insertLog(cardRow.account_id, "deposit", amount, cardRow.identifier, "Dépôt via interface")
    
    xPlayer.removeMoney(amount)
    
    TriggerClientEvent('ox_lib:notify', src, {
        type = 'success',
        description = string.format(Config.Notifications.deposit_success, amount)
    })
    
    local acc = getAccount(cardRow.account_id)
    TriggerClientEvent('bank:client:updateBalance', src, acc.balance or 0)
end)

-- Event: Retrait
RegisterNetEvent('bank:server:withdraw', function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local amount = tonumber(data.amount)
    local cardId = tonumber(data.cardId)
    local pin = tostring(data.pin)
    
    if not amount or amount <= 0 then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "Montant invalide"
        })
        return
    end
    
    local cardRow, err = validatePinAndGetCard(cardId, pin)
    if not cardRow then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = err
        })
        return
    end
    
    local limits = getLimitsForCardType(cardRow.card_type)
    if amount > limits.MaxWithdraw then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = string.format("Limite de retrait: $%s", limits.MaxWithdraw)
        })
        return
    end
    
    local acc = getAccount(cardRow.account_id)
    if not acc or (acc.balance or 0) < amount then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = Config.Notifications.insufficient_balance
        })
        return
    end
    
    -- Transaction
    local updateQuery = string.format("UPDATE %s SET balance = balance - ? WHERE ID = ?", DB.banking_table)
    dbExecute(updateQuery, {amount, cardRow.account_id})
    insertLog(cardRow.account_id, "withdraw", amount, cardRow.identifier, "Retrait via interface")
    
    xPlayer.addMoney(amount)
    
    TriggerClientEvent('ox_lib:notify', src, {
        type = 'success',
        description = string.format(Config.Notifications.withdraw_success, amount)
    })
    
    local acc2 = getAccount(cardRow.account_id)
    TriggerClientEvent('bank:client:updateBalance', src, acc2.balance or 0)
end)

-- Event: Transfert
RegisterNetEvent('bank:server:transfer', function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local amount = tonumber(data.amount)
    local cardId = tonumber(data.cardId)
    local pin = tostring(data.pin)
    local target = data.target
    
    if not amount or amount <= 0 then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "Montant invalide"
        })
        return
    end
    
    if not target or target == "" then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "Destinataire invalide"
        })
        return
    end
    
    local cardRow, err = validatePinAndGetCard(cardId, pin)
    if not cardRow then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = err
        })
        return
    end
    
    local fromAcc = getAccount(cardRow.account_id)
    if not fromAcc or (fromAcc.balance or 0) < amount then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = Config.Notifications.insufficient_balance
        })
        return
    end
    
    -- Rechercher compte destinataire
    local targetAcc = nil
    if tonumber(target) then
        targetAcc = getAccount(tonumber(target))
    else
        local query = string.format(
            "SELECT * FROM %s WHERE label = ? OR identifier = ? LIMIT 1",
            DB.banking_table
        )
        local result = dbFetch(query, {target, target})
        if result and result[1] then
            targetAcc = result[1]
        end
    end
    
    if not targetAcc then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = Config.Notifications.target_not_found
        })
        return
    end
    
    if targetAcc.ID == fromAcc.ID then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "Vous ne pouvez pas transférer vers votre propre compte"
        })
        return
    end
    
    -- Transaction
    local updateQuery1 = string.format("UPDATE %s SET balance = balance - ? WHERE ID = ?", DB.banking_table)
    local updateQuery2 = string.format("UPDATE %s SET balance = balance + ? WHERE ID = ?", DB.banking_table)
    
    dbExecute(updateQuery1, {amount, fromAcc.ID})
    dbExecute(updateQuery2, {amount, targetAcc.ID})
    
    insertLog(fromAcc.ID, "transfer_out", amount, cardRow.identifier, 
        string.format("Transfert vers %s", targetAcc.label or targetAcc.ID))
    insertLog(targetAcc.ID, "transfer_in", amount, xPlayer.identifier, 
        string.format("Reçu de %s", fromAcc.label or fromAcc.ID))
    
    TriggerClientEvent('ox_lib:notify', src, {
        type = 'success',
        description = string.format(Config.Notifications.transfer_success, amount)
    })
    
    local after = getAccount(fromAcc.ID)
    TriggerClientEvent('bank:client:updateBalance', src, after.balance or 0)
end)

-- ==============================
-- FONCTIONS ADMIN (EXPORTS)
-- ==============================

function AdminDeactivateCard(cardId)
    if not cardId then return false end
    
    local query = string.format("UPDATE %s SET active = 0 WHERE id = ?", DB.bank_cards_table)
    local result = dbExecute(query, {cardId})
    
    return result and result > 0
end

function AdminReprintPin(cardId)
    if not cardId then return nil end
    
    local newPin = string.format("%04d", math.random(0, 9999))
    local query = string.format("UPDATE %s SET pin = ? WHERE id = ?", DB.bank_cards_table)
    local result = dbExecute(query, {newPin, cardId})
    
    if result and result > 0 then
        return newPin
    end
    return nil
end

function AdminCreateCardForPlayer(identifier, cardType, ownerName)
    if not identifier or not cardType then return nil end
    
    local playerLabel = ownerName or identifier
    cardType = cardType or "carte_basique"
    
    -- Créer compte
    local accountNumber = generateIBANLike()
    local accQuery = string.format(
        "INSERT INTO %s (identifier, type, amount, balance, label, time) VALUES (?, ?, ?, ?, ?, ?)",
        DB.banking_table
    )
    local accId = dbInsert(accQuery, {identifier, 'personal', 0, 0, accountNumber, os.time()})
    
    if not accId then return nil end
    
    -- Créer carte
    local cardNum = generateCardNumber()
    local newPin = string.format("%04d", math.random(0, 9999))
    
    local cardQuery = string.format(
        "INSERT INTO %s (account_id, identifier, owner_name, card_number, pin, active, card_type) VALUES (?, ?, ?, ?, ?, ?, ?)",
        DB.bank_cards_table
    )
    local cardId = dbInsert(cardQuery, {accId, identifier, playerLabel, cardNum, newPin, 1, cardType})
    
    if not cardId then return nil end
    
    insertLog(accId, "admin_created", 0, identifier, "Compte créé par admin")
    
    return {
        account_id = accId,
        card_id = cardId,
        pin = newPin,
        account_number = accountNumber,
        card_number = cardNum
    }
end

function AdminGetAccountInfo(accountId)
    if not accountId then return nil end
    
    local account = getAccount(accountId)
    if not account then return nil end
    
    local cardQuery = string.format(
        "SELECT * FROM %s WHERE account_id = ? ORDER BY created_at DESC",
        DB.bank_cards_table
    )
    local cards = dbFetch(cardQuery, {accountId}) or {}
    
    local logsQuery = string.format(
        "SELECT * FROM %s WHERE account_id = ? ORDER BY date DESC LIMIT 50",
        DB.bank_logs_table
    )
    local logs = dbFetch(logsQuery, {accountId}) or {}
    
    return {
        account = account,
        cards = cards,
        logs = logs
    }
end

function AdminSetBalance(accountId, newBalance)
    if not accountId or not newBalance then return false end
    
    local query = string.format("UPDATE %s SET balance = ? WHERE ID = ?", DB.banking_table)
    local result = dbExecute(query, {newBalance, accountId})
    
    if result and result > 0 then
        insertLog(accountId, "admin_set_balance", newBalance, "system", "Balance modifiée par admin")
        return true
    end
    return false
end

-- Events admin
RegisterNetEvent('bank:admin:deactivateCard', function(cardId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    
    -- Vérifier permissions (adapter selon votre système)
    if not xPlayer or xPlayer.getGroup() ~= 'admin' then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "Permissions insuffisantes"
        })
        return
    end
    
    local ok = AdminDeactivateCard(cardId)
    if ok then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'success',
            description = 'Carte désactivée avec succès'
        })
    else
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Erreur lors de la désactivation'
        })
    end
end)

RegisterNetEvent('bank:admin:reprintPin', function(cardId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    
    if not xPlayer or xPlayer.getGroup() ~= 'admin' then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "Permissions insuffisantes"
        })
        return
    end
    
    local pin = AdminReprintPin(cardId)
    if pin then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'success',
            description = string.format('Nouveau PIN généré: %s', pin)
        })
    else
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Erreur lors de la génération du PIN'
        })
    end
end)

RegisterNetEvent('bank:admin:createCardFor', function(identifier, cardType, ownerName)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    
    if not xPlayer or xPlayer.getGroup() ~= 'admin' then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "Permissions insuffisantes"
        })
        return
    end
    
    local result = AdminCreateCardForPlayer(identifier, cardType or "carte_basique", ownerName)
    if result then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'success',
            description = string.format('Carte créée - ID: %s, PIN: %s', result.card_id, result.pin)
        })
    else
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Erreur lors de la création'
        })
    end
end)

-- Commandes admin
ESX.RegisterCommand('bankadmin', 'admin', function(xPlayer, args, showError)
    local src = xPlayer.source
    
    if args.action == 'createcard' then
        if not args.identifier or not args.cardtype then
            TriggerClientEvent('ox_lib:notify', src, {
                type = 'error',
                description = 'Usage: /bankadmin createcard <identifier> <cardtype>'
            })
            return
        end
        
        local result = AdminCreateCardForPlayer(args.identifier, args.cardtype, args.name)
        if result then
            TriggerClientEvent('ox_lib:notify', src, {
                type = 'success',
                description = string.format('Carte créée - PIN: %s', result.pin)
            })
        end
    elseif args.action == 'deactivate' then
        if not args.cardid then
            TriggerClientEvent('ox_lib:notify', src, {
                type = 'error',
                description = 'Usage: /bankadmin deactivate <cardid>'
            })
            return
        end
        
        AdminDeactivateCard(tonumber(args.cardid))
    elseif args.action == 'setbalance' then
        if not args.accountid or not args.amount then
            TriggerClientEvent('ox_lib:notify', src, {
                type = 'error',
                description = 'Usage: /bankadmin setbalance <accountid> <amount>'
            })
            return
        end
        
        AdminSetBalance(tonumber(args.accountid), tonumber(args.amount))
    end
end, false, {
    help = 'Commandes admin bancaires',
    validate = false,
    arguments = {
        {name = 'action', help = 'Action à effectuer', type = 'string'},
        {name = 'identifier', help = 'Identifier du joueur', type = 'string'},
        {name = 'cardtype', help = 'Type de carte', type = 'string'},
        {name = 'cardid', help = 'ID de la carte', type = 'number'},
        {name = 'accountid', help = 'ID du compte', type = 'number'},
        {name = 'amount', help = 'Montant', type = 'number'},
        {name = 'name', help = 'Nom du propriétaire', type = 'string'}
    }
})

-- Logs système
print('^2[KT Banque]^7 Système bancaire initialisé avec succès')