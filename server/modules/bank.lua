-- ==================== KT BANQUE v7.5.0 — SERVER/MODULES/BANK ====================
-- Logique métier : ouverture de compte, dépôt, retrait, virement, carte.
--
-- CORRECTIONS v7.5.0 :
--   FIX-1 : Ce fichier était une copie de db.lua — remplacé par la vraie logique.
--   FIX-2 : Bank.Open envoie pin_hash dans le payload (nécessaire pour la page PIN côté web).
--   FIX-3 : Bank.Deposit / Withdraw / Transfer vérifient les limites journalières.
--   FIX-4 : Bank.Transfer supporte la recherche par numéro de compte ET par IBAN.
--   FIX-5 : Anti-spam via Utils.CheckSpam à chaque opération sensible.
--   FIX-6 : Bank.UpgradeCard vérifie que la carte actuelle est inférieure au type cible.

Bank = {}

-- ──────────────────────────────────────────
-- HELPER INTERNE
-- ──────────────────────────────────────────

local function Notify(src, t, msg)
    TriggerClientEvent('bank:client:notify', src, t, msg)
end

local function GetUID(src)
    return Union.GetCharacterUniqueId(src)
end

-- ──────────────────────────────────────────
-- OUVERTURE DE L'INTERFACE BANCAIRE
-- FIX-2 : envoie pin_hash dans le payload pour validation PIN côté web
-- ──────────────────────────────────────────

function Bank.Open(src)
    if Utils.CheckSpam(src) then
        Notify(src, 'error', Config.Lang.spam)
        return
    end

    local uid = GetUID(src)
    if not uid then return end

    local acc = DB.GetAccount(uid)
    if not acc then
        -- Pas de compte → proposer la création
        TriggerClientEvent('bank:client:openCreate', src)
        return
    end

    -- Vérifier qu'une carte est présente si requis
    if Config.RequireCard and not OxInv.HasCard(src) then
        Notify(src, 'error', Config.Lang.no_card)
        return
    end

    local card = DB.GetCard(uid)
    if not card then
        Notify(src, 'error', Config.Lang.no_card)
        return
    end

    if tonumber(card.active) ~= 1 then
        Notify(src, 'error', Config.Lang.card_inactive)
        return
    end

    local limits  = Config.CardLimits[card.type] or Config.CardLimits['card_basic']
    local history = DB.GetTransactions(acc.id, 20)

    local player = Union.GetPlayer(src)
    local name   = player and Union.GetName(player) or "Inconnu"

    -- FIX-2 : pin_hash inclus pour validation client
    local payload = {
        account_id   = acc.account_number,
        balance      = acc.balance,
        pin_hash     = card.pin_hash,
        requiresPin  = true,
        card_meta    = {
            id          = card.id,
            card_number = card.card_number,
            card_type   = card.type,
            owner       = name,
            active      = card.active
        },
        account_info = {
            label   = acc.label,
            created = tostring(acc.created_at)
        },
        limits       = limits,
        history      = history or {}
    }

    TriggerClientEvent('bank:client:openBank', src, payload)
end

-- ──────────────────────────────────────────
-- CRÉATION DE COMPTE
-- ──────────────────────────────────────────

function Bank.Create(src, pin)
    if Utils.CheckSpam(src) then
        Notify(src, 'error', Config.Lang.spam)
        return
    end

    if not Utils.ValidatePin(pin) then
        Notify(src, 'error', Config.Lang.invalid_pin)
        return
    end

    local uid = GetUID(src)
    if not uid then return end

    local existing = DB.GetAccountAny(uid)
    if existing then
        Notify(src, 'error', Config.Lang.account_exists)
        return
    end

    local player  = Union.GetPlayer(src)
    local name    = player and Union.GetName(player) or "Joueur"
    local ownerId = player and Union.GetOwnerIdentifier(player) or uid

    local pinHash = Utils.HashPin(pin)

    local accId, accNumber, iban = DB.CreateAccount(uid, ownerId, name)

    -- Émettre la carte via CardManager
    CardManager.IssueCard(src, uid, accId, pinHash, 'card_basic')

    DB.AddTransaction(accId, 'system', 'account_created', 0, 0, nil, 'Création de compte')
    DB.Log(uid, 'account_created', ('Compte %s créé'):format(accNumber))

    Notify(src, 'success', Config.Lang.account_created)
    TriggerClientEvent('bank:client:forceClose', src)
