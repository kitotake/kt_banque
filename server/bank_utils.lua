local oxmysql = exports.oxmysql
local DB = Config.DB

BankUtils = {}

-----------------------------------
-- 🔧 HELPERS BASE DE DONNÉES (AMÉLIORÉS)
-----------------------------------
function BankUtils.dbFetch(query, params)
    local p = promise.new()
    oxmysql:query(query, params or {}, function(result)
        p:resolve(result)
    end)
    return Citizen.Await(p)
end

function BankUtils.dbExecute(query, params)
    local p = promise.new()
    oxmysql:execute(query, params or {}, function(affected)
        p:resolve(affected)
    end)
    return Citizen.Await(p)
end

function BankUtils.dbInsert(query, params)
    local p = promise.new()
    oxmysql:insert(query, params or {}, function(insertId)
        p:resolve(insertId)
    end)
    return Citizen.Await(p)
end

-----------------------------------
-- 🔢 GÉNÉRATION IBAN-LIKE (AMÉLIORÉ)
-----------------------------------
function BankUtils.generateIBANLike()
    local function randDigits(n)
        local s = ""
        for i = 1, n do
            s = s .. tostring(math.random(0, 9))
        end
        return s
    end
    
    for attempt = 1, 20 do
        local bankCode = randDigits(5)
        local account = randDigits(11)
        local checksum = randDigits(2)
        local iban = string.format("FR%s %s %s", checksum, bankCode, account)
        
        local query = string.format("SELECT ID FROM %s WHERE label = ? LIMIT 1", DB.banking_table)
        local exists = BankUtils.dbFetch(query, {iban})
        
        if not exists or #exists == 0 then
            return iban
        end
    end
    
    -- Fallback avec timestamp pour unicité garantie
    return string.format("FR%s %s", os.time(), randDigits(8))
end

-----------------------------------
-- 💳 GÉNÉRATION NUMÉRO DE CARTE (AMÉLIORÉ)
-----------------------------------
function BankUtils.generateCardNumber()
    for attempt = 1, 20 do
        -- Format: 4xxx xxxx xxxx xxxx (commence par 4 comme Visa)
        local part1 = math.random(100, 999)
        local part2 = math.random(1000, 9999)
        local part3 = math.random(1000, 9999)
        local part4 = math.random(1000, 9999)
        local cardNum = string.format("4%03d%04d%04d%04d", part1, part2, part3, part4)
        
        local query = string.format("SELECT id FROM %s WHERE card_number = ? LIMIT 1", DB.bank_cards_table)
        local exists = BankUtils.dbFetch(query, {cardNum})
        
        if not exists or #exists == 0 then
            return cardNum
        end
    end
    
    -- Fallback avec timestamp
    return string.format("4%d%04d", os.time(), math.random(1000, 9999))
end

-----------------------------------
-- 🔍 RÉCUPÉRATION CARTE DEPUIS INVENTAIRE (CORRIGÉ)
-----------------------------------
function BankUtils.getCardFromInventory(source)
    if not source then return nil end
    
    for cardType, itemName in pairs(Config.BankCardItem) do
        local items = exports.ox_inventory:Search(source, 'slots', itemName)
        
        if items then
            for slot, item in pairs(items) do
                if item and item.metadata then
                    -- Vérifier que la carte a les données nécessaires
                    if item.metadata.id and item.metadata.account_id then
                        item.card_type = cardType
                        item.item_name = itemName
                        item.slot = slot
                        
                        BankUtils.debugPrint(string.format(
                            "Carte trouvée - Type: %s | ID: %s | Compte: %s",
                            cardType, item.metadata.id, item.metadata.account_id
                        ))
                        
                        return item
                    end
                end
            end
        end
    end
    
    BankUtils.debugPrint("Aucune carte bancaire trouvée dans l'inventaire")
    return nil
end

-----------------------------------
-- 🔍 RÉCUPÉRATION CARTE DEPUIS DB (CORRIGÉ)
-----------------------------------
function BankUtils.getCardFromDB(cardId)
    if not cardId or cardId == 0 then 
        BankUtils.debugPrint("ID de carte invalide: " .. tostring(cardId))
        return nil 
    end
    
    local query = string.format("SELECT * FROM %s WHERE id = ? AND active = 1 LIMIT 1", DB.bank_cards_table)
    local result = BankUtils.dbFetch(query, {tonumber(cardId)})
    
    if result and result[1] then
        BankUtils.debugPrint(string.format(
            "Carte DB trouvée - ID: %s | Compte: %s | Type: %s",
            result[1].id, result[1].account_id, result[1].card_type
        ))
        return result[1]
    end
    
    BankUtils.debugPrint("Carte non trouvée en BDD pour ID: " .. tostring(cardId))
    return nil
end

-----------------------------------
-- 🏦 RÉCUPÉRATION COMPTE (CORRIGÉ)
-----------------------------------
function BankUtils.getAccount(accountId)
    if not accountId or accountId == 0 then 
        BankUtils.debugPrint("ID de compte invalide: " .. tostring(accountId))
        return nil 
    end
    
    local query = string.format("SELECT * FROM %s WHERE ID = ? LIMIT 1", DB.banking_table)
    local result = BankUtils.dbFetch(query, {tonumber(accountId)})
    
    if result and result[1] then
        BankUtils.debugPrint(string.format(
            "Compte trouvé - ID: %s | Solde: $%s | IBAN: %s",
            result[1].ID, result[1].balance, result[1].label
        ))
        return result[1]
    end
    
    BankUtils.debugPrint("Compte non trouvé pour ID: " .. tostring(accountId))
    return nil
end

