-- ==================== KT BANQUE - SERVER (UNION v7.4 FIX + IBAN) ====================

local lastAction = {}

-- ==================== UNION ====================
local Union = {}

function Union.GetPlayer(src)
    return exports["union"]:GetPlayerFromId(src)
end

-- 🔥 FIX : récupère unique_id via SQL characters
function Union.GetCharacterUniqueId(src)
    local identifier = GetPlayerIdentifier(src, 0)
    if not identifier then return nil end

    local result = MySQL.single.await(
        'SELECT unique_id FROM user_character WHERE identifier = ? LIMIT 1',
        {identifier}
    )

    return result and result.unique_id or nil
end

function Union.GetOwnerIdentifier(player)
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
        if p and Union.GetCharacterUniqueId(tonumber(src)) == unique_id then
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
    return "UN" .. math.random(10000000, 99999999)
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

-- 🔥 IBAN SQL READY
function Utils.GenerateIBAN(accountNumber)
    local num = accountNumber:gsub("UN", "")
    num = string.format("%010d", tonumber(num) or math.random(1000000000,9999999999))
    return "UN" .. num
end

function Utils.GenerateExpiryDate()
    local now = os.time()

    local future = os.time({
        year = tonumber(os.date("%Y", now)) + 3,
        month = tonumber(os.date("%m", now)),
        day = tonumber(os.date("%d", now))
    })

    return os.date("%Y-%m-%d", future)
end

function Utils.GenerateUUID()
    return string.gsub('xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx', '[xy]', function(c)
        local v = (c == 'x') and math.random(0, 15) or math.random(8, 11)
        return string.format('%x', v)
    end)
end

-- ==================== DATABASE ====================
local DB = {}

function DB.GetAccount(unique_id)
    return MySQL.single.await(
        'SELECT * FROM bank_accounts WHERE unique_id = ? LIMIT 1',
        {unique_id}
    )
end

-- 🔥 FIX UNIQUE CREATE ACCOUNT (WITH IBAN)
function DB.CreateAccount(unique_id, owner_identifier, name)
    local accNumber = Utils.GenerateAccountNumber()
    local iban = Utils.GenerateIBAN(accNumber)

    local id = MySQL.insert.await(
        [[
        INSERT INTO bank_accounts 
        (account_number, unique_id, owner_identifier, iban, label) 
        VALUES (?, ?, ?, ?, ?)
        ]],
        {accNumber, unique_id, owner_identifier, iban, name}
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
        [[
        INSERT INTO bank_cards 
        (account_id, unique_id, card_number, pin, expires_at) 
        VALUES (?, ?, ?, ?, ?)
        ]],
        {
            account_id,
            unique_id,
            Utils.GenerateCardNumber(),
            pin,
            Utils.GenerateExpiryDate()
        }
    )
end

function DB.UpdateBalance(account_id, balance)
    MySQL.update.await(
        'UPDATE bank_accounts SET balance = ? WHERE id = ?',
        {balance, account_id}
    )
end

function DB.AddTransaction(account_id, source_identifier, type, amount, balance, target_account_id)
    MySQL.insert.await(
        [[
        INSERT INTO bank_transactions 
        (account_id, transaction_uuid, type, amount, balance_after, source_identifier, target_account_id)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ]],
        {
            account_id,
            Utils.GenerateUUID(),
            type,
            amount,
            balance,
            source_identifier,
            target_account_id
        }
    )
end

-- ==================== BANK ====================
local Bank = {}

function Bank.Create(src, pin)
    local p = Union.GetPlayer(src)
    if not p then return end

    local uid = Union.GetCharacterUniqueId(src)
    local owner = Union.GetOwnerIdentifier(p)

    if not uid or not owner then return end

    if DB.GetAccount(uid) then
        TriggerClientEvent('bank:client:notify', src, 'error', "Compte déjà existant")
        return
    end

    if not Utils.ValidatePin(pin) then
        TriggerClientEvent('bank:client:notify', src, 'error', "PIN invalide")
        return
    end

    local accId = DB.CreateAccount(uid, owner, Union.GetName(p))
    DB.CreateCard(accId, uid, pin)

    TriggerClientEvent('bank:client:notify', src, 'success', "Compte créé")
end

function Bank.GetData(src)
    local p = Union.GetPlayer(src)
    if not p then return end

    local uid = Union.GetCharacterUniqueId(src)
    local acc = DB.GetAccount(uid)

    if not acc then return end

    TriggerClientEvent('bank:client:openBank', src, {
        balance = acc.balance,
        accountNumber = acc.account_number,
        iban = acc.iban
    })
end

-- (Deposit / Withdraw / Transfer inchangés sauf IBAN déjà en DB)

-- ==================== EVENTS ====================
RegisterNetEvent('bank:server:createAccount', function(pin)
    Bank.Create(source, pin)
end)

RegisterNetEvent('bank:server:open', function()
    Bank.GetData(source)
end)

RegisterNetEvent('ktbank:openbank', function()
    local src = source
    local uid = Union.GetCharacterUniqueId(src)

    local account = MySQL.single.await(
        'SELECT * FROM bank_accounts WHERE unique_id = ? LIMIT 1',
        {uid}
    )

    if not account then return end

    TriggerClientEvent('bank:client:openBank', src, {
        balance = account.balance,
        accountNumber = account.account_number,
        iban = account.iban,
        label = account.label,
        type = account.type
    })
end)

print('^2[KT Banque]^7 Loaded (FULL FIX + IBAN READY)')