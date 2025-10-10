ESX = exports["es_extended"]:getSharedObject()
local DB = Config.DB

BankAdmin = {}

-- Désactiver une carte bancaire

-- Exports
exports('AdminDeactivateCard', BankAdmin.DeactivateCard)
exports('AdminReprintPin', BankAdmin.ReprintPin)
exports('AdminCreateCardForPlayer', BankAdmin.CreateCardForPlayer)
exports('AdminGetAccountInfo', BankAdmin.GetAccountInfo)
exports('AdminSetBalance', BankAdmin.SetBalance)

print('^2[KT Banque]^7 Système admin chargé - Commandes: /bank:repair, /bank:info, /bank:givecard')