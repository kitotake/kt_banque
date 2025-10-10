ESX = exports["es_extended"]:getSharedObject()
local DB = Config.DB

BankTransactions = {}

-----------------------------------
-- 💰 DÉPÔT (CORRIGÉ AVEC OX_INVENTORY)
-----------------------------------
RegisterNetEvent('bank:server:deposit', function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local amount = tonumber(data.amount)
    local cardId = tonumber(data.cardId)
    local pin = tostring(data.pin)
    
    print(("^3[DÉPÔT]^7 Joueur: %s | Montant: $%s"):format(xPlayer.getName(), amount))
    
    -- Validation montant
    if not amount or amount <= 0 then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "Montant invalide"
        })
        return
    end
    
    -- Validation PIN et carte
    local cardRow, err = BankUtils.validatePinAndGetCard(cardId, pin)
    if not cardRow then
        print(("^1[ERREUR]^7 %s"):format(err))
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = err
        })
        return
    end
    
    -- Vérifier les limites
    local limits = BankUtils.getLimitsForCardType(cardRow.card_type)
    if amount > limits.MaxDeposit then
        print(("^1[ERREUR]^7 Limite dépassée - Max: $%s"):format(limits.MaxDeposit))
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = string.format("💳 Limite de dépôt: $%s", limits.MaxDeposit)
        })
        return
    end
    
    -- CORRECTION: Utiliser ox_inventory pour vérifier l'argent
    local playerMoney = BankUtils.getPlayerMoney(src)
    print(("^6[INFO]^7 Argent du joueur: $%s | Montant demandé: $%s"):format(playerMoney, amount))
    
    if playerMoney < amount then
        print(("^1[ERREUR]^7 Argent insuffisant - Requis: $%s | Possédé: $%s"):format(amount, playerMoney))
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = Config.Notifications.insufficient_cash
        })
        return
    end
    
    -- CORRECTION: Retirer l'argent avec ox_inventory
    local removed = BankUtils.removePlayerMoney(src, amount)
    if not removed then
        print("^1[ERREUR]^7 Impossible de retirer l'argent de l'inventaire")
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "Erreur lors du retrait de l'argent"
        })
        return
    end
    
    -- Mettre à jour le solde bancaire
    local updateQuery = string.format("UPDATE %s SET balance = balance + ? WHERE ID = ?", DB.banking_table)
    BankUtils.dbExecute(updateQuery, {amount, cardRow.account_id})
    
    -- Log de la transaction
    BankLogs.insert(cardRow.account_id, "deposit", amount, cardRow.identifier, "Dépôt via ATM")
    
    print(("^2[SUCCÈS]^7 Dépôt de $%s effectué"):format(amount))
    TriggerClientEvent('ox_lib:notify', src, {
        type = 'success',
        description = string.format(Config.Notifications.deposit_success, amount)
    })
    
    -- Mettre à jour l'interface
    local acc = BankUtils.getAccount(cardRow.account_id)
    TriggerClientEvent('bank:client:updateBalance', src, acc.balance or 0)
end)

-----------------------------------
-- 💵 RETRAIT (CORRIGÉ AVEC OX_INVENTORY)
-----------------------------------
RegisterNetEvent('bank:server:withdraw', function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local amount = tonumber(data.amount)
    local cardId = tonumber(data.cardId)
    local pin = tostring(data.pin)
    
    print(("^3[RETRAIT]^7 Joueur: %s | Montant: $%s"):format(xPlayer.getName(), amount))
    
    -- Validation montant
    if not amount or amount <= 0 then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "Montant invalide"
        })
        return
    end
    
    -- Validation PIN et carte
    local cardRow, err = BankUtils.validatePinAndGetCard(cardId, pin)
    if not cardRow then
        print(("^1[ERREUR]^7 %s"):format(err))
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = err
        })
        return
    end
    
    -- Vérifier les limites
    local limits = BankUtils.getLimitsForCardType(cardRow.card_type)
    if amount > limits.MaxWithdraw then
        print(("^1[ERREUR]^7 Limite dépassée - Max: $%s"):format(limits.MaxWithdraw))
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = string.format("💳 Limite de retrait: $%s", limits.MaxWithdraw)
        })
        return
    end
    
    -- Vérifier le solde du compte
    local acc = BankUtils.getAccount(cardRow.account_id)
    if not acc or (acc.balance or 0) < amount then
        print(("^1[ERREUR]^7 Solde insuffisant - Requis: $%s | Solde: $%s"):format(amount, acc and acc.balance or 0))
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = Config.Notifications.insufficient_balance
        })
        return
    end
    
    -- Mettre à jour le solde bancaire
    local updateQuery = string.format("UPDATE %s SET balance = balance - ? WHERE ID = ?", DB.banking_table)
    BankUtils.dbExecute(updateQuery, {amount, cardRow.account_id})
    
    -- CORRECTION: Ajouter l'argent avec ox_inventory
    local added = BankUtils.addPlayerMoney(src, amount)
    if not added then
        -- ROLLBACK: remettre l'argent sur le compte
        local rollbackQuery = string.format("UPDATE %s SET balance = balance + ? WHERE ID = ?", DB.banking_table)
        BankUtils.dbExecute(rollbackQuery, {amount, cardRow.account_id})
        
        print("^1[ERREUR]^7 Impossible d'ajouter l'argent à l'inventaire - Transaction annulée")
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "Erreur lors de l'ajout de l'argent (inventaire plein?)"
        })
        return
    end
    
    -- Log de la transaction
    BankLogs.insert(cardRow.account_id, "withdraw", amount, cardRow.identifier, "Retrait via ATM")
    
    print(("^2[SUCCÈS]^7 Retrait de $%s effectué"):format(amount))
    TriggerClientEvent('ox_lib:notify', src, {
        type = 'success',
        description = string.format(Config.Notifications.withdraw_success, amount)
    })
    
    -- Mettre à jour l'interface
    local acc2 = BankUtils.getAccount(cardRow.account_id)
    TriggerClientEvent('bank:client:updateBalance', src, acc2.balance or 0)
