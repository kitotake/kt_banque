-- ==================== KT BANQUE - SERVER (UNION v7.4) ====================

local lastAction = {}

-- ==================== UNION ====================
local Union = {}

function Union.GetPlayer(src)
    return exports["union"]:GetPlayerFromId(src)
end

function Union.GetIdentifier(player)
    return player.identifier or player.license or player.citizenid
end

function Union.GetMoney(player)
    return player.getMoney and player.getMoney() or player.money or 0
end

function Union.AddMoney(player, amount)
    if player.addMoney then player.addMoney(amount) end
end

function Union.RemoveMoney(player, amount)
    if player.removeMoney then player.removeMoney(amount) end
end

function Union.GetName(player)
    return player.getName and player.getName() or player.name or "Unknown"
end

function Union.GetSourceFromUniqueId(unique_id)
    for _, src in pairs(GetPlayers()) do
        local p = Union.GetPlayer(tonumber(src))
        if p and Union.GetIdentifier(p) == unique_id then
            return tonumber(src)
        end
    end
end

-- ==================== UTILS ====================
local Utils = {}

function Utils.CheckSpam(src)
    local t = GetGameTimer()
    if lastAction[src] and (t - lastAction[src]) < 1000 then return true end
    lastAction[src] = t
    return false
end

function Utils.GenerateAccountNumber()
    return "KT" .. math.random(10000000, 99999999)
end

function Utils.GenerateCardNumber()
    local parts = {}
    for i = 1, 4 do
        parts[i] = string.format("%04d", math.random(1000, 9999))
    end
    return table.concat(parts, " ")
end

function Utils.ValidatePin(pin)
    local p = tostring(pin)
    return p and #p == 4 and p:match("^%d+$")
end

-- ==================== DATABASE ====================
local DB = {}

function DB.GetAccount(unique_id)
    return MySQL.single.await(
        'SELECT * FROM bank_accounts WHERE unique_id = ? LIMIT 1',
        {unique_id}
    )
end

function DB.CreateAccount(unique_id, name)
    local accNumber = Utils.GenerateAccountNumber()

    local id = MySQL.insert.await(
        'INSERT INTO bank_accounts (account_number, unique_id, label) VALUES (?, ?, ?)',
        {accNumber, unique_id, name}
    )

    return id
end

function DB.GetCard(unique_id)
    return MySQL.single.await(
        'SELECT * FROM bank_cards WHERE unique_id = ? AND active = 1 LIMIT 1',
        {unique_id}
    )
end

function DB.CreateCard(account_id, unique_id, pin)
    MySQL.insert.await(
        'INSERT INTO bank_cards (account_id, unique_id, card_number, pin) VALUES (?, ?, ?, ?)',
        {account_id, unique_id, Utils.GenerateCardNumber(), pin}
    )
end

function DB.UpdateBalance(account_id, balance)
    MySQL.update.await(
        'UPDATE bank_accounts SET balance = ? WHERE id = ?',
        {balance, account_id}
    )
end

function DB.AddTransaction(account_id, unique_id, type, amount, balance)
    MySQL.insert.await(
        'INSERT INTO bank_transactions (account_id, unique_id, type, amount, balance_after) VALUES (?, ?, ?, ?, ?)',
        {account_id, unique_id, type, amount, balance}
    )
end

-- ==================== BANK ====================
local Bank = {}

function Bank.Create(src, pin)
    local p = Union.GetPlayer(src)
    if not p then return end

    local uid = Union.GetIdentifier(p)

    if DB.GetAccount(uid) then
        TriggerClientEvent('bank:client:notify', src, 'error', "Compte déjà existant")
        return
    end

    if not Utils.ValidatePin(pin) then
        TriggerClientEvent('bank:client:notify', src, 'error', "PIN invalide")
        return
    end

    local accId = DB.CreateAccount(uid, Union.GetName(p))
    DB.CreateCard(accId, uid, pin)

    TriggerClientEvent('bank:client:notify', src, 'success', "Compte créé")
end

function Bank.GetData(src)
    local p = Union.GetPlayer(src)
    if not p then return end

    local uid = Union.GetIdentifier(p)
    local acc = DB.GetAccount(uid)

    if not acc then
        TriggerClientEvent('bank:client:notify', src, 'error', "Aucun compte")
        return
    end

    TriggerClientEvent('bank:client:openBank', src, {
        balance = acc.balance,
        accountNumber = acc.account_number
    })
end

