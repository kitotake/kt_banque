-- server/bank.lua
ESX = exports["es_extended"]:getSharedObject()
local oxmysql = exports.oxmysql
local DB = Config.DB

-- Helper sync wrappers (utilisent callbacks d'oxmysql)
local function dbFetch(query, params)
  local result = nil
  local done = false
  oxmysql:fetch(query, params or {}, function(res)
    result = res
    done = true
  end)
  while not done do Citizen.Wait(0) end
  return result
end

local function dbExecute(query, params)
  local result = nil
  local done = false
  oxmysql:execute(query, params or {}, function(affected)
    result = affected
    done = true
  end)
  while not done do Citizen.Wait(0) end
  return result
end

local function dbInsert(query, params)
  -- oxmysql:execute retourne affect rows, il y a pas de insertId direct.
  -- Pour obtenir un insert id on utilise une requête SELECT LAST_INSERT_ID() si nécessaire.
  -- Ici on exécute la requête INSERT puis on récupère LAST_INSERT_ID()
  dbExecute(query, params)
  local res = dbFetch("SELECT LAST_INSERT_ID() as id", {})
  if res and res[1] and res[1].id then
    return tonumber(res[1].id)
  end
  return nil
end

-- UTIL: genera un IBAN-like FRXXXX... simple (non standardisé mais lisible)
local function generateIBANLike()
  local function randDigits(n)
    local s = ""
    for i = 1, n do s = s .. tostring(math.random(0,9)) end
    return s
  end

  -- boucle jusqu'à trouver un numéro unique (safety)
  for i=1,10 do
    local bankCode = randDigits(5)
    local account = randDigits(11)
    local checksum = randDigits(2)
    local iban = ("FR%s%s%s"):format(checksum, bankCode, account) -- ex: FR12 12345 12345678901
    -- check uniqueness in banking table (we'll use label/account maybe)
    local q = string.format("SELECT ID FROM %s WHERE label = ? LIMIT 1", DB.banking_table)
    local exists = dbFetch(q, { iban })
    if not (exists and exists[1]) then
      return iban
    end
  end
  -- fallback
  return "FR" .. tostring(math.random(10000000,99999999))
end

-- récupère l'item carte dans l'inventaire du joueur
local function getCardFromInventory(source)
  -- cherche pour chaque nom d'item possible (carte basique / or / dimas)
  for cardType, itemName in pairs(Config.BankCardItem) do
    local slots = exports.ox_inventory:Search(source, 'slots', itemName)
    if slots and #slots > 0 then
      -- retourne le premier item (avec metadata)
      for _, it in ipairs(slots) do
        if it.metadata and (it.metadata.id or it.metadata.account_id) then
          -- ajoute un champ card_type pour indiquer le type détecté
          it.card_type = cardType
          it.item_name = itemName
          return it
        end
      end
    end
  end
  return nil
end

-- get card from DB by id
local function getCardFromDB(cardId)
  if not cardId then return nil end
  local q = string.format("SELECT * FROM %s WHERE id = ? AND active = 1 LIMIT 1", DB.bank_cards_table)
  local r = dbFetch(q, { cardId })
  if r and r[1] then return r[1] end
  return nil
end

local function getAccount(accountId)
  if not accountId then return nil end
  local q = string.format("SELECT * FROM %s WHERE ID = ? LIMIT 1", DB.banking_table)
  local r = dbFetch(q, { accountId })
  if r and r[1] then return r[1] end
  return nil
end

local function insertLog(accountId, action, amount, identifier, description)
  local q = string.format("INSERT INTO %s (account_id, action, amount, identifier, description) VALUES (?, ?, ?, ?, ?)", DB.bank_logs_table)
  dbExecute(q, { accountId, action, amount, identifier, description })
end

-- retourne limits selon type de carte (fallback carte_basique)
local function getLimitsForCardType(cardType)
  cardType = cardType or "carte_basique"
  return Config.CardLimits[cardType] or Config.CardLimits["carte_basique"]
end

-- validate PIN server-side and return card row
local function validatePinAndGetCard(cardId, pin)
  local card = getCardFromDB(cardId)
  if not card then return nil, "Carte introuvable ou désactivée." end
  if tostring(card.pin) ~= tostring(pin) then return nil, "PIN incorrect." end
  return card, nil
end

-- CREATE ACCOUNT + CARD (NUI createAccount)
RegisterNetEvent('bank:server:createAccount', function(data)
  local src = source
  local pin = tostring(data.pin or data) -- accept either string or table
  local chosenType = tostring(data.card_type or "carte_basique")
  local xPlayer = ESX.GetPlayerFromId(src)
  if not xPlayer then return end
  if not pin or #pin ~= 4 or tonumber(pin) == nil then
    TriggerClientEvent('ox_lib:notify', src, {type='error', description='PIN invalide (4 chiffres).'})
    return
  end
  -- insert banking account with readable account number (IBAN-like)
  local accountNumber = generateIBANLike()
  local insertAccQ = string.format("INSERT INTO %s (identifier, type, amount, balance, label, time) VALUES (?, ?, ?, ?, ?, ?)", DB.banking_table)
  local accId = dbInsert(insertAccQ, { xPlayer.identifier, 'personal', 0, 0, accountNumber, os.time() })
  if not accId then
    TriggerClientEvent('ox_lib:notify', src, {type='error', description='Erreur création compte.'})
    return
  end

  -- generate card number & store card_type
  math.randomseed(GetGameTimer() + os.time())
  local cardNum = tostring(math.random(40000000,49999999)) .. tostring(math.random(1000,9999))

  local insertCardQ = string.format("INSERT INTO %s (account_id, identifier, owner_name, card_number, pin, expires, active, card_type) VALUES (?, ?, ?, ?, ?, ?, ?, ?)", DB.bank_cards_table)
  local cardId = dbInsert(insertCardQ, { accId, xPlayer.identifier, xPlayer.getName(), cardNum, pin, nil, 1, chosenType })
  if not cardId then
    TriggerClientEvent('ox_lib:notify', src, {type='error', description='Erreur création carte.'})
    return
  end

  -- add item in inventory with metadata linking to DB (id + account_id + card_type)
  local metadata = {
    id = cardId,
    account_id = accId,
    owner = xPlayer.getName(),
    card_number = cardNum,
    card_type = chosenType
  }
  exports.ox_inventory:AddItem(src, Config.BankCardItem[chosenType], 1, metadata)

  TriggerClientEvent('ox_lib:notify', src, {type='success', description='Compte créé et carte ajoutée à votre inventaire.'})
end)

-- Request open NUI (server verifies card exists and sends payload)
RegisterNetEvent('bank:server:requestOpen', function()
  local src = source
  local cardItem = getCardFromInventory(src)
  if not cardItem then
    TriggerClientEvent('ox_lib:notify', src, {type='error', description="Aucune carte bancaire trouvée."})
    return
  end

  local dbCard = nil
  if cardItem.metadata and cardItem.metadata.id then
    dbCard = getCardFromDB(cardItem.metadata.id)
  end

  if not dbCard then
    TriggerClientEvent('ox_lib:notify', src, {type='error', description="Carte invalide ou non activée."})
    return
  end

  local account = getAccount(dbCard.account_id)
  if not account then
    TriggerClientEvent('ox_lib:notify', src, {type='error', description="Compte introuvable."})
    return
  end

  local logsQ = string.format("SELECT action, amount, identifier, description, date FROM %s WHERE account_id = ? ORDER BY date DESC LIMIT 30", DB.bank_logs_table)
  local logs = dbFetch(logsQ, { dbCard.account_id }) or {}

  local payload = {
    balance = account.balance or 0,
    label = account.label or "personnel",
    history = logs,
    card_meta = {
      id = dbCard.id,
      account_id = dbCard.account_id,
      owner = dbCard.owner_name,
      last4 = tostring(dbCard.card_number):sub(-4),
      card_type = dbCard.card_type or "carte_basique"
    }
  }

  TriggerClientEvent('bank:client:openNUI', src, payload)
end)

-- DEPOSIT (expects table: { amount = X, cardId = Y, pin = Z })
RegisterNetEvent('bank:server:deposit', function(data)
  local src = source
  local amount = tonumber(data.amount)
  local cardId = tonumber(data.cardId)
  local pin = tostring(data.pin)

  if not amount or amount <= 0 then
    TriggerClientEvent('ox_lib:notify', src, {type='error', description='Montant invalide.'})
    return
  end

  local cardRow, err = validatePinAndGetCard(cardId, pin)
  if not cardRow then
    TriggerClientEvent('ox_lib:notify', src, {type='error', description=err})
    return
  end

  -- limites selon type de carte
  local limits = getLimitsForCardType(cardRow.card_type)
  if amount > (limits.MaxDeposit or Config.CardLimits.carte_basique.MaxDeposit) then
    TriggerClientEvent('ox_lib:notify', src, {type='error', description=('Montant max dépôt pour votre carte: %s'):format(limits.MaxDeposit)})
    return
  end

  local xPlayer = ESX.GetPlayerFromId(src)
  if not xPlayer then return end
  if xPlayer.getMoney() < amount then
    TriggerClientEvent('ox_lib:notify', src, {type='error', description='Pas assez d\'argent liquide.'})
    return
  end

  -- update DB
  local updateQ = string.format("UPDATE %s SET balance = balance + ? WHERE ID = ?", DB.banking_table)
  dbExecute(updateQ, { amount, cardRow.account_id })
  insertLog(cardRow.account_id, "deposit", amount, cardRow.identifier, "Dépôt via NUI")

  xPlayer.removeMoney(amount)
  TriggerClientEvent('ox_lib:notify', src, {type='success', description=('Dépôt de $%s effectué.'):format(amount)})

  local acc = getAccount(cardRow.account_id)
  TriggerClientEvent('bank:client:updateBalance', src, acc.balance or 0)
end)

-- WITHDRAW
RegisterNetEvent('bank:server:withdraw', function(data)
  local src = source
  local amount = tonumber(data.amount)
  local cardId = tonumber(data.cardId)
  local pin = tostring(data.pin)

  if not amount or amount <= 0 then
    TriggerClientEvent('ox_lib:notify', src, {type='error', description='Montant invalide.'})
    return
  end

  local cardRow, err = validatePinAndGetCard(cardId, pin)
  if not cardRow then
    TriggerClientEvent('ox_lib:notify', src, {type='error', description=err})
    return
  end

  local limits = getLimitsForCardType(cardRow.card_type)
  if amount > (limits.MaxWithdraw or Config.CardLimits.carte_basique.MaxWithdraw) then
    TriggerClientEvent('ox_lib:notify', src, {type='error', description=('Montant max retrait pour votre carte: %s'):format(limits.MaxWithdraw)})
    return
  end

  local acc = getAccount(cardRow.account_id)
  if not acc or (acc.balance or 0) < amount then
    TriggerClientEvent('ox_lib:notify', src, {type='error', description='Solde insuffisant.'})
    return
  end

  local updateQ = string.format("UPDATE %s SET balance = balance - ? WHERE ID = ?", DB.banking_table)
  dbExecute(updateQ, { amount, cardRow.account_id })
  insertLog(cardRow.account_id, "withdraw", amount, cardRow.identifier, "Retrait via NUI")

  local xPlayer = ESX.GetPlayerFromId(src)
  xPlayer.addMoney(amount)

  TriggerClientEvent('ox_lib:notify', src, {type='success', description=('Retrait de $%s effectué.'):format(amount)})
  local acc2 = getAccount(cardRow.account_id)
  TriggerClientEvent('bank:client:updateBalance', src, acc2.balance or 0)
end)

-- TRANSFER (target can be account ID (number) or identifier)
RegisterNetEvent('bank:server:transfer', function(data)
  local src = source
  local amount = tonumber(data.amount)
  local cardId = tonumber(data.cardId)
  local pin = tostring(data.pin)
  local target = data.target

  if not amount or amount <= 0 then
    TriggerClientEvent('ox_lib:notify', src, {type='error', description='Montant invalide.'})
    return
  end

  local cardRow, err = validatePinAndGetCard(cardId, pin)
  if not cardRow then
    TriggerClientEvent('ox_lib:notify', src, {type='error', description=err})
    return
  end

  local fromAcc = getAccount(cardRow.account_id)
  if not fromAcc or (fromAcc.balance or 0) < amount then
    TriggerClientEvent('ox_lib:notify', src, {type='error', description='Solde insuffisant.'})
    return
  end

  local targetAcc = nil
  if tonumber(target) then
    targetAcc = getAccount(tonumber(target))
  else
    local q = string.format("SELECT * FROM %s WHERE label = ? OR identifier = ? LIMIT 1", DB.banking_table)
    local r = dbFetch(q, { target, target })
    if r and r[1] then targetAcc = r[1] end
  end

  if not targetAcc then
    TriggerClientEvent('ox_lib:notify', src, {type='error', description='Compte destinataire introuvable.'})
    return
  end

  -- transaction
  dbExecute(string.format("UPDATE %s SET balance = balance - ? WHERE ID = ?", DB.banking_table), { amount, fromAcc.ID })
  dbExecute(string.format("UPDATE %s SET balance = balance + ? WHERE ID = ?", DB.banking_table), { amount, targetAcc.ID })

  insertLog(fromAcc.ID, "transfer_out", amount, cardRow.identifier, ("Transfert vers %s"):format(targetAcc.ID))
  insertLog(targetAcc.ID, "transfer_in", amount, cardRow.identifier, ("Reçu de %s"):format(fromAcc.ID))

  TriggerClientEvent('ox_lib:notify', src, {type='success', description=('Transfert de $%s vers %s effectué.'):format(amount, targetAcc.ID)})
  local after = getAccount(fromAcc.ID)
  TriggerClientEvent('bank:client:updateBalance', src, after.balance or 0)
end)

-- ==============================
-- ADMIN EXPORTS / FUNCTIONS
-- ==============================
-- Important: to allow other resources to call these functions as exports,
-- add server_export lines to fxmanifest.lua, e.g.:
-- server_export 'AdminDeactivateCard'
-- server_export 'AdminReprintPin'
-- server_export 'AdminCreateCardForPlayer'

-- Désactiver une carte (returns true/false)
function AdminDeactivateCard(cardId)
  if not cardId then return false end
  local q = string.format("UPDATE %s SET active = 0 WHERE id = ?", DB.bank_cards_table)
  local r = dbExecute(q, { cardId })
  return r and r > 0
end

-- Réimprimer / regénérer un PIN (returns newPin or nil)
function AdminReprintPin(cardId)
  if not cardId then return nil end
  local newPin = tostring(math.random(1000,9999))
  local q = string.format("UPDATE %s SET pin = ? WHERE id = ?", DB.bank_cards_table)
  local r = dbExecute(q, { newPin, cardId })
  if r and r > 0 then
    return newPin
  end
  return nil
end

-- Créer une carte pour un joueur (identifier = steam:xxxx ou ESX identifier)
function AdminCreateCardForPlayer(identifier, cardType, ownerName)
  if not identifier or not cardType then return nil end
  local playerLabel = ownerName or identifier

  -- create account
  local accountNumber = generateIBANLike()
  local accQ = string.format("INSERT INTO %s (identifier, type, amount, balance, label, time) VALUES (?, ?, ?, ?, ?, ?)", DB.banking_table)
  local accId = dbInsert(accQ, { identifier, 'personal', 0, 0, accountNumber, os.time() })
  if not accId then return nil end

  -- card
  math.randomseed(GetGameTimer() + os.time())
  local cardNum = tostring(math.random(40000000,49999999)) .. tostring(math.random(1000,9999))
  local newPin = tostring(math.random(1000,9999))

  local cardQ = string.format("INSERT INTO %s (account_id, identifier, owner_name, card_number, pin, expires, active, card_type) VALUES (?, ?, ?, ?, ?, ?, ?, ?)", DB.bank_cards_table)
  local cardId = dbInsert(cardQ, { accId, identifier, playerLabel, cardNum, newPin, nil, 1, cardType })
  if not cardId then return nil end

  return { account_id = accId, card_id = cardId, pin = newPin, account_number = accountNumber }
end

-- Register server exports so other resources can call them
-- Important: also add server_export entries in your fxmanifest.lua
_G.AdminDeactivateCard = AdminDeactivateCard
_G.AdminReprintPin = AdminReprintPin
_G.AdminCreateCardForPlayer = AdminCreateCardForPlayer

-- You can also register them as events for menu usage:
RegisterNetEvent('bank:admin:deactivateCard', function(cardId)
  local ok = AdminDeactivateCard(cardId)
  local src = source
  if ok then TriggerClientEvent('ox_lib:notify', src, {type='success', description='Carte désactivée.'})
  else TriggerClientEvent('ox_lib:notify', src, {type='error', description='Erreur désactivation.'}) end
end)

RegisterNetEvent('bank:admin:reprintPin', function(cardId)
  local src = source
  local pin = AdminReprintPin(cardId)
  if pin then TriggerClientEvent('ox_lib:notify', src, {type='success', description=('Nouveau PIN: %s'):format(pin)}) 
  else TriggerClientEvent('ox_lib:notify', src, {type='error', description='Erreur génération PIN.'}) end
end)

RegisterNetEvent('bank:admin:createCardFor', function(identifier, cardType, ownerName)
  local src = source
  local res = AdminCreateCardForPlayer(identifier, cardType or "carte_basique", ownerName)
  if res then
    TriggerClientEvent('ox_lib:notify', src, {type='success', description=('Carte créée (cardId:%s, pin:%s)'):format(res.card_id, res.pin)})
  else
    TriggerClientEvent('ox_lib:notify', src, {type='error', description='Erreur création carte.'})
  end
end)