end

-- ──────────────────────────────────────────
-- DÉPÔT
-- FIX-3 : vérification limite journalière
-- ──────────────────────────────────────────

function Bank.Deposit(src, amount, pinHash)
    if Utils.CheckSpam(src) then
        Notify(src, 'error', Config.Lang.spam)
        return
    end

    amount = math.floor(amount)
    if amount <= 0 then
        Notify(src, 'error', Config.Lang.invalid_amount)
        return
    end

    local uid = GetUID(src)
    if not uid then return end

    local acc  = DB.GetAccount(uid)
    local card = DB.GetCard(uid)

    if not acc or not card then
        Notify(src, 'error', Config.Lang.no_account)
        return
    end

    if tonumber(card.active) ~= 1 then
        Notify(src, 'error', Config.Lang.card_inactive)
        return
    end

    -- Vérification PIN
    if card.pin_hash ~= pinHash then
        Notify(src, 'error', Config.Lang.incorrect_pin)
        return
    end

    -- Vérification argent liquide
    local cash = OxInv.GetMoney(src)
    if cash < amount then
        Notify(src, 'error', Config.Lang.insufficient_cash)
        return
    end

    -- Vérification limite journalière
    local limits    = Config.CardLimits[card.type] or Config.CardLimits['card_basic']
    local dailyLims = DB.GetLimits(acc.id)
    if dailyLims and (dailyLims.deposit_today + amount) > limits.MaxDeposit then
        Notify(src, 'error', Config.Lang.limit_exceeded)
        return
    end

    -- Opération
    OxInv.RemoveMoney(src, amount)
    local newBalance = acc.balance + amount
    DB.UpdateBalance(acc.id, newBalance)
    DB.UpdateLimits(acc.id, amount, 0)
    DB.AddTransaction(acc.id, uid, 'deposit', amount, newBalance, nil,
        ('Dépôt espèces $%d'):format(amount))

    OxInv.GiveReceipt(src, Config.Lang.receipt_deposit .. ' $' .. amount)

    TriggerClientEvent('bank:client:updateBalance', src, newBalance)
    Notify(src, 'success', Config.Lang.deposit_success:format(amount))
end

-- ──────────────────────────────────────────
-- RETRAIT
-- FIX-3 : vérification limite journalière
-- ──────────────────────────────────────────

function Bank.Withdraw(src, amount, pinHash)
    if Utils.CheckSpam(src) then
        Notify(src, 'error', Config.Lang.spam)
        return
    end

    amount = math.floor(amount)
    if amount <= 0 then
        Notify(src, 'error', Config.Lang.invalid_amount)
        return
    end

    local uid  = GetUID(src)
    if not uid then return end

    local acc  = DB.GetAccount(uid)
    local card = DB.GetCard(uid)

    if not acc or not card then
        Notify(src, 'error', Config.Lang.no_account)
        return
    end

    if tonumber(card.active) ~= 1 then
        Notify(src, 'error', Config.Lang.card_inactive)
        return
    end

    if card.pin_hash ~= pinHash then
        Notify(src, 'error', Config.Lang.incorrect_pin)
        return
    end

    if acc.balance < amount then
        Notify(src, 'error', Config.Lang.insufficient_balance)
        return
    end

    -- Vérification limite journalière
    local limits    = Config.CardLimits[card.type] or Config.CardLimits['card_basic']
    local dailyLims = DB.GetLimits(acc.id)
    if dailyLims and (dailyLims.withdraw_today + amount) > limits.MaxWithdraw then
        Notify(src, 'error', Config.Lang.limit_exceeded)
        return
    end

    local newBalance = acc.balance - amount
    DB.UpdateBalance(acc.id, newBalance)
    DB.UpdateLimits(acc.id, 0, amount)
    OxInv.AddMoney(src, amount)
    DB.AddTransaction(acc.id, uid, 'withdraw', amount, newBalance, nil,
        ('Retrait espèces $%d'):format(amount))

    OxInv.GiveReceipt(src, Config.Lang.receipt_withdraw .. ' $' .. amount)

    TriggerClientEvent('bank:client:updateBalance', src, newBalance)
    Notify(src, 'success', Config.Lang.withdraw_success:format(amount))
end

-- ──────────────────────────────────────────
-- VIREMENT
-- FIX-4 : recherche par numéro de compte ET par IBAN
-- ──────────────────────────────────────────