function Bank.Deposit(src, amount)
    local p = Union.GetPlayer(src)
    if not p or Utils.CheckSpam(src) then return end

    amount = tonumber(amount)
    if not amount or amount <= 0 then return end

    if Union.GetMoney(p) < amount then return end

    local uid = Union.GetIdentifier(p)
    local acc = DB.GetAccount(uid)
    if not acc then return end

    local new = acc.balance + amount

    DB.UpdateBalance(acc.id, new)
    Union.RemoveMoney(p, amount)
    DB.AddTransaction(acc.id, uid, 'deposit', amount, new)

    TriggerClientEvent('bank:client:updateBalance', src, new)
end

function Bank.Withdraw(src, amount)
    local p = Union.GetPlayer(src)
    if not p or Utils.CheckSpam(src) then return end

    amount = tonumber(amount)
    if not amount or amount <= 0 then return end

    local uid = Union.GetIdentifier(p)
    local acc = DB.GetAccount(uid)
    if not acc then return end

    if acc.balance < amount then return end

    local new = acc.balance - amount

    DB.UpdateBalance(acc.id, new)
    Union.AddMoney(p, amount)
    DB.AddTransaction(acc.id, uid, 'withdraw', amount, new)

    TriggerClientEvent('bank:client:updateBalance', src, new)
end

function Bank.Transfer(src, amount, targetAccountNumber)
    local p = Union.GetPlayer(src)
    if not p or Utils.CheckSpam(src) then return end

    amount = tonumber(amount)
    if not amount or amount <= 0 then return end

    local uid = Union.GetIdentifier(p)
    local sender = DB.GetAccount(uid)
    if not sender then return end

    if sender.balance < amount then return end

    local target = MySQL.single.await(
        'SELECT * FROM bank_accounts WHERE account_number = ?',
        {targetAccountNumber}
    )

    if not target then return end

    DB.UpdateBalance(sender.id, sender.balance - amount)
    DB.UpdateBalance(target.id, target.balance + amount)

    DB.AddTransaction(sender.id, uid, 'transfer_out', amount, sender.balance - amount)
    DB.AddTransaction(target.id, target.unique_id, 'transfer_in', amount, target.balance + amount)

    local targetSrc = Union.GetSourceFromUniqueId(target.unique_id)
    if targetSrc then
        TriggerClientEvent('bank:client:notify', targetSrc, 'success', ("Reçu $%s"):format(amount))
    end

    TriggerClientEvent('bank:client:updateBalance', src, sender.balance - amount)
end

-- ==================== EVENTS ====================
RegisterNetEvent('bank:server:createAccount', function(pin)
    Bank.Create(source, pin)
end)

RegisterNetEvent('bank:server:open', function()
    Bank.GetData(source)
end)

RegisterNetEvent('bank:server:deposit', function(amount)
    Bank.Deposit(source, amount)
end)

RegisterNetEvent('bank:server:withdraw', function(amount)
    Bank.Withdraw(source, amount)
end)

RegisterNetEvent('bank:server:transfer', function(amount, target)
    Bank.Transfer(source, amount, target)
end)

-- ==================== CLEANUP ====================
AddEventHandler('playerDropped', function()
    lastAction[source] = nil
end)

-- ==================== CHECK ACCOUNTS DEBUG ====================
RegisterNetEvent("ktbank:checkAccounts", function()
    local src = source
    print(("Demande de checkaccounts par %s"):format(src))

    for _, id in ipairs(GetPlayers()) do
        local player = exports["union"]:GetPlayerFromId(tonumber(id))

        if player then
            local uniqueId = Union.GetIdentifier(player)
            print(("Player %s (server id %s)"):format(uniqueId, id))
        end
    end

    print("--- FIN CHECK ACCOUNTS ---")
end)

-- ==================== OPEN BANK ====================
RegisterNetEvent("ktbank:openbank", function()
    local src = source
    local p = Union.GetPlayer(src)
    if not p then return end

    local uniqueId = Union.GetIdentifier(p)

    -- ⚠️ SQL v7.4 (bank_accounts)
    local account = MySQL.single.await(
        'SELECT * FROM bank_accounts WHERE unique_id = ? LIMIT 1',
        { uniqueId }
    )

    if not account then
        TriggerClientEvent('bank:client:notify', src, 'error', "Aucun compte trouvé")
        return
    end

    TriggerClientEvent('bank:client:openBank', src, {
        balance = account.balance,
        accountNumber = account.account_number,
        label = account.label,
        type = account.type
    })
end)

print('^2[KT Banque]^7 Loaded (UNION ONLY)')