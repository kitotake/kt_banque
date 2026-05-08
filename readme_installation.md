# 🏦 KT Banque v7.5.0 — Guide d'installation

Système bancaire FiveM entièrement refactorisé en modules, avec kt_inventory, commandes admin et traçabilité complète.

---

## 📁 Structure des fichiers

```
kt_banque/
├── fxmanifest.lua
├── bank.sql
├── shared/
│   ├── config/config.lua        ← configuration globale
│   └── locales/fr.lua           ← messages
├── server/
│   ├── main.lua                 ← enregistrement des événements réseau
│   ├── admin.lua                ← commandes admin + exports API
│   └── modules/
│       ├── utils.lua            ← générateurs, hash PIN, wrappers Union & kt_inventory
│       ├── db.lua               ← toutes les requêtes SQL (DAL)
│       ├── bank.lua             ← logique métier (dépôt, retrait, virement, carte)
│       └── card_recovery.lua    ← récupération de carte bloquée
└── client/
    ├── main.lua                 ← nettoyage à l'arrêt
    └── modules/
        ├── animation.lua        ← animation ATM
        ├── ui.lua               ← NUI + callbacks + événements serveur→client
        ├── atm.lua              ← détection proximité distributeurs
        ├── npc.lua              ← détection proximité PNJ
        └── card_recovery.lua    ← UI récupération de carte
```

---

## 📋 Prérequis

| Ressource      | Rôle                              |
|---------------|-----------------------------------|
| `oxmysql`     | Requêtes SQL asynchrones          |
| `kt_lib`      | Notifications, TextUI             |
| `kt_inventory`| Gestion des items (cartes, cash)  |
| `union`       | Framework de personnages          |

---

## 🚀 Installation

### 1. Base de données
```sql
source bank.sql
```

### 2. Items kt_inventory

Dans la config d'kt_inventory, ajoutez :

```lua
['bank_card']         = { label = 'Carte Bancaire Basique', weight = 10, stack = false },
['bank_gold_card']    = { label = 'Carte Bancaire Or',      weight = 10, stack = false },
['bank_diamond_card'] = { label = 'Carte Bancaire Diamant', weight = 10, stack = false },
['bank_receipt']      = { label = 'Reçu bancaire',          weight = 1,  stack = true  },
['money']             = { label = 'Argent liquide',         weight = 0,  stack = true  },
```

> `money` est l'item cash standard d'kt_inventory. Si votre serveur utilise un nom différent, adaptez `KtInv.GetMoney / AddMoney / RemoveMoney` dans `server/modules/utils.lua`.

### 3. Images

Placez dans le dossier images d'kt_inventory :
- `bank_card.png`
- `bank_gold_card.png`
- `bank_diamond_card.png`
- `bank_receipt.png`

### 4. server.cfg
```cfg
ensure oxmysql
ensure kt_lib
ensure kt_inventory
ensure union
ensure kt_banque
```

---

## ⚙️ Configuration

Tout se passe dans `shared/config/config.lua`.

### Limites journalières par carte
```lua
Config.CardLimits = {
    card_basic   = { MaxDeposit = 1500,  MaxWithdraw = 7500,  Price = 250   },
    card_gold    = { MaxDeposit = 5500,  MaxWithdraw = 17500, Price = 15000 },
    card_diamond = { MaxDeposit = 50000, MaxWithdraw = 25000, Price = 35000 },
}
```

### Reçus d'inventaire
```lua
Config.Inventory = {
    GiveReceipt  = true,          -- false pour désactiver
    ReceiptItem  = "bank_receipt",
    ReceiptCount = 1
}
```

### Permission admin
```lua
Config.AdminAce = "group.admin"   -- ace FiveM standard
```

---

## 🎮 Commandes admin (console ou joueur avec ACE)

| Commande | Description |
|---|---|
| `/bank_status <uid> <active\|suspended\|closed>` | Activer / suspendre / fermer un compte |
| `/bank_addmoney <uid> <montant>` | Créditer un compte |
| `/bank_removemoney <uid> <montant>` | Débiter un compte |
| `/bank_info <uid>` | Afficher les infos d'un compte |
| `/bank_total` | Somme globale de tous les comptes actifs |
| `/bank_logs <uid> [limit]` | Historique des actions admin (console serveur) |

