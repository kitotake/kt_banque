// Variables globales
let currentData = null;
let isUIOpen = false;
let currentPage = null;

// Fonction pour afficher/masquer l'interface
function setUIVisible(visible) {
  const body = document.body;
  if (visible) {
    body.classList.add('show');
    isUIOpen = true;
  } else {
    body.classList.remove('show');
    isUIOpen = false;
    closeAllPages();
    currentPage = null;
  }
}

// Fermer toutes les pages
function closeAllPages() {
  document.querySelectorAll('.page').forEach(el => {
    el.classList.remove('active');
    el.classList.add('hidden');
  });
}

// Ouvrir une page spécifique
function openPage(pageId) {
  closeAllPages();
  const page = document.getElementById(pageId);
  if (page) {
    page.classList.remove('hidden');
    page.classList.add('active');
    currentPage = pageId;
  }
}

// Formater montant en devise
function formatCurrency(amount) {
  return '$' + parseInt(amount).toLocaleString('fr-FR');
}

// Formater date
function formatDate(dateString) {
  const date = new Date(dateString);
  const now = new Date();
  const diff = now - date;
  const seconds = Math.floor(diff / 1000);
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);
  const days = Math.floor(hours / 24);

  if (seconds < 60) return 'À l\'instant';
  if (minutes < 60) return `Il y a ${minutes} min`;
  if (hours < 24) return `Il y a ${hours}h`;
  if (days < 7) return `Il y a ${days}j`;
  
  return date.toLocaleDateString('fr-FR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  });
}

// Mettre à jour l'affichage du solde
function updateBalanceUI(balance) {
  const balanceElements = document.querySelectorAll('#balance, #atmBalance');
  balanceElements.forEach(el => {
    if (el) {
      el.textContent = formatCurrency(balance);
      // Animation
      el.style.transition = 'transform 0.2s';
      el.style.transform = 'scale(1.05)';
      setTimeout(() => {
        el.style.transform = 'scale(1)';
      }, 200);
    }
  });
}

// Afficher les informations de la carte
function displayCardInfo(cardMeta) {
  if (!cardMeta) return;

  const cardType = document.getElementById('cardType');
  const cardNumber = document.getElementById('cardNumber');
  const cardOwner = document.getElementById('cardOwner');

  if (cardType && cardMeta.card_type) {
    const types = {
      'carte_basique': '💳 Carte Basique',
      'carte_or': '🏅 Carte Or',
      'carte_dimas': '💎 Carte Diamant'
    };
    cardType.textContent = types[cardMeta.card_type] || '💳 Carte';
  }

  if (cardNumber && cardMeta.last4) {
    cardNumber.textContent = `**** **** **** ${cardMeta.last4}`;
  }

  if (cardOwner && cardMeta.owner) {
    cardOwner.textContent = cardMeta.owner;
  }
}

// Afficher les limites
function displayLimits(limits, isAtm = false) {
  if (!limits) return;

  const prefix = isAtm ? 'atm' : '';
  const depositLimit = document.getElementById(`${prefix}${prefix ? 'D' : 'd'}epositLimit`);
  const withdrawLimit = document.getElementById(`${prefix}${prefix ? 'W' : 'w'}ithdrawLimit`);

  if (depositLimit) {
    depositLimit.textContent = formatCurrency(limits.MaxDeposit || 0);
  }

  if (withdrawLimit) {
    withdrawLimit.textContent = formatCurrency(limits.MaxWithdraw || 0);
  }
}

