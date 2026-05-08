-- ==================== KT BANQUE v7.5.0 — SERVER/MODULES/CARD_MANAGER ====================
-- Gestion avancée des cartes bancaires : métadonnées, blocage, désactivation de compte.
-- Dépend de : Union, DB, KtInv, Config

CardManager = {}

-- ──────────────────────────────────────────
-- HELPERS INTERNES
-- ──────────────────────────────────────────

local function Notify(src, type, msg)
    TriggerClientEvent('bank:client:notify', src, type, msg)
end

-- Génère les métadonnées complètes d'une carte
local function BuildCardMetadata(uid, accountNumber, cardNumber, playerName, cardType, expiryDate)
    return {
        accountNumber = accountNumber,
        cardNumber    = cardNumber,
        owner         = playerName,
        expireDate    = expiryDate,
        cardType      = cardType,
        blocked       = false,
        disabled      = false,
        createdAt     = os.time(),
        lastUsed      = nil,
        issueReason   = "initial_issue"
    }
end

-- ──────────────────────────────────────────
-- ÉMISSION D'UNE CARTE (avec métadonnées)
-- ──────────────────────────────────────────

function CardManager.IssueCard(src, uid, accountId, accountNumber, pinHash, cardType, reason)
    local player  = Union.GetPlayer(src)
    if not player then return false, "Joueur introuvable" end

    local name        = Union.GetName(player)
    local cardNumber  = Utils.GenerateCardNumber()
    local expiryDate  = Utils.GenerateExpiryDateFormatted()

    -- Enregistrement en base
    DB.CreateCard(accountId, uid, pinHash, cardType)

    -- Récupérer l'ID de la carte fraîchement créée
    local newCard = DB.GetLatestCard(uid)
    if not newCard then return false, "Erreur création carte" end

    -- Construire les métadonnées
    local meta = BuildCardMetadata(uid, accountNumber, cardNumber, name, cardType, expiryDate)
    meta.issueReason = reason or "initial_issue"
    meta.cardId      = newCard.id

    -- Donner l'item avec métadonnées
    local itemName = Config.BankCardItem[cardType]
    if itemName then
        exports.kt_inventory:AddItem(src, itemName, 1, meta)
    end

    DB.Log(uid, "card_issued", ("Carte %s émise — raison: %s"):format(cardType, reason or "initial_issue"))

    if Config.Debug then
        print(("[KT Banque] Carte %s émise pour %s (acc: %s)"):format(cardType, name, accountNumber))
    end

    return true, meta
end

-- ──────────────────────────────────────────
-- BLOCAGE / DÉBLOCAGE DE CARTE
-- ──────────────────────────────────────────

function CardManager.BlockCard(uid, cardId, reason)
    local ok = MySQL.update.await(
        "UPDATE bank_cards SET active = 0 WHERE id = ? AND unique_id = ?",
        { cardId, uid }
    )
    if ok and ok > 0 then
        DB.Log(uid, "card_blocked", ("Carte #%d bloquée — raison: %s"):format(cardId, reason or "N/A"))
        return true
    end
    return false
end

function CardManager.UnblockCard(uid, cardId)
    local ok = MySQL.update.await(
        [[UPDATE bank_cards SET active = 1,
            expires_at = DATE_ADD(CURDATE(), INTERVAL 1 YEAR)
          WHERE id = ? AND unique_id = ? AND active = 0]],
        { cardId, uid }
    )
    if ok and ok > 0 then
        DB.Log(uid, "card_unblocked", ("Carte #%d débloquée"):format(cardId))
        return true
    end
    return false
end

-- ──────────────────────────────────────────
-- MISE À JOUR DES MÉTADONNÉES INVENTAIRE
-- ──────────────────────────────────────────

function CardManager.UpdateCardMetadata(src, uid, updates)
    local items = exports.kt_inventory:GetInventoryItems(src)
    if not items then return false end

    for _, cardType in pairs(Config.BankCardItem) do
        for _, item in pairs(items) do
            if item.name == cardType and item.metadata and item.metadata.accountNumber then
                local newMeta = item.metadata
                for k, v in pairs(updates) do
                    newMeta[k] = v
                end
                exports.kt_inventory:SetMetadata(src, item.slot, newMeta)
                return true
            end
        end
    end
    return false
