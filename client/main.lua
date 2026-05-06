-- ==================== KT BANQUE CLIENT (UNION CLEAN) ====================

local isUIOpen = false
local nearATM = false
local currentAccount = nil
local isInAnimation = false
local animThreadId = 0

-- ==================== UTILS ====================
local function Notify(type, msg)
    lib.notify({
        title = type == 'success' and 'Succès' or type == 'error' and 'Erreur' or 'Info',
        description = msg,
        type = type
    })
end

local function HasCard()
    for _, item in pairs(Config.BankCardItem) do
        if exports.ox_inventory:GetItemCount(item) > 0 then
            return true
        end
    end
    return false
end

-- ==================== ANIMATION ====================
local function StopAnimation()
    if not isInAnimation then return end
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    isInAnimation = false
    animThreadId += 1
end

local function PlayATMAnimation()
    if not Config.Animations.enabled or isInAnimation then return end

    local ped = PlayerPedId()
    RequestAnimDict(Config.Animations.dict)
    while not HasAnimDictLoaded(Config.Animations.dict) do Wait(10) end

    isInAnimation = true
    TaskPlayAnim(ped, Config.Animations.dict, Config.Animations.anim, 8.0, -8.0, -1, Config.Animations.flag, 0, false, false, false)

    local id = animThreadId + 1
    animThreadId = id

    CreateThread(function()
        while animThreadId == id do
            Wait(500)
            if not nearATM or not isUIOpen then
                StopAnimation()
                break
            end
        end
    end)
end

RegisterCommand("checkaccounts", function()
    TriggerServerEvent("ktbank:checkAccounts")
end)
RegisterCommand("openbank", function()
    TriggerServerEvent("ktbank:openbank")
end)

-- ==================== UI ====================
local UI = {}

function UI.Open(data)
    if isUIOpen then return end
    isUIOpen = true
    currentAccount = data

    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openBank', data = data })

    if nearATM then
        Wait(100)
        PlayATMAnimation()
    end
end

function UI.Close()
    if not isUIOpen then return end
    isUIOpen = false
    currentAccount = nil

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    StopAnimation()
end

function UI.UpdateBalance(balance)
    SendNUIMessage({ action = 'updateBalance', data = balance })
    if currentAccount then currentAccount.balance = balance end
end

-- ==================== NUI ====================
RegisterNUICallback('close', function(_, cb)
    UI.Close()
    cb('ok')
end)

RegisterNUICallback('deposit', function(data, cb)
    TriggerServerEvent('bank:server:deposit', tonumber(data.amount))
    cb('ok')
end)

RegisterNUICallback('withdraw', function(data, cb)
    TriggerServerEvent('bank:server:withdraw', tonumber(data.amount))
    cb('ok')
end)

RegisterNUICallback('transfer', function(data, cb)
    TriggerServerEvent('bank:server:transfer', tonumber(data.amount), data.target)
    cb('ok')
end)

RegisterNUICallback('createAccount', function(data, cb)
    TriggerServerEvent('bank:server:createAccount', tostring(data.pin))
    cb('ok')
end)

-- ==================== EVENTS ====================
RegisterNetEvent('bank:client:receiveAccountData', function(data)
    UI.Open(data)
end)

RegisterNetEvent('bank:client:updateBalance', function(balance)
    UI.UpdateBalance(balance)
end)

RegisterNetEvent('bank:client:notify', function(type, msg)
    Notify(type, msg)
end)

RegisterNetEvent('bank:client:forceClose', function()
    UI.Close()
end)

-- ==================== ATM DETECTION ====================
CreateThread(function()
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)

        nearATM = false

        for _, model in pairs(Config.ATMModels) do
            local atm = GetClosestObjectOfType(coords, 3.0, model, false)
            if atm ~= 0 then
                local dist = #(coords - GetEntityCoords(atm))
                if dist < Config.ATMDistance then
                    nearATM = true
                    sleep = 0

                    lib.showTextUI('[E] Accéder à la banque')

                    if IsControlJustReleased(0, 38) then
                        TriggerServerEvent('bank:server:requestOpen')
                    end
                    break
                end
            end
        end

        if not nearATM then
            lib.hideTextUI()
        end

        Wait(sleep)
    end
end)

-- ==================== PNJ ====================
CreateThread(function()
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)

        if Config.PNJ and #(coords - Config.PNJ.Coords) < 2.0 then
            sleep = 0
            lib.showTextUI('[E] Améliorer carte')
            if IsControlJustReleased(0, 38) then
                TriggerServerEvent('bank:server:upgradeCard', 'carte_or')
            end
        elseif Config.PNJ2 and #(coords - Config.PNJ2.Coords) < 2.0 then
            sleep = 0
            lib.showTextUI('[E] Créer compte')
            if IsControlJustReleased(0, 38) then
                TriggerServerEvent('bank:server:createAccount', '1234')
            end
        else
            lib.hideTextUI()
        end

        Wait(sleep)
    end
end)

-- ==================== ESC CLOSE ====================
CreateThread(function()
    while true do
        if isUIOpen then
            Wait(0)
            if IsControlJustPressed(0, 322) then
                UI.Close()
            end
        else
            Wait(500)
        end
    end
end)

-- ==================== CLEAN ====================
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    UI.Close()
    StopAnimation()
end)

print('^2[KT Banque]^7 Client chargé (UNION)')