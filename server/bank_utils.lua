local oxmysql = exports.oxmysql
local DB = Config.DB

BankUtils = {}

-----------------------------------
-- 🔧 HELPERS BASE DE DONNÉES
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
-- 🔢 GÉNÉRATION IBAN-LIKE
-----------------------------------
function BankUtils.generateIBANLike()
    local function randDigits(n)
        local s = ""
        for i = 1, n do
            s = s .. tostring(math.random(0, 9))
        end
        return s
    end
    
    for attempt = 1, 10 do
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
    
    return "FR" .. tostring(math.random(10000000, 99999999))
end

-----------------------------------
-- 💳 GÉNÉRATION NUMÉRO DE CARTE
-----------------------------------
function BankUtils.generateCardNumber()
    for attempt = 1, 10 do
        local cardNum = string.format("4%07d%04d", math.random(0, 9999999), math.random(1000, 9999))
        
        local query = string.format("SELECT id FROM %s WHERE card_number = ? LIMIT 1", DB.bank_cards_table)
        local exists = BankUtils.dbFetch(query, {cardNum})
        
        if not exists or #exists == 0 then
            return cardNum
        end
    end
    
    return tostring(os.time()) .. tostring(math.random(1000, 9999))
end

-----------------------------------
-- 🔍 RÉCUPÉRATION CARTE DEPUIS INVENTAIRE
-----------------------------------
function BankUtils.getCardFromInventory(source)
    for cardType, itemName in pairs(Config.BankCardItem) do
        local items = exports.ox_inventory:Search(source, 'slots', itemName)
        
        if items then
            for _, item in pairs(items) do
                if item.metadata and (item.metadata.id or item.metadata.account_id) then
                    item.card_type = cardType
                    item.item_name = itemName
                    return item
                end
            end
        end
    end
    return nil
end

-----------------------------------
-- 🔍 RÉCUPÉRATION CARTE DEPUIS DB
-----------------------------------
function BankUtils.getCardFromDB(cardId)
    if not cardId then return nil end
    
    local query = string.format("SELECT * FROM %s WHERE id = ? AND active = 1 LIMIT 1", DB.bank_cards_table)
    local result = BankUtils.dbFetch(query, {cardId})
    
    if result and result[1] then
        return result[1]
    end
    return nil
end

-----------------------------------
-- 🏦 RÉCUPÉRATION COMPTE
-----------------------------------
function BankUtils.getAccount(accountId)
    if not accountId then return nil end
    
    local query = string.format("SELECT * FROM %s WHERE ID = ? LIMIT 1", DB.banking_table)
    local result = BankUtils.dbFetch(query, {accountId})
    
    if result and result[1] then
        return result[1]
    end
    return nil
end

-----------------------------------
-- 🎯 LIMITES PAR TYPE DE CARTE
-----------------------------------
function BankUtils.getLimitsForCardType(cardType)
    return Config.CardLimits[cardType] or Config.CardLimits["carte_basique"]
end

-----------------------------------
-- 🔐 VALIDATION PIN
-----------------------------------
function BankUtils.validatePinAndGetCard(cardId, pin)
    local card = BankUtils.getCardFromDB(cardId)
    if not card then
        return nil, Config.Notifications.no_card
    end
    
    if tostring(card.pin) ~= tostring(pin) then
        return nil, Config.Notifications.incorrect_pin
    end
    
    return card, nil
end

-----------------------------------
-- 💰 VÉRIFIER ARGENT OX_INVENTORY
-----------------------------------
function BankUtils.getPlayerMoney(source)
    local items = exports.ox_inventory:Search(source, 'count', 'money')
    return items or 0
end

function BankUtils.removePlayerMoney(source, amount)
    return exports.ox_inventory:RemoveItem(source, 'money', amount)
end

function BankUtils.addPlayerMoney(source, amount)
    return exports.ox_inventory:AddItem(source, 'money', amount)
end

-----------------------------------
-- 📊 DEBUG PRINT
-----------------------------------
function BankUtils.debugPrint(message)
    if Config.Debug then
        print(("^3[BANK DEBUG]^7 %s"):format(message))
    end
end

print('^2[KT Banque]^7 Utilitaires chargés')