end

function CardManager.HasPhysicalCard(src)
    for _, itemName in pairs(Config.BankCardItem) do
        if exports.kt_inventory:GetItemCount(src, itemName) > 0 then
            return true
        end
    end
    return false
end

function CardManager.GetPhysicalCardMeta(src)
    local items = exports.kt_inventory:GetInventoryItems(src)
    if not items then return nil, nil end

    for _, itemName in pairs(Config.BankCardItem) do
        for _, item in pairs(items) do
            if item.name == itemName and item.count > 0 then
                return item.metadata or {}, itemName
            end
        end
    end
    return nil, nil
end
-- ──────────────────────────────────────────
-- AMÉLIORATION DE CARTE (nécessite ancienne carte)
-- ──────────────────────────────────────────

function CardManager.UpgradeCard(src, newCardType)
    local player = Union.GetPlayer(src)
    if not player then
        return false, "Joueur introuvable"
    end

    -- Vérifier que le type cible est valide
    if not Config.CardLimits[newCardType] then
        return false, "Type de carte invalide"
    end

    local uid = Union.GetCharacterUniqueId(src)
    local acc = DB.GetAccount(uid)
    if not acc then return false, Config.Lang.no_account end

    -- VÉRIFICATION : l'ancienne carte physique doit être présente
    local oldMeta, oldItemName = CardManager.GetPhysicalCardMeta(src)
    if not oldMeta or not oldItemName then
        return false, "Vous devez posséder votre carte bancaire actuelle pour l'améliorer"
    end

    -- Vérifier que la carte n'est pas bloquée / désactivée
    if oldMeta.blocked or oldMeta.disabled then
        return false, "Votre carte est bloquée ou désactivée. Contactez votre banque"
    end

    -- Prix de la nouvelle carte
    local price = Config.CardLimits[newCardType].Price or 0
    local cash  = KtInv.GetMoney(src)
    if price > 0 and cash < price then
        return false, Config.Lang.insufficient_cash
    end

    -- Conserver le PIN de l'ancienne carte
    local oldCard = DB.GetCard(uid)
    local pinHash = (oldCard and oldCard.pin_hash) or Utils.HashPin("0000")

    -- Retirer l'ancienne carte physique (elle est « convertie »)
    exports.kt_inventory:RemoveItem(src, oldItemName, 1)

    -- Désactiver les anciennes cartes en base
    DB.DeactivateCards(uid)

    -- Débiter le prix
    if price > 0 then KtInv.RemoveMoney(src, price) end

    -- Émettre la nouvelle carte avec métadonnées à jour
    local ok, meta = CardManager.IssueCard(
        src, uid, acc.id, acc.account_number,
        pinHash, newCardType, "upgrade_from_" .. (oldMeta.cardType or "unknown")
    )

    if not ok then
        -- Rollback : redonner l'ancienne carte et le cash
        exports.kt_inventory:AddItem(src, oldItemName, 1, oldMeta)
        if price > 0 then KtInv.AddMoney(src, price) end
        return false, "Erreur lors de l'émission de la nouvelle carte"
    end

    DB.Log(uid, "card_upgraded",
        ("Carte améliorée : %s → %s"):format(oldMeta.cardType or "?", newCardType))

    return true, meta
end

-- ──────────────────────────────────────────
-- REMPLACEMENT DE CARTE BLOQUÉE
-- ──────────────────────────────────────────

