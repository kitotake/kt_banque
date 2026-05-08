-- ==================== KT BANQUE v7.5.0 — SERVER/MODULES/BANK ====================
-- Logique métier bancaire pure.
-- Dépend de : Utils, OxInv, Union, DB (chargés avant via fxmanifest).

Bank = {}

-- ──────────────────────────────────────────
-- HELPERS INTERNES
-- ──────────────────────────────────────────

local function Notify(src, type, msg)
    TriggerClientEvent('bank:client:notify', src, type, msg)
end

local function CheckLimit(accountId, limitType, amount, cardType)
    local limits     = DB.GetLimits(accountId)
    if not limits then return true end
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

local function ValidateCard(src, card, pinHash)
    if not card or card.pin_hash ~= tostring(pinHash) then
        Notify(src, 'error', Config.Lang.incorrect_pin)
        return false
    end
    if card.active ~= 1 then
        Notify(src, 'error', Config.Lang.card_inactive)
        return false
    end
    return true
end

-- ──────────────────────────────────────────
-- CRÉATION DE COMPTE
-- ──────────────────────────────────────────

function Bank.Create(src, pin)
    local p = Union.GetPlayer(src)
    if not p then return end

    local uid = Union.GetCharacterUniqueId(src)
    if not uid then
        Notify(src, 'error', "Impossible d'identifier votre personnage")
        return
    end

    if DB.GetAccount(uid) then
        Notify(src, 'error', Config.Lang.account_exists)
        return
    end

    if not Utils.ValidatePin(pin) then
        Notify(src, 'error', Config.Lang.invalid_pin)
        return
    end

    local owner   = Union.GetOwnerIdentifier(p)
    local name    = Union.GetName(p)
    local pinHash = Utils.HashPin(pin)

    local accId, accNumber, iban = DB.CreateAccount(uid, owner, name)
    DB.CreateCard(accId, uid, pinHash, 'card_basic')
    OxInv.AddCard(src, 'card_basic')

    DB.AddTransaction(accId, owner, 'account_created', 0, 0, nil, 'Ouverture de compte')
    DB.Log(uid, 'create_account', 'Compte ' .. accNumber .. ' créé')

    Notify(src, 'success', Config.Lang.account_created)

    if Config.Debug then
        print(('[KT Banque] Compte créé — uid=%s acc=%s iban=%s'):format(uid, accNumber, iban))
    end
end

-- ──────────────────────────────────────────
-- OUVERTURE DU MENU
-- ──────────────────────────────────────────

function Bank.Open(src)
    local p = Union.GetPlayer(src)
    if not p then return end

    local uid = Union.GetCharacterUniqueId(src)
    if not uid then return end

    if Config.RequireCard and not OxInv.HasCard(src) then
        Notify(src, 'error', Config.Lang.no_card)
        return
    end

    local acc = DB.GetAccount(uid)
    if not acc then
        TriggerClientEvent('bank:client:openCreate', src)
        return
    end

    local card       = DB.GetCard(uid)
    local history    = DB.GetTransactions(acc.id, 20)
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
        account_info = { label = acc.label, created = acc.created_at },
        limits       = cardLimits,
        history      = history or {}
    })
end

-- ──────────────────────────────────────────
-- DÉPÔT
-- ──────────────────────────────────────────

function Bank.Deposit(src, amount, pinHash)
    if Utils.CheckSpam(src) then Notify(src, 'warning', Config.Lang.spam); return end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then Notify(src, 'error', Config.Lang.invalid_amount); return end

    local p   = Union.GetPlayer(src)
    if not p then return end

    local uid = Union.GetCharacterUniqueId(src)
    local acc = DB.GetAccount(uid)
    if not acc then Notify(src, 'error', Config.Lang.no_account); return end

    local card = DB.GetCard(uid)
    if not ValidateCard(src, card, pinHash) then return end

    if OxInv.GetMoney(src) < amount then
        Notify(src, 'error', Config.Lang.insufficient_cash)
        return
    end

    if not CheckLimit(acc.id, 'deposit', amount, card.type) then
        Notify(src, 'error', Config.Lang.limit_exceeded)
        return
    end

    -- Retirer le cash de l'inventaire
    OxInv.RemoveMoney(src, amount)

    local newBalance = acc.balance + amount
    DB.UpdateBalance(acc.id, newBalance)
    DB.UpdateLimits(acc.id, amount, 0)
    DB.AddTransaction(acc.id, Union.GetOwnerIdentifier(p), 'deposit', amount, newBalance, nil, nil)

    -- Donner un reçu dans l'inventaire
    OxInv.GiveReceipt(src, ('%s +$%d'):format(Config.Lang.receipt_deposit, amount))

    TriggerClientEvent('bank:client:updateBalance', src, newBalance)
    Notify(src, 'success', Config.Lang.deposit_success:format(amount))
    DB.Log(uid, 'deposit', tostring(amount))
end

-- ──────────────────────────────────────────
-- RETRAIT
-- ──────────────────────────────────────────

