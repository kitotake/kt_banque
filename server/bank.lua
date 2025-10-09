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
        local cardNum = string.format("4%07d%04d", math.random(0, 9999999), math.random(1000, 9999))
        
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
    if not xPlayer then 
        print("^1[ERREUR]^7 Aucun xPlayer trouvé pour source:", src)
        return 
    end
    
    print(("^3[PNJ1 - Vérif Compte]^7 Joueur: %s | Identifier: %s"):format(xPlayer.getName(), xPlayer.identifier))
    
    -- Vérifier si le joueur a déjà une carte active dans son inventaire
    local cardItem = getCardFromInventory(src)
    if cardItem then
        print("^6[INFO]^7 Le joueur possède déjà une carte active dans son inventaire")
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'info',
            description = "✅ Vous possédez déjà une carte bancaire active"
        })
        return
    end
    
    -- Chercher un compte appartenant au joueur
    local accountQuery = string.format(
        "SELECT ID, label FROM %s WHERE identifier = ? LIMIT 1",
        DB.banking_table
    )
    local accountResult = dbFetch(accountQuery, {xPlayer.identifier})
    
    if not accountResult or not accountResult[1] then
        print("^1[ERREUR]^7 Aucun compte trouvé pour ce joueur")
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "❌ Vous devez d'abord créer un compte au guichet d'ouverture (PNJ à côté)"
        })
        return
    end
    
    local accountId = accountResult[1].ID
    print(("^6[INFO]^7 Compte trouvé - ID: %s"):format(accountId))
    
    -- Vérifier si une carte active existe déjà pour ce compte
    local activeCardQuery = string.format(
        "SELECT id FROM %s WHERE account_id = ? AND active = 1 LIMIT 1",
        DB.bank_cards_table
    )
    local activeCard = dbFetch(activeCardQuery, {accountId})
    
    if activeCard and activeCard[1] then
        print("^1[ERREUR]^7 Une carte active existe déjà en base mais pas dans l'inventaire")
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "⚠️ Une carte existe déjà pour ce compte. Contactez un administrateur si vous l'avez perdue."
        })
        return
    end
    
    -- Vérifier s'il existe une carte pending
    local pendingCardQuery = string.format(
        "SELECT id, pin FROM %s WHERE account_id = ? AND (active = 0 OR card_type = 'pending') LIMIT 1",
        DB.bank_cards_table
    )
    local pendingCard = dbFetch(pendingCardQuery, {accountId})
    
    if pendingCard and pendingCard[1] then
        print(("^2[SUCCÈS]^7 Carte pending trouvée - ID: %s"):format(pendingCard[1].id))
        TriggerClientEvent('bank:client:showCardPurchaseMenu', src, accountId)
    else
        print("^3[INFO]^7 Aucune carte pending trouvée, création automatique...")
        
        -- Créer une carte pending automatiquement si elle n'existe pas
        local cardNum = generateCardNumber()
        local pin = string.format("%04d", math.random(1000, 9999))
        
        local insertCardQuery = string.format(
            "INSERT INTO %s (account_id, identifier, owner_name, card_number, pin, active, card_type) VALUES (?, ?, ?, ?, ?, ?, ?)",
            DB.bank_cards_table
        )
        local cardId = dbInsert(insertCardQuery, {
            accountId,
            xPlayer.identifier,
            xPlayer.getName(),
            cardNum,
            pin,
            0, -- Inactive
            'pending' -- Type temporaire
        })
        
        if cardId then
            print(("^2[SUCCÈS]^7 Carte pending créée automatiquement - ID: %s | PIN: %s"):format(cardId, pin))
            TriggerClientEvent('bank:client:showCardPurchaseMenu', src, accountId)
        else
            print("^1[ERREUR]^7 Impossible de créer la carte pending")
            TriggerClientEvent('ox_lib:notify', src, {
                type = 'error',
                description = "❌ Erreur lors de la création de la carte. Contactez un administrateur."
            })
        end
    end
end)

