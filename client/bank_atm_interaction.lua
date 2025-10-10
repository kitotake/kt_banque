BankATM = {}

-----------------------------------
-- 🏧 DETECTION DES ATM
-----------------------------------
CreateThread(function()
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        ClientBankUtils.nearATM = false
        
        for _, model in pairs(Config.ATMModels) do
            local atm = GetClosestObjectOfType(coords.x, coords.y, coords.z, Config.ATMDistance, model, false, false, false)
            if DoesEntityExist(atm) then
                local atmCoords = GetEntityCoords(atm)
                local distance = #(coords - atmCoords)
                if distance < Config.ATMDistance then
                    sleep = 0
                    ClientBankUtils.nearATM = true
                    ESX.ShowHelpNotification("Appuyez sur ~INPUT_CONTEXT~ pour utiliser l'ATM")
                    if IsControlJustReleased(0, 38) then
                        -- Jouer animation
                        BankAnimations.playATMAnimation()
                        
                        -- Ouvrir l'interface après un petit délai
                        Wait(500)
                        TriggerServerEvent('bank:server:requestOpen')
                    end
                    break
                end
            end
        end
        Wait(sleep)
    end
end)

print('^2[KT Banque]^7 Détection ATM chargée')