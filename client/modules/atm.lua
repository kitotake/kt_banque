-- ==================== KT BANQUE v7.5.0 — CLIENT/MODULES/ATM ====================
-- Détection de proximité des distributeurs automatiques.
--
-- CORRECTIONS :
--   FIX-1 : lib.showTextUI et lib.hideTextUI appelés une seule fois
--            via un flag `textUiShown` — évite le spam d'appels NUI à chaque tick.
--   FIX-2 : UI.SetNearATM appelé uniquement au changement d'état (found/not found).

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

        -- FIX-2 : appel UI.SetNearATM seulement au changement d'état
        if found and not wasNearATM then
            wasNearATM = true
            UI.SetNearATM(true)
        elseif not found and wasNearATM then
            wasNearATM = false
            UI.SetNearATM(false)
        end

        -- FIX-1 : affichage/masquage du TextUI uniquement au changement
        if found then
            if not textUiShown then
                lib.showTextUI(Config.Lang.press_to_use_atm or '[E] Utiliser l\'ATM')
                textUiShown = true
            end
            -- Détection appui touche E (38)
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