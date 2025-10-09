-- config.lua
Config = {}

-- Items ox_inventory utilisés pour les cartes (différents plans)
Config.BankCardItem = {
    carte_basique = "bank_card",
    carte_or    = "bank_or",
    carte_dimas = "bank_dimas"
  }
  
  -- Limites (par type de carte)
  Config.CardLimits = {
    carte_basique = { MaxDeposit = 2000, MaxWithdraw = 1000 },
    carte_or      = { MaxDeposit = 3500, MaxWithdraw = 2000 },
    carte_dimas   = { MaxDeposit = 4500, MaxWithdraw = 2000 }
  }
 

-- PNJ banque centrale
Config.PNJ = {
    Enabled = true,
    Model = "s_m_m_banker_01",
    Coords = vector4(150.266, -1040.203, 29.374, 337.5),
}

-- Modèles ATM reconnus
Config.ATMModels = {
    "prop_atm_01",
    "prop_atm_02",
    "prop_atm_03",
    "prop_fleeca_atm",
}

-- Liste complète des blips de banques / ATM (modifiable)
Config.Blips = {
    { label = "Banque Centrale", pos = vector3(150.266, -1040.203, 29.374), sprite = 108, color = 2, scale = 0.8 },
    { label = "Banque Vinewood", pos = vector3(247.49, 223.15, 106.29), sprite = 108, color = 2, scale = 0.8 },
    { label = "Banque Legion Square", pos = vector3(314.18, -278.62, 54.17), sprite = 108, color = 2, scale = 0.8 },
    { label = "Banque Sandy Shores", pos = vector3(1175.02, 2706.64, 38.09), sprite = 108, color = 2, scale = 0.8 },
    { label = "Banque Paleto Bay", pos = vector3(-112.20, 6469.29, 31.63), sprite = 108, color = 2, scale = 0.8 },
    -- quelques ATM d'exemple
    { label = "ATM", pos = vector3(-386.733, 6045.953, 31.501), sprite = 277, color = 3, scale = 0.6 },
    { label = "ATM", pos = vector3(1171.977, 2702.328, 38.175), sprite = 277, color = 3, scale = 0.6 },
}

-- Option: restreindre l'utilisation aux joueurs possédant la carte (true recommandé)
Config.RequireCard = true

-- Nom de la table / champs (si besoin d'adapter)
Config.DB = {
  banking_table = "banking",
  bank_cards_table = "bank_cards",
  bank_logs_table = "bank_logs"
}
