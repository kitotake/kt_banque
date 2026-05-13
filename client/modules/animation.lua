-- ==================== KT BANQUE v7.5.0 — CLIENT/MODULES/ANIMATION ====================
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
    animThreadId  = animThreadId + 1
    local id      = animThreadId

    TaskPlayAnim(ped, dict, Config.Animations.anim,
        8.0, -8.0, -1, Config.Animations.flag, 0, false, false, false)

    CreateThread(function()
        while animThreadId == id and isInAnimation do
            Wait(500)
        end
        if animThreadId == id then
            isInAnimation = false
        end
    end)
end
