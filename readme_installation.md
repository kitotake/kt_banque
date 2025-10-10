# 🏦 KT Banque - Système Bancaire Modulaire v6.0.0

## 📋 Corrections et Améliorations

### ✅ Problèmes Corrigés

#### 1. **Dépôt et Retrait (ox_inventory)**
- ❌ **Ancien code**: Utilisait `xPlayer.getMoney()` et `xPlayer.addMoney()` (ESX natif)
- ✅ **Nouveau code**: Utilise `BankUtils.getPlayerMoney()`, `BankUtils.removePlayerMoney()`, `BankUtils.addPlayerMoney()` (ox_inventory)
- **Impact**: Les transactions fonctionnent maintenant correctement avec ox_inventory

#### 2. **Architecture Modulaire**
- ✅ Code séparé en modules logiques (utils, logs, transactions, admin)
- ✅ Ordre de chargement optimisé dans fxmanifest
- ✅ Meilleure maintenabilité et débogage

#### 3. **Système de Rollback**
- ✅ Ajout d'un système de rollback sur les retraits en cas d'erreur d'inventaire
- ✅ Protection contre les pertes d'argent

#### 4. **Debug Mode**
- ✅ Ajout d'un système de debug configurable
- ✅ Logs détaillés pour faciliter le troubleshooting

---

## 📁 Structure des Fichiers

```
kt_banque/
├── 📄 fxmanifest.lua (CORRIGÉ)
├── 📄 config.lua (Amélioré)
├── 📄 bank.sql (Inchangé)
│
├── 📂 client/
│   ├── bank_utils.lua          (Utilitaires client + anti-spam)
│   ├── bank_notifications.lua  (Système de notifications)
│   ├── bank_animations.lua     (Animations ATM)
│   ├── bank_pnj.lua           (Spawn PNJ et blips)
│   ├── bank_atm_interaction.lua (Détection ATM)
│   ├── bank_ui.lua            (Interface NUI et callbacks)
│   └── bank_menu.lua          (Menus supplémentaires)
│
├── 📂 server/
│   ├── bank_utils.lua         (Utilitaires serveur + DB)
│   ├── bank_logs.lua          (Système de logs)
│   ├── bank_accounts.lua      (Création compte, achat carte)
│   ├── bank_transactions.lua  (Dépôt, retrait, transfert) ⚡ CORRIGÉ
│   └── bank_admin.lua         (Commandes admin)
│
└── 📂 web/
    ├── index.html
    ├── create.html
    ├── atm.html
    ├── style/
    └── js/
```

---

## 🔧 Installation

### 1. Sauvegarde
```bash
# Sauvegarder votre ancien système
cp -r kt_banque kt_banque_backup
```

### 2. Remplacer les fichiers
- Remplacez **tous** les fichiers par les nouveaux
- Gardez uniquement votre dossier `web/` si vous avez des customisations

### 3. Base de données
```sql
-- Exécuter si première installation
source bank.sql
```

### 4. Configuration
Éditez `config.lua` selon vos besoins:
```lua
-- Activer le mode debug pour tester
Config.Debug = true

-- Coordonnées des PNJ
Config.PNJ.Coords = vec3(254.04, 222.72, 104.25)
Config.PNJ2.Coords = vec3(249.04, 224.72, 104.25)
```

### 5. Redémarrage
```bash
ensure kt_banque
```

---

## 🎯 Principales Modifications

### 🔹 server/bank_utils.lua
```lua
-- AVANT (Ne marchait pas avec ox_inventory)
local playerMoney = xPlayer.getMoney()
xPlayer.removeMoney(amount)
xPlayer.addMoney(amount)

-- APRÈS (Corrigé pour ox_inventory)
local playerMoney = BankUtils.getPlayerMoney(src)
BankUtils.removePlayerMoney(src, amount)
BankUtils.addPlayerMoney(src, amount)
```

