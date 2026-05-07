-- ==================== KT BANQUE v7.4.1 - SERVEUR ====================
-- Aligné avec config.lua : card_basic / card_gold / card_diamond

local lastAction = {}

-- ==================== UNION ====================
local Union = {}

function Union.GetPlayer(src)
    return exports["union"]:GetPlayerFromId(src)
end

function Union.GetCharacterUniqueId(src)
    local identifier = GetPlayerIdentifier(src, 0)
    if not identifier then return nil end
    local result = MySQL.single.await(
        'SELECT unique_id FROM user_character WHERE identifier = ? LIMIT 1',
        { identifier }
    )
    return result and result.unique_id or nil
end

function Union.GetOwnerIdentifier(player)
    return player.identifier or player.license or player.citizenid
end

function Union.GetCash(player)
    return player.getMoney and player.getMoney('cash') or player.money or 0
end

function Union.AddCash(player, amount)
    if player.addMoney then player.addMoney('cash', amount) end
end

function Union.RemoveCash(player, amount)
    if player.removeMoney then player.removeMoney('cash', amount) end
end

function Union.GetName(player)
    return player.getName and player.getName() or player.name or "Inconnu"
end

-- ==================== UTILS ====================
local Utils = {}

function Utils.CheckSpam(src)
    local t = GetGameTimer()
    local delay = Config.SpamDelay or 1000
    if lastAction[src] and (t - lastAction[src]) < delay then return true end
    lastAction[src] = t
    return false
end

function Utils.GenerateAccountNumber()
    return "UN" .. math.random(10000000, 99999999)
end

function Utils.GenerateCardNumber()
    local parts = {}
    for i = 1, 4 do parts[i] = string.format("%04d", math.random(1000, 9999)) end
    return table.concat(parts, " ")
end

function Utils.ValidatePin(pin)
    local p = tostring(pin or "")
    return #p == 4 and p:match("^%d+$") ~= nil
end

-- Hash PIN — miroir de web/src/utils/index.ts → hashPin()
function Utils.HashPin(pin)
    local hash = 0
    local salt = "kt_banque_v7"
    local combined = salt .. tostring(pin)
    for i = 1, #combined do
        hash = (hash * 31 + combined:byte(i)) % (2^32)
    end
    return string.format("%08x", hash)
end

function Utils.GenerateIBAN(accountNumber)
    local num = accountNumber:gsub("UN", "")
    num = string.format("%010d", tonumber(num) or math.random(1000000000, 9999999999))
    return "FRKT" .. num
end

function Utils.GenerateExpiryDate()
    local y = tonumber(os.date("%Y")) + 3
    return string.format("%d-%s-%s", y, os.date("%m"), os.date("%d"))
end

function Utils.GenerateUUID()
    return string.gsub('xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx', '[xy]', function(c)
        local v = (c == 'x') and math.random(0, 15) or math.random(8, 11)
        return string.format('%x', v)
    end)
end

function Utils.Log(uniqueId, action, details)
    MySQL.insert.await(
        'INSERT INTO bank_logs (unique_id, action, details) VALUES (?, ?, ?)',
        { uniqueId, action, details }
    )
end

-- Retourne la clé interne de carte (card_basic / card_gold / card_diamond)
-- en inspectant l'inventaire du joueur
function Utils.GetCardTypeForPlayer(src)
    if not Config.RequireCard then return 'card_basic' end
    for key, item in pairs(Config.BankCardItem) do
        if exports.kt_inventory:GetItemCount(src, item) > 0 then
            return key
        end
    end
    return nil
end

-- ==================== DATABASE ====================
local DB = {}

function DB.GetAccount(uniqueId)
    return MySQL.single.await(
        'SELECT * FROM bank_accounts WHERE unique_id = ? AND status = "active" LIMIT 1',
        { uniqueId }
    )
end

function DB.GetAccountByNumber(accountNumber)
    return MySQL.single.await(
        'SELECT * FROM bank_accounts WHERE account_number = ? AND status = "active" LIMIT 1',
        { accountNumber }
    )
