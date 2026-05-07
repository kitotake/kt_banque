Config = {}

-- ==================== CONFIGURATION GÉNÉRALE ====================
Config.Debug      = false
Config.RequireCard = true
Config.SpamDelay  = 1000  -- ms entre deux actions (anti-spam)

-- ==================== ITEMS & TYPES DE CARTES ====================
-- Clés internes : card_basic / card_gold / card_diamond
-- Valeurs       : nom de l'item dans kt_inventory
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
    {
        label  = "Banque Centrale",
        pos    = vector3(150.266, -1040.203, 29.374),
        sprite = 108,
        color  = 2,
        scale  = 0.8
    },
    {
        label  = "Banque Pacific Standard",
        pos    = vector3(247.49, 223.15, 106.29),
        sprite = 108,
        color  = 2,
        scale  = 0.8
    },
    {
        label  = "Banque Legion Square",
        pos    = vector3(314.18, -278.62, 54.17),
        sprite = 108,
        color  = 2,
        scale  = 0.8
    }
}

-- ==================== ANIMATIONS ====================
Config.Animations = {
    enabled = true,
    dict    = "amb@prop_human_atm@male@enter",
    anim    = "enter",
    flag    = 1
}

-- ==================== MESSAGES ====================
Config.Lang = {
    -- Succès
    account_created  = "✅ Compte bancaire créé avec succès !",
    deposit_success  = "✅ Dépôt de $%s effectué",
    withdraw_success = "✅ Retrait de $%s effectué",
    transfer_success = "✅ Transfert de $%s effectué",
    card_upgraded    = "✅ Carte améliorée avec succès !",

    -- Erreurs
    no_card              = "❌ Aucune carte bancaire dans votre inventaire",
    no_account           = "❌ Vous n'avez pas de compte bancaire",
    account_exists       = "⚠️ Vous avez déjà un compte bancaire",
    invalid_pin          = "❌ Le PIN doit contenir 4 chiffres",
    incorrect_pin        = "❌ Code PIN incorrect",
    insufficient_balance = "❌ Solde insuffisant",
    insufficient_cash    = "❌ Argent liquide insuffisant",
    limit_exceeded       = "❌ Limite journalière dépassée pour votre carte",
    target_not_found     = "❌ Compte destinataire introuvable",
    same_account         = "❌ Vous ne pouvez pas vous transférer à vous-même",
    invalid_amount       = "❌ Montant invalide",
    spam                 = "⏳ Veuillez patienter",
    card_inactive        = "❌ Votre carte bancaire est désactivée",

    -- Interactions
    press_to_use_atm        = "Appuyez sur ~INPUT_CONTEXT~ pour utiliser l'ATM",
    press_to_create_account = "Appuyez sur ~INPUT_CONTEXT~ pour ouvrir un compte",
    press_to_upgrade_card   = "Appuyez sur ~INPUT_CONTEXT~ pour améliorer votre carte"
}

if Config.Debug then
    print('^3[KT Banque]^7 Mode DEBUG activé')
end
print('^2[KT Banque]^7 Configuration chargée (v7.4.1)')
