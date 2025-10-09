ESX = exports["es_extended"]:getSharedObject()

local isUIOpen = false
local currentCardMeta = nil
local lastAction = 0
local bankerPed = nil
local nearATM = false

-- Anti-spam helper
local function canPerformAction()
    local currentTime = GetGameTimer()
    if currentTime - lastAction < Config.SpamDelay then
        return false
    end
    lastAction = currentTime
    return true
end

-- Création des blips bancaires
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

-- Spawn des PNJ Banquiers
CreateThread(function()
    -- Table des PNJ à spawn
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

            local ped = CreatePed(4, hash, coords.x, coords.y, coords.z + 1.0, heading, false, true) 
            if DoesEntityExist(ped) then
                print(("✅ PNJ %d spawné avec succès !"):format(i))

                SetEntityHeading(ped, heading)
                FreezeEntityPosition(ped, pnjConfig.Frozen or true)
                SetEntityInvincible(ped, pnjConfig.Invincible or true)
                SetBlockingOfNonTemporaryEvents(ped, true)
                
                if pnjConfig.Scenario then
                    TaskStartScenarioInPlace(ped, pnjConfig.Scenario, 0, true)
                end
            else
                print(("❌ Impossible de spawn le PNJ %d !"):format(i))
            end
        end
    end
end)


-- Ouvrir l'interface bancaire
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

-- Mise à jour du solde
RegisterNetEvent("bank:client:updateBalance", function(balance)
    if not isUIOpen then return end
    SendNUIMessage({ 
        action = "updateBalance", 
        balance = balance 
    })
end)

-- Callbacks NUI
RegisterNUICallback("close", function(_, cb)
    SetNuiFocus(false, false)
    isUIOpen = false
    currentCardMeta = nil
    cb("ok")
end)

RegisterNUICallback("createAccount", function(data, cb)
    if not canPerformAction() then
        cb("spam")
        return
    end
    
    if not data.pin or #tostring(data.pin) ~= 4 then
        lib.notify({
            title = "Erreur",
            description = Config.Notifications.invalid_pin,
            type = "error"
        })
        cb("invalid")
        return
    end
    
    TriggerServerEvent("bank:server:createAccount", data)
    cb("ok")
end)

RegisterNUICallback("deposit", function(data, cb)
    if not canPerformAction() then
        cb("spam")
        return
    end
    
    if not currentCardMeta or not currentCardMeta.id then
        lib.notify({
            title = "Erreur",
            description = Config.Notifications.no_card,
            type = "error"
        })
        cb("no_card")
        return
    end
    
    local amount = tonumber(data.amount)
    if not amount or amount <= 0 then
        lib.notify({
            title = "Erreur",
            description = "Montant invalide",
            type = "error"
        })
        cb("invalid")
        return
    end
    
    TriggerServerEvent("bank:server:deposit", {
        amount = amount,
        cardId = currentCardMeta.id,
        pin = tostring(data.pin)
    })
    cb("ok")
end)

RegisterNUICallback("withdraw", function(data, cb)
    if not canPerformAction() then
        cb("spam")
        return
    end
    
    if not currentCardMeta or not currentCardMeta.id then
        lib.notify({
            title = "Erreur",
            description = Config.Notifications.no_card,
            type = "error"
        })
        cb("no_card")
        return
    end
    
    local amount = tonumber(data.amount)
    if not amount or amount <= 0 then
        lib.notify({
            title = "Erreur",
            description = "Montant invalide",
            type = "error"
        })
        cb("invalid")
        return
    end
    
    TriggerServerEvent("bank:server:withdraw", {
        amount = amount,
        cardId = currentCardMeta.id,
        pin = tostring(data.pin)
    })
    cb("ok")
end)

RegisterNUICallback("transfer", function(data, cb)
    if not canPerformAction() then
        cb("spam")
        return
    end
    
    if not currentCardMeta or not currentCardMeta.id then
        lib.notify({
            title = "Erreur",
            description = Config.Notifications.no_card,
            type = "error"
        })
        cb("no_card")
        return
    end
    
    local amount = tonumber(data.amount)
    if not amount or amount <= 0 or not data.target then
        lib.notify({
            title = "Erreur",
            description = "Données invalides",
            type = "error"
        })
        cb("invalid")
        return
    end
    
    TriggerServerEvent("bank:server:transfer", {
        amount = amount,
        target = data.target,
        cardId = currentCardMeta.id,
        pin = tostring(data.pin)
    })
    cb("ok")
end)

-- Menu de sélection de carte
local function openCardMenu()
    local moneyItems = exports.ox_inventory:Search('count', 'money')
    local playerMoney = moneyItems or 0
    
    local options = {}
    
    for cardType, limits in pairs(Config.CardLimits) do
        local price = limits.Price or 0
        local icon = "credit-card"
        local title = cardType:gsub("_", " "):gsub("^%l", string.upper)
        
        if cardType == "carte_or" then
            icon = "gem"
        elseif cardType == "carte_dimas" then
            icon = "crown"
        end
        
        table.insert(options, {
            title = title,
            description = string.format(
                "Prix: $%s\nDépôt max: $%s\nRetrait max: $%s",
                price,
                limits.MaxDeposit,
                limits.MaxWithdraw
            ),
            icon = icon,
            onSelect = function()
                if playerMoney >= price then
                    TriggerServerEvent('bank:server:createAccount', {
                        pin = "0000",
                        card_type = cardType
                    })
                else
                    lib.notify({
                        title = "Erreur",
                        description = string.format("Vous avez besoin de $%s", price),
                        type = "error"
                    })
                end
            end
        })
    end
    
    lib.registerContext({
        id = 'bank_card_selection',
        title = 'Choisissez votre Carte Bancaire',
        options = options
    })
    lib.showContext('bank_card_selection')
end

-- Interaction avec le banquier
CreateThread(function()
    while true do
        local sleep = 500
        
        if Config.PNJ and Config.PNJ.Enabled then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local distance = #(coords - Config.PNJ.Coords)
            
            if distance < Config.InteractionDistance then
                sleep = 0
                ESX.ShowHelpNotification("Appuyez sur ~INPUT_CONTEXT~ pour parler au banquier")
                
                if IsControlJustReleased(0, 38) then -- E
                    openCardMenu()
                end
            end
        end
        
        Wait(sleep)
    end
end)

-- Détection des ATM
CreateThread(function()
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        
        for _, model in pairs(Config.ATMModels) do
            local atm = GetClosestObjectOfType(coords.x, coords.y, coords.z, Config.ATMDistance, model, false, false, false)
            
            if DoesEntityExist(atm) then
                local atmCoords = GetEntityCoords(atm)
                local distance = #(coords - atmCoords)
                
                if distance < Config.ATMDistance then
                    sleep = 0
                    nearATM = true
                    ESX.ShowHelpNotification("Appuyez sur ~INPUT_CONTEXT~ pour utiliser l'ATM")
                    
                    if IsControlJustReleased(0, 38) then -- E
                        TriggerServerEvent('bank:server:requestOpen')
                    end
                    break
                else
                    nearATM = false
                end
            end
        end
        
        Wait(sleep)
    end
end)

-- Fermeture UI avec ESC
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