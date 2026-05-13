-- ==================== KT BANQUE v7.5.0 — SERVER/MODULES/CARD_MANAGER ====================
-- Gestion des cartes physiques : remplacement, métadonnées inventaire.
-- Ce module est chargé AVANT bank.lua et card_recovery.lua.
--
-- CORRECTIONS v7.5.0 :
--   FIX-1 : Fichier était une copie identique de db.lua — remplacé par le vrai CardManager.
--   FIX-2 : CardManager.ReplaceBlockedCard implémenté (utilisé par card_recovery).
--   FIX-3 : CardManager.GetPhysicalCardMeta / UpdateCardMetadata implémentés.
--   FIX-4 : Rollback automatique si UPDATE conditionnel échoue (anti double-clic).

CardManager = {}

local REPLACE_COST = Config and Config.CardReplaceCost or 1000

-- ──────────────────────────────────────────
-- REMPLACEMENT D'UNE CARTE BLOQUÉE
-- Débite le solde, réactive la carte (UPDATE conditionnel), donne la carte en inventaire.
-- Retourne (true, newBalance) ou (false, errorMessage).
-- ──────────────────────────────────────────

function CardManager.ReplaceBlockedCard(src, uniqueId)
    local acc = DB.GetAccount(uniqueId)
    if not acc then
        return false, Config.Lang.no_account
    end

    local card = DB.GetLatestCard(uniqueId)
    if not card then
        return false, "Aucune carte trouvée."
    end

    if tonumber(card.active) == 1 then
        return false, "Votre carte est déjà active."
    end

    local cost = Config.CardReplaceCost or REPLACE_COST
    if acc.balance < cost then
        return false, ("Solde insuffisant ($%d requis, vous avez $%d)"):format(cost, acc.balance)
    end

    -- Débit
    local newBalance = acc.balance - cost
    DB.UpdateBalance(acc.id, newBalance)
    DB.AddTransaction(acc.id, 'system', 'withdraw', cost, newBalance, nil,
        'Remplacement carte bancaire')

    -- Réactivation conditionnelle (anti double-exécution)
    local ok = DB.ReactivateCard(card.id)

    if not ok then
        -- Rollback : rembourser
        DB.UpdateBalance(acc.id, acc.balance)
        DB.AddTransaction(acc.id, 'system', 'deposit', cost, acc.balance, nil,
            'Rollback remplacement carte')
        return false, "Erreur lors de la réactivation de la carte."
    end

    -- Donner la carte physique en inventaire (remplace l'ancienne)
    OxInv.RemoveCard(src)
    local cardType = card.type or 'card_basic'
    OxInv.AddCard(src, cardType)

    -- Mettre à jour les métadonnées de l'item carte
    CardManager.UpdateCardMetadata(src, uniqueId, {
        blocked     = false,
        blockReason = nil,
        blockedAt   = nil,
        expireDate  = card.expires_at
    })

    DB.Log(uniqueId, 'card_replaced',
        ("Carte #%d réactivée — $%d débité"):format(card.id, cost))

    -- Notifier la balance mise à jour
    TriggerClientEvent('bank:client:updateBalance', src, newBalance)

    return true, newBalance
end

-- ──────────────────────────────────────────
-- RÉCUPÉRATION DES MÉTADONNÉES DE LA CARTE PHYSIQUE
-- Retourne (meta, itemName) ou (nil, nil).
-- ──────────────────────────────────────────

function CardManager.GetPhysicalCardMeta(src)
    for key, itemName in pairs(Config.BankCardItem) do
        local count = exports.kt_inventory:GetItemCount(src, itemName)
        if count and count > 0 then
            -- Essayer de récupérer les métadonnées de l'item
            local ok, meta = pcall(function()
                return exports.kt_inventory:GetItemMetadata(src, itemName)
            end)
            if ok and meta then
                return meta, itemName
            end
            return {}, itemName
        end
    end
    return nil, nil
end

-- ──────────────────────────────────────────
-- MISE À JOUR DES MÉTADONNÉES DE LA CARTE PHYSIQUE
-- ──────────────────────────────────────────

function CardManager.UpdateCardMetadata(src, uniqueId, metaUpdate)
    for key, itemName in pairs(Config.BankCardItem) do
        local count = exports.kt_inventory:GetItemCount(src, itemName)
        if count and count > 0 then
            local ok, currentMeta = pcall(function()
                return exports.kt_inventory:GetItemMetadata(src, itemName) or {}
            end)
            if not ok then currentMeta = {} end

            local newMeta = {}
            for k, v in pairs(currentMeta) do newMeta[k] = v end
            for k, v in pairs(metaUpdate)   do newMeta[k] = v end

            -- Ajouter owner si absent
            if not newMeta.owner then
                local player = Union.GetPlayer(src)
                if player then
                    newMeta.owner = Union.GetName(player)
                end
            end
            newMeta.uniqueId = uniqueId

            pcall(function()
                exports.kt_inventory:SetItemMetadata(src, itemName, newMeta)
            end)
            return
        end
    end
end

-- ──────────────────────────────────────────
-- ÉMISSION D'UNE NOUVELLE CARTE (création de compte)
-- ──────────────────────────────────────────

function CardManager.IssueCard(src, uniqueId, accountId, pinHash, cardType)
    cardType = cardType or 'card_basic'

    -- Créer en base
    DB.CreateCard(accountId, uniqueId, pinHash, cardType)

    -- Donner l'item
    OxInv.AddCard(src, cardType)

    -- Reçu optionnel
    OxInv.GiveReceipt(src, "Émission carte " .. cardType)

    local player = Union.GetPlayer(src)
    local name   = player and Union.GetName(player) or "Inconnu"

    -- Métadonnées initiales
    CardManager.UpdateCardMetadata(src, uniqueId, {
        blocked    = false,
        owner      = name,
        expireDate = Utils.GenerateExpiryDate()
    })
end

print('^2[KT Banque]^7 CardManager chargé')
