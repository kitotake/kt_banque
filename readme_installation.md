# 🏦 KT Banque v7.4.1 — Système Bancaire FiveM

Système bancaire complet pour FiveM avec interface NUI React, gestion des cartes, limites journalières et transferts sécurisés.

---

## 📋 Prérequis

| Ressource      | Usage                         |
|---------------|-------------------------------|
| `oxmysql`     | Requêtes SQL asynchrones      |
| `kt_lib`      | Librairie partagée Kitotake   |
| `kt_inventory`| Gestion des items (cartes)    |
| `union`       | Framework de personnages      |

---

## 🚀 Installation

### 1. Base de données

```sql
-- Exécuter une seule fois
source bank.sql
```

### 2. Items kt_inventory

Dans `kt_inventory/data/items.lua`, ajoutez :

```lua
["bank_card"]         = { label = "Carte Bancaire Basique",  weight = 10 },
["bank_gold_card"]    = { label = "Carte Bancaire Or",        weight = 10 },
["bank_diamond_card"] = { label = "Carte Bancaire Diamant",   weight = 10 },
```

### 3. Images

Placez dans `kt_inventory/web/images/` :
- `bank_card.png`
- `bank_gold_card.png`
- `bank_diamond_card.png`

### 4. server.cfg

```cfg
ensure kt_lib
ensure kt_inventory
ensure kt_banque
```

---

## ⚙️ Configuration (`config.lua`)

### Limites de cartes

```lua
Config.CardLimits = {
    carte_basique = { MaxDeposit = 5000,  MaxWithdraw = 5000,  Price = 0     },
    carte_or      = { MaxDeposit = 15000, MaxWithdraw = 10000, Price = 15000 },
    carte_dimas   = { MaxDeposit = 50000, MaxWithdraw = 25000, Price = 50000 },
}
```

Les limites sont **journalières** et se réinitialisent automatiquement à minuit.

### Options

```lua
Config.RequireCard = true    -- Carte requise pour accéder au menu
Config.Debug       = false   -- Active les logs et la commande /ktbank_open (admin)
Config.SpamDelay   = 1500    -- Délai anti-spam entre deux opérations (ms)
```

---

## 🎮 Utilisation

### Joueurs

1. **Ouvrir un compte** : approchez-vous du PNJ "Ouvrir un compte" (touche `E`)  
2. **Choisissez un PIN** à 4 chiffres lors de la création  
3. **Utiliser un ATM** : approchez-vous d'un distributeur (touche `E`)  
4. **Améliorer votre carte** : parlez au PNJ "Améliorer carte"

### Raccourcis

| Touche | Action                  |
|--------|-------------------------|
| `E`    | Interagir ATM / PNJ     |
| `ESC`  | Fermer l'interface      |

### Commandes admin (Debug uniquement)

```
/ktbank_open   — Ouvre le menu (ACE permission requis)
```

---

## 🔧 Exports serveur

```lua
-- Solde d'un compte
local balance = exports['kt_banque']:GetAccountBalance(uniqueId)

-- Informations complètes
local info = exports['kt_banque']:GetAccountInfo(uniqueId)
-- Retourne : { id, account_number, iban, balance, status, label }

-- Ajouter de l'argent (admin)
local ok = exports['kt_banque']:AddMoney(uniqueId, montant)

-- Retirer de l'argent (admin)
local ok = exports['kt_banque']:RemoveMoney(uniqueId, montant)

-- Virement entre deux comptes (API)
local ok, msg = exports['kt_banque']:Transfer(fromUniqueId, toUniqueId, montant)
```

---

## 🔒 Sécurité

- Le PIN n'est **jamais** envoyé en clair sur le réseau — seul son hash transite
- La vérification du PIN se fait **côté serveur** uniquement
- Anti-spam configurable (`Config.SpamDelay`)
- Validation de tous les montants côté serveur (positif, entier)
- Limites journalières enforced côté serveur

---

## 📊 Schéma base de données

| Table                | Contenu                               |
|---------------------|---------------------------------------|
| `bank_accounts`     | Comptes bancaires                     |
| `bank_cards`        | Cartes (PIN hashé, type, expiration)  |
| `bank_transactions` | Historique complet des opérations     |
| `bank_limits`       | Limites journalières par compte       |
| `bank_logs`         | Logs admin                            |

---

## 🐛 Dépannage

| Symptôme | Solution |
|----------|----------|
| L'interface ne s'ouvre pas | Vérifiez que `kt_lib` démarre avant `kt_banque` |
| "Aucune carte" alors que vous en avez une | Vérifiez les noms d'items dans `Config.BankCardItem` |
| Solde incorrect après opération | Vérifiez les logs MySQL avec `Config.Debug = true` |
| PIN refusé | Le hash doit être identique dans `server/main.lua` et `web/src/utils/index.ts` |
| Le PNJ ne spawn pas | Vérifiez les coordonnées `Config.PNJ.Coords` en jeu |

---

## 📝 Changelog

### v7.4.1 (correctif)
- ✅ Deposit / Withdraw / Transfer implémentés côté serveur (manquants en v7.4)
- ✅ PIN hashé — jamais transmis en clair
- ✅ Événements NUI alignés entre client et serveur (`openBank`, `openCreate`)
- ✅ PNJ2 ouvre le formulaire NUI (plus de PIN `1234` hardcodé)
- ✅ `useRef` inutilisé supprimé du Dashboard
- ✅ Dépendances `useCallback` corrigées dans PinPage
- ✅ Limites journalières utilisées et vérifiées
- ✅ Guard null sur `accountData` dans DashboardPage
- ✅ Timeout 8s sur les requêtes NUI
- ✅ `fxmanifest.lua` nettoyé (virgule superflue supprimée)
- ✅ Fichier de config unifié (suppression de `shared/config.lua`)
- ✅ Exports `GetAccountInfo` et `Transfer` ajoutés

### v7.4.0
- Intégration complète kt_lib / kt_inventory
- Interface NUI React/TypeScript
- Système de cartes et limites
- Historique des transactions

---

## 📄 Licence

Tous droits réservés — Kitotake Development
