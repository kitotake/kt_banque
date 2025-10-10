ESX = exports["es_extended"]:getSharedObject()
local DB = Config.DB

BankAccounts = {}

-----------------------------------
-- 📋 VÉRIFIER COMPTE EN ATTENTE (PNJ1 - ACHAT CARTE)
-----------------------------------
RegisterNetEvent('bank:server:checkPendingAccount', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then 
        print("^1[ERREUR]^7 Aucun xPlayer trouvé pour source:", src)
        return 
    end
    
    BankUtils.debugPrint(("Vérif compte - Joueur: %s"):format(xPlayer.getName()))
    
    -- Vérifier si le joueur a déjà une carte active dans son inventaire
    local cardItem = BankUtils.getCardFromInventory(src)
    if cardItem then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'info',
            description = "✅ Vous possédez déjà une carte bancaire active"
        })
        return
    end
    
    -- Chercher un compte appartenant au joueur
    local accountQuery = string.format("SELECT ID, label FROM %s WHERE identifier = ? LIMIT 1", DB.banking_table)
    local accountResult = BankUtils.dbFetch(accountQuery, {xPlayer.identifier})
    
    if not accountResult or not accountResult[1] then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "❌ Vous devez d'abord créer un compte au guichet d'ouverture (PNJ à côté)"
        })
        return
    end
    
    local accountId = accountResult[1].ID
    BankUtils.debugPrint(("Compte trouvé - ID: %s"):format(accountId))
    
    -- Vérifier si une carte active existe déjà pour ce compte
    local activeCardQuery = string.format("SELECT id FROM %s WHERE account_id = ? AND active = 1 LIMIT 1", DB.bank_cards_table)
    local activeCard = BankUtils.dbFetch(activeCardQuery, {accountId})
    
    if activeCard and activeCard[1] then
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
    local pendingCard = BankUtils.dbFetch(pendingCardQuery, {accountId})
    
    if pendingCard and pendingCard[1] then
        BankUtils.debugPrint(("Carte pending trouvée - ID: %s"):format(pendingCard[1].id))
        TriggerClientEvent('bank:client:showCardPurchaseMenu', src, accountId)
    else
        -- Créer une carte pending automatiquement
        local cardNum = BankUtils.generateCardNumber()
        local pin = string.format("%04d", math.random(1000, 9999))
        
        local insertCardQuery = string.format(
            "INSERT INTO %s (account_id, identifier, owner_name, card_number, pin, active, card_type) VALUES (?, ?, ?, ?, ?, ?, ?)",
            DB.bank_cards_table
        )
        local cardId = BankUtils.dbInsert(insertCardQuery, {
            accountId,
            xPlayer.identifier,
            xPlayer.getName(),
            cardNum,
            pin,
            0,
            'pending'
        })
        
        if cardId then
            print(("^2[SUCCÈS]^7 Carte pending créée - ID: %s | PIN: %s"):format(cardId, pin))
            TriggerClientEvent('bank:client:showCardPurchaseMenu', src, accountId)
        else
            TriggerClientEvent('ox_lib:notify', src, {
                type = 'error',
                description = "❌ Erreur lors de la création de la carte"
            })
        end
    end
end)

-----------------------------------
-- ✨ VÉRIFIER CRÉATION DE COMPTE (PNJ2)
-----------------------------------
RegisterNetEvent('bank:server:checkExistingAccount', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    BankUtils.debugPrint(("Demande création compte - Joueur: %s"):format(xPlayer.getName()))
    
    -- Vérifier si le joueur a déjà un compte
    local query = string.format("SELECT ID FROM %s WHERE identifier = ? LIMIT 1", DB.banking_table)
    local result = BankUtils.dbFetch(query, {xPlayer.identifier})
    
    if result and result[1] then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'info',
            description = "ℹ️ Vous possédez déjà un compte bancaire. Allez au guichet à côté pour acheter une carte."
        })
        return
    end
    
    TriggerClientEvent('bank:client:openAccountCreation', src)
end)

-----------------------------------
-- 🆕 CRÉER COMPTE UNIQUEMENT (SANS CARTE)
-----------------------------------
RegisterNetEvent('bank:server:createAccountOnly', function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local pin = tostring(data.pin or "0000")
    
    BankUtils.debugPrint(("Création compte - PIN: %s"):format(pin))
    
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
    local exists = BankUtils.dbFetch(checkQuery, {xPlayer.identifier})
    
    if exists and exists[1] then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "❌ Vous possédez déjà un compte bancaire"
        })
        return
    end
    
    -- Créer le compte
    local accountNumber = BankUtils.generateIBANLike()
    local insertAccQuery = string.format(
        "INSERT INTO %s (identifier, type, amount, balance, label, time) VALUES (?, ?, ?, ?, ?, ?)",
        DB.banking_table
    )
    local accId = BankUtils.dbInsert(insertAccQuery, {
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
    
    print(("^2[SUCCÈS]^7 Compte créé - ID: %s | IBAN: %s"):format(accId, accountNumber))
    
    -- Créer carte "pending"
    local cardNum = BankUtils.generateCardNumber()
    local insertCardQuery = string.format(
        "INSERT INTO %s (account_id, identifier, owner_name, card_number, pin, active, card_type) VALUES (?, ?, ?, ?, ?, ?, ?)",
        DB.bank_cards_table
    )
    local cardId = BankUtils.dbInsert(insertCardQuery, {
        accId,
        xPlayer.identifier,
        xPlayer.getName(),
        cardNum,
        pin,
        0,
        'pending'
    })
    
    if not cardId then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = Config.Notifications.error
        })
        return
    end
    
    BankLogs.insert(accId, "account_created", 0, xPlayer.identifier, "Compte créé - en attente de carte")
    
    TriggerClientEvent('bank:client:openNUI', src, nil)
    TriggerClientEvent('ox_lib:notify', src, {
        type = 'success',
        description = "✅ Compte créé ! Rendez-vous au guichet à côté pour acheter votre carte bancaire."
    })