// Afficher l'historique
function displayHistory(history) {
  const historyList = document.getElementById('historyList');
  if (!historyList) return;

  historyList.innerHTML = '';

  if (!history || history.length === 0) {
    historyList.innerHTML = '<li class="history-empty">Aucune transaction récente</li>';
    return;
  }

  history.forEach(transaction => {
    const li = document.createElement('li');
    li.className = 'history-item';

    const info = document.createElement('div');
    info.className = 'history-info';

    const action = document.createElement('div');
    action.className = 'history-action';
    
    const actionIcons = {
      'deposit': '💰 Dépôt',
      'withdraw': '💵 Retrait',
      'transfer_out': '📤 Transfert envoyé',
      'transfer_in': '📥 Transfert reçu',
      'account_created': '✨ Compte créé',
      'admin_created': '👑 Créé par admin',
      'admin_set_balance': '⚙️ Ajustement admin'
    };

    action.textContent = actionIcons[transaction.action] || transaction.action;

    const description = document.createElement('div');
    description.className = 'history-description';
    description.textContent = transaction.description || '';

    const date = document.createElement('div');
    date.className = 'history-date';
    date.textContent = formatDate(transaction.date);

    info.appendChild(action);
    if (transaction.description) {
      info.appendChild(description);
    }
    info.appendChild(date);

    const amount = document.createElement('div');
    amount.className = 'history-amount';
    
    const isPositive = ['deposit', 'transfer_in', 'admin_set_balance'].includes(transaction.action);
    amount.classList.add(isPositive ? 'positive' : 'negative');
    
    if (transaction.amount && transaction.amount !== 0) {
      amount.textContent = (isPositive ? '+' : '-') + formatCurrency(Math.abs(transaction.amount));
    } else {
      amount.textContent = '—';
    }

    li.appendChild(info);
    li.appendChild(amount);
    historyList.appendChild(li);
  });
}

// Écouter les messages NUI
window.addEventListener('message', function(event) {
  const data = event.data;

  switch(data.action) {
    case 'openBank':
      currentData = data.data;
      setUIVisible(true);
      openPage('account-page');
      
      // Afficher les données
      if (currentData.balance !== undefined) {
        updateBalanceUI(currentData.balance);
      }
      
      if (currentData.label) {
        const accountLabel = document.getElementById('accountLabel');
        if (accountLabel) {
          accountLabel.textContent = currentData.label;
        }
      }
      
      if (currentData.card_meta) {
        displayCardInfo(currentData.card_meta);
      }
      
      if (currentData.limits) {
        displayLimits(currentData.limits, false);
      }
      
      if (currentData.history) {
        displayHistory(currentData.history);
      }
      break;

    case 'openPin':
      currentData = data.card || data.data;
      setUIVisible(true);
      openPage('pin-page');
      break;

    case 'openCreate':
      setUIVisible(true);
      openPage('create-page');
      break;

    case 'openATM':
      currentData = data.data || data;
      setUIVisible(true);
      openPage('atm-page');
      
      if (currentData.balance !== undefined) {
        updateBalanceUI(currentData.balance);
      }
      
      if (currentData.limits) {
        displayLimits(currentData.limits, true);
      }
      break;

    case 'updateBalance':
      if (data.balance !== undefined) {
        updateBalanceUI(data.balance);
        if (currentData) {
          currentData.balance = data.balance;
        }
      }
      break;

    case 'close':
      setUIVisible(false);
      currentData = null;
      break;

    default:
      console.log('[KT Banque] Action NUI inconnue:', data.action);
      break;
  }
});

// Fermeture avec ESC
document.addEventListener('keydown', function(e) {
  if (e.key === 'Escape' && isUIOpen) {
    postNUI('close', {});
    setUIVisible(false);
  }
});

// Helper pour envoyer des données au client
function postNUI(callback, data = {}) {
  return fetch(`https://${GetParentResourceName()}/${callback}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(data)
  }).catch(err => {
    console.error('[KT Banque] Erreur NUI:', err);
  });
}

// Obtenir le nom de la ressource parente
function GetParentResourceName() {
  let resourceName = 'kt_banque';
  
  // Essayer de récupérer le vrai nom depuis l'URL
  if (window.location.href.includes('nui://')) {
    const match = window.location.href.match(/nui:\/\/([^\/]+)/);
    if (match && match[1]) {
      resourceName = match[1];
    }
  }
  
  return resourceName;
}

// Initialisation
document.addEventListener('DOMContentLoaded', function() {
  console.log('[KT Banque] Interface chargée et prête');
  
  // S'assurer que l'UI est cachée au démarrage
  setUIVisible(false);
  
  // Animation de transition pour les inputs
  const inputs = document.querySelectorAll('input[type="number"], input[type="text"], input[type="password"]');
  inputs.forEach(input => {
    input.style.transition = 'all 0.2s ease';
  });
  
  console.log('[KT Banque] Système initialisé');
});

// Export global pour utilisation dans d'autres fichiers
window.KTBanque = {
  setUIVisible,
  openPage,
  closeAllPages,
  updateBalanceUI,
  displayCardInfo,
  displayLimits,
  displayHistory,
  formatCurrency,
  formatDate,
  postNUI,
  GetParentResourceName
};