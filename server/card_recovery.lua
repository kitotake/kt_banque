local RECOVERY_COST = 1000
local MySQL = exports.oxmysql

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- RECOVER CARD
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RegisterNetEvent("kt_banque:card:recover", function()
    local src = source
    local player = exports['union']:GetPlayerFromId(src)

    if not player or not player.currentCharacter then
        TriggerClientEvent("kt_banque:card:recoverResult", src, false, "Aucun personnage actif.")
        return
    end

    local uid = player.currentCharacter.unique_id

    -- Get latest card
    MySQL:single([[
        SELECT id, active, expires_at
        FROM bank_cards
        WHERE unique_id = ?
        ORDER BY id DESC
        LIMIT 1
    ]], { uid }, function(card)

        if not card then
            TriggerClientEvent("kt_banque:card:recoverResult", src, false, "Aucune carte trouvée.")
            return
        end

        if tonumber(card.active) == 1 then
            TriggerClientEvent("kt_banque:card:recoverResult", src, false, "Votre carte est déjà active.")
            return
        end

        -- Balance check
        Bank.getBalance(uid, function(balance)

            if balance < RECOVERY_COST then
                TriggerClientEvent("kt_banque:card:recoverResult", src, false,
                    ("Solde insuffisant ($%d / $%d)"):format(balance, RECOVERY_COST))
                return
            end

            -- Withdraw
            Bank.withdraw(uid, RECOVERY_COST, "Récupération carte bancaire", function(success)

                if not success then
                    TriggerClientEvent("kt_banque:card:recoverResult", src, false, "Erreur paiement.")
                    return
                end

                -- Safe update (anti double execute)
                MySQL:execute([[
                    UPDATE bank_cards
                    SET active = 1,
                        expires_at = DATE_ADD(CURDATE(), INTERVAL 1 YEAR)
                    WHERE id = ?
                    AND active = 0
                ]], { card.id }, function(result)

                    local affected = result and result.affectedRows or 0

                    if affected > 0 then

                        Logger:info(("[BANQUE] %s a récupéré sa carte ($%d)"):format(player.name, RECOVERY_COST))

                        MySQL:execute(
                            "INSERT INTO bank_logs (unique_id, action, details) VALUES (?, ?, ?)",
                            {
                                uid,
                                "card_recovery",
                                ("Carte #%d réactivée"):format(card.id)
                            }
                        )

                        TriggerClientEvent("kt_banque:card:recoverResult", src, true)

                    else
                        Bank.deposit(uid, RECOVERY_COST, "Rollback récupération carte", function() end)
                        TriggerClientEvent("kt_banque:card:recoverResult", src, false, "Erreur réactivation.")
                    end
                end)
            end)
        end)
    end)
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CHECK STATUS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RegisterNetEvent("kt_banque:card:checkStatus", function()
    local src = source
    local player = exports['union']:GetPlayerFromId(src)

    if not player or not player.currentCharacter then return end

    local uid = player.currentCharacter.unique_id

    MySQL:single([[
        SELECT
            bc.id,
            bc.card_number,
            bc.type,
            bc.active,
            bc.expires_at,
            ba.balance,
            ba.status,
            ba.iban
        FROM bank_cards bc
        JOIN bank_accounts ba ON ba.id = bc.account_id
        WHERE bc.unique_id = ?
        ORDER BY bc.id DESC
        LIMIT 1
    ]], { uid }, function(data)
        TriggerClientEvent("kt_banque:card:statusReceived", src, data)
    end)
end)