---

## 🔧 Exports serveur

```lua
-- Solde (nil si inexistant)
local balance = exports['kt_banque']:GetAccountBalance(uniqueId)

-- Infos complètes (nil si inexistant, statut quelconque)
local info = exports['kt_banque']:GetAccountInfo(uniqueId)

-- Somme globale de tous les comptes actifs
local total = exports['kt_banque']:GetAllAccountsTotal()

-- Changer le statut (retourne true/false, message)
local ok, msg = exports['kt_banque']:SetAccountStatus(uniqueId, "suspended")

-- Créditer (retourne bool)
local ok = exports['kt_banque']:AddMoney(uniqueId, 5000)

-- Débiter (retourne bool)
local ok = exports['kt_banque']:RemoveMoney(uniqueId, 1000)

-- Virement API (retourne bool, message)
local ok, msg = exports['kt_banque']:Transfer(fromUid, toUid, 2500)
```

---

## 🗄️ Intégration kt_inventory

La connexion argent ↔ banque passe par l'item `money` d'kt_inventory :

- **Dépôt** : `kt_inventory:RemoveItem(src, "money", amount)` → crédit en base
- **Retrait** : crédit en base → `kt_inventory:AddItem(src, "money", amount)`
- **Reçu** : chaque opération ajoute un item `bank_receipt` avec les métadonnées (label, date)

Si vous préférez un système de cash séparé (ex. `GetPlayerMoney` d'un framework), remplacez les fonctions dans `OxInv.GetMoney / AddMoney / RemoveMoney` dans `server/modules/utils.lua` sans toucher au reste.

---

## 🔒 Sécurité & traçabilité

- PIN hashé (SHA-like maison) — jamais transmis en clair
- Vérification PIN **côté serveur uniquement**
- Anti-spam configurable (`Config.SpamDelay`)
- Tous les montants validés côté serveur (entier positif)
- Limites journalières enforced en base (réinitialisation automatique à minuit)
- **Chaque action admin** est tracée dans `bank_logs` avec la source
- Réactivation de carte en deux temps (débit + UPDATE conditionnel `WHERE active = 0`) pour éviter le double-clic

---

## 📊 Schéma base de données

| Table | Contenu |
|---|---|
| `bank_accounts` | Comptes (solde, statut, IBAN…) |
| `bank_cards` | Cartes (PIN hashé, type, expiration) |
| `bank_transactions` | Historique complet |
| `bank_limits` | Limites journalières par compte |
| `bank_logs` | Journal admin |

---

## 🐛 Dépannage

| Symptôme | Solution |
|---|---|
| Interface ne s'ouvre pas | Vérifiez que `kt_lib` démarre avant `kt_banque` |
| "Aucune carte" alors que vous en avez une | Vérifiez les noms d'items dans `Config.BankCardItem` |
| Cash non débité/crédité | Vérifiez que l'item `money` existe dans kt_inventory |
| PIN refusé | Hash doit être identique dans `utils.lua` et `web/src/utils/index.ts` |
| PNJ invisible | Vérifiez les coordonnées `Config.PNJ.Coords` |
| Commande admin refusée | Vérifiez que le joueur a l'ACE `group.admin` |

---

## 📝 Changelog

### v7.5.0
- ✅ Refactorisation complète en modules (utils / db / bank / admin)
- ✅ Migration kt_inventory → kt_inventory (cash via item `money`)
- ✅ Reçus de transaction dans l'inventaire du joueur
- ✅ Couche DAL (`db.lua`) : toutes les requêtes SQL isolées
- ✅ Commandes admin avec traçabilité complète
- ✅ Export `GetAllAccountsTotal` et `SetAccountStatus`
- ✅ `DB.GetAccountAny` pour les admins (ignore le statut)
- ✅ `DB.ReactivateCard` avec UPDATE conditionnel anti double-exécution
- ✅ Modules client séparés (animation / ui / atm / npc / card_recovery)
- ✅ `fxmanifest.lua` mis à jour (kt_lib, kt_inventory, ordre de chargement)

### v7.4.1
- Deposit / Withdraw / Transfer implémentés côté serveur
- PIN hashé, jamais transmis en clair
- Limites journalières enforced

---

## 📄 Licence
Tous droits réservés — Kitotake Development
