-- client/bank.lua
ESX = exports["es_extended"]:getSharedObject()
local isUIOpen = false
local currentCardMeta = nil -- { id = ..., account_id = ..., owner = ..., last4 = ... }

-- créer blips
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

-- Serveur envoie payload pour ouvrir NUI
RegisterNetEvent("bank:client:openNUI", function(payload)
    -- payload contient balance, label, history, card_meta {id, account_id, owner, last4}
    currentCardMeta = payload.card_meta or nil
    -- n'envoyer aucune info sensible (PIN)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = "openPin", card = payload }) -- le web affichera l'écran PIN puis ouvrira l'UI
    isUIOpen = true
end)

-- serveur envoie update solde
RegisterNetEvent("bank:client:updateBalance", function(balance)
    SendNUIMessage({ action = "updateBalance", balance = balance })
end)

-- NUI close (appelé par web)
RegisterNUICallback("close", function(data, cb)
    SetNuiFocus(false, false)
    isUIOpen = false
    currentCardMeta = nil
    cb("ok")
end)

-- NUI create account (create pin) -> forward to server
RegisterNUICallback("createAccount", function(data, cb)
    local pin = tostring(data.pin)
    TriggerServerEvent("bank:server:createAccount", pin)
    cb("ok")
end)

-- NUI deposit -> send to server with pin & cardId
RegisterNUICallback("deposit", function(data, cb)
    if not currentCardMeta or not currentCardMeta.id then
        cb("no_card")
        return
    end
    TriggerServerEvent("bank:server:deposit", { amount = tonumber(data.amount), cardId = currentCardMeta.id, pin = tostring(data.pin) })
    cb("ok")
end)

-- NUI withdraw
RegisterNUICallback("withdraw", function(data, cb)
    if not currentCardMeta or not currentCardMeta.id then
        cb("no_card")
        return
    end
    TriggerServerEvent("bank:server:withdraw", { amount = tonumber(data.amount), cardId = currentCardMeta.id, pin = tostring(data.pin) })
    cb("ok")
end)

-- NUI transfer
RegisterNUICallback("transfer", function(data, cb)
    if not currentCardMeta or not currentCardMeta.id then
        cb("no_card")
        return
    end
    TriggerServerEvent("bank:server:transfer", { amount = tonumber(data.amount), target = data.target, cardId = currentCardMeta.id, pin = tostring(data.pin) })
    cb("ok")
end)

-- Interaction PNJ / ATM
CreateThread(function()
    while true do
        Wait(500)
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        -- PNJ
        if Config.PNJ and Config.PNJ.Enabled then
            local d = #(coords - vector3(Config.PNJ.Coords.x, Config.PNJ.Coords.y, Config.PNJ.Coords.z))
            if d < 2.0 then
                ESX.ShowHelpNotification("Appuyez sur ~INPUT_CONTEXT~ pour accéder à la ~g~Banque~s~.")
                if IsControlJustReleased(0, 38) then
                    -- demande au serveur d'ouvrir (server vérifiera la carte)
                    TriggerServerEvent("bank:server:requestOpen")
                end
            end
        end

        -- ATM detection (objets) - parcourt la liste
        for _, model in ipairs(Config.ATMModels) do
            local atmHash = GetHashKey(model)
            local obj = GetClosestObjectOfType(coords, 1.5, atmHash, false, false, false)
            if obj ~= 0 then
                local d = #(coords - GetEntityCoords(obj))
                if d < 1.5 then
                    ESX.ShowHelpNotification("Appuyez sur ~INPUT_CONTEXT~ pour accéder à l'ATM.")
                    if IsControlJustReleased(0, 38) then
                        TriggerServerEvent("bank:server:requestOpen")
                    end
                end
            end
        end
    end
end)
