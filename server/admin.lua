-- ==================== KT BANQUE v7.5.0 — SERVER/ADMIN ====================
-- Commandes et exports d'administration.
-- Toutes les actions sont tracées dans bank_logs.
-- Permission requise : Config.AdminAce (défaut "group.admin")
--
-- CORRECTIONS v7.5.0 :
--   FIX-1 : DB.AddTransaction — paramètres dans le bon ordre.
--   FIX-2 : exports Transfer — txType 'transfer_out'/'transfer_in' corrigés.
--   FIX-3 : IsAdmin depuis console (src == 0) autorisé sans ACE check.
--   FIX-4 : GetAccountByNumber / GetAccountByIBAN utilisés dans Transfer.

local function IsAdmin(src)
    -- FIX-3 : la console (src == 0) est toujours admin
    if src == 0 then return true end
    return IsPlayerAceAllowed(src, Config.AdminAce)
end

local function AdminNotify(src, msg)
    if src == 0 then
        print("[KT Banque Admin] " .. msg)
    else
        TriggerClientEvent('bank:client:notify', src, 'info', msg)
    end
end

-- ──────────────────────────────────────────
-- COMMANDES ADMIN
-- ──────────────────────────────────────────

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
    -- FIX-1 : signature correcte (accountId, sourceId, txType, amount, balanceAfter, targetId, desc)
    DB.AddTransaction(acc.id, 'admin', 'admin', amount, newBalance, nil,
        ('Admin AddMoney — src=%d'):format(src))
    DB.Log(uid, 'admin_add_money', ('$%d ajouté par admin src=%d'):format(amount, src))
    AdminNotify(src, ('✅ $%d ajouté sur %s (nouveau solde : $%d)'):format(amount, uid, newBalance))
end, false)

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

RegisterCommand("bank_total", function(src)
    if not IsAdmin(src) then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang.no_permission)
        return
    end
    local total = DB.GetGlobalTotal()
    AdminNotify(src, ('💰 Total en banque : $%d'):format(total))
end, false)

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

-- FIX-2 : transfer_out / transfer_in dans le bon ordre
exports('Transfer', function(fromUniqueId, toUniqueId, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false, "Montant invalide" end
    local fromAcc = DB.GetAccount(fromUniqueId)
    local toAcc   = DB.GetAccount(toUniqueId)
    if not fromAcc then return false, "Compte source introuvable" end
    if not toAcc   then return false, "Compte destinataire introuvable" end
    if fromAcc.balance < amount then return false, "Solde insuffisant" end

    local newFromBalance = fromAcc.balance - amount
    local newToBalance   = toAcc.balance   + amount

    DB.UpdateBalance(fromAcc.id, newFromBalance)
    DB.UpdateBalance(toAcc.id,   newToBalance)

    DB.AddTransaction(fromAcc.id, 'admin', 'transfer_out', amount, newFromBalance,
        toAcc.id, 'Transfer API')
    DB.AddTransaction(toAcc.id,   'admin', 'transfer_in',  amount, newToBalance,
        fromAcc.id, 'Transfer API')

    DB.Log(fromUniqueId, 'api_transfer',
        ('%s -> %s : %d'):format(fromUniqueId, toUniqueId, amount))
    return true, "OK"
end)

exports('BlockCard', function(uniqueId)
    local card = DB.GetCard(uniqueId)
    if not card then return false, "Aucune carte active" end
    DB.BlockCard(card.id)
    DB.Log(uniqueId, 'api_card_blocked', ('Carte #%d bloquée via API'):format(card.id))
    return true, "OK"
end)

exports('ValidateAccountAccess', function(uniqueId)
    local acc  = DB.GetAccount(uniqueId)
    local card = acc and DB.GetCard(uniqueId) or nil
    return acc ~= nil and card ~= nil and tonumber(card.active) == 1
end)

print('^2[KT Banque]^7 Admin chargé')
