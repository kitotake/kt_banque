-- ==================== KT BANQUE v7.5.0 — CLIENT/MODULES/ANIMATION ====================
-- Gestion de l'animation ATM côté client.
--
-- CORRECTIONS :
--   FIX-1 : RequestAnimDict avec timeout pour éviter un blocage infini
--            si le dict n'existe pas ou tarde à charger.
--   FIX-2 : animThreadId incrémenté AVANT de créer le thread
--            pour éviter la race condition.
--   FIX-3 : Anim.Stop vérifie isInAnimation avant ClearPedTasks.

Anim = {}

local isInAnimation = false
local animThreadId  = 0

function Anim.Stop()
    if not isInAnimation then return end
    isInAnimation = false
    animThreadId  = animThreadId + 1
    ClearPedTasks(PlayerPedId())
end

function Anim.PlayATM()
    if not Config.Animations.enabled or isInAnimation then return end

    local ped  = PlayerPedId()
    local dict = Config.Animations.dict

    -- FIX-1 : chargement du dict avec timeout de 5 secondes
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        Wait(10)
        if GetGameTimer() > timeout then
            print('^1[KT Banque] Timeout chargement anim dict : ' .. dict .. '^7')
            return
        end
    end

    isInAnimation = true

    -- FIX-2 : incrémenter l'ID AVANT de lancer le thread
    animThreadId = animThreadId + 1
    local id = animThreadId

    TaskPlayAnim(ped, dict, Config.Animations.anim,
        8.0, -8.0, -1, Config.Animations.flag, 0, false, false, false)

    CreateThread(function()
        while animThreadId == id and isInAnimation do
            Wait(500)
        end
        -- FIX-3 : nettoyage si ce thread est encore le thread actif
        if animThreadId == id then
            isInAnimation = false
        end
    end)
end