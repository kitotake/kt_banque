-- ==================== KT BANQUE v7.5.0 — CLIENT/MODULES/NPC ====================
local textUiShown  = false
local lastShownLabel = ""

CreateThread(function()
    while true do
        local sleep  = 500
        local ped    = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local shown  = false
        local label  = ""

        if Config.PNJ and Config.PNJ.Enabled
            and Config.PNJ.Coords
            and #(coords - Config.PNJ.Coords) < Config.InteractionDistance then
            sleep = 0
            shown = true
            label = Config.PNJ.Label or '[E] Améliorer carte'

            if IsControlJustReleased(0, 38) then
                TriggerServerEvent('bank:server:upgradeCard', 'card_gold')
            end

        elseif Config.PNJ_Replace and Config.PNJ_Replace.Enabled
            and Config.PNJ_Replace.Coords
            and #(coords - Config.PNJ_Replace.Coords) < Config.InteractionDistance then
            sleep = 0
            shown = true
            label = Config.PNJ_Replace.Label or ('[E] Remplacer carte ($%d)'):format(Config.CardReplaceCost or 500)

            if IsControlJustReleased(0, 38) then
                OpenCardRecovery()
            end

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

        if shown then
            if not textUiShown or lastShownLabel ~= label then
                if textUiShown then lib.hideTextUI() end
                lib.showTextUI(label)
                textUiShown    = true
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