function CardManager.ReplaceBlockedCard(src, uid)
    local player = Union.GetPlayer(src)
    if not player then return false, "Joueur introuvable" end

    local acc = DB.GetAccount(uid)
    if not acc then return false, Config.Lang.no_account end

    -- Vérifier solde pour le remplacement sur le joueur
    local replaceCost = Config.CardReplaceCost or 500
    local currentMoney = KtInv.GetMoney(src)
    if currentMoney < replaceCost then
        print(("[KT Banque] Remplacement carte refusé pour %s (solde insuffisant: $%d)"):format(
            player.name, replaceCost - currentMoney))
        return false, ("Solde insuffisant ($%d requis)"):format(replaceCost)
    end

    KtInv.RemoveMoney(src, replaceCost)

    -- Récupérer l'ancienne carte en base
    local latestCard = DB.GetLatestCard(uid)
    if not latestCard then
        return false, "Aucune carte associée à ce compte"
    end

    local cardType = latestCard.type or "card_basic"
    local pinHash  = latestCard.pin_hash

    -- Désactiver l'ancienne carte en base
    DB.DeactivateCards(uid)

    -- Débiter le remplacement
    local newBalance = acc.balance - replaceCost
    DB.UpdateBalance(acc.id, newBalance)
    DB.AddTransaction(acc.id, "system", "withdraw", replaceCost, newBalance, nil, "Remplacement carte bancaire")

    -- Émettre la nouvelle carte
    local ok, meta = CardManager.IssueCard(
        src, uid, acc.id, acc.account_number,
        pinHash, cardType, "card_replacement"
    )

    if not ok then
        -- Rollback
        DB.UpdateBalance(acc.id, acc.balance)
        return false, "Erreur lors de l'émission de la nouvelle carte"
    end

    TriggerClientEvent('bank:client:updateBalance', src, newBalance)
    DB.Log(uid, "card_replaced",
        ("Carte remplacée — type: %s — $%d débité"):format(cardType, replaceCost))

    return true, newBalance
end

-- ──────────────────────────────────────────
-- VÉRIFICATION COMPTE + CARTE POUR ACCÈS ATM
-- ──────────────────────────────────────────

function CardManager.ValidateAccess(src)
    local player = Union.GetPlayer(src)
    if not player then
        return false, "Joueur introuvable", nil
    end

    local uid = Union.GetCharacterUniqueId(src)
    if not uid then
        return false, "Impossible d'identifier le personnage", nil
    end

    -- Vérifier l'existence et l'état du compte
    local acc = DB.GetAccount(uid)
    if not acc then
        -- Pas de compte → proposer d'en créer un
        TriggerClientEvent('bank:client:openCreate', src)
        return false, "no_account", nil
    end

    -- Vérifier le statut du compte
    if acc.status == 'suspended' then
        return false, Config.Lang.account_suspended or "Compte suspendu", nil
    end
    if acc.status == 'closed' then
        return false, "Ce compte a été clôturé. Contactez votre agence", nil
    end

    -- Si carte physique obligatoire
    if Config.RequireCard then
        local meta, itemName = CardManager.GetPhysicalCardMeta(src)

        if not meta or not itemName then
            return false, Config.Lang.no_card or "Aucune carte bancaire dans votre inventaire", nil
        end

        -- Vérifier que la carte n'est pas bloquée (métadonnées)
        if meta.blocked then
            return false, "Votre carte est bloquée. Demandez un remplacement au guichet", nil
        end
        if meta.disabled then
            return false, "Votre carte est désactivée. Contactez votre banque", nil
        end

        -- Vérifier la cohérence : la carte appartient-elle bien à ce compte ?
        if meta.accountNumber and meta.accountNumber ~= "" and meta.accountNumber ~= acc.account_number then
            return false, "Cette carte n'est pas associée à votre compte actuel", nil
        end

        return true, nil, acc
    end

    return true, nil, acc
end

-- ──────────────────────────────────────────
-- BLOCAGE ADMIN D'UNE CARTE (via métadonnées)
-- ──────────────────────────────────────────

function CardManager.AdminBlockCard(adminSrc, targetSrc, uid, reason)
    -- Bloquer en base
    local card = DB.GetCard(uid)
    if not card then return false, "Aucune carte active" end

    CardManager.BlockCard(uid, card.id, reason)

    -- Si le joueur est connecté, mettre à jour ses métadonnées inventaire
    if targetSrc then
        CardManager.UpdateCardMetadata(targetSrc, uid, {
            blocked   = true,
            blockReason = reason or "Blocage administratif",
            blockedAt = os.time()
        })
        TriggerClientEvent('bank:client:notify', targetSrc, 'error',
            "Votre carte bancaire a été bloquée par l'administration")
    end

    DB.Log(uid, "admin_card_blocked",
        ("Carte bloquée par admin src=%s — raison: %s"):format(tostring(adminSrc), reason or "N/A"))

    return true, "Carte bloquée avec succès"
end

print('^2[KT Banque]^7 Card Manager chargé')