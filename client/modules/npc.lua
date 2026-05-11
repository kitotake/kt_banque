-- ==================== KT BANQUE v7.5.0 — CLIENT/MODULES/NPC ====================
-- Détection de proximité des PNJ banquiers.
--
-- CORRECTIONS :
--   FIX-1 : textUiShown flag pour éviter le spam de lib.showTextUI/hideTextUI.
--   FIX-2 : lib.hideTextUI appelé seulement si le TextUI était affiché.
--   FIX-3 : Vérification Config.PNJ et Config.PNJ2 avant accès aux champs.
--   FIX-4 : sleep=0 uniquement si proche, sinon 500ms pour économiser CPU.

local textUiShown = false
local lastShownLabel = ""

CreateThread(function()
    while true do
        local sleep  = 500
        local ped    = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local shown  = false
        local label  = ""

        -- FIX-3 : guard sur Config.PNJ
        if Config.PNJ and Config.PNJ.Enabled
            and Config.PNJ.Coords
            and #(coords - Config.PNJ.Coords) < Config.InteractionDistance then
            sleep = 0
            shown = true
            label = Config.PNJ.Label or '[E] Améliorer carte'

            if IsControlJustReleased(0, 38) then
                TriggerServerEvent('bank:server:upgradeCard', 'card_gold')
            end

        -- FIX-3 : guard sur Config.PNJ2
        elseif Config.PNJ2 and Config.PNJ2.Enabled
            and Config.PNJ2.Coords
            and #(coords - Config.PNJ2.Coords) < Config.InteractionDistance then
            sleep = 0
            shown = true
            label = Config.PNJ2.Label or '[E] Ouvrir un compte'

            if IsControlJustReleased(0, 38) then
                TriggerServerEvent('bank:server:requestOpen')
            end
        end

        -- FIX-1 & FIX-2 : gestion propre du TextUI sans spam
        if shown then
            if not textUiShown or lastShownLabel ~= label then
                if textUiShown then lib.hideTextUI() end
                lib.showTextUI(label)
                textUiShown   = true
                lastShownLabel = label
            end
        else
            if textUiShown then
                lib.hideTextUI()
                textUiShown    = false
                lastShownLabel = ""
            end
        end

        Wait(sleep)
    end
end)