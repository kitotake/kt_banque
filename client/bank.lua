ESX = exports["es_extended"]:getSharedObject()

local isUIOpen = false
local currentCardMeta = nil
local lastAction = 0
local nearATM = false

-----------------------------------
-- 🔧 ANTI-SPAM
-----------------------------------
local function canPerformAction()
    local currentTime = GetGameTimer()
    if currentTime - lastAction < Config.SpamDelay then
        return false
    end
    lastAction = currentTime
    return true
end

-----------------------------------
-- 🗺️ CREATION DES BLIPS
-----------------------------------
CreateThread(function()
    for _, blip in pairs(Config.Blips) do
        local b = AddBlipForCoord(blip.pos.x, blip.pos.y, blip.pos.z)
        SetBlipSprite(b, blip.sprite)
        SetBlipScale(b, blip.scale or 0.8)
        SetBlipColour(b, blip.color or 2)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(blip.label)
        EndTextCommandSetBlipName(b)
    end
end)

-----------------------------------
-- 🧍 SPAWN DES PNJ BANQUIERS
-----------------------------------
CreateThread(function()
    local pnjs = { Config.PNJ, Config.PNJ2 }

    for i, pnjConfig in ipairs(pnjs) do
        if not pnjConfig or not pnjConfig.Enabled then
            print(("❌ PNJ %d désactivé ou Config manquante"):format(i))
        else
            local model = pnjConfig.Model
            local hash = GetHashKey(model)
            print(("🔍 Chargement modèle PNJ %d : %s"):format(i, model))

            RequestModel(hash)
            local count = 0
            while not HasModelLoaded(hash) do
                Wait(100)
                count = count + 1
                if count > 50 then
                    print(("⚠️ Le modèle PNJ %d ne charge pas : %s"):format(i, model))
                    break
                end
            end

            local coords = pnjConfig.Coords
            local heading = pnjConfig.Heading or 0.0

            local ped = CreatePed(4, hash, coords.x, coords.y, coords.z - 1.0, heading, false, true)
            if DoesEntityExist(ped) then
                print(("✅ PNJ %d spawné avec succès !"):format(i))
                SetEntityHeading(ped, heading)
                FreezeEntityPosition(ped, pnjConfig.Frozen or true)
                SetEntityInvincible(ped, pnjConfig.Invincible or true)
                SetBlockingOfNonTemporaryEvents(ped, true)

                if pnjConfig.Scenario and pnjConfig.Scenario ~= "" then
                    TaskStartScenarioInPlace(ped, pnjConfig.Scenario, 0, true)
                end
            else
                print(("❌ Impossible de spawn le PNJ %d !"):format(i))
            end
        end
    end
end)

-----------------------------------
-- 💳 INTERFACE BANCAIRE (NUI)
-----------------------------------
RegisterCommand("openNUI", function()
    TriggerServerEvent('bank:server:requestOpen')
end)

RegisterNetEvent("bank:client:openNUI", function(payload)
    if not payload then return end
    currentCardMeta = payload.card_meta or nil
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openBank",
        data = payload
    })
    isUIOpen = true
end)

RegisterNetEvent("bank:client:updateBalance", function(balance)
    if isUIOpen then
        SendNUIMessage({
            action = "updateBalance",
            balance = balance
        })
    end
end)

-----------------------------------
-- 🆕 EVENT: OUVRIR CRÉATION DE COMPTE
-----------------------------------
RegisterNetEvent('bank:client:openAccountCreation', function()
    print("^2[CLIENT]^7 Ouverture interface création de compte")
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openCreate"
    })
    isUIOpen = true
end)

-----------------------------------
-- 💳 EVENT: AFFICHER MENU ACHAT CARTE
-----------------------------------
RegisterNetEvent('bank:client:showCardPurchaseMenu', function(accountId)
    print("^2[CLIENT]^7 Ouverture menu achat carte pour compte ID:", accountId)
    
    -- Créer le menu avec ox_lib
    local options = {}
    
    for cardType, limits in pairs(Config.CardLimits) do
        local cardNames = {
            carte_basique = "💳 Carte Basique",
            carte_or = "🏅 Carte Or",
            carte_dimas = "💎 Carte Diamant"
        }
        
        table.insert(options, {
            title = cardNames[cardType] or cardType,
            description = string.format("Dépôt max: $%s | Retrait max: $%s\nPrix: $%s", 
                limits.MaxDeposit, 
                limits.MaxWithdraw, 
                limits.Price
            ),
            icon = cardType == 'carte_basique' and 'credit-card' or (cardType == 'carte_or' and 'star' or 'gem'),
            onSelect = function()
                TriggerServerEvent('bank:server:purchaseCard', {
                    account_id = accountId,
                    card_type = cardType
                })
            end
        })
    end
    
    lib.registerContext({
        id = 'card_purchase_menu',
        title = '🏦 Achat de Carte Bancaire',
        options = options
    })
    
    lib.showContext('card_purchase_menu')
end)

-----------------------------------
-- 🔁 CALLBACKS NUI
-----------------------------------
RegisterNUICallback("close", function(_, cb)
    SetNuiFocus(false, false)
    isUIOpen = false
    currentCardMeta = nil
    cb("ok")
end)

