local DB = Config.DB

BankAccounts = {}

-----------------------------------
-- 📊 RÉCUPÉRER INFO COMPTE
-----------------------------------
function BankAccounts.getAccountInfo(accountId)
    local query = string.format(
        "SELECT * FROM %s WHERE account_id = ? LIMIT 1",
        DB.banking_table
    )
    local result = BankUtils.dbFetch(query, {accountId})
    return result[1] or nil
end

-----------------------------------
-- 💰 AJOUTER AU SOLDE
-----------------------------------
function BankAccounts.addMoney(accountId, amount)
    local current = BankUtils.getBalance(accountId)
    local newBalance = current + amount
    return BankUtils.updateBalance(accountId, newBalance)
end

-----------------------------------
-- 💸 RETIRER DU SOLDE
-----------------------------------
function BankAccounts.removeMoney(accountId, amount)
    local current = BankUtils.getBalance(accountId)
    if current < amount then return false end
    
    local newBalance = current - amount
    return BankUtils.updateBalance(accountId, newBalance)
end

-----------------------------------
-- 🔍 RECHERCHER COMPTE PAR IDENTIFIER
-----------------------------------
function BankAccounts.findByIdentifier(identifier)
    local query = string.format(
        "SELECT * FROM %s WHERE identifier = ? LIMIT 1",
        DB.banking_table
    )
    local result = BankUtils.dbFetch(query, {identifier})
    return result[1] or nil
end

-----------------------------------
-- 📋 LISTER TOUS LES COMPTES
-----------------------------------
function BankAccounts.getAllAccounts(limit)
    limit = limit or 100
    local query = string.format(
        "SELECT * FROM %s ORDER BY created_at DESC LIMIT ?",
        DB.banking_table
    )
    return BankUtils.dbFetch(query, {limit})
end

-----------------------------------
-- 🔄 TRANSFÉRER ENTRE COMPTES
-----------------------------------
function BankAccounts.transfer(fromAccountId, toAccountId, amount)
    -- Vérifier solde source
    local fromBalance = BankUtils.getBalance(fromAccountId)
    if fromBalance < amount then
        return false, "Solde insuffisant"
    end
    
    -- Vérifier existence compte destination
    local toAccount = BankAccounts.getAccountInfo(toAccountId)
    if not toAccount then
        return false, "Compte destinataire introuvable"
    end
    
    -- Effectuer le transfert
    BankAccounts.removeMoney(fromAccountId, amount)
    BankAccounts.addMoney(toAccountId, amount)
    
    return true, "Transfert effectué"
end

-----------------------------------
-- ❌ FERMER UN COMPTE
-----------------------------------
function BankAccounts.closeAccount(accountId)
    -- Désactiver les cartes associées
    local query1 = string.format(
        "UPDATE %s SET active = 0 WHERE account_id = ?",
        DB.bank_cards_table
    )
    BankUtils.dbExecute(query1, {accountId})
    
    -- Supprimer le compte (optionnel, peut juste mettre un flag 'closed')
    local query2 = string.format(
        "DELETE FROM %s WHERE account_id = ?",
        DB.banking_table
    )
    BankUtils.dbExecute(query2, {accountId})
    
    BankUtils.debugPrint(("Compte fermé: %s"):format(accountId))
    return true
end

-----------------------------------
-- 🏷️ RENOMMER UN COMPTE
-----------------------------------
function BankAccounts.renameAccount(accountId, newLabel)
    local query = string.format(
        "UPDATE %s SET label = ? WHERE account_id = ?",
        DB.banking_table
    )
    return BankUtils.dbExecute(query, {newLabel, accountId})
end

-----------------------------------
-- 📈 STATISTIQUES COMPTE
-----------------------------------
function BankAccounts.getStats(accountId)
    -- Total dépôts
    local query1 = string.format(
        "SELECT COALESCE(SUM(amount), 0) as total FROM %s WHERE account_id = ? AND action = 'deposit'",
        DB.bank_logs_table
    )
    local totalDeposits = BankUtils.dbFetchScalar(query1, {accountId}) or 0
    
    -- Total retraits
    local query2 = string.format(
        "SELECT COALESCE(SUM(amount), 0) as total FROM %s WHERE account_id = ? AND action = 'withdraw'",
        DB.bank_logs_table
    )
    local totalWithdraws = BankUtils.dbFetchScalar(query2, {accountId}) or 0
    
    -- Total transferts sortants
    local query3 = string.format(
        "SELECT COALESCE(SUM(amount), 0) as total FROM %s WHERE account_id = ? AND action = 'transfer_out'",
        DB.bank_logs_table
    )
    local totalTransfersOut = BankUtils.dbFetchScalar(query3, {accountId}) or 0
    
    -- Total transferts entrants
    local query4 = string.format(
        "SELECT COALESCE(SUM(amount), 0) as total FROM %s WHERE account_id = ? AND action = 'transfer_in'",
        DB.bank_logs_table
    )
    local totalTransfersIn = BankUtils.dbFetchScalar(query4, {accountId}) or 0
    
    -- Nombre de transactions
    local query5 = string.format(
        "SELECT COUNT(*) as count FROM %s WHERE account_id = ?",
        DB.bank_logs_table
    )
    local transactionCount = BankUtils.dbFetchScalar(query5, {accountId}) or 0
    
    return {
        total_deposits = totalDeposits,
        total_withdraws = totalWithdraws,
        total_transfers_out = totalTransfersOut,
        total_transfers_in = totalTransfersIn,
        transaction_count = transactionCount,
        current_balance = BankUtils.getBalance(accountId)
    }
end

-----------------------------------
-- 🔧 EXPORTS
-----------------------------------
exports('GetAccountInfo', BankAccounts.getAccountInfo)
exports('GetAccountBalance', BankUtils.getBalance)
exports('AddMoney', BankAccounts.addMoney)
exports('RemoveMoney', BankAccounts.removeMoney)
exports('Transfer', BankAccounts.transfer)
exports('GetStats', BankAccounts.getStats)

print('^2[KT Banque]^7 Gestion des comptes chargée')