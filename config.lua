Config = {}

-- ==================== CONFIGURATION GÉNÉRALE ====================
Config.Debug = false
Config.RequireCard = true
Config.SpamDelay = 1000

-- ==================== ITEMS & TYPES DE CARTES ====================
Config.BankCardItem = {
    carte_basique = "bank_card",
    carte_or = "bank_gold_card",
    carte_dimas = "bank_diamond_card"
}

Config.CardLimits = {
    carte_basique = { 
        MaxDeposit = 5000, 
        MaxWithdraw = 20000,
        Price = 0,  -- Gratuite à la création
        DisplayName = "Carte Basique"
    },
    carte_or = { 
        MaxDeposit = 10000, 
        MaxWithdraw = 5000,
        Price = 15000,
        DisplayName = "Carte Or"
    },
    carte_dimas = { 
        MaxDeposit = 50000, 
        MaxWithdraw = 25000,
        Price = 50000,
        DisplayName = "Carte Diamant"
    }
}

-- ==================== BASE DE DONNÉES ====================
Config.DB = {
    banking_table = "banking",
    bank_cards_table = "bank_cards",
    bank_logs_table = "bank_logs"
}

-- ==================== PNJ BANQUIERS ====================
Config.PNJ = {
    Enabled = true,
    Model = "cs_bankman",
    Coords = vector3(242.90, 222.07, 106.28),
    Heading = 340.0,
    Frozen = true,
    Invincible = true,
    Scenario = "WORLD_HUMAN_CLIPBOARD"
}

Config.PNJ2 = {
    Enabled = true,
    Model = "cs_bankman",
    Coords = vector3(251.90, 219.07, 106.28),
    Heading = 250.0,
    Frozen = true,
    Invincible = true,
    Scenario = "WORLD_HUMAN_STAND_IMPATIENT"
}

-- ==================== ATM ====================
Config.ATMModels = {
    `prop_atm_01`,
    `prop_atm_02`,
    `prop_atm_03`,
    `prop_fleeca_atm`
}

Config.InteractionDistance = 2.5
Config.ATMDistance = 1.5

-- ==================== BLIPS ====================
Config.Blips = {
    {
        label = "Banque Centrale",
        pos = vector3(150.266, -1040.203, 29.374),
        sprite = 108,
        color = 2,
        scale = 0.8
    },
    {
        label = "Banque Pacific Standard",
        pos = vector3(247.49, 223.15, 106.29),
        sprite = 108,
        color = 2,
        scale = 0.8
    },
    {
        label = "Banque Legion Square",
        pos = vector3(314.18, -278.62, 54.17),
        sprite = 108,
        color = 2,
        scale = 0.8
    }
}

-- ==================== ANIMATIONS ====================
Config.Animations = {
    enabled = true,
    dict = "amb@prop_human_atm@male@enter",
    anim = "enter",
    flag = 1
}

-- ==================== MESSAGES ====================
Config.Lang = {
    -- Succès
    account_created = "✅ Compte bancaire créé avec succès !",
    deposit_success = "✅ Dépôt de $%s effectué",
    withdraw_success = "✅ Retrait de $%s effectué",
    transfer_success = "✅ Transfert de $%s effectué",
    card_upgraded = "✅ Carte améliorée avec succès !",
    
    -- Erreurs
    no_card = "❌ Aucune carte bancaire dans votre inventaire",
    no_account = "❌ Vous n'avez pas de compte bancaire",
    account_exists = "⚠️ Vous avez déjà un compte bancaire",
    invalid_pin = "❌ Le PIN doit contenir 4 chiffres",
    incorrect_pin = "❌ Code PIN incorrect",
    insufficient_balance = "❌ Solde insuffisant",
    insufficient_cash = "❌ Argent liquide insuffisant",
    limit_exceeded = "❌ Limite dépassée pour votre carte",
    target_not_found = "❌ Compte destinataire introuvable",
    same_account = "❌ Vous ne pouvez pas transférer sur votre propre compte",
    invalid_amount = "❌ Montant invalide",
    
    -- Interactions
    press_to_use_atm = "Appuyez sur ~INPUT_CONTEXT~ pour utiliser le ATM",
    press_to_create_account = "Appuyez sur ~INPUT_CONTEXT~ pour ouvrir un compte",
    press_to_upgrade_card = "Appuyez sur ~INPUT_CONTEXT~ pour améliorer votre carte"
}

print('^2[KT Banque]^7 Configuration chargée')