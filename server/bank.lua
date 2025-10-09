ESX = exports["es_extended"]:getSharedObject()
local oxmysql = exports.oxmysql
local DB = Config.DB

-----------------------------------
-- 🔧 HELPERS BASE DE DONNÉES
-----------------------------------
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

-----------------------------------
-- 🔢 GÉNÉRATION IBAN-LIKE
-----------------------------------
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

-----------------------------------
-- 💳 GÉNÉRATION NUMÉRO DE CARTE
-----------------------------------
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

-----------------------------------
-- 🔍 RÉCUPÉRATION DONNÉES
-----------------------------------
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

local function getCardFromDB(cardId)
    if not cardId then return nil end
    
    local query = string.format("SELECT * FROM %s WHERE id = ? AND active = 1 LIMIT 1", DB.bank_cards_table)
    local result = dbFetch(query, {cardId})
    
    if result and result[1] then
        return result[1]
    end
    return nil
end

local function getAccount(accountId)
    if not accountId then return nil end
    
    local query = string.format("SELECT * FROM %s WHERE ID = ? LIMIT 1", DB.banking_table)
    local result = dbFetch(query, {accountId})
    
    if result and result[1] then
        return result[1]
    end
    return nil
end

-----------------------------------
-- 📝 LOGS BANCAIRES
-----------------------------------
local function insertLog(accountId, action, amount, identifier, description)
    local query = string.format(
        "INSERT INTO %s (account_id, action, amount, identifier, description) VALUES (?, ?, ?, ?, ?)",
        DB.bank_logs_table
    )
    dbExecute(query, {accountId, action, amount or 0, identifier, description})
end

-----------------------------------
-- 🎯 LIMITES PAR TYPE DE CARTE
-----------------------------------
local function getLimitsForCardType(cardType)
    return Config.CardLimits[cardType] or Config.CardLimits["carte_basique"]
end

-----------------------------------
-- 🔐 VALIDATION PIN
-----------------------------------
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

-----------------------------------
-- 📋 EVENT: VÉRIFIER COMPTE EN ATTENTE (PNJ1)
-----------------------------------
RegisterNetEvent('bank:server:checkPendingAccount', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    -- Vérifier si le joueur a déjà une carte active
    local cardItem = getCardFromInventory(src)
    if cardItem then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'info',
            description = "Vous possédez déjà une carte bancaire"
        })
        return
    end
    
    -- Chercher un compte sans carte active
    local query = string.format(
        "SELECT b.ID, b.label FROM %s b LEFT JOIN %s c ON b.ID = c.account_id AND c.active = 1 WHERE b.identifier = ? AND c.id IS NULL LIMIT 1",
        DB.banking_table,
        DB.bank_cards_table
    )
    local result = dbFetch(query, {xPlayer.identifier})
    
    if result and result[1] then
        -- Compte trouvé sans carte active - proposer l'achat
        TriggerClientEvent('bank:client:showCardPurchaseMenu', src, result[1].ID)
    else
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "❌ Vous devez d'abord créer un compte au guichet d'ouverture"
        })
    end
end)

-----------------------------------
-- ✨ EVENT: VÉRIFIER CRÉATION DE COMPTE (PNJ2)
-----------------------------------
RegisterNetEvent('bank:server:checkExistingAccount', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)

    print(("^3[bank:server:checkExistingAccount]^7 → Appel reçu du joueur [src: %s]"):format(src))

    if not xPlayer then
        print(("^1[ERREUR]^7 Aucun joueur trouvé pour src %s !"):format(src))
        return
    end

    print(("^2[xPlayer]^7 Trouvé → Nom: %s | Identifier: %s"):format(xPlayer.getName(), xPlayer.identifier or "nil"))

    -- Vérifier si le joueur a déjà un compte
    local query = string.format("SELECT ID FROM %s WHERE identifier = ? LIMIT 1", DB.banking_table)
    print(("^4[SQL]^7 Exécution de la requête: %s"):format(query))

    local result = dbFetch(query, {xPlayer.identifier})

    if result and result[1] then
        print(("^6[Résultat SQL]^7 Compte trouvé pour %s (ID: %s)"):format(xPlayer.identifier, result[1].ID))

        TriggerClientEvent('ox_lib:notify', src, {
            type = 'info',
            description = "ℹ️ Vous possédez déjà un compte bancaire"
        })

        print("^3[Action]^7 Notification envoyée au client → compte déjà existant.")
        return
    else
        print(("^2[Résultat SQL]^7 Aucun compte trouvé pour %s"):format(xPlayer.identifier))
    end

    -- Ouvrir l'interface de création
    TriggerClientEvent('bank:client:openAccountCreation', src)
    print(("^5[Action]^7 Ouverture de l'interface de création de compte pour %s (src: %s)"):format(xPlayer.getName(), src))
end)


-----------------------------------
-- 🆕 EVENT: CRÉER COMPTE UNIQUEMENT (SANS CARTE)
-----------------------------------
RegisterNetEvent('bank:server:createAccountOnly', function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local pin = tostring(data.pin or "0000")
    
    -- Validation PIN
    if #pin ~= 4 or not tonumber(pin) then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = Config.Notifications.invalid_pin
        })
        return
    end
    
    -- Vérifier si le joueur a déjà un compte
    local checkQuery = string.format("SELECT ID FROM %s WHERE identifier = ? LIMIT 1", DB.banking_table)
    local exists = dbFetch(checkQuery, {xPlayer.identifier})
    
    if exists and exists[1] then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "❌ Vous possédez déjà un compte bancaire"
        })
        return
    end
    
    -- Créer le compte
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
    
    -- Créer carte "pending" (inactive) avec le PIN
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
        0, -- Inactive
        'pending' -- Type temporaire
    })
    
    if not cardId then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = Config.Notifications.error
        })
        return
    end
    
    insertLog(accId, "account_created", 0, xPlayer.identifier, "Compte créé - en attente de carte")
    
    TriggerClientEvent('ox_lib:notify', src, {
        type = 'success',
        description = "✅ Compte créé ! Rendez-vous au guichet pour acheter votre carte bancaire"
    })