RegisterNUICallback("createAccount", function(data, cb)
    if not canPerformAction() then return cb("spam") end
    if not data.pin or #tostring(data.pin) ~= 4 then
        lib.notify({ title = "Erreur", description = Config.Notifications.invalid_pin, type = "error" })
        return cb("invalid")
    end
    print("^3[NUI Callback]^7 Création compte avec PIN:", data.pin)
    TriggerServerEvent("bank:server:createAccountOnly", data)
    cb("ok")
end)

RegisterNUICallback("deposit", function(data, cb)
    if not canPerformAction() then return cb("spam") end
    if not currentCardMeta then
        lib.notify({ title = "Erreur", description = Config.Notifications.no_card, type = "error" })
        return cb("no_card")
    end
    local amount = tonumber(data.amount)
    if not amount or amount <= 0 then
        lib.notify({ title = "Erreur", description = "Montant invalide", type = "error" })
        return cb("invalid")
    end
    TriggerServerEvent("bank:server:deposit", {
        amount = amount,
        cardId = currentCardMeta.id,
        pin = tostring(data.pin)
    })
    cb("ok")
end)

RegisterNUICallback("withdraw", function(data, cb)
    if not canPerformAction() then return cb("spam") end
    if not currentCardMeta then
        lib.notify({ title = "Erreur", description = Config.Notifications.no_card, type = "error" })
        return cb("no_card")
    end
    local amount = tonumber(data.amount)
    if not amount or amount <= 0 then
        lib.notify({ title = "Erreur", description = "Montant invalide", type = "error" })
        return cb("invalid")
    end
    TriggerServerEvent("bank:server:withdraw", {
        amount = amount,
        cardId = currentCardMeta.id,
        pin = tostring(data.pin)
    })
    cb("ok")
end)

RegisterNUICallback("transfer", function(data, cb)
    if not canPerformAction() then return cb("spam") end
    if not currentCardMeta then
        lib.notify({ title = "Erreur", description = Config.Notifications.no_card, type = "error" })
        return cb("no_card")
    end
    local amount = tonumber(data.amount)
    if not amount or amount <= 0 or not data.target then
        lib.notify({ title = "Erreur", description = "Données invalides", type = "error" })
        return cb("invalid")
    end
    TriggerServerEvent("bank:server:transfer", {
        amount = amount,
        target = data.target,
        cardId = currentCardMeta.id,
        pin = tostring(data.pin)
    })
    cb("ok")
end)

-----------------------------------
-- 🏦 INTERACTIONS PNJ
-----------------------------------
-- PNJ1 - Achat de carte
local function openCardPurchaseMenu()
    print("^5[PNJ1]^7 Interaction détectée - Achat de carte")
    TriggerServerEvent('bank:server:checkPendingAccount')
end

-- PNJ2 - Ouverture de compte
local function openAccountCreationMenu()
    print("^5[PNJ2]^7 Interaction détectée - Création de compte")
    TriggerServerEvent('bank:server:checkExistingAccount')
end

-- Interaction PNJ1
CreateThread(function()
    while true do
        local sleep = 500
        if Config.PNJ and Config.PNJ.Enabled then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local distance = #(coords - Config.PNJ.Coords)
            if distance < Config.InteractionDistance then
                sleep = 0
                ESX.ShowHelpNotification("Appuyez sur ~INPUT_CONTEXT~ pour acheter une carte bancaire")
                if IsControlJustReleased(0, 38) then
                    openCardPurchaseMenu()
                end
            end
        end
        Wait(sleep)
    end
end)

-- Interaction PNJ2
CreateThread(function()
    while true do
        local sleep = 500
        if Config.PNJ2 and Config.PNJ2.Enabled then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local distance = #(coords - Config.PNJ2.Coords)
            if distance < Config.InteractionDistance then
                sleep = 0
                ESX.ShowHelpNotification("Appuyez sur ~INPUT_CONTEXT~ pour ouvrir un compte bancaire")
                if IsControlJustReleased(0, 38) then
                    openAccountCreationMenu()
                end
            end
        end
        Wait(sleep)
    end
end)

-----------------------------------
-- 🏧 DETECTION DES ATM
-----------------------------------
CreateThread(function()
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        nearATM = false
        
        for _, model in pairs(Config.ATMModels) do
            local atm = GetClosestObjectOfType(coords.x, coords.y, coords.z, Config.ATMDistance, model, false, false, false)
            if DoesEntityExist(atm) then
                local atmCoords = GetEntityCoords(atm)
                local distance = #(coords - atmCoords)
                if distance < Config.ATMDistance then
                    sleep = 0
                    nearATM = true
                    ESX.ShowHelpNotification("Appuyez sur ~INPUT_CONTEXT~ pour utiliser l'ATM")
                    if IsControlJustReleased(0, 38) then
                        TriggerServerEvent('bank:server:requestOpen')
                    end
                    break
                end
            end
        end
        Wait(sleep)
    end
end)

-----------------------------------
-- ⌨️ FERMETURE DE L'UI
-----------------------------------
CreateThread(function()
    while true do
        Wait(0)
        if isUIOpen and IsControlJustReleased(0, 322) then -- ESC
            SendNUIMessage({ action = "close" })
            SetNuiFocus(false, false)
            isUIOpen = false
            currentCardMeta = nil
        end
    end
end)