### 🔹 server/bank_transactions.lua
```lua
-- AJOUT: Vérification et logs détaillés
print(("^6[INFO]^7 Argent du joueur: $%s | Montant demandé: $%s"):format(playerMoney, amount))

-- AJOUT: Système de rollback
local added = BankUtils.addPlayerMoney(src, amount)
if not added then
    -- ROLLBACK: remettre l'argent sur le compte
    local rollbackQuery = string.format("UPDATE %s SET balance = balance + ? WHERE ID = ?", DB.banking_table)
    BankUtils.dbExecute(rollbackQuery, {amount, cardRow.account_id})
    -- ...
end
```

---

## 🧪 Tests à Effectuer

### Test 1: Dépôt
1. Avoir de l'argent liquide sur soi
2. Aller à un ATM
3. Tenter un dépôt
4. ✅ L'argent doit être retiré de l'inventaire et ajouté au compte

### Test 2: Retrait
1. Avoir de l'argent sur le compte bancaire
2. Aller à un ATM
3. Tenter un retrait
4. ✅ L'argent doit être retiré du compte et ajouté à l'inventaire

### Test 3: Création de compte
1. Aller au PNJ2 (Création de compte)
2. Créer un compte avec un PIN à 4 chiffres
3. ✅ Le compte doit être créé avec une carte pending

### Test 4: Achat de carte
1. Avoir un compte sans carte
2. Aller au PNJ1 (Achat carte)
3. Choisir un type de carte
4. ✅ La carte doit apparaître dans l'inventaire

---

## 🐛 Debug

### Activer le mode debug
```lua
-- Dans config.lua
Config.Debug = true
```

### Vérifier les logs
```bash
# Console serveur
[BANK DEBUG] Dépôt: $500
[INFO] Argent du joueur: $1000 | Montant demandé: $500
[SUCCÈS] Dépôt de $500 effectué

# Console F8 (client)
[BANK CLIENT DEBUG] Animation ATM lancée
[BANK CLIENT DEBUG] Interface bancaire ouverte
```

### Commandes Admin Utiles
```bash
/bank:info [ID]          # Voir infos compte
/bank:repair [ID]        # Réparer compte (créer carte pending)
/bank:givecard [ID] [type] # Donner une carte
```

---

## 📊 Commandes Admin

| Commande | Description | Exemple |
|----------|-------------|---------|
| `/bank:info [ID]` | Affiche les infos du compte d'un joueur | `/bank:info 1` |
| `/bank:repair [ID]` | Crée une carte pending pour un compte | `/bank:repair 1` |
| `/bank:givecard [ID] [type]` | Donne une carte à un joueur | `/bank:givecard 1 carte_or` |

**Types de carte disponibles**: `carte_basique`, `carte_or`, `carte_dimas`

---

## ⚙️ Configuration Avancée

### Animations
```lua
Config.Animations = {
    enabled = true,
    dict = "amb@prop_human_atm@male@enter",
    anim = "enter",
    flag = 1
}
```

### Limites par carte
```lua
Config.CardLimits = {
    carte_basique = { 
        MaxDeposit = 2500, 
        MaxWithdraw = 1000,
        Price = 50 
    },
    -- ...
}
```

---

## 🆘 Support

### Problèmes courants

#### "Argent liquide insuffisant" alors que j'ai de l'argent
**Solution**: Vérifiez que vous utilisez bien ox_inventory et que l'item `money` existe

#### Les PNJ n'apparaissent pas
**Solution**: Vérifiez les coordonnées dans config.lua et relancez le script

#### L'interface ne s'ouvre pas
**Solution**: 
1. Vérifiez que vous avez une carte dans l'inventaire
2. Activez le debug mode
3. Regardez les logs console

#### Erreur de rollback lors des retraits
**Solution**: Votre inventaire est peut-être plein. Libérez de l'espace ou réduisez la quantité demandée.