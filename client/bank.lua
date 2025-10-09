ESX = exports["es_extended"]:getSharedObject()
local isUIOpen = false
local currentCardMeta = nil

-- Créer blips
CreateThread(function()
    for _, blip in pairs(Config.Blips) do
        local b = AddBlipForCoord(blip.pos)
        SetBlipSprite(b, blip.sprite)
        SetBlipScale(b, blip.scale or 0.8)
        SetBlipColour(b, blip.color or 2)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(blip.label)
        EndTextCommandSetBlipName(b)
    end
end)

-- Serveur ouvre NUI
RegisterNetEvent("bank:client:openNUI", function(payload)
    currentCardMeta = payload.card_meta or nil
    SetNuiFocus(true, true)
    SendNUIMessage({ action = "openPin", card = payload })
    isUIOpen = true
end)

RegisterNetEvent("bank:client:updateBalance", function(balance)
    SendNUIMessage({ action = "updateBalance", balance = balance })
end)

RegisterNUICallback("close", function(_, cb)
    SetNuiFocus(false, false)
    isUIOpen = false
    currentCardMeta = nil
    cb("ok")
end)

RegisterNUICallback("createAccount", function(data, cb)
    TriggerServerEvent("bank:server:createAccount", data)
    cb("ok")
end)

RegisterNUICallback("deposit", function(data, cb)
    if not currentCardMeta or not currentCardMeta.id then
        cb("no_card")
        return
    end
    TriggerServerEvent("bank:server:deposit", {
        amount = tonumber(data.amount),
        cardId = currentCardMeta.id,
        pin = tostring(data.pin)
    })
    cb("ok")
end)

RegisterNUICallback("withdraw", function(data, cb)
    if not currentCardMeta or not currentCardMeta.id then
        cb("no_card")
        return
    end
    TriggerServerEvent("bank:server:withdraw", {
        amount = tonumber(data.amount),
        cardId = currentCardMeta.id,
        pin = tostring(data.pin)
    })
    cb("ok")
end)

RegisterNUICallback("transfer", function(data, cb)
    if not currentCardMeta or not currentCardMeta.id then
        cb("no_card")
        return
    end
    TriggerServerEvent("bank:server:transfer", {
        amount = tonumber(data.amount),
        target = data.target,
        cardId = currentCardMeta.id,
        pin = tostring(data.pin)
    })
    cb("ok")
end)

------------------------------------------
-- 👇 Interaction PNJ + Menu ox_lib
------------------------------------------
local function openCardMenu()
    -- Récupération de la valeur de l’argent (depuis ox_inventory)
    local moneyItems = exports.ox_inventory:Search('count', 'money')
    local playerMoney = moneyItems or 0

    local options = {
        {
            title = "💳 Carte Basique",
            description = "Gratuite. Limites faibles.\n• Dépôt max: $2000\n• Retrait max: $1000",
            icon = "credit-card",
            onSelect = function()
                if playerMoney >= 0 then
                    TriggerServerEvent('bank:server:createAccount', { pin = "0000", card_type = "carte_basique" })
                else
                    lib.notify({ title = "Erreur", description = "Argent insuffisant.", type = "error" })
                end
            end
        },
        {
            title = "🏅 Carte Or",
            description = "Frais: $2,500\nLimites élevées.\n• Dépôt max: $3500\n• Retrait max: $2000",
            icon = "gem",
            onSelect = function()
                local price = 2500
                if playerMoney >= price then
                    TriggerServerEvent('bank:server:createAccount', { pin = "0000", card_type = "carte_or" })
                    exports.ox_inventory:RemoveItem('money', price)
                else
                    lib.notify({ title = "Erreur", description = "Vous n'avez pas assez d'argent liquide ($2500).", type = "error" })
                end
            end
        },
        {
            title = "💎 Carte Dimas",
            description = "Frais: $5,000\nPrestige ultime.\n• Dépôt max: $4500\n• Retrait max: $2000",
            icon = "crown",
            onSelect = function()
                local price = 5000
                if playerMoney >= price then
                    TriggerServerEvent('bank:server:createAccount', { pin = "0000", card_type = "carte_dimas" })
                    exports.ox_inventory:RemoveItem('money', price)
                else
                    lib.notify({ title = "Erreur", description = "Vous n'avez pas assez d'argent liquide ($5000).", type = "error" })
                end
            end
        },
    }

    lib.registerContext({
        id = 'bank_card_selection',
        title = 'Choisissez votre Carte Bancaire',
        options = options
    })
    lib.showContext('bank_card_selection')
end

------------------------------------------
-- 👇 Détection du PNJ
------------------------------------------
CreateThread(function()
    while true do
        Wait(500)
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        if Config.PNJ and Config.PNJ.Enabled then
            local d = #(coords - vector3(Config.PNJ.Coords.x, Config.PNJ.Coords.y, Config.PNJ.Coords.z))
            if d < 2.0 then
                ESX.ShowHelpNotification("Appuyez sur ~INPUT_CONTEXT~ pour parler au banquier.")
                if IsControlJustReleased(0, 38) then
                    openCardMenu()
                end
            end
        end
    end
end)
