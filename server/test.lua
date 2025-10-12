-- Assure-toi d'avoir ESX défini comme dans ton projet
ESX = ESX or exports['es_extended']:getSharedObject()

RegisterCommand("prbn", function(source, args)
   
    -- si source ~= 0 alors commande lancée par un joueur ; on autorise seulement console/admin si voulu
   
    local players = ESX.GetPlayers() -- liste d'ids
    print(("---- Comptes pour %d joueurs ----"):format(#players))

    for _, id in ipairs(players) do
        local xPlayer = ESX.GetPlayerFromId(id)
        if xPlayer then
            -- Récupère les comptes si la fonction existe
            local accounts = nil
            if xPlayer.getAccounts then
                accounts = xPlayer.getAccounts()
            else
                -- fallback selon anciennes versions : getAccount
                accounts = {}
                local success, bank = pcall(function() return xPlayer.getAccount and xPlayer.getAccount('bank') end)
                if success and bank and bank.money then
                    table.insert(accounts, {name='bank', money = bank.money})
                end
                -- tu peux ajouter 'money' etc si nécessaire
            end

            -- Affiche l'identifiant et les comptes
            local identifier = xPlayer.identifier or ("player:"..id)
            print(("Player id=%s (server id=%d)"):format(identifier, id))
            if type(accounts) == "table" then
                for _, acc in ipairs(accounts) do
                    -- acc.name et acc.money sont la structure standard ESX
                    print(("  - %s : %s"):format(tostring(acc.name), tostring(acc.money)))
                end
            else
                print("  - Aucun compte trouvé ou format inattendu")
            end
        else
            print(("  - Aucun xPlayer trouvé pour id %s"):format(tostring(id)))
        end
    end

    print("---- Fin ----")
end, false)

RegisterCommand("checkbank", function(source)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then
        print("^1[ERREUR]^7 Aucun joueur trouvé pour la source:", src)
        return
    end

    local identifier = xPlayer.identifier
    print(("--- 💳 Comptes bancaires pour %s ---"):format(identifier))

    -- 🔹 Lecture du compte ESX
    local esxMoney = xPlayer.getMoney()
    local esxBank = xPlayer.getAccount('bank').money
    local esxBlack = xPlayer.getAccount('black_money').money
    print(("💰 ESX - Argent: %s | Banque: %s | Sale: %s"):format(esxMoney, esxBank, esxBlack))

    -- 🔹 Lecture du compte KT Banque
    local result = MySQL.query.await("SELECT account_id, balance, label FROM banking WHERE identifier = ?", {identifier})
    if result and #result > 0 then
        for _, row in ipairs(result) do
            print(("🏦 [KT BANQUE] %s (%s): %.2f$"):format(row.label or "Compte", row.account_id, row.balance))
        end
    else
        print("⚠️ Aucun compte trouvé dans la table `banking` pour cet utilisateur.")
    end
end, false)
