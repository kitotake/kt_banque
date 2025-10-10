BankPNJ = {}

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
    ClientBankUtils.debugPrint("Blips créés")
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
-- 🏦 INTERACTIONS PNJ
-----------------------------------

-- PNJ1 - Achat de carte
local function openCardPurchaseMenu()
    ClientBankUtils.debugPrint("Interaction PNJ1 - Achat de carte")
    TriggerServerEvent('bank:server:checkPendingAccount')
end

-- PNJ2 - Ouverture de compte
local function openAccountCreationMenu()
    ClientBankUtils.debugPrint("Interaction PNJ2 - Création de compte")
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

print('^2[KT Banque]^7 PNJ et interactions chargés')