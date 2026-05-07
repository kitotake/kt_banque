# 🏦 KT Banque - Système Bancaire Complet

Système bancaire moderne pour FiveM avec support kt_lib et kt_inventory.

## 📋 Prérequis

- ✅ union
- ✅ oxmysql
- ✅ kt_lib
- ✅ kt_inventory

## 🚀 Installation

### 1️⃣ Base de Données

Exécutez le fichier SQL dans votre base de données:
```bash
banking_schema.sql
```

### 2️⃣ Items kt_inventory

Ajoutez les items dans `kt_inventory/data/items.lua`:
```lua
-- Copiez le contenu de kt_inventory_items.lua
```

### 3️⃣ Images des Cartes

Placez les images suivantes dans `kt_inventory/web/images/`:
- `bank_card.png` - Carte basique
- `bank_gold_card.png` - Carte or
- `bank_diamond_card.png` - Carte diamant

### 4️⃣ Ressource

1. Placez le dossier `kt_banque` dans votre dossier `resources/`
2. Ajoutez dans votre `server.cfg`:
```cfg
ensure kt_lib
ensure kt_inventory
ensure kt_banque
```

## ⚙️ Configuration

Éditez `config.lua` pour personnaliser:

### Types de Cartes
```lua
Config.CardLimits = {
    carte_basique = { 
        MaxDeposit = 2500,    -- Dépôt maximum
        MaxWithdraw = 1000,   -- Retrait maximum
        Price = 50            -- Prix de la carte
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
```

### PNJ Banquier
```lua
Config.PNJ = {
    Enabled = true,
    Model = "cs_bankman",
    Coords = vec3(254.04, 222.72, 104.25),
    Heading = 147.0
}
```

### Options
```lua
Config.RequireCard = true       -- Nécessite une carte pour utiliser le système
Config.Debug = false            -- Mode debug (logs détaillés)
Config.SpamDelay = 1000        -- Délai anti-spam en ms
```

## 🎮 Utilisation

### Pour les Joueurs

1. **Créer un compte**: Rendez-vous au PNJ "Création de compte" dans une banque
2. **Acheter une carte améliorée**: Parlez au PNJ "Achat de carte"
3. **Utiliser un ATM**: Approchez-vous d'un distributeur automatique et appuyez sur `E`

### Commandes

- `/bankmenu` - Ouvrir le menu bancaire avancé (optionnel)

### Raccourcis Clavier

- `E` - Interagir avec ATM ou PNJ
- `ESC` - Fermer l'interface

## 🔧 Exports Serveur

### Récupérer les informations d'un compte
```lua
local accountInfo = exports['kt_banque']:GetAccountInfo(accountId)
```

### Récupérer le solde
```lua
local balance = exports['kt_banque']:GetAccountBalance(accountId)
```

### Ajouter de l'argent
```lua
exports['kt_banque']:AddMoney(accountId, amount)
```

### Retirer de l'argent
```lua
local success = exports['kt_banque']:RemoveMoney(accountId, amount)
```

### Transférer entre comptes
```lua
local success, message = exports['kt_banque']:Transfer(fromAccountId, toAccountId, amount)
```

### Statistiques du compte
```lua
local stats = exports['kt_banque']:GetStats(accountId)
-- Retourne: total_deposits, total_withdraws, total_transfers_out, total_transfers_in, transaction_count, current_balance
```

### Exports Admin
```lua
-- Désactiver une carte
exports['kt_banque']:AdminDeactivateCard(identifier)

-- Réimprimer le PIN
exports['kt_banque']:AdminReprintPin(identifier)

-- Créer une carte pour un joueur
exports['kt_banque']:AdminCreateCardForPlayer(identifier, cardType, pin)

-- Obtenir les infos d'un compte
exports['kt_banque']:AdminGetAccountInfo(identifier)

-- Définir le solde
exports['kt_banque']:AdminSetBalance(accountId, amount)
```

## 📊 Structure de la Base de Données

### Table `banking`
- Stocke les comptes bancaires
- Champs: account_id, identifier, balance, owner_name, label

### Table `bank_cards`
- Stocke les cartes bancaires
- Champs: id, identifier, account_id, card_number, pin, card_type, active

### Table `bank_logs`
- Historique des transactions
- Champs: id, account_id, action, amount, identifier, description, date

## 🎨 Interface

- Design moderne et responsive
- Animations fluides
- Support mobile
- Thème sombre élégant
- Effets visuels immersifs

## 🐛 Dépannage

### Le NUI ne s'ouvre pas
1. Vérifiez que `kt_lib` est bien démarré avant `kt_banque`
2. Vérifiez la console F8 pour les erreurs JavaScript
3. Activez le mode debug: `Config.Debug = true`

### Les cartes n'apparaissent pas dans l'inventaire
1. Vérifiez que les items sont bien ajoutés dans kt_inventory
2. Redémarrez kt_inventory après avoir ajouté les items
3. Vérifiez les noms des items dans `Config.BankCardItem`

### Les PNJ ne spawn pas
1. Vérifiez les coordonnées dans `Config.PNJ` et `Config.PNJ2`
2. Vérifiez que le modèle existe: `cs_bankman`
3. Consultez la console serveur pour les messages d'erreur

### Erreurs SQL
1. Vérifiez que toutes les tables sont créées
2. Vérifiez les permissions MySQL
3. Utilisez oxmysql récent

## 📝 Changelog

faut debug les pages web pour voir les erreurs acheta des carte pas possible

### Version 6.5.0
- ✅ Intégration complète kt_lib
- ✅ Support kt_inventory
- ✅ Système de cartes améliorées
- ✅ Interface NUI moderne
- ✅ Système de logs détaillé
- ✅ Exports pour développeurs
- ✅ Animations ATM

## 💡 Support

Pour toute question ou problème:
1. Vérifiez ce README
2. Consultez les logs serveur/client
3. Activez le mode debug

## 📄 Licence

Tous droits réservés - Kitotake Development

---