-----------------------------------
-- ✨ EVENT: VÉRIFIER CRÉATION DE COMPTE (PNJ2)
-----------------------------------
RegisterNetEvent('bank:server:checkExistingAccount', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)

    print(("^3[PNJ2 - Création Compte]^7 Appel reçu du joueur [src: %s]"):format(src))

    if not xPlayer then
        print(("^1[ERREUR]^7 Aucun joueur trouvé pour src %s"):format(src))
        return
    end

    print(("^2[xPlayer]^7 Trouvé → Nom: %s | Identifier: %s"):format(xPlayer.getName(), xPlayer.identifier))

    -- Vérifier si le joueur a déjà un compte
    local query = string.format("SELECT ID FROM %s WHERE identifier = ? LIMIT 1", DB.banking_table)
    local result = dbFetch(query, {xPlayer.identifier})

    if result and result[1] then
        print(("^6[Compte existant]^7 ID: %s pour %s"):format(result[1].ID, xPlayer.identifier))
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'info',
            description = "ℹ️ Vous possédez déjà un compte bancaire. Allez au guichet à côté pour acheter une carte."
        })
        return
    end

    print(("^5[Action]^7 Ouverture interface création de compte pour %s"):format(xPlayer.getName()))
    TriggerClientEvent('bank:client:openAccountCreation', src)
end)

-----------------------------------
-- 🆕 EVENT: CRÉER COMPTE UNIQUEMENT (SANS CARTE)
-----------------------------------
RegisterNetEvent('bank:server:createAccountOnly', function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local pin = tostring(data.pin or "0000")
    
    print(("^3[Création Compte]^7 Joueur: %s | PIN: %s"):format(xPlayer.getName(), pin))
    
    -- Validation PIN
    if #pin ~= 4 or not tonumber(pin) then
        print("^1[ERREUR]^7 PIN invalide")
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
        print("^1[ERREUR]^7 Compte déjà existant")
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
        print("^1[ERREUR]^7 Impossible de créer le compte")
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = Config.Notifications.error
        })
        return
    end
    
    print(("^2[SUCCÈS]^7 Compte créé - ID: %s | IBAN: %s"):format(accId, accountNumber))
    
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
        print("^1[ERREUR]^7 Impossible de créer la carte pending")
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = Config.Notifications.error
        })
        return
    end
    
    print(("^2[SUCCÈS]^7 Carte pending créée - ID: %s"):format(cardId))
    
    insertLog(accId, "account_created", 0, xPlayer.identifier, "Compte créé - en attente de carte")
    
    -- Fermer l'interface
    TriggerClientEvent('bank:client:openNUI', src, nil)
    
    TriggerClientEvent('ox_lib:notify', src, {
        type = 'success',
        description = "✅ Compte créé ! Rendez-vous au guichet à côté pour acheter votre carte bancaire."
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
    
    print(("^3[Achat Carte]^7 Joueur: %s | Compte: %s | Type: %s"):format(xPlayer.getName(), accountId, chosenType))
    
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
        print("^1[ERREUR]^7 Compte n'appartient pas au joueur")
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
        print("^1[ERREUR]^7 Carte active déjà existante")
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "Une carte active existe déjà pour ce compte"
        })
        return
    end
    
    -- Vérifier le prix
    local limits = Config.CardLimits[chosenType]
    if not limits then
        print("^1[ERREUR]^7 Type de carte invalide")
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
            print(("^1[ERREUR]^7 Fonds insuffisants - Requis: %s | Possédé: %s"):format(price, playerMoney))
            TriggerClientEvent('ox_lib:notify', src, {
                type = 'error',
                description = string.format("💵 Fonds insuffisants. Prix: $%s", price)
            })
            return
        end
        exports.ox_inventory:RemoveItem(src, 'money', price)
        print(("^6[PAIEMENT]^7 $%s prélevés"):format(price))
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
        print(("^2[SUCCÈS]^7 Carte pending activée - ID: %s"):format(cardId))
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
        print(("^2[SUCCÈS]^7 Nouvelle carte créée - ID: %s"):format(cardId))
    end
    
    if not cardId then
        print("^1[ERREUR]^7 Impossible de créer/activer la carte")
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
        account_number = account.label,
        description = string.format("Carte bancaire %s\nTitulaire: %s", chosenType, xPlayer.getName())
    }
    
    local itemName = Config.BankCardItem[chosenType]
    local success = exports.ox_inventory:AddItem(src, itemName, 1, metadata)
    
    if success then
        insertLog(accountId, "card_issued", price, xPlayer.identifier, "Carte émise: " .. chosenType)
        print(("^2[SUCCÈS TOTAL]^7 Carte %s ajoutée à l'inventaire"):format(chosenType))
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'success',
            description = "✅ Carte bancaire ajoutée à votre inventaire !"
        })
    else
        print("^1[ERREUR]^7 Impossible d'ajouter la carte à l'inventaire")
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "❌ Erreur lors de l'ajout de la carte à votre inventaire"
        })
    end
