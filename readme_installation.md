# 📁 Structure Complète - KT Banque

## 🗂️ Arborescence du Projet

```
kt_banque/
├── 📄 fxmanifest.lua
├── ⚙️ config.lua
├── 🗄️ bank.sql
│
├── 📂 client/
│   └── 💻 bank.lua
│
├── 📂 server/
│   └── 🖥️ bank.lua
│
└── 📂 nui/
    ├── 📄 index.html (PAGE PRINCIPALE - Point d'entrée unique)
    │
    ├── 📂 style/
    │   ├── 🎨 main.css (Styles globaux + gestion affichage)
    │   ├── 🎨 pin.css (Styles écran PIN)
    │   ├── 🎨 account.css (Styles compte bancaire)
    │   └── 🎨 create.css (Styles création compte)
    │
    └── 📂 js/
        ├── ⚡ main.js (Gestionnaire principal + routing pages)
        ├── ⚡ pin.js (Logique écran PIN)
        ├── ⚡ account.js (Logique opérations bancaires)
        └── ⚡ create.js (Logique création compte)
```

## 📝 Description des Fichiers

### 🔧 Fichiers de Configuration

- **fxmanifest.lua** : Manifeste de la ressource FiveM
- **config.lua** : Configuration (limites, positions, blips)
- **bank.sql** : Structure de base de données

### 💻 Fichiers Client (Lua)

- **client/bank.lua** : 
  - Gestion des blips
  - Spawn du PNJ banquier
  - Détection ATM
  - Communication avec NUI
  - Callbacks NUI

### 🖥️ Fichiers Serveur (Lua)

- **server/bank.lua** :
  - Gestion des comptes bancaires
  - Transactions (dépôt, retrait, transfert)
  - Validation sécurisée
  - Commandes admin
  - Exports pour autres ressources

### 🌐 Interface Web (NUI)

#### HTML
- **index.html** : Page unique contenant toutes les interfaces
  - Page PIN (`#pin-page`)
  - Page Création (`#create-page`)
  - Page Compte (`#account-page`)
  - Page ATM (`#atm-page`)

#### CSS
- **main.css** : 
  - Reset & variables CSS
  - Gestion `display: none` par défaut ✅
  - Styles génériques (boutons, inputs)
  - Layout responsive
  - Animations

- **pin.css** : Styles spécifiques écran PIN
- **account.css** : Styles dashboard bancaire
- **create.css** : Styles création de compte

#### JavaScript
- **main.js** (PRINCIPAL) :
  - ✅ Gestion affichage UI (`setUIVisible`)
  - ✅ Routing entre pages (`openPage`)
  - ✅ Réception messages NUI
  - ✅ Utilitaires (formatage, etc.)
  - ✅ Export global `window.KTBanque`

- **pin.js** : Validation PIN
- **account.js** : Opérations bancaires
- **create.js** : Création compte avec validation

## 🔄 Flux d'Utilisation

### 1️⃣ Joueur approche du banquier
```
Client Lua → Détection proximité
          → Menu ox_lib (choix carte)
          → Event serveur "createAccount"
```

### 2️⃣ Joueur utilise un ATM
```
Client Lua → Détection ATM
          → Event serveur "requestOpen"
          → Serveur vérifie carte
          → Event client "openNUI"
          → NUI affiche interface
```

### 3️⃣ Interface NUI s'ouvre
```
main.js → Reçoit message "openBank"
        → setUIVisible(true) ✅
        → body.classList.add('show')
        → openPage('account-page')
        → Affichage des données
```

### 4️⃣ Opération bancaire
```
account.js → Click bouton
           → Demande PIN (prompt)
           → postNUI('deposit/withdraw/transfer')
           → Serveur traite
           → Callback mise à jour solde
```

### 5️⃣ Fermeture
```
Bouton X ou ESC → postNUI('close')
                → setUIVisible(false) ✅
                → body.classList.remove('show')
                → Interface cachée
```

## ✅ Points Clés de la Correction

### 🎯 Problème Résolu : Interface Toujours Visible

**AVANT** :
```css
body {
  display: flex; /* ❌ Toujours visible */
}
```

**APRÈS** :
```css
body {
  display: none; /* ✅ Caché par défaut */
}

body.show {
  display: block; /* ✅ Visible seulement avec classe */
}
```

### 🔐 Architecture Multi-Pages

- ✅ Une seule page HTML (index.html)
- ✅ Plusieurs `<div class="page">` à l'intérieur
- ✅ Système de routing JS pour changer de page
- ✅ Pas de chargement/rechargement de pages

### 📡 Communication NUI

```javascript
// Lua → JavaScript
SendNUIMessage({ action = "openBank", data = payload })

// JavaScript → Lua
fetch(`https://kt_banque/deposit`, { 
  method: "POST", 
  body: JSON.stringify(data) 
})

// Lua reçoit via
RegisterNUICallback("deposit", function(data, cb) ... end)
```

## 🚀 Installation Rapide

```bash
# 1. Copier tous les fichiers dans resources/kt_banque/
# 2. Importer bank.sql dans la base de données
# 3. Ajouter les items dans ox_inventory
# 4. Ajouter dans server.cfg :
ensure kt_banque

# 5. Redémarrer le serveur
restart kt_banque
```

## 🐛 Débogage

### L'interface ne se cache pas
```javascript
// Console F12 dans le jeu
console.log(document.body.classList); 
// Doit être vide quand fermé
// Doit contenir "show" quand ouvert
```

### Vérifier les messages NUI
```javascript
// Dans main.js, ajouter :
window.addEventListener('message', function(event) {
  console.log('NUI MESSAGE:', event.data);
  // ...
});
```

### Logs Lua
```lua
-- Dans client/bank.lua
print("^2[DEBUG]^7 Ouverture NUI avec payload:", json.encode(payload))
```

## 📊 Performances

- ✅ Interface cachée = 0 impact CPU
- ✅ Pas de polling constant
- ✅ Events déclenchés uniquement à l'interaction
- ✅ Queries DB optimisées avec index

---

**Version** : 5.1.0  
**Statut** : ✅ Entièrement fonctionnel  
**Interface** : ✅ Se cache correctement