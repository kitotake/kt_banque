ESX = exports["es_extended"]:getSharedObject()
local DB = Config.DB

BankAdmin = {}

-----------------------------------
-- 🔧 DÉSACTIVER UNE CARTE
-----------------------------------
function BankAdmin.DeactivateCard(identifier)
    local query = string.format(
        "UPDATE %s SET active = 0 WHERE identifier = ?",
        DB.bank_cards_table
    )
    local affected = BankUtils.dbExecute(query, {identifier})
    
    if affected > 0 then
        BankUtils.debugPrint(("Carte désactivée pour: %s"):format(identifier))
        return true
    end
    return false
end

-----------------------------------
-- 🖨️ RÉIMPRIMER LE PIN
-----------------------------------
function BankAdmin.ReprintPin(identifier)
    local query = string.format(
        "SELECT pin, card_number FROM %s WHERE identifier = ? AND active = 1 LIMIT 1",
        DB.bank_cards_table
    )
    local result = BankUtils.dbFetch(query, {identifier})
    
    if result[1] then
        return {
            pin = result[1].pin,
            card_number = result[1].card_number
        }
    end
    return nil
end

-----------------------------------
-- 💳 CRÉER UNE CARTE POUR UN JOUEUR
-----------------------------------
function BankAdmin.CreateCardForPlayer(identifier, cardType, pin)
    -- Vérifier si le joueur a déjà une carte
    local existingCard = BankUtils.getCardByIdentifier(identifier)
    if existingCard then
        return false, "Le joueur possède déjà une carte"
    end
    
    -- Vérifier le type de carte
    if not Config.BankCardItem[cardType] then
        return false, "Type de carte invalide"
    end
    
    -- Vérifier le PIN
    if not pin or #tostring(pin) ~= 4 then
        return false, "PIN invalide (4 chiffres requis)"
    end
    
    -- Créer le compte
    local accountId = "ACC_" .. identifier:gsub(":", "_")
    local cardNumber = BankUtils.generateCardNumber()
    
    -- Insérer le compte
    local query1 = string.format(
        "INSERT INTO %s (account_id, identifier, balance, owner_name, label) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE identifier = identifier",
        DB.banking_table
    )
    BankUtils.dbExecute(query1, {accountId, identifier, 0, "Admin Created", "Compte Admin"})
    
    -- Insérer la carte
    local query2 = string.format(
        "INSERT INTO %s (identifier, account_id, card_number, pin, card_type, active) VALUES (?, ?, ?, ?, ?, ?)",
        DB.bank_cards_table
    )
    BankUtils.dbExecute(query2, {identifier, accountId, cardNumber, pin, cardType, 1})
    
    -- Log
    BankLogs.insert(accountId, 'card_issued', 0, identifier, "Carte créée par admin")
    
    return true, "Carte créée avec succès"
end

-----------------------------------
-- 📊 OBTENIR INFOS COMPTE
-----------------------------------
function BankAdmin.GetAccountInfo(identifier)
    local card = BankUtils.getCardByIdentifier(identifier)
    if not card then
        return nil, "Aucune carte trouvée"
    end
    
    local account = BankUtils.getAccount(card.account_id)
    if not account then
        return nil, "Compte introuvable"
    end
    
    local stats = BankAccounts.getStats(card.account_id)
    
    return {
        account_id = account.account_id,
        identifier = account.identifier,
        balance = account.balance,
        owner_name = account.owner_name,
        label = account.label,
        card_number = card.card_number,
        card_type = card.card_type,
        pin = card.pin,
        active = card.active,
        created_at = account.created_at,
        stats = stats
    }
end

-----------------------------------
-- 💰 DÉFINIR LE SOLDE
-----------------------------------
function BankAdmin.SetBalance(accountId, amount)
    amount = tonumber(amount)
    if not amount or amount < 0 then
        return false, "Montant invalide"
    end
    
    local success = BankUtils.updateBalance(accountId, amount)
    if success then
        BankLogs.insert(accountId, 'deposit', amount, 'ADMIN', "Solde modifié par admin")
        return true, "Solde mis à jour"
    end
    
    return false, "Erreur lors de la mise à jour"
end

