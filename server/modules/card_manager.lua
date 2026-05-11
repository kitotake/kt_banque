-- ==================== KT BANQUE v7.5.0 — SERVER/MODULES/DB ====================
-- Couche d'accès aux données (DAL).
-- Toutes les requêtes SQL sont centralisées ici.
-- Aucune logique métier dans ce fichier.
--
-- CORRECTIONS :
--   FIX-1 : DB.GetLimits retourne last_reset comme string comparable.
--   FIX-2 : DB.ReactivateCard — résultat oxmysql normalisé.
--   FIX-3 : DB.AddTransaction — paramètres dans le bon ordre.

DB = {}

-- ──────────────────────────────────────────
-- COMPTES
-- ──────────────────────────────────────────

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

-- Admin : récupère un compte quel que soit son statut
function DB.GetAccountAny(uniqueId)
    return MySQL.single.await(
        'SELECT * FROM bank_accounts WHERE unique_id = ? LIMIT 1',
        { uniqueId }
    )
end

function DB.CreateAccount(uniqueId, ownerIdentifier, name)
    local accNumber = Utils.GenerateAccountNumber()
    local iban      = Utils.GenerateIBAN(accNumber)
    local id = MySQL.insert.await(
        [[INSERT INTO bank_accounts (account_number, unique_id, owner_identifier, iban, label)
          VALUES (?, ?, ?, ?, ?)]],
        { accNumber, uniqueId, ownerIdentifier, iban, name .. "'s Account" }
    )
    MySQL.insert.await(
        'INSERT IGNORE INTO bank_limits (account_id, last_reset) VALUES (?, CURDATE())',
        { id }
    )
    return id, accNumber, iban
end

function DB.UpdateBalance(accountId, balance)
    MySQL.update.await(
        'UPDATE bank_accounts SET balance = ? WHERE id = ?',
        { balance, accountId }
    )
end

function DB.SetAccountStatus(uniqueId, status)
    return MySQL.update.await(
        'UPDATE bank_accounts SET status = ? WHERE unique_id = ?',
        { status, uniqueId }
    )
end

function DB.GetGlobalTotal()
    local result = MySQL.single.await(
        "SELECT SUM(balance) AS total FROM bank_accounts WHERE status = 'active'",
        {}
    )
    return result and result.total or 0
end

function DB.GetAllAccounts(limit, offset)
    return MySQL.query.await(
        [[SELECT unique_id, account_number, iban, label, balance, status, created_at
          FROM bank_accounts ORDER BY created_at DESC LIMIT ? OFFSET ?]],
        { limit or 50, offset or 0 }
    )
end

-- ──────────────────────────────────────────
-- CARTES
-- ──────────────────────────────────────────

function DB.GetCard(uniqueId)
    return MySQL.single.await(
        'SELECT * FROM bank_cards WHERE unique_id = ? AND active = 1 LIMIT 1',
        { uniqueId }
    )
end

function DB.GetLatestCard(uniqueId)
    return MySQL.single.await(
        'SELECT * FROM bank_cards WHERE unique_id = ? ORDER BY id DESC LIMIT 1',
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

function DB.DeactivateCards(uniqueId)
    MySQL.update.await(
        'UPDATE bank_cards SET active = 0 WHERE unique_id = ?',
        { uniqueId }
    )
end

-- FIX-2 : oxmysql retourne un entier (affectedRows) pour MySQL.update.await
-- On normalise pour gérer à la fois les cas où result est un nombre ou une table
function DB.ReactivateCard(cardId)
    local result = MySQL.update.await(
        [[UPDATE bank_cards SET active = 1,
            expires_at = DATE_ADD(CURDATE(), INTERVAL 1 YEAR)
          WHERE id = ? AND active = 0]],
        { cardId }
    )
    -- oxmysql peut retourner un entier ou une table avec affectedRows
    if type(result) == "number" then
        return result > 0
    elseif type(result) == "table" then
        return (result.affectedRows or 0) > 0
    end
    return false
end

-- ──────────────────────────────────────────
-- TRANSACTIONS
-- FIX-3 : ordre des paramètres aligné avec la signature
-- ──────────────────────────────────────────

-- Signature : (accountId, sourceIdentifier, txType, amount, balanceAfter, targetAccountId, description)
function DB.AddTransaction(accountId, sourceIdentifier, txType, amount, balanceAfter, targetAccountId, description)
    MySQL.insert.await(
        [[INSERT INTO bank_transactions
            (account_id, transaction_uuid, type, amount, balance_after, source_identifier, target_account_id, description)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)]],
        {
            accountId,
            Utils.GenerateUUID(),
            txType,
            amount,
            balanceAfter,
            sourceIdentifier,
            targetAccountId,
            description
        }
    )
end

function DB.GetTransactions(accountId, limit)
    return MySQL.query.await(
        [[SELECT id, type AS action, amount, balance_after, description, created_at AS date
          FROM bank_transactions WHERE account_id = ? ORDER BY created_at DESC LIMIT ?]],
        { accountId, limit or 20 }
    )
end

-- ──────────────────────────────────────────
-- LIMITES JOURNALIÈRES
-- FIX-1 : la comparaison de date se fait en SQL (CURDATE()) pour éviter
--          les problèmes de timezone entre le serveur Lua et MySQL.
-- ──────────────────────────────────────────

function DB.GetLimits(accountId)
    return MySQL.single.await(
        [[SELECT deposit_today, withdraw_today,
                 DATE_FORMAT(last_reset, '%Y-%m-%d') AS last_reset
          FROM bank_limits WHERE account_id = ?]],
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

-- ──────────────────────────────────────────
-- LOGS
-- ──────────────────────────────────────────

function DB.Log(uniqueId, action, details)
    MySQL.insert.await(
        'INSERT INTO bank_logs (unique_id, action, details) VALUES (?, ?, ?)',
        { uniqueId, action, details }
    )
end

function DB.GetLogs(uniqueId, limit)
    return MySQL.query.await(
        'SELECT action, details, created_at FROM bank_logs WHERE unique_id = ? ORDER BY created_at DESC LIMIT ?',
        { uniqueId, limit or 50 }
    )
end

print('^2[KT Banque]^7 DB chargé')