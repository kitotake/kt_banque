-- ==================== VARIABLES GLOBALES ====================
local isUIOpen = false
local nearATM = false
local currentAccount = nil
local isInAnimation = false
local animationThread = nil

-- ==================== UTILITAIRES ====================
local function DebugPrint(message)
    if Config.Debug then
        print(("^6[DEBUG Client]^7 %s"):format(message))
    end
end

local function HasCard()
    for cardType, itemName in pairs(Config.BankCardItem) do
        local count = exports.ox_inventory:Search('count', itemName)
        if count > 0 then
            return true, cardType, itemName
        end
    end
    return false
end

local function Notify(type, message)
    lib.notify({
        title = type == 'success' and 'Succès' or type == 'error' and 'Erreur' or 'Information',
        description = message,
        type = type,
        duration = 5000
    })
end

-- ==================== ANIMATIONS CORRIGÉES ====================
local function StopAnimation()
    if not isInAnimation then return end
    
    local ped = PlayerPedId()
    
    -- Arrêt propre de l'animation
    if IsEntityPlayingAnim(ped, Config.Animations.dict, Config.Animations.anim, 3) then
        StopAnimTask(ped, Config.Animations.dict, Config.Animations.anim, 1.0)
    end
    
    ClearPedTasks(ped)
    isInAnimation = false
    
    -- Arrêter le thread de surveillance
    if animationThread then
        animationThread = nil
    end
    
    DebugPrint("🟢 Animation arrêtée proprement")
end

local function PlayATMAnimation()
    if not Config.Animations.enabled or isInAnimation then return end
    
    local ped = PlayerPedId()
    local dict = Config.Animations.dict
    local anim = Config.Animations.anim
    local flag = Config.Animations.flag

    -- Charger l'animation avec timeout
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
        Wait(10)
    end

    if not HasAnimDictLoaded(dict) then
        DebugPrint("❌ Animation non chargée, annulation.")
        return
    end

    isInAnimation = true
    DebugPrint("✅ Animation ATM lancée")

    -- Lancer l'animation
    TaskPlayAnim(ped, dict, anim, 8.0, -8.0, -1, flag, 0, false, false, false)

    -- Thread de surveillance amélioré
    if animationThread then
        animationThread = nil
    end
    
    animationThread = CreateThread(function()
        local startTime = GetGameTimer()
        local maxDuration = 30000 -- 30 secondes max
        
        while isInAnimation and animationThread do
            Wait(500)
            
            local currentPed = PlayerPedId()
            
            -- Vérifications multiples pour arrêt automatique
            local shouldStop = false
            
            -- 1. Le ped a changé
            if currentPed ~= ped then
                shouldStop = true
                DebugPrint("⚠️ Le ped a changé")
            end
            
            -- 2. L'animation ne joue plus
            if not IsEntityPlayingAnim(currentPed, dict, anim, 3) then
                shouldStop = true
                DebugPrint("⚠️ Animation interrompue (non en lecture)")
            end
            
            -- 3. Plus près d'un ATM
            if not nearATM then
                shouldStop = true
                DebugPrint("⚠️ Plus près d'un ATM")
            end
            
            -- 4. Durée maximale atteinte
            if (GetGameTimer() - startTime) > maxDuration then
                shouldStop = true
                DebugPrint("⏹️ Durée maximale atteinte")
            end
            
            -- 5. L'UI est fermée
            if not isUIOpen then
                shouldStop = true
                DebugPrint("⚠️ UI fermée")
            end
            
            -- 6. Le joueur est dans un véhicule
            if IsPedInAnyVehicle(currentPed, false) then
                shouldStop = true
                DebugPrint("⚠️ Joueur en véhicule")
            end
            
            if shouldStop then
                StopAnimation()
                break
            end
        end
        
        animationThread = nil
    end)
end

-- ==================== INTERFACE NUI ====================
local UI = {}

function UI.Open(data)
    if isUIOpen then return end
    
    DebugPrint("Ouverture interface bancaire")
    isUIOpen = true
    currentAccount = data
    
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openBank',
        data = data
    })
    
    -- Lancer l'animation après l'ouverture
    if nearATM then
        Wait(100)
        PlayATMAnimation()
    end
end

function UI.OpenCreate()
    if isUIOpen then return end
    
    DebugPrint("Ouverture création de compte")
    isUIOpen = true
    
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openCreate'
    })
end

function UI.UpdateBalance(newBalance)
    if not isUIOpen then return end
    
    SendNUIMessage({
        action = 'updateBalance',
        balance = newBalance
    })
    
    if currentAccount then
        currentAccount.balance = newBalance
    end
end