end)

-----------------------------------
-- 🏦 EVENT: OUVRIR INTERFACE BANCAIRE
-----------------------------------
RegisterNetEvent('bank:server:requestOpen', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    print(("^3[Ouverture Interface]^7 Joueur: %s"):format(xPlayer.getName()))
    
    local cardItem = getCardFromInventory(src)
    
    if not cardItem then
        print("^1[ERREUR]^7 Aucune carte trouvée dans l'inventaire")
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
        print("^1[ERREUR]^7 Carte invalide ou désactivée")
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "Carte invalide ou désactivée"
        })
        return
    end
    
    local account = getAccount(dbCard.account_id)
    if not account then
        print("^1[ERREUR]^7 Compte introuvable")
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
    
    print(("^2[SUCCÈS]^7 Interface ouverte - Solde: $%s"):format(account.balance))
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
    
    print(("^3[Dépôt]^7 Joueur: %s | Montant: $%s"):format(xPlayer.getName(), amount))
    
    if not amount or amount <= 0 then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "Montant invalide"
        })
        return
    end
    
    local cardRow, err = validatePinAndGetCard(cardId, pin)
    if not cardRow then
        print(("^1[ERREUR]^7 %s"):format(err))
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = err
        })
        return
    end
    
    local limits = getLimitsForCardType(cardRow.card_type)
    if amount > limits.MaxDeposit then
        print(("^1[ERREUR]^7 Limite dépassée - Max: $%s"):format(limits.MaxDeposit))
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = string.format("💳 Limite de dépôt: $%s", limits.MaxDeposit)
        })
        return
    end
    
    local playerMoney = xPlayer.getMoney()
    if playerMoney < amount then
        print(("^1[ERREUR]^7 Argent insuffisant - Requis: $%s | Possédé: $%s"):format(amount, playerMoney))
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
    
    print(("^2[SUCCÈS]^7 Dépôt de $%s effectué"):format(amount))
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
    
    print(("^3[Retrait]^7 Joueur: %s | Montant: $%s"):format(xPlayer.getName(), amount))
    
    if not amount or amount <= 0 then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "Montant invalide"
        })
        return
    end
    
    local cardRow, err = validatePinAndGetCard(cardId, pin)
    if not cardRow then
        print(("^1[ERREUR]^7 %s"):format(err))
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = err
        })
        return
    end
    
    local limits = getLimitsForCardType(cardRow.card_type)
    if amount > limits.MaxWithdraw then
        print(("^1[ERREUR]^7 Limite dépassée - Max: $%s"):format(limits.MaxWithdraw))
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = string.format("💳 Limite de retrait: $%s", limits.MaxWithdraw)
        })
        return
    end
    
    local acc = getAccount(cardRow.account_id)
    if not acc or (acc.balance or 0) < amount then
        print(("^1[ERREUR]^7 Solde insuffisant - Requis: $%s | Solde: $%s"):format(amount, acc and acc.balance or 0))
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
    
    print(("^2[SUCCÈS]^7 Retrait de $%s effectué"):format(amount))
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
    
    print(("^3[Transfert]^7 Joueur: %s | Montant: $%s | Cible: %s"):format(xPlayer.getName(), amount, target))
    
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
        print(("^1[ERREUR]^7 %s"):format(err))
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = err
        })
        return
    end
    
    local fromAcc = getAccount(cardRow.account_id)
    if not fromAcc or (fromAcc.balance or 0) < amount then
        print(("^1[ERREUR]^7 Solde insuffisant - Requis: $%s | Solde: $%s"):format(amount, fromAcc and fromAcc.balance or 0))
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
        print("^1[ERREUR]^7 Compte destinataire introuvable")
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = Config.Notifications.target_not_found
        })
        return
    end
    
    if targetAcc.ID == fromAcc.ID then
        print("^1[ERREUR]^7 Tentative de transfert vers soi-même")
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "❌ Vous ne pouvez pas transférer vers votre propre compte"
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
    
    print(("^2[SUCCÈS]^7 Transfert de $%s vers compte ID %s"):format(amount, targetAcc.ID))
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