-----------------------------------
-- 🗑️ SUPPRIMER UN COMPTE
-----------------------------------
function BankAdmin.DeleteAccount(accountId)
    -- Désactiver les cartes
    local query1 = string.format(
        "UPDATE %s SET active = 0 WHERE account_id = ?",
        DB.bank_cards_table
    )
    BankUtils.dbExecute(query1, {accountId})
    
    -- Supprimer le compte
    local query2 = string.format(
        "DELETE FROM %s WHERE account_id = ?",
        DB.banking_table
    )
    local affected = BankUtils.dbExecute(query2, {accountId})
    
    if affected > 0 then
        BankUtils.debugPrint(("Compte supprimé: %s"):format(accountId))
        return true, "Compte supprimé"
    end
    
    return false, "Compte introuvable"
end

-----------------------------------
-- 🔍 RECHERCHER DES COMPTES
-----------------------------------
function BankAdmin.SearchAccounts(searchTerm)
    local query = string.format(
        "SELECT * FROM %s WHERE account_id LIKE ? OR identifier LIKE ? OR owner_name LIKE ? LIMIT 50",
        DB.banking_table
    )
    local pattern = "%" .. searchTerm .. "%"
    return BankUtils.dbFetch(query, {pattern, pattern, pattern})
end

-----------------------------------
-- 📈 STATISTIQUES GLOBALES
-----------------------------------
function BankAdmin.GetGlobalStats()
    -- Nombre total de comptes
    local query1 = string.format("SELECT COUNT(*) as count FROM %s", DB.banking_table)
    local totalAccounts = BankUtils.dbFetchScalar(query1, {}) or 0
    
    -- Solde total
    local query2 = string.format("SELECT COALESCE(SUM(balance), 0) as total FROM %s", DB.banking_table)
    local totalBalance = BankUtils.dbFetchScalar(query2, {}) or 0
    
    -- Nombre de cartes actives
    local query3 = string.format("SELECT COUNT(*) as count FROM %s WHERE active = 1", DB.bank_cards_table)
    local activeCards = BankUtils.dbFetchScalar(query3, {}) or 0
    
    -- Nombre total de transactions
    local query4 = string.format("SELECT COUNT(*) as count FROM %s", DB.bank_logs_table)
    local totalTransactions = BankUtils.dbFetchScalar(query4, {}) or 0
    
    -- Répartition par type de carte
    local query5 = string.format(
        "SELECT card_type, COUNT(*) as count FROM %s WHERE active = 1 GROUP BY card_type",
        DB.bank_cards_table
    )
    local cardDistribution = BankUtils.dbFetch(query5, {})
    
    return {
        total_accounts = totalAccounts,
        total_balance = totalBalance,
        active_cards = activeCards,
        total_transactions = totalTransactions,
        card_distribution = cardDistribution
    }
end

-----------------------------------
-- 🛠️ COMMANDES ADMIN
-----------------------------------

-- Commande: /bank:info [id]
RegisterCommand('bank:info', function(source, args, rawCommand)
    if source == 0 then -- Console
        if not args[1] then
            print("Usage: /bank:info [server_id ou identifier]")
            return
        end
        
        local target = args[1]
        local identifier = nil
        
        -- Vérifier si c'est un ID serveur
        local targetPlayer = ESX.GetPlayerFromId(tonumber(target))
        if targetPlayer then
            identifier = targetPlayer.identifier
        else
            identifier = target
        end
        
        local info, err = BankAdmin.GetAccountInfo(identifier)
        if not info then
            print("❌ " .. (err or "Compte introuvable"))
            return
        end
        
        print("================== INFOS COMPTE ==================")
        print(("Compte ID: %s"):format(info.account_id))
        print(("Identifier: %s"):format(info.identifier))
        print(("Propriétaire: %s"):format(info.owner_name))
        print(("Solde: $%s"):format(info.balance))
        print(("Type de carte: %s"):format(info.card_type))
        print(("Numéro carte: %s"):format(info.card_number))
        print(("PIN: %s"):format(info.pin))
        print(("Active: %s"):format(info.active == 1 and "Oui" or "Non"))
        print(("Créé le: %s"):format(info.created_at))
        print("================ STATISTIQUES =================")
        print(("Total dépôts: $%s"):format(info.stats.total_deposits))
        print(("Total retraits: $%s"):format(info.stats.total_withdrawals))
        print(("Total transferts: $%s"):format(info.stats.total_transfers))
        print("================================================")
    else
        TriggerClientEvent('esx:showNotification', source, "❌ Seul le serveur peut utiliser cette commande")
    end
end)