end)

-----------------------------------
-- 💳 EVENT: ACHETER CARTE BANCAIRE
-----------------------------------
RegisterNetEvent('bank:server:purchaseCard', function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local accountId = tonumber(data.account_id)
    local chosenType = tostring(data.card_type or "carte_basique")
    
    if not accountId then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "Compte invalide"
        })
        return
    end
    
    -- Vérifier que le compte appartient au joueur
    local account = getAccount(accountId)
    if not account or account.identifier ~= xPlayer.identifier then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "Ce compte ne vous appartient pas"
        })
        return
    end
    
    -- Vérifier si une carte active existe déjà
    local cardQuery = string.format(
        "SELECT id FROM %s WHERE account_id = ? AND active = 1 LIMIT 1",
        DB.bank_cards_table
    )
    local existingCard = dbFetch(cardQuery, {accountId})
    if existingCard and existingCard[1] then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "Une carte active existe déjà pour ce compte"
        })
        return
    end
    
    -- Vérifier le prix
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
    
    -- Récupérer la carte pending
    local pendingQuery = string.format(
        "SELECT id, pin, card_number FROM %s WHERE account_id = ? AND card_type = 'pending' LIMIT 1",
        DB.bank_cards_table
    )
    local pendingCard = dbFetch(pendingQuery, {accountId})
    
    local cardId, cardNum, pin
    
    if pendingCard and pendingCard[1] then
        -- Mettre à jour la carte pending
        cardId = pendingCard[1].id
        cardNum = pendingCard[1].card_number
        pin = pendingCard[1].pin
        
        local updateQuery = string.format(
            "UPDATE %s SET active = 1, card_type = ? WHERE id = ?",
            DB.bank_cards_table
        )
        dbExecute(updateQuery, {chosenType, cardId})
    else
        -- Créer nouvelle carte (fallback)
        cardNum = generateCardNumber()
        pin = string.format("%04d", math.random(0, 9999))
        
        local insertCardQuery = string.format(
            "INSERT INTO %s (account_id, identifier, owner_name, card_number, pin, active, card_type) VALUES (?, ?, ?, ?, ?, ?, ?)",
            DB.bank_cards_table
        )
        cardId = dbInsert(insertCardQuery, {
            accountId,
            xPlayer.identifier,
            xPlayer.getName(),
            cardNum,
            pin,
            1,
            chosenType
        })
    end
    
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
        account_id = accountId,
        owner = xPlayer.getName(),
        card_number = cardNum,
        card_type = chosenType,
        account_number = account.label
    }
    
    local success = exports.ox_inventory:AddItem(src, Config.BankCardItem[chosenType], 1, metadata)
    
    if success then
        insertLog(accountId, "card_issued", price, xPlayer.identifier, "Carte émise: " .. chosenType)
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'success',
            description = "✅ Carte bancaire ajoutée à votre inventaire !"
        })
    else
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "Erreur lors de l'ajout de la carte"
        })
    end
end)

-----------------------------------
-- 🏦 EVENT: OUVRIR INTERFACE BANCAIRE
-----------------------------------
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
    
    -- Historique
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

-----------------------------------
-- 💰 EVENT: DÉPÔT
-----------------------------------
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
    insertLog(cardRow.account_id, "deposit", amount, cardRow.identifier, "Dépôt via ATM")
    
    xPlayer.removeMoney(amount)
    
    TriggerClientEvent('ox_lib:notify', src, {
        type = 'success',
        description = string.format(Config.Notifications.deposit_success, amount)
    })
    
    local acc = getAccount(cardRow.account_id)
    TriggerClientEvent('bank:client:updateBalance', src, acc.balance or 0)
end)

-----------------------------------
-- 💵 EVENT: RETRAIT
-----------------------------------
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
    insertLog(cardRow.account_id, "withdraw", amount, cardRow.identifier, "Retrait via ATM")
    
    xPlayer.addMoney(amount)
    
    TriggerClientEvent('ox_lib:notify', src, {
        type = 'success',
        description = string.format(Config.Notifications.withdraw_success, amount)
    })
    
    local acc2 = getAccount(cardRow.account_id)
    TriggerClientEvent('bank:client:updateBalance', src, acc2.balance or 0)
end)

-----------------------------------
-- 🔄 EVENT: TRANSFERT
-----------------------------------
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

-----------------------------------
-- 👑 FONCTIONS ADMIN (EXPORTS)
-----------------------------------
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
    if result and result > 0 then return newPin end
    return nil
end

function AdminCreateCardForPlayer(identifier, cardType, ownerName)
    if not identifier or not cardType then return nil end
    local playerLabel = ownerName or identifier
    cardType = cardType or "carte_basique"
    
    local accountNumber = generateIBANLike()
    local accQuery = string.format(
        "INSERT INTO %s (identifier, type, amount, balance, label, time) VALUES (?, ?, ?, ?, ?, ?)",
        DB.banking_table
    )
    local accId = dbInsert(accQuery, {identifier, 'personal', 0, 0, accountNumber, os.time()})
    if not accId then return nil end
    
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
    
    return { account = account, cards = cards, logs = logs }
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

-----------------------------------
-- 📊 LOGS SYSTÈME
-----------------------------------
print('^2[KT Banque]^7 Système bancaire initialisé avec succès')
print('^3[KT Banque]^7 Mode 2 PNJ activé : PNJ1=Achat carte | PNJ2=Création compte')