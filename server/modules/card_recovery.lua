-- ==================== KT BANQUE v7.5.0 — SERVER/MODULES/CARD_RECOVERY ====================
-- Gestion de la récupération de carte bloquée.

local RECOVERY_COST = 1000

-- ──────────────────────────────────────────
-- RÉCUPÉRER LA CARTE
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

    local acc = DB.GetAccount(uid)
    if not acc or acc.balance < RECOVERY_COST then
        local bal = acc and acc.balance or 0
        TriggerClientEvent("kt_banque:card:recoverResult", src, false,
            ("Solde insuffisant ($%d / $%d)"):format(bal, RECOVERY_COST))
        return
    end

    -- Débiter le compte
    local newBalance = acc.balance - RECOVERY_COST
    DB.UpdateBalance(acc.id, newBalance)
    DB.AddTransaction(acc.id, 'system', 'withdraw', RECOVERY_COST, newBalance, nil, 'Récupération carte bancaire')

    -- Réactiver la carte (anti double-exécution)
    local ok = DB.ReactivateCard(card.id)
    if not ok then
        -- Rollback
        DB.UpdateBalance(acc.id, acc.balance)
        TriggerClientEvent("kt_banque:card:recoverResult", src, false, "Erreur réactivation.")
        return
    end

    DB.Log(uid, "card_recovery", ("Carte #%d réactivée — $%d débité"):format(card.id, RECOVERY_COST))
    TriggerClientEvent("kt_banque:card:recoverResult", src, true)
    TriggerClientEvent('bank:client:updateBalance', src, newBalance)

    if Config.Debug then
        print(('[KT Banque] %s a récupéré sa carte ($%d)'):format(player.name or uid, RECOVERY_COST))
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

    TriggerClientEvent("kt_banque:card:statusReceived", src, data)
end)

print('^2[KT Banque]^7 Card recovery (server) chargé')