-----------------------------------
-- 🎯 LIMITES PAR TYPE DE CARTE (AMÉLIORÉ)
-----------------------------------
function BankUtils.getLimitsForCardType(cardType)
    if not cardType or cardType == "" then
        BankUtils.debugPrint("Type de carte invalide, utilisation des limites par défaut")
        return Config.CardLimits["carte_basique"]
    end
    
    local limits = Config.CardLimits[cardType]
    
    if not limits then
        BankUtils.debugPrint(string.format(
            "Type de carte inconnu: %s, utilisation des limites par défaut",
            cardType
        ))
        return Config.CardLimits["carte_basique"]
    end
    
    BankUtils.debugPrint(string.format(
        "Limites %s - Dépôt: $%s | Retrait: $%s",
        cardType, limits.MaxDeposit, limits.MaxWithdraw
    ))
    
    return limits
end

-----------------------------------
-- 🔐 VALIDATION PIN (AMÉLIORÉ)
-----------------------------------
function BankUtils.validatePinAndGetCard(cardId, pin)
    if not cardId or cardId == 0 then
        return nil, "Carte invalide"
    end
    
    if not pin or pin == "" then
        return nil, "PIN manquant"
    end
    
    local card = BankUtils.getCardFromDB(cardId)
    
    if not card then
        return nil, Config.Notifications.no_card or "Carte introuvable"
    end
    
    -- Vérifier si la carte est active
    if card.active ~= 1 then
        return nil, "Carte désactivée"
    end
    
    -- Comparer les PINs
    local storedPin = tostring(card.pin):gsub("%s+", "")
    local inputPin = tostring(pin):gsub("%s+", "")
    
    if storedPin ~= inputPin then
        BankUtils.debugPrint(string.format(
            "PIN incorrect - Attendu: %s | Reçu: %s",
            storedPin, inputPin
        ))
        return nil, Config.Notifications.incorrect_pin or "Code PIN incorrect"
    end
    
    BankUtils.debugPrint("Validation PIN réussie")
    return card, nil
end

-----------------------------------
-- 💰 GESTION ARGENT OX_INVENTORY (CORRIGÉ)
-----------------------------------
function BankUtils.getPlayerMoney(source)
    if not source then return 0 end
    
    local success, items = pcall(function()
        return exports.ox_inventory:Search(source, 'count', 'money')
    end)
    
    if success and items then
        BankUtils.debugPrint(string.format("Argent du joueur: $%s", items))
        return items
    end
    
    BankUtils.debugPrint("Impossible de récupérer l'argent du joueur")
    return 0
end

function BankUtils.removePlayerMoney(source, amount)
    if not source or not amount or amount <= 0 then 
        return false 
    end
    
    local success, result = pcall(function()
        return exports.ox_inventory:RemoveItem(source, 'money', amount)
    end)
    
    if success and result then
        BankUtils.debugPrint(string.format("$%s retiré avec succès", amount))
        return true
    end
    
    BankUtils.debugPrint(string.format("Échec du retrait de $%s", amount))
    return false
end

function BankUtils.addPlayerMoney(source, amount)
    if not source or not amount or amount <= 0 then 
        return false 
    end
    
    local success, result = pcall(function()
        return exports.ox_inventory:AddItem(source, 'money', amount)
    end)
    
    if success and result then
        BankUtils.debugPrint(string.format("$%s ajouté avec succès", amount))
        return true
    end
    
    BankUtils.debugPrint(string.format("Échec de l'ajout de $%s (inventaire plein?)", amount))
    return false
end

-----------------------------------
-- 🔄 METTRE À JOUR LE SOLDE (NOUVEAU)
-----------------------------------
function BankUtils.updateBalance(accountId, amount, operation)
    if not accountId or not amount then return false end
    
    local query
    if operation == "add" then
        query = string.format("UPDATE %s SET balance = balance + ? WHERE ID = ?", DB.banking_table)
    elseif operation == "remove" then
        query = string.format("UPDATE %s SET balance = balance - ? WHERE ID = ?", DB.banking_table)
    else
        query = string.format("UPDATE %s SET balance = ? WHERE ID = ?", DB.banking_table)
    end
    
    local result = BankUtils.dbExecute(query, {amount, accountId})
    
    if result and result > 0 then
        BankUtils.debugPrint(string.format(
            "Solde mis à jour - Compte: %s | Opération: %s | Montant: $%s",
            accountId, operation or "set", amount
        ))
        return true
    end
    
    return false
end

-----------------------------------
-- 📊 DEBUG PRINT (AMÉLIORÉ)
-----------------------------------
function BankUtils.debugPrint(message)
    if Config.Debug then
        local timestamp = os.date("%H:%M:%S")
        print(string.format("^3[BANK DEBUG %s]^7 %s", timestamp, message))
    end
end

-----------------------------------
-- ✅ VALIDATION MONTANT (NOUVEAU)
-----------------------------------
function BankUtils.validateAmount(amount, minAmount, maxAmount)
    amount = tonumber(amount)
    
    if not amount then
        return false, "Montant invalide"
    end
    
    if amount <= 0 then
        return false, "Le montant doit être positif"
    end
    
    if minAmount and amount < minAmount then
        return false, string.format("Montant minimum: $%s", minAmount)
    end
    
    if maxAmount and amount > maxAmount then
        return false, string.format("Montant maximum: $%s", maxAmount)
    end
    
    return true, nil
end

-----------------------------------
-- 🔒 VÉRIFIER PROPRIÉTAIRE (NOUVEAU)
-----------------------------------
function BankUtils.isAccountOwner(accountId, identifier)
    if not accountId or not identifier then return false end
    
    local account = BankUtils.getAccount(accountId)
    
    if not account then
        return false
    end
    
    return account.identifier == identifier
end

print('^2[KT Banque]^7 Utilitaires chargés et améliorés')