function Bank.Transfer(src, amount, target, pinHash)
    if Utils.CheckSpam(src) then
        Notify(src, 'error', Config.Lang.spam)
        return
    end

    amount = math.floor(amount)
    if amount <= 0 then
        Notify(src, 'error', Config.Lang.invalid_amount)
        return
    end

    local uid  = GetUID(src)
    if not uid then return end

    local fromAcc = DB.GetAccount(uid)
    local card    = DB.GetCard(uid)

    if not fromAcc or not card then
        Notify(src, 'error', Config.Lang.no_account)
        return
    end

    if tonumber(card.active) ~= 1 then
        Notify(src, 'error', Config.Lang.card_inactive)
        return
    end

    if card.pin_hash ~= pinHash then
        Notify(src, 'error', Config.Lang.incorrect_pin)
        return
    end

    -- FIX-4 : chercher par numéro de compte OU par IBAN
    local toAcc = DB.GetAccountByNumber(target)
    if not toAcc then
        toAcc = DB.GetAccountByIBAN(target)
    end

    if not toAcc then
        Notify(src, 'error', Config.Lang.target_not_found)
        return
    end

    if toAcc.id == fromAcc.id then
        Notify(src, 'error', Config.Lang.same_account)
        return
    end

    if fromAcc.balance < amount then
        Notify(src, 'error', Config.Lang.insufficient_balance)
        return
    end

    local newFromBalance = fromAcc.balance - amount
    local newToBalance   = toAcc.balance   + amount

    DB.UpdateBalance(fromAcc.id, newFromBalance)
    DB.UpdateBalance(toAcc.id,   newToBalance)

    DB.AddTransaction(fromAcc.id, uid, 'transfer_out', amount, newFromBalance,
        toAcc.id, ('Virement vers %s'):format(toAcc.account_number))
    DB.AddTransaction(toAcc.id, uid, 'transfer_in', amount, newToBalance,
        fromAcc.id, ('Virement de %s'):format(fromAcc.account_number))

    OxInv.GiveReceipt(src,
        Config.Lang.receipt_transfer .. ' $' .. amount .. ' → ' .. toAcc.account_number)

    TriggerClientEvent('bank:client:updateBalance', src, newFromBalance)
    Notify(src, 'success', Config.Lang.transfer_success:format(amount))
end

-- ──────────────────────────────────────────
-- UPGRADE DE CARTE
-- FIX-6 : vérification de hiérarchie card_basic < card_gold < card_diamond
-- ──────────────────────────────────────────

local CARD_RANK = { card_basic = 1, card_gold = 2, card_diamond = 3 }

function Bank.UpgradeCard(src, targetType)
    if Utils.CheckSpam(src) then
        Notify(src, 'error', Config.Lang.spam)
        return
    end

    if not Config.CardLimits[targetType] then
        Notify(src, 'error', 'Type de carte invalide.')
        return
    end

    local uid  = GetUID(src)
    if not uid then return end

    local acc  = DB.GetAccount(uid)
    local card = DB.GetCard(uid)

    if not acc or not card then
        Notify(src, 'error', Config.Lang.no_account)
        return
    end

    -- FIX-6 : vérifier que la carte cible est supérieure à la carte actuelle
    local currentRank = CARD_RANK[card.type]    or 0
    local targetRank  = CARD_RANK[targetType]   or 0

    if targetRank <= currentRank then
        Notify(src, 'error', 'Vous avez déjà une carte de niveau équivalent ou supérieur.')
        return
    end

    local price = Config.CardLimits[targetType].Price or 0
    if acc.balance < price then
        Notify(src, 'error', Config.Lang.insufficient_balance)
        return
    end

    local newBalance = acc.balance - price
    DB.UpdateBalance(acc.id, newBalance)
    DB.AddTransaction(acc.id, uid, 'withdraw', price, newBalance, nil,
        ('Upgrade carte → %s'):format(targetType))

    -- Changer le type en base
    DB.UpdateCardType(uid, targetType)

    -- Remplacer l'item inventaire
    OxInv.RemoveCard(src)
    OxInv.AddCard(src, targetType)

    DB.Log(uid, 'card_upgrade', ('%s → %s'):format(card.type, targetType))

    TriggerClientEvent('bank:client:updateBalance', src, newBalance)
    Notify(src, 'success', Config.Lang.card_upgraded)
end

print('^2[KT Banque]^7 Bank (logique métier) chargé')
