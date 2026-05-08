-- ==================== KT BANQUE v7.5.0 — CLIENT/MODULES/ATM ====================
-- Détection de proximité des distributeurs automatiques.

CreateThread(function()
    while true do
        local sleep  = 500
        local ped    = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local found  = false

        for _, model in pairs(Config.ATMModels) do
            local atm = GetClosestObjectOfType(coords, Config.ATMDistance + 1.0, model, false)
            if atm ~= 0 and #(coords - GetEntityCoords(atm)) < Config.ATMDistance then
                found = true
                sleep = 0
                UI.SetNearATM(true)
                lib.showTextUI(Config.Lang.press_to_use_atm or '[E] Utiliser l\'ATM')
                if IsControlJustReleased(0, 38) then
                    TriggerServerEvent('bank:server:requestOpen')
                end
                break
            end
        end

        if not found then
            UI.SetNearATM(false)
            lib.hideTextUI()
        end

        Wait(sleep)
    end
end)
