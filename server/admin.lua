-- ==================== KT BANQUE v7.5.0 — SERVER/ADMIN ====================
-- Commandes et exports d'administration.
-- Toutes les actions sont tracées dans bank_logs.
-- Permission requise : Config.AdminAce (défaut "group.admin")

local function IsAdmin(src)
    return IsPlayerAceAllowed(src, Config.AdminAce)
end

local function AdminNotify(src, msg)
    TriggerClientEvent('bank:client:notify', src, 'info', msg)
end

-- ──────────────────────────────────────────
-- COMMANDES ADMIN
-- ──────────────────────────────────────────

-- /bank_status <uniqueId> <active|suspended|closed>
RegisterCommand("bank_status", function(src, args)
    if not IsAdmin(src) then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang.no_permission)
        return
    end

    local uid    = args[1]
    local status = args[2]
    local valid  = { active = true, suspended = true, closed = true }

    if not uid or not valid[status] then
        AdminNotify(src, "Usage : /bank_status <uniqueId> <active|suspended|closed>")
        return
    end

    local affected = DB.SetAccountStatus(uid, status)
    if affected and affected > 0 then
        DB.Log(uid, 'admin_status_change', ('Statut → %s par admin src=%d'):format(status, src))
        AdminNotify(src, ('✅ Compte %s → %s'):format(uid, status))
    else
        AdminNotify(src, "❌ Compte introuvable.")
    end
end, false)

-- /bank_addmoney <uniqueId> <montant>
RegisterCommand("bank_addmoney", function(src, args)
    if not IsAdmin(src) then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang.no_permission)
        return
    end

    local uid    = args[1]
    local amount = math.floor(tonumber(args[2]) or 0)

    if not uid or amount <= 0 then
        AdminNotify(src, "Usage : /bank_addmoney <uniqueId> <montant>")
        return
    end

    local acc = DB.GetAccountAny(uid)
    if not acc then AdminNotify(src, "❌ Compte introuvable."); return end

    local newBalance = acc.balance + amount
    DB.UpdateBalance(acc.id, newBalance)
    DB.AddTransaction(acc.id, 'admin', 'admin', amount, newBalance, nil,
        ('Admin AddMoney — src=%d'):format(src))
    DB.Log(uid, 'admin_add_money', ('$%d ajouté par admin src=%d'):format(amount, src))
    AdminNotify(src, ('✅ $%d ajouté sur %s (nouveau solde : $%d)'):format(amount, uid, newBalance))
end, false)

-- /bank_removemoney <uniqueId> <montant>
RegisterCommand("bank_removemoney", function(src, args)
    if not IsAdmin(src) then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang.no_permission)
        return
    end

    local uid    = args[1]
    local amount = math.floor(tonumber(args[2]) or 0)

    if not uid or amount <= 0 then
        AdminNotify(src, "Usage : /bank_removemoney <uniqueId> <montant>")
        return
    end

    local acc = DB.GetAccountAny(uid)
    if not acc then AdminNotify(src, "❌ Compte introuvable."); return end
    if acc.balance < amount then AdminNotify(src, "❌ Solde insuffisant."); return end

    local newBalance = acc.balance - amount
    DB.UpdateBalance(acc.id, newBalance)
    DB.AddTransaction(acc.id, 'admin', 'admin', amount, newBalance, nil,
        ('Admin RemoveMoney — src=%d'):format(src))
    DB.Log(uid, 'admin_remove_money', ('$%d retiré par admin src=%d'):format(amount, src))
    AdminNotify(src, ('✅ $%d retiré de %s (nouveau solde : $%d)'):format(amount, uid, newBalance))
end, false)

-- /bank_info <uniqueId>
RegisterCommand("bank_info", function(src, args)
    if not IsAdmin(src) then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang.no_permission)
        return
    end

    local uid = args[1]
    if not uid then AdminNotify(src, "Usage : /bank_info <uniqueId>"); return end

    local acc = DB.GetAccountAny(uid)
    if not acc then AdminNotify(src, "❌ Compte introuvable."); return end

    local info = ('📋 %s | IBAN: %s | Solde: $%d | Statut: %s'):format(
        acc.account_number, acc.iban, acc.balance, acc.status)
    AdminNotify(src, info)
end, false)

