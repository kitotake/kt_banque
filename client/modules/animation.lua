-- ==================== KT BANQUE v7.5.0 — CLIENT/MODULES/ANIMATION ====================
-- Gestion de l'animation ATM côté client.

Anim = {}

local isInAnimation = false
local animThreadId  = 0

function Anim.Stop()
    if not isInAnimation then return end
    ClearPedTasks(PlayerPedId())
    isInAnimation = false
    animThreadId  = animThreadId + 1
end

function Anim.PlayATM()
    if not Config.Animations.enabled or isInAnimation then return end
    local ped = PlayerPedId()
    RequestAnimDict(Config.Animations.dict)
    while not HasAnimDictLoaded(Config.Animations.dict) do Wait(10) end
    isInAnimation = true
    TaskPlayAnim(ped, Config.Animations.dict, Config.Animations.anim,
        8.0, -8.0, -1, Config.Animations.flag, 0, false, false, false)

    local id = animThreadId + 1
    animThreadId = id

    CreateThread(function()
        while animThreadId == id do
            Wait(500)
            -- Sera arrêtée par UI.Close ou la détection ATM
        end
    end)
end
