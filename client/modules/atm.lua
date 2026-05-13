-- ==================== KT BANQUE v7.5.0 — CLIENT/MODULES/ATM ====================
local textUiShown = false
local wasNearATM  = false

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
                break
            end
        end

        if found and not wasNearATM then
            wasNearATM = true
            UI.SetNearATM(true)
        elseif not found and wasNearATM then
            wasNearATM = false
            UI.SetNearATM(false)
        end

        if found then
            if not textUiShown then
                lib.showTextUI(Config.Lang.press_to_use_atm or '[E] Utiliser l\'ATM')
                textUiShown = true
            end
            if IsControlJustReleased(0, 38) then
                TriggerServerEvent('bank:server:requestOpen')
            end
        else
            if textUiShown then
                lib.hideTextUI()
                textUiShown = false
            end
        end

        Wait(sleep)
    end
end)
