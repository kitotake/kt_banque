ESX = exports["es_extended"]:getSharedObject()

ClientBankUtils = {}

-- Variables globales
ClientBankUtils.isUIOpen = false
ClientBankUtils.currentCardMeta = nil
ClientBankUtils.lastAction = 0
ClientBankUtils.nearATM = false

-----------------------------------
-- 🔧 ANTI-SPAM
-----------------------------------
function ClientBankUtils.canPerformAction()
    local currentTime = GetGameTimer()
    if currentTime - ClientBankUtils.lastAction < Config.SpamDelay then
        return false
    end
    ClientBankUtils.lastAction = currentTime
    return true
end

-----------------------------------
-- 📊 DEBUG CLIENT
-----------------------------------
function ClientBankUtils.debugPrint(message)
    if Config.Debug then
        print(("^3[BANK CLIENT DEBUG]^7 %s"):format(message))
    end
end

print('^2[KT Banque]^7 Client utils chargé')