end

function DB.CreateAccount(uniqueId, ownerIdentifier, name)
    local accNumber = Utils.GenerateAccountNumber()
    local iban = Utils.GenerateIBAN(accNumber)
    local id = MySQL.insert.await(
        [[INSERT INTO bank_accounts (account_number, unique_id, owner_identifier, iban, label)
          VALUES (?, ?, ?, ?, ?)]],
        { accNumber, uniqueId, ownerIdentifier, iban, name .. "'s Account" }
    )
    -- Initialiser les limites journalières
    MySQL.insert.await(
        'INSERT IGNORE INTO bank_limits (account_id, last_reset) VALUES (?, CURDATE())',
        { id }
    )
    return id, accNumber, iban
end

function DB.GetCard(uniqueId)
    return MySQL.single.await(
        'SELECT * FROM bank_cards WHERE unique_id = ? AND active = 1 LIMIT 1',
        { uniqueId }
    )
end

function DB.CreateCard(accountId, uniqueId, pinHash, cardType)
    MySQL.insert.await(
        [[INSERT INTO bank_cards (account_id, unique_id, card_number, pin_hash, type, expires_at)
          VALUES (?, ?, ?, ?, ?, ?)]],
        {
            accountId,
            uniqueId,
            Utils.GenerateCardNumber(),
            pinHash,
            cardType or 'card_basic',
            Utils.GenerateExpiryDate()
        }
    )
end

function DB.UpdateBalance(accountId, balance)
    MySQL.update.await('UPDATE bank_accounts SET balance = ? WHERE id = ?', { balance, accountId })
end

function DB.AddTransaction(accountId, sourceIdentifier, txType, amount, balanceAfter, targetAccountId, description)
    MySQL.insert.await(
        [[INSERT INTO bank_transactions
            (account_id, transaction_uuid, type, amount, balance_after, source_identifier, target_account_id, description)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)]],
        {
            accountId, Utils.GenerateUUID(), txType,
            amount, balanceAfter, sourceIdentifier, targetAccountId, description
        }
    )
end

function DB.GetTransactions(accountId, limit)
    return MySQL.query.await(
        [[SELECT id, type as action, amount, balance_after, description, created_at as date
          FROM bank_transactions WHERE account_id = ? ORDER BY created_at DESC LIMIT ?]],
        { accountId, limit or 20 }
    )
end

function DB.GetLimits(accountId)
    return MySQL.single.await(
        'SELECT deposit_today, withdraw_today, last_reset FROM bank_limits WHERE account_id = ?',
        { accountId }
    )
end

function DB.UpdateLimits(accountId, depositDelta, withdrawDelta)
    MySQL.update.await(
        [[UPDATE bank_limits SET
            deposit_today  = IF(last_reset < CURDATE(), ?, deposit_today  + ?),
            withdraw_today = IF(last_reset < CURDATE(), ?, withdraw_today + ?),
            last_reset     = CURDATE()
          WHERE account_id = ?]],
        { depositDelta, depositDelta, withdrawDelta, withdrawDelta, accountId }
    )
end

-- ==================== BANK LOGIC ====================
local Bank = {}

function Bank.CheckLimit(accountId, limitType, amount, cardType)
    local limits     = DB.GetLimits(accountId)
    if not limits then return true end

    -- FIX: clés alignées avec config.lua (card_basic / card_gold / card_diamond)
    local cardLimits = Config.CardLimits[cardType]
    if not cardLimits then return true end

    local today    = os.date("%Y-%m-%d")
    local isNewDay = (tostring(limits.last_reset):sub(1, 10) ~= today)

    if limitType == 'deposit' then
        local used = isNewDay and 0 or (limits.deposit_today or 0)
        return (used + amount) <= cardLimits.MaxDeposit
    elseif limitType == 'withdraw' then
        local used = isNewDay and 0 or (limits.withdraw_today or 0)
        return (used + amount) <= cardLimits.MaxWithdraw
    end
    return true
end

