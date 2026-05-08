-- ==================== KT BANQUE v7.5.0 — CLIENT/MAIN ====================
-- Point d'entrée client.
-- Les modules sont déjà chargés par fxmanifest dans l'ordre :
--   animation → ui → atm → npc → card_recovery → main

-- ──────────────────────────────────────────
-- NETTOYAGE À L'ARRÊT DE LA RESSOURCE
-- ──────────────────────────────────────────

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    UI.Close()
    Anim.Stop()
end)

print('^2[KT Banque]^7 Client chargé v7.5.0')
