-- ==================== KT BANQUE v7.5.0 — SERVER/MODULES/UTILS ====================
-- Fonctions utilitaires partagées côté serveur.
-- Aucune dépendance vers DB ou Bank : peut être chargé en premier.

Utils = {}

-- ──────────────────────────────────────────
-- Anti-spam
-- ──────────────────────────────────────────
local lastAction = {}

function Utils.CheckSpam(src)
    local t     = GetGameTimer()
    local delay = Config.SpamDelay or 1000
    if lastAction[src] and (t - lastAction[src]) < delay then return true end
    lastAction[src] = t
    return false
end

AddEventHandler('playerDropped', function()
    lastAction[source] = nil
end)

-- ──────────────────────────────────────────
-- Générateurs
-- ──────────────────────────────────────────
function Utils.GenerateAccountNumber()
    return "UN" .. math.random(10000000, 99999999)
end

function Utils.GenerateCardNumber()
    local parts = {}
    for i = 1, 4 do parts[i] = string.format("%04d", math.random(1000, 9999)) end
    return table.concat(parts, " ")
end

function Utils.GenerateIBAN(accountNumber)
    local num = accountNumber:gsub("UN", "")
    num = string.format("%010d", tonumber(num) or math.random(1000000000, 9999999999))
    return "FRKT" .. num
end

function Utils.GenerateExpiryDate()
    local y = tonumber(os.date("%Y")) + 3
    return string.format("%d-%s-%s", y, os.date("%m"), os.date("%d"))
end

function Utils.GenerateUUID()
    return string.gsub('xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx', '[xy]', function(c)
        local v = (c == 'x') and math.random(0, 15) or math.random(8, 11)
        return string.format('%x', v)
    end)
end

-- ──────────────────────────────────────────
-- PIN
-- ──────────────────────────────────────────
function Utils.ValidatePin(pin)
    local p = tostring(pin or "")
    return #p == 4 and p:match("^%d+$") ~= nil
end

-- Hash PIN — miroir de web/src/utils/index.ts → hashPin()
function Utils.HashPin(pin)
    local hash     = 0
    local salt     = "kt_banque_v7"
    local combined = salt .. tostring(pin)
    for i = 1, #combined do
        hash = (hash * 31 + combined:byte(i)) % (2 ^ 32)
    end
    return string.format("%08x", hash)
end

-- ──────────────────────────────────────────
-- Logs d'administration
-- ──────────────────────────────────────────
function Utils.Log(uniqueId, action, details)
    MySQL.insert.await(
        'INSERT INTO bank_logs (unique_id, action, details) VALUES (?, ?, ?)',
        { uniqueId, action, details }
    )
end

-- ──────────────────────────────────────────
-- Framework Union — wrappers légers
-- ──────────────────────────────────────────
Union = {}

function Union.GetPlayer(src)
    return exports["union"]:GetPlayerFromId(src)
end

function Union.GetCharacterUniqueId(src)
    local identifier = GetPlayerIdentifier(src, 0)
    if not identifier then return nil end
    local result = MySQL.single.await(
        'SELECT unique_id FROM user_character WHERE identifier = ? LIMIT 1',
        { identifier }
    )
    return result and result.unique_id or nil
end

function Union.GetOwnerIdentifier(player)
    return player.identifier or player.license or player.citizenid
end

function Union.GetName(player)
    return (player.getName and player.getName()) or player.name or "Inconnu"
end

-- ──────────────────────────────────────────
-- kt_inventory — wrappers
-- ──────────────────────────────────────────
OxInv = {}

function OxInv.GetMoney(src)
    -- kt_inventory stocke le cash dans l'item "money"
    return exports.kt_inventory:GetItemCount(src, "money") or 0
end

function OxInv.AddMoney(src, amount)
    exports.kt_inventory:AddItem(src, "money", amount)
end

function OxInv.RemoveMoney(src, amount)
    return exports.kt_inventory:RemoveItem(src, "money", amount)
end

function OxInv.HasCard(src)
    for _, item in pairs(Config.BankCardItem) do
        if exports.kt_inventory:GetItemCount(src, item) > 0 then return true end
    end
    return false
end

-- Retourne la clé interne de la carte (card_basic / card_gold / card_diamond)
function OxInv.GetCardType(src)
    for key, item in pairs(Config.BankCardItem) do
        if exports.kt_inventory:GetItemCount(src, item) > 0 then return key end
    end
    return nil
end

function OxInv.AddCard(src, cardType)
    local item = Config.BankCardItem[cardType]
    if item then exports.kt_inventory:AddItem(src, item, 1) end
end

function OxInv.RemoveCard(src)
    for _, item in pairs(Config.BankCardItem) do
        if exports.kt_inventory:GetItemCount(src, item) > 0 then
            exports.kt_inventory:RemoveItem(src, item, 1)
            return
        end
    end
end

-- Donne un reçu de transaction si activé dans la config
function OxInv.GiveReceipt(src, label)
    if not Config.Inventory.GiveReceipt then return end
    exports.kt_inventory:AddItem(
        src,
        Config.Inventory.ReceiptItem,
        Config.Inventory.ReceiptCount,
        { label = label, date = os.date("%d/%m/%Y %H:%M") }
    )
end

print('^2[KT Banque]^7 Utils chargé')