function Bank.Create(src, pin)
    local p = Union.GetPlayer(src)
    if not p then return end

    local uid = Union.GetCharacterUniqueId(src)
    if not uid then
        TriggerClientEvent('bank:client:notify', src, 'error', "Impossible d'identifier votre personnage")
        return
    end

    if DB.GetAccount(uid) then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang.account_exists)
        return
    end

    if not Utils.ValidatePin(pin) then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang.invalid_pin)
        return
    end

    local owner   = Union.GetOwnerIdentifier(p)
    local name    = Union.GetName(p)
    local pinHash = Utils.HashPin(pin)

    local accId, accNumber, iban = DB.CreateAccount(uid, owner, name)
    -- FIX: clé card_basic (pas carte_basique)
    DB.CreateCard(accId, uid, pinHash, 'card_basic')

    -- Donner la carte basique dans l'inventaire
    exports.kt_inventory:AddItem(src, Config.BankCardItem.card_basic, 1)

    DB.AddTransaction(accId, owner, 'account_created', 0, 0, nil, 'Ouverture de compte')
    Utils.Log(uid, 'create_account', 'Compte ' .. accNumber .. ' créé')

    TriggerClientEvent('bank:client:notify', src, 'success', Config.Lang.account_created)

    if Config.Debug then
        print(string.format('[KT Banque] Compte créé — uid=%s acc=%s iban=%s', uid, accNumber, iban))
    end
end

function Bank.Open(src)
    local p = Union.GetPlayer(src)
    if not p then return end

    local uid = Union.GetCharacterUniqueId(src)
    if not uid then return end

    -- Vérification carte si requise
    if Config.RequireCard then
        local cardType = Utils.GetCardTypeForPlayer(src)
        if not cardType then
            TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang.no_card)
            return
        end
    end

    local acc = DB.GetAccount(uid)
    if not acc then
        TriggerClientEvent('bank:client:openCreate', src)
        return
    end

    local card    = DB.GetCard(uid)
    local history = DB.GetTransactions(acc.id, 20)

    -- FIX: type de carte aligné avec config.lua
    local cardType   = (card and card.type) or 'card_basic'
    local cardLimits = Config.CardLimits[cardType] or Config.CardLimits.card_basic

    TriggerClientEvent('bank:client:openBank', src, {
        account_id   = acc.account_number,
        balance      = acc.balance,
        iban         = acc.iban,
        pin_hash     = (card and card.pin_hash) or "",
        requiresPin  = true,
        card_meta    = {
            id          = (card and card.id)          or 0,
            card_number = (card and card.card_number) or "---- ---- ---- ----",
            card_type   = cardType,
            owner       = Union.GetName(p),
            active      = (card and card.active)      or 0
        },
        account_info = {
            label   = acc.label,
            created = acc.created_at
        },
        limits  = cardLimits,
        history = history or {}
    })
end

function Bank.Deposit(src, amount, pinHash)
    if Utils.CheckSpam(src) then
        TriggerClientEvent('bank:client:notify', src, 'warning', Config.Lang.spam)
        return
    end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang.invalid_amount)
        return
    end

    local p   = Union.GetPlayer(src)
    if not p then return end

    local uid = Union.GetCharacterUniqueId(src)
    local acc = DB.GetAccount(uid)
    if not acc then TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang.no_account); return end

    local card = DB.GetCard(uid)
    if not card or card.pin_hash ~= tostring(pinHash) then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang.incorrect_pin)
        return
    end
    if card.active ~= 1 then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang.card_inactive)
        return
    end

    if Union.GetCash(p) < amount then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang.insufficient_cash)
        return
    end

    -- FIX: card.type = card_basic / card_gold / card_diamond
    if not Bank.CheckLimit(acc.id, 'deposit', amount, card.type) then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang.limit_exceeded)
        return
    end

    Union.RemoveCash(p, amount)
    local newBalance = acc.balance + amount
    DB.UpdateBalance(acc.id, newBalance)
    DB.UpdateLimits(acc.id, amount, 0)
    DB.AddTransaction(acc.id, Union.GetOwnerIdentifier(p), 'deposit', amount, newBalance, nil, nil)

    TriggerClientEvent('bank:client:updateBalance', src, newBalance)
    TriggerClientEvent('bank:client:notify', src, 'success', string.format(Config.Lang.deposit_success, amount))
    Utils.Log(uid, 'deposit', tostring(amount))
