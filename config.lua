Config = {}

-- Items ox_inventory pour les différents types de cartes
Config.BankCardItem = {
    carte_basique = "bank_card",
    carte_or = "bank_or",
    carte_dimas = "bank_dimas"
}

-- Limites par type de carte
Config.CardLimits = {
    carte_basique = { 
        MaxDeposit = 2500, 
        MaxWithdraw = 1000,
        Price = 50 
    },
    carte_or = { 
        MaxDeposit = 4500, 
        MaxWithdraw = 3000,
        Price = 12500 
    },
    carte_dimas = { 
        MaxDeposit = 5500, 
        MaxWithdraw = 4500,
        Price = 45000 
    }
}

-- Configuration du PNJ banquier
Config.PNJ = {
    Enabled = true,
    Model = "cs_bankman",
    Coords = vec3(254.04, 222.72, 104.25), -- vec3 uniquement
    Heading = 147.0,                        -- angle séparé
    Frozen = true,
    Invincible = true,
    Scenario = ""      -- scénario valide
}

Config.PNJ2 = {
    Enabled = true,
    Model = "cs_bankman",
    Coords = vec3(249.04, 224.72, 104.25), -- vec3 uniquement
    Heading = 147.0,
    Frozen = true,
    Invincible = true,
    Scenario = ""      -- scénario valide

}


-- Modèles ATM reconnus
Config.ATMModels = {
    `prop_atm_01`,
    `prop_atm_02`,
    `prop_atm_03`,
    `prop_fleeca_atm`
}

-- Distance d'interaction
Config.InteractionDistance = 4.0
Config.ATMDistance = 1.5

-- Liste des blips
Config.Blips = {
    { 
        label = "Banque Centrale", 
        pos = vector3(150.266, -1040.203, 29.374), 
        sprite = 108, 
        color = 2, 
        scale = 0.8 
    },
    { 
        label = "Banque Vinewood", 
        pos = vector3(247.49, 223.15, 106.29), 
        sprite = 108, 
        color = 5, 
        scale = 0.8 
    },
    { 
        label = "Banque Legion Square", 
        pos = vector3(314.18, -278.62, 54.17), 
        sprite = 108, 
        color = 2, 
        scale = 0.8 
    },
    { 
        label = "Banque Sandy Shores", 
        pos = vector3(1175.02, 2706.64, 38.09), 
        sprite = 108, 
        color = 2, 
        scale = 0.8 
    },
    { 
        label = "Banque Paleto Bay", 
        pos = vector3(-112.20, 6469.29, 31.63), 
        sprite = 108, 
        color = 2, 
        scale = 0.8 
    }
}

-- Configuration base de données
Config.DB = {
    banking_table = "banking",
    bank_cards_table = "bank_cards",
    bank_logs_table = "bank_logs"
}

-- Nécessite d'avoir la carte pour utiliser le système
Config.RequireCard = true

-- Délai anti-spam (en millisecondes)
Config.SpamDelay = 1000

-- Messages de notification
Config.Notifications = {
    no_card = "Aucune carte bancaire trouvée dans votre inventaire",
    card_created = "Compte créé avec succès ! Carte ajoutée à votre inventaire",
    invalid_pin = "Code PIN invalide (4 chiffres requis)",
    incorrect_pin = "Code PIN incorrect",
    deposit_success = "Dépôt de $%s effectué avec succès",
    withdraw_success = "Retrait de $%s effectué avec succès",
    transfer_success = "Transfert de $%s effectué avec succès",
    insufficient_balance = "Solde insuffisant sur votre compte",
    insufficient_cash = "Argent liquide insuffisant",
    limit_exceeded = "Limite dépassée pour votre type de carte",
    target_not_found = "Compte destinataire introuvable",
    error = "Une erreur est survenue"
}