end)

-----------------------------------
-- 💳 ACHETER CARTE BANCAIRE
-----------------------------------
RegisterNetEvent('bank:server:purchaseCard', function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local accountId = tonumber(data.account_id)
    local chosenType = tostring(data.card_type or "carte_basique")
    
    BankUtils.debugPrint(("Achat carte - Type: %s"):format(chosenType))
    
    if not accountId then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = "Compte invalide" })
        return
    end
    
    -- Vérifier que le compte appartient au joueur
    local account = BankUtils.getAccount(accountId)
    if not account or account.identifier ~= xPlayer.identifier then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = "Ce compte ne vous appartient pas" })
        return
    end
    
    -- Vérifier si une carte active existe déjà
    local cardQuery = string.format("SELECT id FROM %s WHERE account_id = ? AND active = 1 LIMIT 1", DB.bank_cards_table)
    local existingCard = BankUtils.dbFetch(cardQuery, {accountId})
    if existingCard and existingCard[1] then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = "Une carte active existe déjà" })
        return
    end
    
    -- Vérifier le prix
    local limits = Config.CardLimits[chosenType]
    if not limits then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = "Type de carte invalide" })
        return
    end
    
    local price = limits.Price or 0
    if price > 0 then
        local playerMoney = BankUtils.getPlayerMoney(src)
        if playerMoney < price then
            TriggerClientEvent('ox_lib:notify', src, {
                type = 'error',
                description = string.format("💵 Fonds insuffisants. Prix: $%s", price)
            })
            return
        end
        BankUtils.removePlayerMoney(src, price)
    end
    
    -- Récupérer ou créer la carte
    local pendingQuery = string.format(
        "SELECT id, pin, card_number FROM %s WHERE account_id = ? AND card_type = 'pending' LIMIT 1",
        DB.bank_cards_table
    )
    local pendingCard = BankUtils.dbFetch(pendingQuery, {accountId})
    
    local cardId, cardNum, pin
    
    if pendingCard and pendingCard[1] then
        cardId = pendingCard[1].id
        cardNum = pendingCard[1].card_number
        pin = pendingCard[1].pin
        
        local updateQuery = string.format("UPDATE %s SET active = 1, card_type = ? WHERE id = ?", DB.bank_cards_table)
        BankUtils.dbExecute(updateQuery, {chosenType, cardId})
    else
        cardNum = BankUtils.generateCardNumber()
        pin = string.format("%04d", math.random(0, 9999))
        
        local insertCardQuery = string.format(
            "INSERT INTO %s (account_id, identifier, owner_name, card_number, pin, active, card_type) VALUES (?, ?, ?, ?, ?, ?, ?)",
            DB.bank_cards_table
        )
        cardId = BankUtils.dbInsert(insertCardQuery, {
            accountId, xPlayer.identifier, xPlayer.getName(), cardNum, pin, 1, chosenType
        })
    end
    
    if not cardId then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = Config.Notifications.error })
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
        BankLogs.insert(accountId, "card_issued", price, xPlayer.identifier, "Carte émise: " .. chosenType)
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'success',
            description = "✅ Carte bancaire ajoutée à votre inventaire !"
        })
    else
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "❌ Erreur lors de l'ajout de la carte"
        })
    end
end)

-----------------------------------
-- 🏦 OUVRIR INTERFACE BANCAIRE
-----------------------------------
RegisterNetEvent('bank:server:requestOpen', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local cardItem = BankUtils.getCardFromInventory(src)
    
    if not cardItem then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = Config.Notifications.no_card })
        return
    end
    
    local dbCard = nil
    if cardItem.metadata and cardItem.metadata.id then
        dbCard = BankUtils.getCardFromDB(cardItem.metadata.id)
    end
    
    if not dbCard then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = "Carte invalide ou désactivée" })
        return
    end
    
    local account = BankUtils.getAccount(dbCard.account_id)
    if not account then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = "Compte introuvable" })
        return
    end
    
    local logs = BankLogs.getHistory(dbCard.account_id)
    local limits = BankUtils.getLimitsForCardType(dbCard.card_type)
    
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

print('^2[KT Banque]^7 Gestion des comptes chargée')