end

function Bank.Withdraw(src, amount, pinHash)
    if Utils.CheckSpam(src) then
        TriggerClientEvent('bank:client:notify', src, 'warning', Config.Lang.spam)
        return
    end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang.invalid_amount)
        return
    end

    local p   = Union.GetPlayer(src)
    if not p then return end

    local uid = Union.GetCharacterUniqueId(src)
    local acc = DB.GetAccount(uid)
    if not acc then TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang.no_account); return end

    local card = DB.GetCard(uid)
    if not card or card.pin_hash ~= tostring(pinHash) then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang.incorrect_pin)
        return
    end
    if card.active ~= 1 then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang.card_inactive)
        return
    end

    if acc.balance < amount then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang.insufficient_balance)
        return
    end

    if not Bank.CheckLimit(acc.id, 'withdraw', amount, card.type) then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang.limit_exceeded)
        return
    end

    local newBalance = acc.balance - amount
    DB.UpdateBalance(acc.id, newBalance)
    DB.UpdateLimits(acc.id, 0, amount)
    Union.AddCash(p, amount)
    DB.AddTransaction(acc.id, Union.GetOwnerIdentifier(p), 'withdraw', amount, newBalance, nil, nil)

    TriggerClientEvent('bank:client:updateBalance', src, newBalance)
    TriggerClientEvent('bank:client:notify', src, 'success', string.format(Config.Lang.withdraw_success, amount))
    Utils.Log(uid, 'withdraw', tostring(amount))
end

function Bank.Transfer(src, amount, targetNumber, pinHash)
    if Utils.CheckSpam(src) then
        TriggerClientEvent('bank:client:notify', src, 'warning', Config.Lang.spam)
        return
    end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang.invalid_amount)
        return
    end

    local p   = Union.GetPlayer(src)
    if not p then return end

    local uid = Union.GetCharacterUniqueId(src)
    local acc = DB.GetAccount(uid)
    if not acc then TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang.no_account); return end

    local card = DB.GetCard(uid)
    if not card or card.pin_hash ~= tostring(pinHash) then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang.incorrect_pin)
        return
    end
    if card.active ~= 1 then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang.card_inactive)
        return
    end

    local targetAcc = DB.GetAccountByNumber(targetNumber)
    if not targetAcc then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang.target_not_found)
        return
    end
    if targetAcc.id == acc.id then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang.same_account)
        return
    end

    if acc.balance < amount then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang.insufficient_balance)
        return
    end

    local owner = Union.GetOwnerIdentifier(p)

    local newBalanceSender = acc.balance - amount
    DB.UpdateBalance(acc.id, newBalanceSender)
    DB.AddTransaction(acc.id, owner, 'transfer_out', amount, newBalanceSender,
        targetAcc.id, 'Virement vers ' .. targetNumber)

    local newBalanceTarget = targetAcc.balance + amount
    DB.UpdateBalance(targetAcc.id, newBalanceTarget)
    DB.AddTransaction(targetAcc.id, owner, 'transfer_in', amount, newBalanceTarget,
        acc.id, 'Virement de ' .. acc.account_number)

    TriggerClientEvent('bank:client:updateBalance', src, newBalanceSender)
    TriggerClientEvent('bank:client:notify', src, 'success', string.format(Config.Lang.transfer_success, amount))
    Utils.Log(uid, 'transfer', string.format('%s -> %s : %d', acc.account_number, targetNumber, amount))
end

