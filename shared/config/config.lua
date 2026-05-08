-- ==================== KT BANQUE v7.5.0 — CONFIG ====================
Config = {}

-- ==================== GÉNÉRAL ====================
Config.Debug      = false
Config.RequireCard = true
Config.SpamDelay  = 1000   -- ms entre deux actions (anti-spam)

-- ==================== CARTES : COÛT DE REMPLACEMENT ====================
-- Coût pour remplacer une carte bloquée / volée
Config.CardReplaceCost = 500

-- ==================== ITEMS & TYPES DE CARTES ====================
Config.BankCardItem = {
    card_basic   = "bank_card",
    card_gold    = "bank_gold_card",
    card_diamond = "bank_diamond_card"
}

Config.CardLimits = {
    card_basic = {
        MaxDeposit  = 1500,
        MaxWithdraw = 7500,
        Price       = 250,
        DisplayName = "Carte Basique"
    },
    card_gold = {
        MaxDeposit  = 5500,
        MaxWithdraw = 17500,
        Price       = 15000,
        DisplayName = "Carte Or"
    },
    card_diamond = {
        MaxDeposit  = 50000,
        MaxWithdraw = 25000,
        Price       = 35000,
        DisplayName = "Carte Diamant"
    }
}

-- ==================== BASE DE DONNÉES ====================
Config.DB = {
    banking_table           = "bank_accounts",
    bank_cards_table        = "bank_cards",
    bank_limits_table       = "bank_limits",
    bank_transactions_table = "bank_transactions",
    bank_logs_table         = "bank_logs"
}

-- ==================== INVENTAIRE ====================
Config.Inventory = {
    GiveReceipt  = true,
    ReceiptItem  = "bank_receipt",
    ReceiptCount = 1
}

-- ==================== PNJ BANQUIERS ====================
Config.PNJ = {
    Enabled    = true,
    Model      = "cs_bankman",
    Coords     = vector3(242.90, 222.07, 106.28),
    Heading    = 340.0,
    Frozen     = true,
    Invincible = true,
    Scenario   = "WORLD_HUMAN_CLIPBOARD",
    Label      = "[E] Améliorer carte"
}

-- PNJ remplacement de carte (guichet)
Config.PNJ_Replace = {
    Enabled    = true,
    Model      = "cs_bankman",
    Coords     = vector3(255.00, 220.00, 106.28),
    Heading    = 250.0,
    Frozen     = true,
    Invincible = true,
    Scenario   = "WORLD_HUMAN_STAND_IMPATIENT",
    Label      = ("[E] Remplacer carte ($%d)"):format(500)
}

Config.PNJ2 = {
    Enabled    = true,
    Model      = "cs_bankman",
    Coords     = vector3(251.90, 219.07, 106.28),
    Heading    = 250.0,
    Frozen     = true,
    Invincible = true,
    Scenario   = "WORLD_HUMAN_STAND_IMPATIENT",
    Label      = "[E] Ouvrir un compte"
}

-- ==================== ATM ====================
Config.ATMModels = {
    `prop_atm_01`,
    `prop_atm_02`,
    `prop_atm_03`,
    `prop_fleeca_atm`
}

Config.InteractionDistance = 2.5
Config.ATMDistance         = 1.5

-- ==================== BLIPS ====================
Config.Blips = {
    { label = "Banque Centrale",         pos = vector3(150.266, -1040.203, 29.374), sprite = 108, color = 2, scale = 0.8 },
    { label = "Banque Pacific Standard", pos = vector3(247.49,  223.15,  106.29),  sprite = 108, color = 2, scale = 0.8 },
    { label = "Banque Legion Square",    pos = vector3(314.18,  -278.62,   54.17),  sprite = 108, color = 2, scale = 0.8 }
}

-- ==================== ANIMATIONS ====================
Config.Animations = {
    enabled = true,
    dict    = "amb@prop_human_atm@male@enter",
    anim    = "enter",
    flag    = 1
}

-- ==================== ADMIN ====================
Config.AdminAce = "group.admin"

if Config.Debug then print('^3[KT Banque]^7 Mode DEBUG activé') end
print('^2[KT Banque]^7 Configuration chargée (v7.5.0)')