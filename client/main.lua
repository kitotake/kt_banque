-- ==================== KT BANQUE v7.4.1 - CLIENT ====================
-- Aligné avec config.lua : card_basic / card_gold / card_diamond

local isUIOpen      = false
local nearATM       = false
local currentAccount = nil
local isInAnimation  = false
local animThreadId   = 0

-- ==================== UTILS ====================
local function Notify(type, msg)
    lib.notify({
        title       = type == 'success' and 'Succès' or type == 'error' and 'Erreur' or 'Info',
        description = msg,
        type        = type
    })
end

local function HasCard()
    for _, item in pairs(Config.BankCardItem) do
        if exports.kt_inventory:GetItemCount(item) > 0 then return true end
    end
    return false
end

-- -- Hash PIN — miroir de server/main.lua → Utils.HashPin et web/src/utils/index.ts → hashPin
-- local function HashPin(pin)
--     local hash = 0
--     local salt = "kt_banque_v7"
--     local combined = salt .. tostring(pin)
--     for i = 1, #combined do
--         hash = (hash * 31 + combined:byte(i)) % (2^32)
--     end
--     return string.format("%08x", hash)
-- end

-- ==================== ANIMATION ====================
local function StopAnimation()
    if not isInAnimation then return end
    ClearPedTasks(PlayerPedId())
    isInAnimation = false
    animThreadId  = animThreadId + 1
end

local function PlayATMAnimation()
    if not Config.Animations.enabled or isInAnimation then return end
    local ped = PlayerPedId()
    RequestAnimDict(Config.Animations.dict)
    while not HasAnimDictLoaded(Config.Animations.dict) do Wait(10) end
    isInAnimation = true
    TaskPlayAnim(ped, Config.Animations.dict, Config.Animations.anim,
        8.0, -8.0, -1, Config.Animations.flag, 0, false, false, false)
    local id = animThreadId + 1
    animThreadId = id
    CreateThread(function()
        while animThreadId == id do
            Wait(500)
            if not nearATM or not isUIOpen then StopAnimation(); break end
        end
    end)
end

-- ==================== UI ====================
local UI = {}

function UI.Open(data)
    if isUIOpen then return end
    isUIOpen       = true
    currentAccount = data
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openBank', data = data })
    if nearATM then Wait(100); PlayATMAnimation() end
end

function UI.OpenCreate()
    if isUIOpen then return end
    isUIOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openCreate' })
end

function UI.Close()
    if not isUIOpen then return end
    isUIOpen       = false
    currentAccount = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    StopAnimation()
end

function UI.UpdateBalance(balance)
    SendNUIMessage({ action = 'updateBalance', data = balance })
    if currentAccount then currentAccount.balance = balance end
end

-- ==================== NUI CALLBACKS ====================

RegisterNUICallback('close', function(_, cb)
    UI.Close(); cb('ok')
end)

-- FIX: pinHash envoyé, jamais le PIN brut
RegisterNUICallback('deposit', function(data, cb)
    local amount  = tonumber(data.amount)
    local pinHash = tostring(data.pinHash or "")
    if not amount or amount <= 0 then cb('err'); return end
    TriggerServerEvent('bank:server:deposit', amount, pinHash)
    cb('ok')
end)

RegisterNUICallback('withdraw', function(data, cb)
    local amount  = tonumber(data.amount)
    local pinHash = tostring(data.pinHash or "")
    if not amount or amount <= 0 then cb('err'); return end
    TriggerServerEvent('bank:server:withdraw', amount, pinHash)
    cb('ok')
end)

RegisterNUICallback('transfer', function(data, cb)
    local amount  = tonumber(data.amount)
    local target  = tostring(data.target or "")
    local pinHash = tostring(data.pinHash or "")
    if not amount or amount <= 0 or target == "" then cb('err'); return end
    TriggerServerEvent('bank:server:transfer', amount, target, pinHash)
    cb('ok')
end)

RegisterNUICallback('createAccount', function(data, cb)
    local pin = tostring(data.pin or "")
    if #pin ~= 4 or not pin:match("^%d+$") then cb('err'); return end
    TriggerServerEvent('bank:server:createAccount', pin)
    cb('ok')
end)

-- -- Le frontend peut demander le hash d'un PIN via ce callback
-- RegisterNUICallback('hashPin', function(data, cb)
--     local pin = tostring(data.pin or "")
--     if #pin ~= 4 then cb({ hash = "" }); return end
--     cb({ hash = HashPin(pin) })
-- end)

-- ==================== ÉVÉNEMENTS SERVEUR ====================

RegisterNetEvent('bank:client:openBank', function(data)
    UI.Open(data)
end)

RegisterNetEvent('bank:client:openCreate', function()
    UI.OpenCreate()
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

-- ==================== DÉTECTION ATM ====================
CreateThread(function()
    while true do
        local sleep = 500
        local ped   = PlayerPedId()
        local coords = GetEntityCoords(ped)
        nearATM = false

        for _, model in pairs(Config.ATMModels) do
            local atm = GetClosestObjectOfType(coords, Config.ATMDistance + 1.0, model, false)
            if atm ~= 0 and #(coords - GetEntityCoords(atm)) < Config.ATMDistance then
                nearATM = true
                sleep   = 0
                lib.showTextUI(Config.Lang.press_to_use_atm or '[E] Utiliser l\'ATM')
                if IsControlJustReleased(0, 38) then
                    TriggerServerEvent('bank:server:requestOpen')
                end
                break
            end
        end

        if not nearATM then lib.hideTextUI() end
        Wait(sleep)
    end
end)

-- ==================== PNJ ====================
CreateThread(function()
    while true do
        local sleep  = 500
        local ped    = PlayerPedId()
        local coords = GetEntityCoords(ped)

        -- PNJ amélioration carte
        if Config.PNJ and Config.PNJ.Enabled
            and #(coords - Config.PNJ.Coords) < Config.InteractionDistance then
            sleep = 0
            lib.showTextUI(Config.PNJ.Label or '[E] Améliorer carte')
            if IsControlJustReleased(0, 38) then
                -- FIX: clé card_gold (pas carte_or)
                TriggerServerEvent('bank:server:upgradeCard', 'card_gold')
            end

        -- PNJ ouverture de compte — FIX: ouvre le menu, pas de PIN hardcodé
        elseif Config.PNJ2 and Config.PNJ2.Enabled
            and #(coords - Config.PNJ2.Coords) < Config.InteractionDistance then
            sleep = 0
            lib.showTextUI(Config.PNJ2.Label or '[E] Ouvrir un compte')
            if IsControlJustReleased(0, 38) then
                TriggerServerEvent('bank:server:requestOpen')
            end

        else
            lib.hideTextUI()
        end

        Wait(sleep)
    end
end)

-- ==================== FERMETURE ESC ====================
CreateThread(function()
    while true do
        if isUIOpen then
            Wait(0)
            if IsControlJustPressed(0, 322) then UI.Close() end
        else
            Wait(500)
        end
    end
end)

-- ==================== DEBUG ====================
if Config.Debug then
    RegisterCommand("ktbank_open", function()
        TriggerServerEvent("bank:server:requestOpen")
    end, true)  -- true = ACE permission requis
end

-- ==================== NETTOYAGE ====================
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    UI.Close(); StopAnimation()
end)

print('^2[KT Banque]^7 Client chargé v7.4.1')
