-- ==================== KT BANQUE v7.5.0 — CLIENT/MODULES/NPC ====================
-- Détection de proximité des PNJ banquiers.

CreateThread(function()
    while true do
        local sleep  = 500
        local ped    = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local shown  = false

        -- PNJ amélioration de carte
        if Config.PNJ and Config.PNJ.Enabled
            and #(coords - Config.PNJ.Coords) < Config.InteractionDistance then
            sleep = 0
            shown = true
            lib.showTextUI(Config.PNJ.Label or '[E] Améliorer carte')
            if IsControlJustReleased(0, 38) then
                TriggerServerEvent('bank:server:upgradeCard', 'card_gold')
            end

        -- PNJ ouverture de compte
        elseif Config.PNJ2 and Config.PNJ2.Enabled
            and #(coords - Config.PNJ2.Coords) < Config.InteractionDistance then
            sleep = 0
            shown = true
            lib.showTextUI(Config.PNJ2.Label or '[E] Ouvrir un compte')
            if IsControlJustReleased(0, 38) then
                TriggerServerEvent('bank:server:requestOpen')
            end
        end

        if not shown then lib.hideTextUI() end
        Wait(sleep)
    end
end)
