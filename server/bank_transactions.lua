ESX = exports["es_extended"]:getSharedObject()
local DB = Config.DB

BankTransactions = {}

-----------------------------------
-- 💰 DÉPÔT (OPTIMISÉ & SÉCURISÉ)
-----------------------------------
RegisterNetEvent('bank:server:deposit', function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local amount = tonumber(data.amount)
    local cardId = tonumber(data.cardId)
    local pin = tostring(data.pin)
    
    BankUtils.debugPrint(string.format("DÉPÔT demandé - Joueur: %s | Montant: $%s", xPlayer.getName(), amount))
    
    -- Validation du montant
    local isValid, error = BankUtils.validateAmount(amount, 1, nil)
    if not isValid then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = error
        })
        return
    end
    
    -- Validation PIN et récupération carte
    local cardRow, err = BankUtils.validatePinAndGetCard(cardId, pin)
    if not cardRow then
        BankUtils.debugPrint("Validation échouée: " .. err)
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = err
        })
        return
    end
    
    -- Vérifier que le compte appartient au joueur
    if not BankUtils.isAccountOwner(cardRow.account_id, xPlayer.identifier) then
        BankUtils.debugPrint("Tentative de dépôt sur un compte non possédé")
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "Ce compte ne vous appartient pas"
        })
        return
    end
    
    -- Vérifier les limites de la carte
    local limits = BankUtils.getLimitsForCardType(cardRow.card_type)
    if amount > limits.MaxDeposit then
        BankUtils.debugPrint(string.format("Limite dépassée - Max: $%s", limits.MaxDeposit))
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = string.format("💳 Limite de dépôt: $%s", limits.MaxDeposit)
        })
        return
    end
    
    -- Vérifier l'argent disponible
    local playerMoney = BankUtils.getPlayerMoney(src)
    if playerMoney < amount then
        BankUtils.debugPrint(string.format("Argent insuffisant - Requis: $%s | Possédé: $%s", amount, playerMoney))
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = Config.Notifications.insufficient_cash or "💵 Argent insuffisant"
        })
        return
    end
    
    -- Retirer l'argent
    if not BankUtils.removePlayerMoney(src, amount) then
        BankUtils.debugPrint("Échec du retrait d'argent")
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "Erreur lors du retrait de l'argent"
        })
        return
    end
    
    -- Ajouter au compte bancaire
    if not BankUtils.updateBalance(cardRow.account_id, amount, "add") then
        -- ROLLBACK: remettre l'argent au joueur
        BankUtils.addPlayerMoney(src, amount)
        BankUtils.debugPrint("Échec de la mise à jour du solde - Rollback effectué")
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "Erreur lors de la mise à jour du compte"
        })
        return
    end
    
    -- Log de la transaction
    BankLogs.insert(
        cardRow.account_id, 
        "deposit", 
        amount, 
        xPlayer.identifier, 
        string.format("Dépôt via ATM - %s", xPlayer.getName())
    )
    
    -- Succès
    local newBalance = BankUtils.getAccount(cardRow.account_id).balance
    BankUtils.debugPrint(string.format("DÉPÔT RÉUSSI - Montant: $%s | Nouveau solde: $%s", amount, newBalance))
    
    TriggerClientEvent('ox_lib:notify', src, {
        type = 'success',
        description = string.format(Config.Notifications.deposit_success or "✅ Dépôt de $%s effectué", amount)
    })
    
    TriggerClientEvent('bank:client:updateBalance', src, newBalance)
end)