-- À ajouter à la fin de server/bank.lua

-----------------------------------
-- 🛠️ COMMANDES ADMIN
-----------------------------------

-- Réparer un compte (créer carte pending si manquante)
RegisterCommand('bank:repair', function(source, args)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    
    -- Vérifier si admin (adaptez selon votre système de permissions)
    if not xPlayer.getGroup() or xPlayer.getGroup() ~= 'admin' then
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = "❌ Vous n'avez pas la permission"
        })
        return
    end
    
    local targetId = tonumber(args[1])
    if not targetId then
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = "Usage: /bank:repair [ID du joueur]"
        })
        return
    end
    
    local targetPlayer = ESX.GetPlayerFromId(targetId)
    if not targetPlayer then
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = "❌ Joueur introuvable"
        })
        return
    end
    
    -- Chercher le compte
    local accountQuery = string.format(
        "SELECT ID FROM %s WHERE identifier = ? LIMIT 1",
        DB.banking_table
    )
    local accountResult = dbFetch(accountQuery, {targetPlayer.identifier})
    
    if not accountResult or not accountResult[1] then
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = "❌ Ce joueur n'a pas de compte"
        })
        return
    end
    
    local accountId = accountResult[1].ID
    
    -- Vérifier si une carte pending existe déjà
    local pendingQuery = string.format(
        "SELECT id FROM %s WHERE account_id = ? AND active = 0",
        DB.bank_cards_table
    )
    local pendingCard = dbFetch(pendingQuery, {accountId})
    
    if pendingCard and pendingCard[1] then
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'info',
            description = "ℹ️ Une carte pending existe déjà pour ce compte"
        })
        return
    end
    
    -- Créer une carte pending
    local cardNum = generateCardNumber()
    local pin = string.format("%04d", math.random(1000, 9999))
    
    local insertCardQuery = string.format(
        "INSERT INTO %s (account_id, identifier, owner_name, card_number, pin, active, card_type) VALUES (?, ?, ?, ?, ?, ?, ?)",
        DB.bank_cards_table
    )
    local cardId = dbInsert(insertCardQuery, {
        accountId,
        targetPlayer.identifier,
        targetPlayer.getName(),
        cardNum,
        pin,
        0,
        'pending'
    })
    
    if cardId then
        print(("^2[ADMIN REPAIR]^7 Carte pending créée pour %s - PIN: %s"):format(targetPlayer.getName(), pin))
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'success',
            description = string.format("✅ Carte pending créée pour %s\nPIN: %s", targetPlayer.getName(), pin)
        })
        TriggerClientEvent('ox_lib:notify', targetId, {
            type = 'success',
            description = "✅ Votre compte a été réparé ! Allez au guichet pour acheter une carte."
        })
    else
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = "❌ Erreur lors de la création de la carte"
        })
    end
end, false)

-- Voir les infos d'un compte
RegisterCommand('bank:info', function(source, args)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    
    -- Vérifier si admin
    if not xPlayer.getGroup() or xPlayer.getGroup() ~= 'admin' then
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = "❌ Vous n'avez pas la permission"
        })
        return
    end
    
    local targetId = tonumber(args[1])
    if not targetId then
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = "Usage: /bank:info [ID du joueur]"
        })
        return
    end
    
    local targetPlayer = ESX.GetPlayerFromId(targetId)
    if not targetPlayer then
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = "❌ Joueur introuvable"
        })
        return
    end
    
    -- Chercher le compte
    local accountQuery = string.format(
        "SELECT * FROM %s WHERE identifier = ? LIMIT 1",
        DB.banking_table
    )
    local accountResult = dbFetch(accountQuery, {targetPlayer.identifier})
    
    if not accountResult or not accountResult[1] then
        print(("^1[BANK INFO]^7 %s n'a pas de compte"):format(targetPlayer.getName()))
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = "❌ Ce joueur n'a pas de compte"
        })
        return
    end
    
    local account = accountResult[1]
    
    -- Chercher les cartes
    local cardsQuery = string.format(
        "SELECT * FROM %s WHERE account_id = ?",
        DB.bank_cards_table
    )
    local cards = dbFetch(cardsQuery, {account.ID}) or {}
    
    print("^2========================================^7")
    print(("^3[BANK INFO]^7 Joueur: %s"):format(targetPlayer.getName()))
    print(("^6[Compte]^7 ID: %s | IBAN: %s"):format(account.ID, account.label))
    print(("^6[Solde]^7 $%s"):format(account.balance))
    print("^5[Cartes:]^7")
    
    if #cards == 0 then
        print("  ^1Aucune carte^7")
    else
        for _, card in ipairs(cards) do
            local status = card.active == 1 and "^2ACTIVE^7" or "^1INACTIVE^7"
            print(("  - ID: %s | Type: %s | Status: %s | PIN: %s"):format(
                card.id, 
                card.card_type, 
                status,
                card.pin
            ))
        end
    end
    print("^2========================================^7")
    
    TriggerClientEvent('ox_lib:notify', source, {
        type = 'success',
        description = "✅ Infos affichées dans la console serveur"
    })
