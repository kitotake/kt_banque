-- ==================== KT BANQUE v7.5.0 — SERVER/MODULES/CARD_RECOVERY ====================
-- Gestion de la récupération de carte bloquée.
-- Utilise CardManager pour la logique de remplacement.

local RECOVERY_COST = Config and Config.CardReplaceCost or 1000

-- ──────────────────────────────────────────
-- RÉCUPÉRER / REMPLACER LA CARTE
-- ──────────────────────────────────────────

RegisterNetEvent("kt_banque:card:recover", function()
    local src    = source
    local player = Union.GetPlayer(src)

    if not player or not player.currentCharacter then
        TriggerClientEvent("kt_banque:card:recoverResult", src, false, "Aucun personnage actif.")
        return
    end

    local uid  = player.currentCharacter.unique_id
    local card = DB.GetLatestCard(uid)

    if not card then
        TriggerClientEvent("kt_banque:card:recoverResult", src, false, "Aucune carte trouvée.")
        return
    end

    if tonumber(card.active) == 1 then
        TriggerClientEvent("kt_banque:card:recoverResult", src, false, "Votre carte est déjà active.")
        return
    end

    -- Déléguer à CardManager.ReplaceBlockedCard
    local ok, result = CardManager.ReplaceBlockedCard(src, uid)

    if not ok then
        TriggerClientEvent("kt_banque:card:recoverResult", src, false, result)
        return
    end

    TriggerClientEvent("kt_banque:card:recoverResult", src, true)
    TriggerClientEvent('bank:client:updateBalance', src, result)

    if Config.Debug then
        print(('[KT Banque] %s a récupéré sa carte ($%d)'):format(
            player.name or uid, Config.CardReplaceCost or 1000))
    end
end)

-- ──────────────────────────────────────────
-- STATUT DE LA CARTE
-- ──────────────────────────────────────────

RegisterNetEvent("kt_banque:card:checkStatus", function()
    local src    = source
    local player = Union.GetPlayer(src)
    if not player or not player.currentCharacter then return end

    local uid = player.currentCharacter.unique_id

    local data = MySQL.single.await([[
        SELECT bc.id, bc.card_number, bc.type, bc.active, bc.expires_at,
               ba.balance, ba.status, ba.iban
        FROM bank_cards bc
        JOIN bank_accounts ba ON ba.id = bc.account_id
        WHERE bc.unique_id = ?
        ORDER BY bc.id DESC LIMIT 1
    ]], { uid })

    -- Enrichir avec les métadonnées inventaire
    if data then
        local physMeta, _ = CardManager.GetPhysicalCardMeta(src)
        if physMeta then
            data.meta_blocked  = physMeta.blocked  or false
            data.meta_disabled = physMeta.disabled or false
            data.meta_expire   = physMeta.expireDate or nil
            data.meta_owner    = physMeta.owner or nil
        end
    end

    TriggerClientEvent("kt_banque:card:statusReceived", src, data)
end)

-- ──────────────────────────────────────────
-- BLOCAGE VOLONTAIRE DE CARTE (joueur)
-- ──────────────────────────────────────────

RegisterNetEvent("kt_banque:card:selfBlock", function()
    local src    = source
    local player = Union.GetPlayer(src)
    if not player or not player.currentCharacter then return end

    local uid  = player.currentCharacter.unique_id
    local card = DB.GetCard(uid)

    if not card then
        TriggerClientEvent('bank:client:notify', src, 'error', "Aucune carte active à bloquer")
        return
    end

    -- Bloquer en base
    DB.BlockCard(card.id)

    -- Mettre à jour les métadonnées inventaire
    CardManager.UpdateCardMetadata(src, uid, {
        blocked     = true,
        blockReason = "Blocage volontaire",
        blockedAt   = os.time()
    })

    DB.Log(uid, "card_self_blocked", ("Carte #%d bloquée volontairement"):format(card.id))

    TriggerClientEvent('bank:client:notify', src, 'success', "Carte bloquée. Demandez un remplacement au guichet")
    TriggerClientEvent("kt_banque:card:checkStatus") -- rafraîchir
end)

print('^2[KT Banque]^7 Card recovery (server) chargé')