-----------------------------------
-- 💵 RETRAIT (OPTIMISÉ & SÉCURISÉ)
-----------------------------------
RegisterNetEvent('bank:server:withdraw', function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local amount = tonumber(data.amount)
    local cardId = tonumber(data.cardId)
    local pin = tostring(data.pin)
    
    BankUtils.debugPrint(string.format("RETRAIT demandé - Joueur: %s | Montant: $%s", xPlayer.getName(), amount))
    
    -- Validation du montant
    local isValid, error = BankUtils.validateAmount(amount, 1, nil)
    if not isValid then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = error
        })
        return
    end
    
    -- Validation PIN et récupération carte
    local cardRow, err = BankUtils.validatePinAndGetCard(cardId, pin)
    if not cardRow then
        BankUtils.debugPrint("Validation échouée: " .. err)
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = err
        })
        return
    end
    
    -- Vérifier que le compte appartient au joueur
    if not BankUtils.isAccountOwner(cardRow.account_id, xPlayer.identifier) then
        BankUtils.debugPrint("Tentative de retrait d'un compte non possédé")
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "Ce compte ne vous appartient pas"
        })
        return
    end
    
    -- Vérifier les limites de la carte
    local limits = BankUtils.getLimitsForCardType(cardRow.card_type)
    if amount > limits.MaxWithdraw then
        BankUtils.debugPrint(string.format("Limite dépassée - Max: $%s", limits.MaxWithdraw))
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = string.format("💳 Limite de retrait: $%s", limits.MaxWithdraw)
        })
        return
    end
    
    -- Vérifier le solde du compte
    local account = BankUtils.getAccount(cardRow.account_id)
    if not account or account.balance < amount then
        BankUtils.debugPrint(string.format("Solde insuffisant - Requis: $%s | Solde: $%s", amount, account and account.balance or 0))
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = Config.Notifications.insufficient_balance or "💳 Solde insuffisant"
        })
        return
    end
    
    -- Retirer du compte bancaire
    if not BankUtils.updateBalance(cardRow.account_id, amount, "remove") then
        BankUtils.debugPrint("Échec de la mise à jour du solde")
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "Erreur lors de la mise à jour du compte"
        })
        return
    end
    
    -- Ajouter l'argent au joueur
    if not BankUtils.addPlayerMoney(src, amount) then
        -- ROLLBACK: remettre l'argent sur le compte
        BankUtils.updateBalance(cardRow.account_id, amount, "add")
        BankUtils.debugPrint("Échec de l'ajout d'argent - Rollback effectué")
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "Erreur: Inventaire plein ou problème ox_inventory"
        })
        return
    end
    
    -- Log de la transaction
    BankLogs.insert(
        cardRow.account_id, 
        "withdraw", 
        amount, 
        xPlayer.identifier, 
        string.format("Retrait via ATM - %s", xPlayer.getName())
    )
    
    -- Succès
    local newBalance = BankUtils.getAccount(cardRow.account_id).balance
    BankUtils.debugPrint(string.format("RETRAIT RÉUSSI - Montant: $%s | Nouveau solde: $%s", amount, newBalance))
    
    TriggerClientEvent('ox_lib:notify', src, {
        type = 'success',
        description = string.format(Config.Notifications.withdraw_success or "✅ Retrait de $%s effectué", amount)
    })
    
    TriggerClientEvent('bank:client:updateBalance', src, newBalance)
end)