-- /bank_total  — somme globale de tous les comptes actifs
RegisterCommand("bank_total", function(src, args)
    if not IsAdmin(src) then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang.no_permission)
        return
    end
    local total = DB.GetGlobalTotal()
    AdminNotify(src, ('💰 Total en banque : $%d'):format(total))
end, false)

-- /bank_logs <uniqueId> [limit]
RegisterCommand("bank_logs", function(src, args)
    if not IsAdmin(src) then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang.no_permission)
        return
    end

    local uid   = args[1]
    local limit = tonumber(args[2]) or 10
    if not uid then AdminNotify(src, "Usage : /bank_logs <uniqueId> [limit]"); return end

    local logs = DB.GetLogs(uid, limit)
    if not logs or #logs == 0 then
        AdminNotify(src, "Aucun log pour ce compte.")
        return
    end

    -- Affichage dans la console serveur pour l'admin
    print(('[KT Banque] Logs pour %s :'):format(uid))
    for _, log in ipairs(logs) do
        print(('  [%s] %s — %s'):format(log.created_at, log.action, log.details or ""))
    end
    AdminNotify(src, ('📜 %d log(s) affiché(s) dans la console serveur.'):format(#logs))
end, false)

-- ──────────────────────────────────────────
-- EXPORTS SERVEUR (API externe)
-- ──────────────────────────────────────────

exports('GetAccountBalance', function(uniqueId)
    local acc = DB.GetAccount(uniqueId)
    return acc and acc.balance or nil
end)

exports('GetAccountInfo', function(uniqueId)
    local acc = DB.GetAccountAny(uniqueId)
    if not acc then return nil end
    return {
        id             = acc.id,
        account_number = acc.account_number,
        iban           = acc.iban,
        balance        = acc.balance,
        status         = acc.status,
        label          = acc.label
    }
end)

exports('GetAllAccountsTotal', function()
    return DB.GetGlobalTotal()
end)

exports('SetAccountStatus', function(uniqueId, status)
    local valid = { active = true, suspended = true, closed = true }
    if not valid[status] then return false, "Statut invalide" end
    local affected = DB.SetAccountStatus(uniqueId, status)
    if affected and affected > 0 then
        DB.Log(uniqueId, 'api_status_change', 'Statut → ' .. status)
        return true, "OK"
    end
    return false, "Compte introuvable"
end)

exports('AddMoney', function(uniqueId, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end
    local acc = DB.GetAccountAny(uniqueId)
    if not acc then return false end
    local newBalance = acc.balance + amount
    DB.UpdateBalance(acc.id, newBalance)
    DB.AddTransaction(acc.id, 'admin', 'admin', amount, newBalance, nil, 'Admin AddMoney (API)')
    DB.Log(uniqueId, 'api_add_money', tostring(amount))
    return true
end)

exports('RemoveMoney', function(uniqueId, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end
    local acc = DB.GetAccountAny(uniqueId)
    if not acc then return false end
    if acc.balance < amount then return false end
    local newBalance = acc.balance - amount
    DB.UpdateBalance(acc.id, newBalance)
    DB.AddTransaction(acc.id, 'admin', 'admin', amount, newBalance, nil, 'Admin RemoveMoney (API)')
    DB.Log(uniqueId, 'api_remove_money', tostring(amount))
    return true
end)

exports('Transfer', function(fromUniqueId, toUniqueId, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false, "Montant invalide" end
    local fromAcc = DB.GetAccount(fromUniqueId)
    local toAcc   = DB.GetAccount(toUniqueId)
    if not fromAcc then return false, "Compte source introuvable" end
    if not toAcc   then return false, "Compte destinataire introuvable" end
    if fromAcc.balance < amount then return false, "Solde insuffisant" end

    DB.UpdateBalance(fromAcc.id, fromAcc.balance - amount)
    DB.UpdateBalance(toAcc.id,   toAcc.balance   + amount)
    DB.AddTransaction(fromAcc.id, 'admin', 'transfer_out', amount, fromAcc.balance - amount, toAcc.id,   'Transfer API')
    DB.AddTransaction(toAcc.id,   'admin', 'transfer_in',  amount, toAcc.balance   + amount, fromAcc.id, 'Transfer API')
    DB.Log(fromUniqueId, 'api_transfer', ('%s -> %s : %d'):format(fromUniqueId, toUniqueId, amount))
    return true, "OK"
end)

print('^2[KT Banque]^7 Admin chargé')
