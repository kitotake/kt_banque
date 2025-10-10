BankAnimations = {}

-----------------------------------
-- 🎭 JOUER ANIMATION ATM
-----------------------------------
function BankAnimations.playATMAnimation()
    if not Config.Animations.enabled then return end
    
    local ped = PlayerPedId()
    local dict = Config.Animations.dict
    local anim = Config.Animations.anim
    local flag = Config.Animations.flag
    
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
    
    TaskPlayAnim(ped, dict, anim, 8.0, -8.0, -1, flag, 0, false, false, false)
    
    ClientBankUtils.debugPrint("Animation ATM lancée")
end

-----------------------------------
-- 🛑 ARRÊTER ANIMATION
-----------------------------------
function BankAnimations.stopAnimation()
    if not Config.Animations.enabled then return end
    
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    
    ClientBankUtils.debugPrint("Animation arrêtée")
end

print('^2[KT Banque]^7 Animations chargées')