-----------------------------------
-- 🔄 TRANSFERT (OPTIMISÉ & SÉCURISÉ)
-----------------------------------
RegisterNetEvent('bank:server:transfer', function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local amount = tonumber(data.amount)
    local cardId = tonumber(data.cardId)
    local pin = tostring(data.pin)
    local target = tostring(data.target):trim()
    
    BankUtils.debugPrint(string.format("TRANSFERT demandé - Joueur: %s | Montant: $%s | Cible: %s", xPlayer.getName(), amount, target))
    
    -- Validation du montant
    local isValid, error = BankUtils.validateAmount(amount, 1, nil)
    if not isValid then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = error
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
    
    -- Validation PIN et récupération carte
    local cardRow, err = BankUtils.validatePinAndGetCard(cardId, pin)
    if not cardRow then
        BankUtils.debugPrint("Validation échouée: " .. err)
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = err
        })
        return
    end
    
    -- Vérifier que le compte appartient au joueur
    if not BankUtils.isAccountOwner(cardRow.account_id, xPlayer.identifier) then
        BankUtils.debugPrint("Tentative de transfert depuis un compte non possédé")
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "Ce compte ne vous appartient pas"
        })
        return
    end
    
    -- Vérifier le solde
    local fromAccount = BankUtils.getAccount(cardRow.account_id)
    if not fromAccount or fromAccount.balance < amount then
        BankUtils.debugPrint(string.format("Solde insuffisant - Requis: $%s | Solde: $%s", amount, fromAccount and fromAccount.balance or 0))
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = Config.Notifications.insufficient_balance or "💳 Solde insuffisant"
        })
        return
    end
    
    -- Rechercher compte destinataire
    local targetAccount = nil
    
    -- Si c'est un nombre, chercher par ID
    if tonumber(target) then
        targetAccount = BankUtils.getAccount(tonumber(target))
    else
        -- Sinon, chercher par IBAN ou identifier
        local query = string.format(
            "SELECT * FROM %s WHERE label = ? OR identifier = ? LIMIT 1",
            DB.banking_table
        )
        local result = BankUtils.dbFetch(query, {target, target})
        if result and result[1] then
            targetAccount = result[1]
        end
    end
    
    if not targetAccount then
        BankUtils.debugPrint("Compte destinataire introuvable: " .. target)
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = Config.Notifications.target_not_found or "❌ Compte destinataire introuvable"
        })
        return
    end
    
    -- Empêcher transfert vers soi-même
    if targetAccount.ID == fromAccount.ID then
        BankUtils.debugPrint("Tentative de transfert vers soi-même")
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "❌ Impossible de transférer vers votre propre compte"
        })
        return
    end
    
    -- Effectuer le transfert (transaction atomique)
    local success1 = BankUtils.updateBalance(fromAccount.ID, amount, "remove")
    if not success1 then
        BankUtils.debugPrint("Échec du débit du compte source")
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "Erreur lors du transfert"
        })
        return
    end
    
    local success2 = BankUtils.updateBalance(targetAccount.ID, amount, "add")
    if not success2 then
        -- ROLLBACK: remettre l'argent sur le compte source
        BankUtils.updateBalance(fromAccount.ID, amount, "add")
        BankUtils.debugPrint("Échec du crédit du compte cible - Rollback effectué")
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "Erreur lors du transfert - Transaction annulée"
        })
        return
    end
    
    -- Logs
    BankLogs.insert(
        fromAccount.ID, 
        "transfer_out", 
        amount, 
        xPlayer.identifier, 
        string.format("Transfert vers %s (%s)", targetAccount.label or targetAccount.ID, target)
    )
    
    BankLogs.insert(
        targetAccount.ID, 
        "transfer_in", 
        amount, 
        targetAccount.identifier, 
        string.format("Reçu de %s (%s)", fromAccount.label or fromAccount.ID, xPlayer.getName())
    )
    
    -- Notifier le destinataire s'il est en ligne
    local targetPlayer = ESX.GetPlayerFromIdentifier(targetAccount.identifier)
    if targetPlayer then
        TriggerClientEvent('ox_lib:notify', targetPlayer.source, {
            type = 'success',
            description = string.format("💰 Transfert reçu: $%s de %s", amount, xPlayer.getName())
        })
    end
    
    -- Succès
    local newBalance = BankUtils.getAccount(fromAccount.ID).balance
    BankUtils.debugPrint(string.format("TRANSFERT RÉUSSI - Montant: $%s | Nouveau solde: $%s", amount, newBalance))
    
    TriggerClientEvent('ox_lib:notify', src, {
        type = 'success',
        description = string.format(Config.Notifications.transfer_success or "✅ Transfert de $%s effectué", amount)
    })
    
    TriggerClientEvent('bank:client:updateBalance', src, newBalance)
end)

-- Helper pour trim les strings
if not string.trim then
    function string:trim()
        return self:gsub("^%s*(.-)%s*$", "%1")
    end
end

print('^2[KT Banque]^7 Système de transactions chargé (OPTIMISÉ & SÉCURISÉ)')