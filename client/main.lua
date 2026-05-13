-- ==================== KT BANQUE v7.5.0 — CLIENT/MAIN ====================
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    UI.Close()
    Anim.Stop()
end)

print('^2[KT Banque]^7 Client chargé v7.5.0')