function UI.Close()
    if not isUIOpen then return end
    
    DebugPrint("Fermeture interface bancaire")
    isUIOpen = false
    currentAccount = nil
    
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'close'
    })
    
    -- Arrêter l'animation proprement
    StopAnimation()
end

-- ==================== CALLBACKS NUI ====================
RegisterNUICallback('close', function(data, cb)
    UI.Close()
    cb('ok')
end)

RegisterNUICallback('createAccount', function(data, cb)
    if not data.pin or #tostring(data.pin) ~= 4 then
        Notify('error', Config.Lang.invalid_pin)
        cb('error')
        return
    end
    
    TriggerServerEvent('bank:server:createAccount', data.pin)
    cb('ok')
end)

RegisterNUICallback('deposit', function(data, cb)
    local amount = tonumber(data.amount)
    if not amount or amount <= 0 then
        Notify('error', Config.Lang.invalid_amount)
        cb('error')
        return
    end
    
    TriggerServerEvent('bank:server:deposit', amount, data.cardId, data.pin)
    cb('ok')
end)

RegisterNUICallback('withdraw', function(data, cb)
    local amount = tonumber(data.amount)
    if not amount or amount <= 0 then
        Notify('error', Config.Lang.invalid_amount)
        cb('error')
        return
    end
    
    TriggerServerEvent('bank:server:withdraw', amount, data.cardId, data.pin)
    cb('ok')
end)

RegisterNUICallback('transfer', function(data, cb)
    local amount = tonumber(data.amount)
    if not amount or amount <= 0 then
        Notify('error', Config.Lang.invalid_amount)
        cb('error')
        return
    end
    
    if not data.target or data.target == '' then
        Notify('error', 'Destinataire invalide')
        cb('error')
        return
    end
    
    TriggerServerEvent('bank:server:transfer', amount, data.target, data.cardId, data.pin)
    cb('ok')
end)

-- ==================== EVENTS SERVEUR ====================
RegisterNetEvent('bank:client:receiveAccountData', function(data)
    currentAccount = data
    UI.Open(data)
end)

RegisterNetEvent('bank:client:updateBalance', function(newBalance)
    UI.UpdateBalance(newBalance)
end)

RegisterNetEvent('bank:client:forceClose', function()
    UI.Close()
end)

RegisterNetEvent('bank:client:openCreate', function()
    UI.OpenCreate()
end)

RegisterNetEvent('bank:client:notify', function(type, message)
    Notify(type, message)
end)

-- ==================== BLIPS ====================
CreateThread(function()
    for _, blipData in pairs(Config.Blips) do
        local blip = AddBlipForCoord(blipData.pos.x, blipData.pos.y, blipData.pos.z)
        SetBlipSprite(blip, blipData.sprite)
        SetBlipScale(blip, blipData.scale)
        SetBlipColour(blip, blipData.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(blipData.label)
        EndTextCommandSetBlipName(blip)
    end
    DebugPrint("Blips créés")
end)

-- ==================== PNJ BANQUIERS ====================
CreateThread(function()
    local pnjs = { Config.PNJ, Config.PNJ2 }
    
    for i, pnjConfig in ipairs(pnjs) do
        if pnjConfig and pnjConfig.Enabled then
            local model = pnjConfig.Model
            local hash = GetHashKey(model)
            
            RequestModel(hash)
            local timeout = GetGameTimer() + 5000
            while not HasModelLoaded(hash) and GetGameTimer() < timeout do
                Wait(100)
            end
            
            if HasModelLoaded(hash) then
                local ped = CreatePed(4, hash, pnjConfig.Coords.x, pnjConfig.Coords.y, pnjConfig.Coords.z - 1.0, pnjConfig.Heading, false, true)
                
                if DoesEntityExist(ped) then
                    SetEntityHeading(ped, pnjConfig.Heading)
                    FreezeEntityPosition(ped, pnjConfig.Frozen)
                    SetEntityInvincible(ped, pnjConfig.Invincible)
                    SetBlockingOfNonTemporaryEvents(ped, true)
                    
                    if pnjConfig.Scenario and pnjConfig.Scenario ~= "" then
                        TaskStartScenarioInPlace(ped, pnjConfig.Scenario, 0, true)
                    end
                    
                    DebugPrint(("PNJ %d spawné avec succès"):format(i))
                else
                    print(("^1[KT Banque] Erreur: Impossible de spawn le PNJ %d^7"):format(i))
                end
                
                SetModelAsNoLongerNeeded(hash)
            else
                print(("^1[KT Banque] Erreur: Modèle PNJ %d non chargé^7"):format(i))
            end
        end
    end
end)

-- ==================== DETECTION ATM OPTIMISÉE ====================
CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local wasNearATM = nearATM
        nearATM = false
        
        for _, model in pairs(Config.ATMModels) do
            local atm = GetClosestObjectOfType(coords.x, coords.y, coords.z, Config.ATMDistance, model, false, false, false)
            
            if DoesEntityExist(atm) then
                local atmCoords = GetEntityCoords(atm)
                local distance = #(coords - atmCoords)
                
                if distance < Config.ATMDistance then
                    sleep = 0
                    nearATM = true
                    
                    ESX.ShowHelpNotification(Config.Lang.press_to_use_atm)
                    
                    if IsControlJustReleased(0, 38) then -- E
                        TriggerServerEvent('bank:server:requestOpen')
                    end
                    
                    break
                end
            end
        end
        
        -- Si on s'éloigne de l'ATM pendant l'animation
        if wasNearATM and not nearATM and isInAnimation then
            StopAnimation()
        end
        
        Wait(sleep)
    end
end)