function Bank.UpgradeCard(src, newCardType)
    if Utils.CheckSpam(src) then
        TriggerClientEvent('bank:client:notify', src, 'warning', Config.Lang.spam)
        return
    end

    -- FIX: validation avec les clés correctes
    if not Config.CardLimits[newCardType] then
        TriggerClientEvent('bank:client:notify', src, 'error', "Type de carte invalide")
        return
    end

    local p = Union.GetPlayer(src)
    if not p then return end

    local uid = Union.GetCharacterUniqueId(src)
    local acc = DB.GetAccount(uid)
    if not acc then TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang.no_account); return end

    local price = Config.CardLimits[newCardType].Price or 0
    if price > 0 and Union.GetCash(p) < price then
        TriggerClientEvent('bank:client:notify', src, 'error', Config.Lang.insufficient_cash)
        return
    end

    -- Récupérer le pin_hash de la carte actuelle avant de désactiver
    local oldCard = DB.GetCard(uid)
    local pinHash = oldCard and oldCard.pin_hash or Utils.HashPin("0000")

    -- Désactiver l'ancienne carte et retirer l'item
    MySQL.update.await('UPDATE bank_cards SET active = 0 WHERE unique_id = ?', { uid })
    for _, item in pairs(Config.BankCardItem) do
        if exports.kt_inventory:GetItemCount(src, item) > 0 then
            exports.kt_inventory:RemoveItem(src, item, 1)
            break
        end
    end

    if price > 0 then Union.RemoveCash(p, price) end

    -- Créer la nouvelle carte avec le même PIN hash
    DB.CreateCard(acc.id, uid, pinHash, newCardType)
    exports.kt_inventory:AddItem(src, Config.BankCardItem[newCardType], 1)

    TriggerClientEvent('bank:client:notify', src, 'success', Config.Lang.card_upgraded)
    Utils.Log(uid, 'upgrade_card', newCardType)
end

-- ==================== ÉVÉNEMENTS ====================

RegisterNetEvent('bank:server:requestOpen',   function() Bank.Open(source) end)
RegisterNetEvent('bank:server:createAccount', function(pin) Bank.Create(source, pin) end)
RegisterNetEvent('bank:server:deposit',       function(amount, pinHash) Bank.Deposit(source, amount, pinHash) end)
RegisterNetEvent('bank:server:withdraw',      function(amount, pinHash) Bank.Withdraw(source, amount, pinHash) end)
RegisterNetEvent('bank:server:transfer',      function(amount, target, pinHash) Bank.Transfer(source, amount, target, pinHash) end)
RegisterNetEvent('bank:server:upgradeCard',   function(cardType) Bank.UpgradeCard(source, cardType) end)

-- ==================== EXPORTS ====================

exports('GetAccountBalance', function(uniqueId)
    local acc = DB.GetAccount(uniqueId)
    return acc and acc.balance or nil
end)

exports('GetAccountInfo', function(uniqueId)
    local acc = DB.GetAccount(uniqueId)
    if not acc then return nil end
    return { id = acc.id, account_number = acc.account_number, iban = acc.iban,
             balance = acc.balance, status = acc.status, label = acc.label }
end)

exports('AddMoney', function(uniqueId, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end
    local acc = DB.GetAccount(uniqueId)
    if not acc then return false end
    local newBalance = acc.balance + amount
    DB.UpdateBalance(acc.id, newBalance)
    DB.AddTransaction(acc.id, 'admin', 'admin', amount, newBalance, nil, 'Admin AddMoney')
    return true
end)

exports('RemoveMoney', function(uniqueId, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end
    local acc = DB.GetAccount(uniqueId)
    if not acc then return false end
    if acc.balance < amount then return false end
    local newBalance = acc.balance - amount
    DB.UpdateBalance(acc.id, newBalance)
    DB.AddTransaction(acc.id, 'admin', 'admin', amount, newBalance, nil, 'Admin RemoveMoney')
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
    return true, "OK"
end)

-- Nettoyage anti-spam à la déconnexion
AddEventHandler('playerDropped', function() lastAction[source] = nil end)

print('^2[KT Banque]^7 Serveur chargé v7.4.1')
