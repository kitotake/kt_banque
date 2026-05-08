-- ==================== KT BANQUE v7.5.0 — SERVER/MODULES/BANK ====================
-- Logique métier bancaire pure.
-- Dépend de : Utils, KtInv, Union, DB, CardManager (chargés avant via fxmanifest).

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
    if tonumber(card.active) ~= 1 then
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

    -- Créer le compte en base
    local accId, accNumber, iban = DB.CreateAccount(uid, owner, name)

    -- Émettre la carte avec métadonnées via CardManager
    local ok, meta = CardManager.IssueCard(
        src, uid, accId, accNumber,
        pinHash, 'card_basic', 'account_creation'
    )

    if not ok then
        Notify(src, 'error', "Erreur lors de l'émission de la carte")
        return
    end

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
    -- Utiliser CardManager.ValidateAccess pour vérification complète
    local canAccess, errMsg, acc = CardManager.ValidateAccess(src)

    if not canAccess then
        if errMsg ~= "no_account" then
            -- "no_account" est déjà géré dans ValidateAccess (openCreate)
            Notify(src, 'error', errMsg)
        end
        return
    end

    local uid = Union.GetCharacterUniqueId(src)

    local card       = DB.GetCard(uid)
    local history    = DB.GetTransactions(acc.id, 20)
    local cardType   = (card and card.type) or 'card_basic'
    local cardLimits = Config.CardLimits[cardType] or Config.CardLimits.card_basic

    -- Récupérer les métadonnées de la carte physique pour enrichir l'UI
    local physMeta, _ = CardManager.GetPhysicalCardMeta(src)

    local p = Union.GetPlayer(src)

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
            active      = (card and card.active)      or 0,
            -- Métadonnées inventaire enrichies
            expire_date = (physMeta and physMeta.expireDate)   or nil,
            blocked     = (physMeta and physMeta.blocked)      or false,
            disabled    = (physMeta and physMeta.disabled)     or false,
        },
        account_info = { label = acc.label, created = acc.created_at },
        limits       = cardLimits,
        history      = history or {}
    })

    -- Marquer la carte comme utilisée
    if card then DB.TouchCard(card.id) end
end

-- ──────────────────────────────────────────
-- DÉPÔT
-- ──────────────────────────────────────────

function Bank.Deposit(src, amount, pinHash)
    if Utils.CheckSpam(src) then Notify(src, 'warning', Config.Lang.spam); return end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then Notify(src, 'error', Config.Lang.invalid_amount); return end

    -- Validation accès (compte + carte physique)
    local canAccess, errMsg, acc = CardManager.ValidateAccess(src)
    if not canAccess then Notify(src, 'error', errMsg); return end

    local uid  = Union.GetCharacterUniqueId(src)
    local p    = Union.GetPlayer(src)

    local card = DB.GetCard(uid)
    if not ValidateCard(src, card, pinHash) then return end

    if KtInv.GetMoney(src) < amount then
        Notify(src, 'error', Config.Lang.insufficient_cash)
        return
    end

    if not CheckLimit(acc.id, 'deposit', amount, card.type) then
        Notify(src, 'error', Config.Lang.limit_exceeded)
        return
    end

    KtInv.RemoveMoney(src, amount)

    local newBalance = acc.balance + amount
    DB.UpdateBalance(acc.id, newBalance)
    DB.UpdateLimits(acc.id, amount, 0)
    DB.AddTransaction(acc.id, Union.GetOwnerIdentifier(p), 'deposit', amount, newBalance, nil, nil)

    KtInv.GiveReceipt(src, ('%s +$%d'):format(Config.Lang.receipt_deposit, amount))

    TriggerClientEvent('bank:client:updateBalance', src, newBalance)
    Notify(src, 'success', Config.Lang.deposit_success:format(amount))
    DB.Log(uid, 'deposit', tostring(amount))

    -- Mettre à jour lastUsed sur la carte physique
    if card then DB.TouchCard(card.id) end
end

-- ──────────────────────────────────────────
-- RETRAIT
-- ──────────────────────────────────────────

function Bank.Withdraw(src, amount, pinHash)
    if Utils.CheckSpam(src) then Notify(src, 'warning', Config.Lang.spam); return end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then Notify(src, 'error', Config.Lang.invalid_amount); return end

    local canAccess, errMsg, acc = CardManager.ValidateAccess(src)
    if not canAccess then Notify(src, 'error', errMsg); return end

    local uid = Union.GetCharacterUniqueId(src)
    local p   = Union.GetPlayer(src)

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

    KtInv.AddMoney(src, amount)

    DB.AddTransaction(acc.id, Union.GetOwnerIdentifier(p), 'withdraw', amount, newBalance, nil, nil)
    KtInv.GiveReceipt(src, ('%s -$%d'):format(Config.Lang.receipt_withdraw, amount))

    TriggerClientEvent('bank:client:updateBalance', src, newBalance)
    Notify(src, 'success', Config.Lang.withdraw_success:format(amount))
    DB.Log(uid, 'withdraw', tostring(amount))

    if card then DB.TouchCard(card.id) end
end

-- ──────────────────────────────────────────
-- VIREMENT
-- ──────────────────────────────────────────

function Bank.Transfer(src, amount, targetNumber, pinHash)
    if Utils.CheckSpam(src) then Notify(src, 'warning', Config.Lang.spam); return end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then Notify(src, 'error', Config.Lang.invalid_amount); return end

    local canAccess, errMsg, acc = CardManager.ValidateAccess(src)
    if not canAccess then Notify(src, 'error', errMsg); return end

    local uid = Union.GetCharacterUniqueId(src)
    local p   = Union.GetPlayer(src)

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

    KtInv.GiveReceipt(src, ('%s $%d → %s'):format(Config.Lang.receipt_transfer, amount, targetNumber))

    TriggerClientEvent('bank:client:updateBalance', src, newBalanceSender)
    Notify(src, 'success', Config.Lang.transfer_success:format(amount))
    DB.Log(uid, 'transfer', ('%s -> %s : %d'):format(acc.account_number, targetNumber, amount))

    if card then DB.TouchCard(card.id) end
end

-- ──────────────────────────────────────────
-- AMÉLIORATION DE CARTE (via CardManager)
-- ──────────────────────────────────────────

function Bank.UpgradeCard(src, newCardType)
    if Utils.CheckSpam(src) then Notify(src, 'warning', Config.Lang.spam); return end

    local ok, result = CardManager.UpgradeCard(src, newCardType)

    if not ok then
        Notify(src, 'error', result)
        return
    end

    Notify(src, 'success', Config.Lang.card_upgraded)
end

-- ──────────────────────────────────────────
-- REMPLACEMENT DE CARTE (guichet / ATM spécial)
-- ──────────────────────────────────────────

function Bank.ReplaceCard(src)
    if Utils.CheckSpam(src) then Notify(src, 'warning', Config.Lang.spam); return end

    local uid = Union.GetCharacterUniqueId(src)
    if not uid then Notify(src, 'error', "Impossible d'identifier le personnage"); return end

    local ok, result = CardManager.ReplaceBlockedCard(src, uid)

    if not ok then
        Notify(src, 'error', result)
        return
    end

    Notify(src, 'success', ("Nouvelle carte émise ($%d débité)"):format(Config.CardReplaceCost or 500))
    TriggerClientEvent('bank:client:updateBalance', src, result)
end

print('^2[KT Banque]^7 Bank (logique métier) chargé')