-- ==================== INTERACTIONS PNJ ====================
-- PNJ 1 - Amélioration carte
CreateThread(function()
    while true do
        local sleep = 1000
        
        if Config.PNJ and Config.PNJ.Enabled then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local distance = #(coords - Config.PNJ.Coords)
            
            if distance < Config.InteractionDistance then
                sleep = 0
                ESX.ShowHelpNotification(Config.Lang.press_to_upgrade_card)
                
                if IsControlJustReleased(0, 38) then -- E
                    OpenUpgradeMenu()
                end
            end
        end
        
        Wait(sleep)
    end
end)

-- PNJ 2 - Création compte
CreateThread(function()
    while true do
        local sleep = 1000
        
        if Config.PNJ2 and Config.PNJ2.Enabled then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local distance = #(coords - Config.PNJ2.Coords)
            
            if distance < Config.InteractionDistance then
                sleep = 0
                ESX.ShowHelpNotification(Config.Lang.press_to_create_account)
                
                if IsControlJustReleased(0, 38) then -- E
                    TriggerServerEvent('bank:server:checkExistingAccount')
                end
            end
        end
        
        Wait(sleep)
    end
end)

-- ==================== MENU AMÉLIORATION CARTE ====================
function OpenUpgradeMenu()
    local hasCard, cardType = HasCard()
    
    if not hasCard then
        Notify('error', Config.Lang.no_card)
        return
    end
    
    local options = {}
    
    for cType, cData in pairs(Config.CardLimits) do
        local disabled = cType == cardType
        local metadata = {}
        
        if disabled then
            table.insert(metadata, '✅ Carte actuelle')
        end
        
        table.insert(options, {
            title = cData.DisplayName,
            description = string.format(
                'Prix: $%s | Dépôt max: $%s | Retrait max: $%s',
                cData.Price,
                cData.MaxDeposit,
                cData.MaxWithdraw
            ),
            icon = cType == 'carte_basique' and 'credit-card' or cType == 'carte_or' and 'gem' or 'crown',
            disabled = disabled,
            metadata = metadata,
            onSelect = function()
                lib.alertDialog({
                    header = 'Confirmation',
                    content = string.format('Voulez-vous améliorer votre carte pour $%s ?', cData.Price),
                    centered = true,
                    cancel = true,
                    labels = {
                        confirm = 'Confirmer',
                        cancel = 'Annuler'
                    }
                }, function(confirmed)
                    if confirmed then
                        TriggerServerEvent('bank:server:upgradeCard', cType)
                    end
                end)
            end
        })
    end
    
    lib.registerContext({
        id = 'bank_upgrade_menu',
        title = '🏦 Améliorer ma Carte',
        options = options
    })
    
    lib.showContext('bank_upgrade_menu')
end

-- ==================== COMMANDES ====================
RegisterCommand('bank', function()
    TriggerServerEvent('bank:server:requestOpen')
end, false)

RegisterCommand('bankmenu', function()
    OpenUpgradeMenu()
end, false)

-- ==================== FERMETURE ESC ====================
CreateThread(function()
    while true do
        Wait(0)
        
        if isUIOpen then
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 106, true)
            
            if IsDisabledControlJustPressed(0, 322) or IsDisabledControlJustPressed(0, 177) then
                UI.Close()
            end
        else
            Wait(500)
        end
    end
end)

-- ==================== CLEANUP À LA DÉCONNEXION ====================
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    -- Nettoyage propre
    StopAnimation()
    if isUIOpen then
        UI.Close()
    end
end)

-- ==================== DEBUG ====================
if Config.Debug then
    RegisterCommand('bankdebug', function()
        print('=== DEBUG BANK ===')
        print('UI Open:', isUIOpen)
        print('Near ATM:', nearATM)
        print('Has Card:', HasCard())
        print('Current Account:', currentAccount ~= nil)
        print('In Animation:', isInAnimation)
    end, false)
end

print('^2[KT Banque]^7 Client chargé avec succès')