end)

-----------------------------------
-- 🔄 TRANSFERT
-----------------------------------
RegisterNetEvent('bank:server:transfer', function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local amount = tonumber(data.amount)
    local cardId = tonumber(data.cardId)
    local pin = tostring(data.pin)
    local target = data.target
    
    print(("^3[TRANSFERT]^7 Joueur: %s | Montant: $%s | Cible: %s"):format(xPlayer.getName(), amount, target))
    
    -- Validation montant
    if not amount or amount <= 0 then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "Montant invalide"
        })
        return
    end
    
    -- Validation destinataire
    if not target or target == "" then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "Destinataire invalide"
        })
        return
    end
    
    -- Validation PIN et carte
    local cardRow, err = BankUtils.validatePinAndGetCard(cardId, pin)
    if not cardRow then
        print(("^1[ERREUR]^7 %s"):format(err))
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = err
        })
        return
    end
    
    -- Vérifier le solde
    local fromAcc = BankUtils.getAccount(cardRow.account_id)
    if not fromAcc or (fromAcc.balance or 0) < amount then
        print(("^1[ERREUR]^7 Solde insuffisant - Requis: $%s | Solde: $%s"):format(amount, fromAcc and fromAcc.balance or 0))
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = Config.Notifications.insufficient_balance
        })
        return
    end
    
    -- Rechercher compte destinataire (par ID ou IBAN)
    local targetAcc = nil
    if tonumber(target) then
        targetAcc = BankUtils.getAccount(tonumber(target))
    else
        local query = string.format(
            "SELECT * FROM %s WHERE label = ? OR identifier = ? LIMIT 1",
            DB.banking_table
        )
        local result = BankUtils.dbFetch(query, {target, target})
        if result and result[1] then
            targetAcc = result[1]
        end
    end
    
    if not targetAcc then
        print("^1[ERREUR]^7 Compte destinataire introuvable")
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = Config.Notifications.target_not_found
        })
        return
    end
    
    -- Empêcher transfert vers soi-même
    if targetAcc.ID == fromAcc.ID then
        print("^1[ERREUR]^7 Tentative de transfert vers soi-même")
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "❌ Vous ne pouvez pas transférer vers votre propre compte"
        })
        return
    end
    
    -- Effectuer le transfert
    local updateQuery1 = string.format("UPDATE %s SET balance = balance - ? WHERE ID = ?", DB.banking_table)
    local updateQuery2 = string.format("UPDATE %s SET balance = balance + ? WHERE ID = ?", DB.banking_table)
    
    BankUtils.dbExecute(updateQuery1, {amount, fromAcc.ID})
    BankUtils.dbExecute(updateQuery2, {amount, targetAcc.ID})
    
    -- Logs
    BankLogs.insert(fromAcc.ID, "transfer_out", amount, cardRow.identifier, 
        string.format("Transfert vers %s", targetAcc.label or targetAcc.ID))
    BankLogs.insert(targetAcc.ID, "transfer_in", amount, xPlayer.identifier, 
        string.format("Reçu de %s", fromAcc.label or fromAcc.ID))
    
    print(("^2[SUCCÈS]^7 Transfert de $%s vers compte ID %s"):format(amount, targetAcc.ID))
    TriggerClientEvent('ox_lib:notify', src, {
        type = 'success',
        description = string.format(Config.Notifications.transfer_success, amount)
    })
    
    -- Mettre à jour l'interface
    local after = BankUtils.getAccount(fromAcc.ID)
    TriggerClientEvent('bank:client:updateBalance', src, after.balance or 0)
end)

print('^2[KT Banque]^7 Système de transactions chargé (CORRIGÉ OX_INVENTORY)')