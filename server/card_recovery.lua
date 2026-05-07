-- kt_banque/server/card_recovery.lua

local RECOVERY_COST = 1000

RegisterNetEvent("kt_banque:card:recover", function()
    local src    = source
    local player = PlayerManager.get(src)

    if not player or not player.currentCharacter then
        TriggerClientEvent("kt_banque:card:recoverResult", src, false, "Aucun personnage actif.")
        return
    end

    local uid = player.currentCharacter.unique_id

    -- 1. Vérifier que la carte existe et est bien bloquée
    Database.fetchOne([[
        SELECT bc.id, bc.active, bc.expires_at
        FROM bank_cards bc
        WHERE bc.unique_id = ?
        LIMIT 1
    ]], { uid }, function(card)

        if not card then
            TriggerClientEvent("kt_banque:card:recoverResult", src, false,
                "Aucune carte bancaire trouvée sur ce compte.")
            return
        end

        if card.active == 1 then
            TriggerClientEvent("kt_banque:card:recoverResult", src, false,
                "Votre carte est déjà active.")
            return
        end

        -- 2. Vérifier expiration
        -- (optionnel : si expirée on refuse et on propose d'en émettre une nouvelle)
        -- Pour l'instant on réactive même si expirée et on repousse la date

        -- 3. Vérifier le solde
        Bank.getBalance(uid, function(balance)
            if balance < RECOVERY_COST then
                TriggerClientEvent("kt_banque:card:recoverResult", src, false,
                    string.format("Solde insuffisant. Coût : $%d | Votre solde : $%d",
                        RECOVERY_COST, balance))
                return
            end

            -- 4. Débiter
            Bank.withdraw(uid, RECOVERY_COST, "Remplacement carte bancaire", function(success)
                if not success then
                    TriggerClientEvent("kt_banque:card:recoverResult", src, false,
                        "Erreur lors du paiement.")
                    return
                end

                -- 5. Réactiver la carte + repousser expiration d'1 an
                Database.execute([[
                    UPDATE bank_cards
                    SET active     = 1,
                        expires_at = DATE_ADD(NOW(), INTERVAL 1 YEAR)
                    WHERE id = ?
                ]], { card.id }, function(result)
                    local affected = type(result) == "table"
                        and (result.affectedRows or 0) or (result or 0)

                    if affected and affected > 0 then
                        Logger:info(string.format(
                            "[BANQUE] %s a récupéré sa carte bancaire pour $%d",
                            player.name, RECOVERY_COST
                        ))

                        -- Log en bank_logs
                        Database.execute(
                            "INSERT INTO bank_logs (unique_id, action, details) VALUES (?, ?, ?)",
                            { uid, "card_recovery", string.format("Carte #%d réactivée pour $%d", card.id, RECOVERY_COST) },
                            function() end
                        )

                        TriggerClientEvent("kt_banque:card:recoverResult", src, true, nil)
                    else
                        -- Remboursement si l'UPDATE échoue
                        Bank.deposit(uid, RECOVERY_COST, "Remboursement récupération carte", function() end)
                        TriggerClientEvent("kt_banque:card:recoverResult", src, false,
                            "Erreur lors de la réactivation. Vous avez été remboursé.")
                    end
                end)
            end)
        end)
    end)
end)


-- Vérifie le statut de la carte (appelé à l'ouverture du menu banque)
RegisterNetEvent("kt_banque:card:checkStatus", function()
    local src    = source
    local player = PlayerManager.get(src)
    if not player or not player.currentCharacter then return end

    local uid = player.currentCharacter.unique_id

    Database.fetchOne([[
        SELECT
            bc.id, bc.card_number, bc.type, bc.active, bc.expires_at,
            ba.balance, ba.status AS account_status, ba.iban
        FROM bank_cards bc
        JOIN bank_accounts ba ON ba.id = bc.account_id
        WHERE bc.unique_id = ?
        LIMIT 1
    ]], { uid }, function(data)
        TriggerClientEvent("kt_banque:card:statusReceived", src, data or nil)
    end)
end)