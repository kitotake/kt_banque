local DB = Config.DB

BankLogs = {}

-----------------------------------
-- 📝 INSERTION LOG BANCAIRE
-----------------------------------
function BankLogs.insert(accountId, action, amount, identifier, description)
    local query = string.format(
        "INSERT INTO %s (account_id, action, amount, identifier, description) VALUES (?, ?, ?, ?, ?)",
        DB.bank_logs_table
    )
    BankUtils.dbExecute(query, {accountId, action, amount or 0, identifier, description})
    
    if Config.Debug then
        print(("^6[LOG]^7 Compte %s | Action: %s | Montant: $%s"):format(accountId, action, amount or 0))
    end
end

-----------------------------------
-- 📋 RÉCUPÉRATION HISTORIQUE
-----------------------------------
function BankLogs.getHistory(accountId, limit)
    limit = limit or 30
    local query = string.format(
        "SELECT action, amount, identifier, description, date FROM %s WHERE account_id = ? ORDER BY date DESC LIMIT ?",
        DB.bank_logs_table
    )
    return BankUtils.dbFetch(query, {accountId, limit}) or {}
end

-----------------------------------
-- 🔍 RÉCUPÉRATION LOGS ADMIN
-----------------------------------
function BankLogs.getAdminLogs(accountId, limit)
    limit = limit or 50
    local query = string.format(
        "SELECT * FROM %s WHERE account_id = ? ORDER BY date DESC LIMIT ?",
        DB.bank_logs_table
    )
    return BankUtils.dbFetch(query, {accountId, limit}) or {}
end

print('^2[KT Banque]^7 Système de logs chargé')