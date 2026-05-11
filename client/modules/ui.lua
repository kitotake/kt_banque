-- ==================== KT BANQUE v7.5.0 — CLIENT/MODULES/UI ====================
-- Gestion de l'interface NUI (ouverture, fermeture, mises à jour).
--
-- CORRECTIONS :
--   FIX-1 : Guard sur amount <= 0 avant envoi au serveur (double validation).
--   FIX-2 : pinHash tostring() garanti avant envoi.
--   FIX-3 : ESC handler — thread optimisé avec Wait(0) seulement si UI ouverte.

UI = {}

local isUIOpen       = false
local currentAccount = nil
local nearATM        = false

function UI.IsOpen()      return isUIOpen  end
function UI.SetNearATM(v) nearATM = v      end

function UI.Open(data)
    if isUIOpen then return end
    isUIOpen       = true
    currentAccount = data
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openBank', data = data })
    if nearATM then
        Wait(100)
        Anim.PlayATM()
    end
end

function UI.OpenCreate()
    if isUIOpen then return end
    isUIOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openCreate' })
end

function UI.Close()
    if not isUIOpen then return end
    isUIOpen       = false
    currentAccount = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    Anim.Stop()
end

function UI.UpdateBalance(balance)
    SendNUIMessage({ action = 'updateBalance', data = balance })
    if currentAccount then currentAccount.balance = balance end
end

-- ──────────────────────────────────────────
-- NUI CALLBACKS
-- ──────────────────────────────────────────

RegisterNUICallback('close', function(_, cb)
    UI.Close(); cb('ok')
end)

RegisterNUICallback('deposit', function(data, cb)
    local amount  = tonumber(data.amount)
    -- FIX-1 : validation montant + FIX-2 : pinHash tostring garanti
    if not amount or amount <= 0 then cb('err'); return end
    local pinHash = tostring(data.pinHash or "")
    if pinHash == "" then cb('err'); return end
    TriggerServerEvent('bank:server:deposit', amount, pinHash)
    cb('ok')
end)

RegisterNUICallback('withdraw', function(data, cb)
    local amount  = tonumber(data.amount)
    if not amount or amount <= 0 then cb('err'); return end
    local pinHash = tostring(data.pinHash or "")
    if pinHash == "" then cb('err'); return end
    TriggerServerEvent('bank:server:withdraw', amount, pinHash)
    cb('ok')
end)

RegisterNUICallback('transfer', function(data, cb)
    local amount  = tonumber(data.amount)
    local target  = tostring(data.target or "")
    local pinHash = tostring(data.pinHash or "")
    if not amount or amount <= 0 or target == "" or pinHash == "" then
        cb('err'); return
    end
    TriggerServerEvent('bank:server:transfer', amount, target, pinHash)
    cb('ok')
end)

RegisterNUICallback('createAccount', function(data, cb)
    local pin = tostring(data.pin or "")
    if #pin ~= 4 or not pin:match("^%d+$") then cb('err'); return end
    TriggerServerEvent('bank:server:createAccount', pin)
    cb('ok')
end)

-- ──────────────────────────────────────────
-- ÉVÉNEMENTS SERVEUR → CLIENT
-- ──────────────────────────────────────────

RegisterNetEvent('bank:client:openBank',      function(data)    UI.Open(data)            end)
RegisterNetEvent('bank:client:openCreate',    function()        UI.OpenCreate()          end)
RegisterNetEvent('bank:client:updateBalance', function(balance) UI.UpdateBalance(balance) end)
RegisterNetEvent('bank:client:forceClose',    function()        UI.Close()               end)

RegisterNetEvent('bank:client:notify', function(type, msg)
    lib.notify({
        title       = type == 'success' and 'Succès' or type == 'error' and 'Erreur' or 'Info',
        description = msg,
        type        = type
    })
end)

-- ──────────────────────────────────────────
-- FERMETURE PAR ESC
-- FIX-3 : Wait(0) uniquement si UI ouverte, sinon Wait(500) pour économiser
--          les ressources CPU.
-- ──────────────────────────────────────────

CreateThread(function()
    while true do
        if isUIOpen then
            Wait(0)
            if IsControlJustPressed(0, 322) then
                UI.Close()
            end
        else
            Wait(500)
        end
    end
end)