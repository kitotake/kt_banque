ESX = exports["es_extended"]:getSharedObject()
local DB = Config.DB

BankAdmin = {}

-----------------------------------
-- 👑 EXPORTS ADMIN
-----------------------------------

-- Désactiver une carte
function BankAdmin.DeactivateCard(cardId)
    if not cardId then return false end
    local query = string.format("UPDATE %s SET active = 0 WHERE id = ?", DB.bank_cards_table)
    local result = BankUtils.dbExecute(query, {cardId})
    return result and result > 0
end

-- Réimprimer le PIN
function BankAdmin.ReprintPin(cardId)
    if not cardId then return nil end
    local newPin = string.format("%04d", math.random(0, 9999))
    local query = string.format("UPDATE %s SET pin = ? WHERE id = ?", DB.bank_cards_table)
    local result = BankUtils.dbExecute(query, {newPin, cardId})
    if result and result > 0 then return newPin end
    return nil
end

-- Créer une carte admin pour un joueur
function BankAdmin.CreateCardForPlayer(identifier, cardType, ownerName)
    if not identifier or not cardType then return nil end
    local playerLabel = ownerName or identifier
    cardType = cardType or "carte_basique"
    
    local accountNumber = BankUtils.generateIBANLike()
    local accQuery = string.format(
        "INSERT INTO %s (identifier, type, amount, balance, label, time) VALUES (?, ?, ?, ?, ?, ?)",
        DB.banking_table
    )
    local accId = BankUtils.dbInsert(accQuery, {identifier, 'personal', 0, 0, accountNumber, os.time()})
    if not accId then return nil end
    
    local cardNum = BankUtils.generateCardNumber()
    local newPin = string.format("%04d", math.random(0, 9999))
    local cardQuery = string.format(
        "INSERT INTO %s (account_id, identifier, owner_name, card_number, pin, active, card_type) VALUES (?, ?, ?, ?, ?, ?, ?)",
        DB.bank_cards_table
    )
    local cardId = BankUtils.dbInsert(cardQuery, {accId, identifier, playerLabel, cardNum, newPin, 1, cardType})
    if not cardId then return nil end
    
    BankLogs.insert(accId, "admin_created", 0, identifier, "Compte créé par admin")
    
    return {
        account_id = accId,
        card_id = cardId,
        pin = newPin,
        account_number = accountNumber,
        card_number = cardNum
    }
end

-- Récupérer les infos d'un compte
function BankAdmin.GetAccountInfo(accountId)
    if not accountId then return nil end
    local account = BankUtils.getAccount(accountId)
    if not account then return nil end
    
    local cardQuery = string.format(
        "SELECT * FROM %s WHERE account_id = ? ORDER BY created_at DESC",
        DB.bank_cards_table
    )
    local cards = BankUtils.dbFetch(cardQuery, {accountId}) or {}
    
    local logs = BankLogs.getAdminLogs(accountId)
    
    return { account = account, cards = cards, logs = logs }
end

-- Modifier le solde
function BankAdmin.SetBalance(accountId, newBalance)
    if not accountId or not newBalance then return false end
    local query = string.format("UPDATE %s SET balance = ? WHERE ID = ?", DB.banking_table)
    local result = BankUtils.dbExecute(query, {newBalance, accountId})
    if result and result > 0 then
        BankLogs.insert(accountId, "admin_set_balance", newBalance, "system", "Balance modifiée par admin")
        return true
    end
    return false
end

-----------------------------------
-- 🛠️ COMMANDES ADMIN
-----------------------------------

-- Réparer un compte (créer carte pending si manquante)
RegisterCommand('bank:repair', function(source, args)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    
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
    
    local accountQuery = string.format("SELECT ID FROM %s WHERE identifier = ? LIMIT 1", DB.banking_table)
    local accountResult = BankUtils.dbFetch(accountQuery, {targetPlayer.identifier})
    
    if not accountResult or not accountResult[1] then
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = "❌ Ce joueur n'a pas de compte"
        })
        return
    end
    
    local accountId = accountResult[1].ID
    
    local pendingQuery = string.format("SELECT id FROM %s WHERE account_id = ? AND active = 0", DB.bank_cards_table)
    local pendingCard = BankUtils.dbFetch(pendingQuery, {accountId})
    
    if pendingCard and pendingCard[1] then
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'info',
            description = "Une carte pending existe déjà pour ce compte"
        })
        return
    end
    
    local cardNum = BankUtils.generateCardNumber()
    local pin = string.format("%04d", math.random(1000, 9999))
    
    local insertCardQuery = string.format(
        "INSERT INTO %s (account_id, identifier, owner_name, card_number, pin, active, card_type) VALUES (?, ?, ?, ?, ?, ?, ?)",
        DB.bank_cards_table
    )
    local cardId = BankUtils.dbInsert(insertCardQuery, {
        accountId, targetPlayer.identifier, targetPlayer.getName(), cardNum, pin, 0, 'pending'
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
    
    local accountQuery = string.format("SELECT * FROM %s WHERE identifier = ? LIMIT 1", DB.banking_table)
    local accountResult = BankUtils.dbFetch(accountQuery, {targetPlayer.identifier})
    
    if not accountResult or not accountResult[1] then
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = "❌ Ce joueur n'a pas de compte"
        })
        return
    end
    
    local account = accountResult[1]
    local cardsQuery = string.format("SELECT * FROM %s WHERE account_id = ?", DB.bank_cards_table)
    local cards = BankUtils.dbFetch(cardsQuery, {account.ID}) or {}
    
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
                card.id, card.card_type, status, card.pin
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
    
    if not Config.BankCardItem[cardType] then
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = "❌ Type de carte invalide"
        })
        return
    end
    
    local result = BankAdmin.CreateCardForPlayer(targetPlayer.identifier, cardType, targetPlayer.getName())
    
    if result then
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

-- Exports
exports('AdminDeactivateCard', BankAdmin.DeactivateCard)
exports('AdminReprintPin', BankAdmin.ReprintPin)
exports('AdminCreateCardForPlayer', BankAdmin.CreateCardForPlayer)
exports('AdminGetAccountInfo', BankAdmin.GetAccountInfo)
exports('AdminSetBalance', BankAdmin.SetBalance)

print('^2[KT Banque]^7 Système admin chargé - Commandes: /bank:repair, /bank:info, /bank:givecard')