function Bank.Withdraw(src, amount, pinHash)
    if Utils.CheckSpam(src) then Notify(src, 'warning', Config.Lang.spam); return end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then Notify(src, 'error', Config.Lang.invalid_amount); return end

    local p   = Union.GetPlayer(src)
    if not p then return end

    local uid = Union.GetCharacterUniqueId(src)
    local acc = DB.GetAccount(uid)
    if not acc then Notify(src, 'error', Config.Lang.no_account); return end

    local card = DB.GetCard(uid)
    if not ValidateCard(src, card, pinHash) then return end

    if acc.balance < amount then
        Notify(src, 'error', Config.Lang.insufficient_balance)
        return
    end

    if not CheckLimit(acc.id, 'withdraw', amount, card.type) then
        Notify(src, 'error', Config.Lang.limit_exceeded)
        return
    end

    local newBalance = acc.balance - amount
    DB.UpdateBalance(acc.id, newBalance)
    DB.UpdateLimits(acc.id, 0, amount)

    -- Ajouter le cash dans l'inventaire
    OxInv.AddMoney(src, amount)

    DB.AddTransaction(acc.id, Union.GetOwnerIdentifier(p), 'withdraw', amount, newBalance, nil, nil)
    OxInv.GiveReceipt(src, ('%s -$%d'):format(Config.Lang.receipt_withdraw, amount))

    TriggerClientEvent('bank:client:updateBalance', src, newBalance)
    Notify(src, 'success', Config.Lang.withdraw_success:format(amount))
    DB.Log(uid, 'withdraw', tostring(amount))
end

-- ──────────────────────────────────────────
-- VIREMENT
-- ──────────────────────────────────────────

function Bank.Transfer(src, amount, targetNumber, pinHash)
    if Utils.CheckSpam(src) then Notify(src, 'warning', Config.Lang.spam); return end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then Notify(src, 'error', Config.Lang.invalid_amount); return end

    local p   = Union.GetPlayer(src)
    if not p then return end

    local uid = Union.GetCharacterUniqueId(src)
    local acc = DB.GetAccount(uid)
    if not acc then Notify(src, 'error', Config.Lang.no_account); return end

    local card = DB.GetCard(uid)
    if not ValidateCard(src, card, pinHash) then return end

    local targetAcc = DB.GetAccountByNumber(targetNumber)
    if not targetAcc then Notify(src, 'error', Config.Lang.target_not_found); return end
    if targetAcc.id == acc.id then Notify(src, 'error', Config.Lang.same_account); return end

    if acc.balance < amount then
        Notify(src, 'error', Config.Lang.insufficient_balance)
        return
    end

    local owner            = Union.GetOwnerIdentifier(p)
    local newBalanceSender = acc.balance - amount
    local newBalanceTarget = targetAcc.balance + amount

    DB.UpdateBalance(acc.id, newBalanceSender)
    DB.AddTransaction(acc.id, owner, 'transfer_out', amount, newBalanceSender,
        targetAcc.id, 'Virement vers ' .. targetNumber)

    DB.UpdateBalance(targetAcc.id, newBalanceTarget)
    DB.AddTransaction(targetAcc.id, owner, 'transfer_in', amount, newBalanceTarget,
        acc.id, 'Virement de ' .. acc.account_number)

    OxInv.GiveReceipt(src, ('%s $%d → %s'):format(Config.Lang.receipt_transfer, amount, targetNumber))

    TriggerClientEvent('bank:client:updateBalance', src, newBalanceSender)
    Notify(src, 'success', Config.Lang.transfer_success:format(amount))
    DB.Log(uid, 'transfer', ('%s -> %s : %d'):format(acc.account_number, targetNumber, amount))
end

-- ──────────────────────────────────────────
-- AMÉLIORATION DE CARTE
-- ──────────────────────────────────────────

function Bank.UpgradeCard(src, newCardType)
    if Utils.CheckSpam(src) then Notify(src, 'warning', Config.Lang.spam); return end

    if not Config.CardLimits[newCardType] then
        Notify(src, 'error', "Type de carte invalide")
        return
    end

    local p = Union.GetPlayer(src)
    if not p then return end

    local uid = Union.GetCharacterUniqueId(src)
    local acc = DB.GetAccount(uid)
    if not acc then Notify(src, 'error', Config.Lang.no_account); return end

    local price   = Config.CardLimits[newCardType].Price or 0
    local cash    = OxInv.GetMoney(src)

    if price > 0 and cash < price then
        Notify(src, 'error', Config.Lang.insufficient_cash)
        return
    end

    -- Conserver le PIN de l'ancienne carte
    local oldCard = DB.GetCard(uid)
    local pinHash = (oldCard and oldCard.pin_hash) or Utils.HashPin("0000")

    -- Désactiver l'ancienne carte + retirer l'item
    DB.DeactivateCards(uid)
    OxInv.RemoveCard(src)

    if price > 0 then OxInv.RemoveMoney(src, price) end

    -- Créer la nouvelle carte
    DB.CreateCard(acc.id, uid, pinHash, newCardType)
    OxInv.AddCard(src, newCardType)

    Notify(src, 'success', Config.Lang.card_upgraded)
    DB.Log(uid, 'upgrade_card', newCardType)
end

print('^2[KT Banque]^7 Bank (logique métier) chargé')