end, false)

-- Donner une carte à un joueur
RegisterCommand('bank:givecard', function(source, args)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    
    -- Vérifier si admin
    if not xPlayer.getGroup() or xPlayer.getGroup() ~= 'admin' then
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = "❌ Vous n'avez pas la permission"
        })
        return
    end
    
    local targetId = tonumber(args[1])
    local cardType = args[2] or 'carte_basique'
    
    if not targetId then
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = "Usage: /bank:givecard [ID] [carte_basique|carte_or|carte_dimas]"
        })
        return
    end
    
    local targetPlayer = ESX.GetPlayerFromId(targetId)
    if not targetPlayer then
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = "❌ Joueur introuvable"
        })
        return
    end
    
    -- Vérifier que le type de carte existe
    if not Config.BankCardItem[cardType] then
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = "❌ Type de carte invalide"
        })
        return
    end
    
    -- Utiliser la fonction admin
    local result = AdminCreateCardForPlayer(targetPlayer.identifier, cardType, targetPlayer.getName())
    
    if result then
        -- Ajouter la carte à l'inventaire
        local metadata = {
            id = result.card_id,
            account_id = result.account_id,
            owner = targetPlayer.getName(),
            card_number = result.card_number,
            card_type = cardType,
            account_number = result.account_number,
            description = string.format("Carte %s\nPIN: %s", cardType, result.pin)
        }
        
        local itemName = Config.BankCardItem[cardType]
        local success = exports.ox_inventory:AddItem(targetId, itemName, 1, metadata)
        
        if success then
            print(("^2[ADMIN GIVE]^7 Carte %s donnée à %s - PIN: %s"):format(cardType, targetPlayer.getName(), result.pin))
            TriggerClientEvent('ox_lib:notify', source, {
                type = 'success',
                description = string.format("✅ Carte donnée à %s\nPIN: %s", targetPlayer.getName(), result.pin)
            })
            TriggerClientEvent('ox_lib:notify', targetId, {
                type = 'success',
                description = string.format("✅ Vous avez reçu une %s !\nPIN: %s", cardType, result.pin)
            })
        else
            TriggerClientEvent('ox_lib:notify', source, {
                type = 'error',
                description = "❌ Erreur lors de l'ajout à l'inventaire"
            })
        end
    else
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = "❌ Erreur lors de la création de la carte"
        })
    end
end, false)

print('^5[KT Banque]^7 Commandes admin chargées: /bank:repair, /bank:info, /bank:givecard')
-----------------------------------
-- 📊 LOGS SYSTÈME
-----------------------------------
print('^2========================================^7')
print('^2[KT Banque]^7 Système bancaire initialisé')
print('^3[Mode]^7 2 PNJ séparés')
print('^6[PNJ1]^7 Achat de carte bancaire')
print('^6[PNJ2]^7 Création de compte')
print('^2========================================^7')

-- Exports
exports('AdminDeactivateCard', AdminDeactivateCard)
exports('AdminReprintPin', AdminReprintPin)
exports('AdminCreateCardForPlayer', AdminCreateCardForPlayer)
exports('AdminGetAccountInfo', AdminGetAccountInfo)
exports('AdminSetBalance', AdminSetBalance)