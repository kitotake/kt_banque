ClientBankUtils = {}

-----------------------------------
-- 🔧 VARIABLES GLOBALES CLIENT
-----------------------------------
ClientBankUtils.nearATM = false
ClientBankUtils.isUIOpen = false
ClientBankUtils.currentAccount = nil

-----------------------------------
-- 🐛 DEBUG PRINT
-----------------------------------
function ClientBankUtils.debugPrint(message)
    if Config.Debug then
        print(("^6[DEBUG Client]^7 %s"):format(message))
    end
end

-----------------------------------
-- ✅ VÉRIFIER POSSESSION CARTE
-----------------------------------
function ClientBankUtils.hasCard()
    local hasAnyCard = false
    
    for cardType, itemName in pairs(Config.BankCardItem) do
        local count = exports.ox_inventory:Search('count', itemName)
        if count > 0 then
            ClientBankUtils.debugPrint(("Carte trouvée: %s (x%d)"):format(itemName, count))
            hasAnyCard = true
            break
        end
    end
    
    return hasAnyCard
end

-----------------------------------
-- 📋 RÉCUPÉRER TYPE DE CARTE
-----------------------------------
function ClientBankUtils.getCardType()
    for cardType, itemName in pairs(Config.BankCardItem) do
        local count = exports.ox_inventory:Search('count', itemName)
        if count > 0 then
            return cardType, itemName
        end
    end
    return nil, nil
end

-----------------------------------
-- 🎨 AFFICHER NOTIFICATION
-----------------------------------
function ClientBankUtils.notify(type, message)
    lib.notify({
        title = type == 'success' and 'Succès' or type == 'error' and 'Erreur' or 'Information',
        description = message,
        type = type,
        duration = 5000
    })
end

print('^2[KT Banque]^7 Utilitaires client chargés')