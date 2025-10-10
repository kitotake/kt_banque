// main.js — version adaptée pour système à pages séparées (web/localStorage)

// ==================== Données globales ====================
let currentData = {
  balance: parseFloat(localStorage.getItem('balance')) || 1000,
  history: JSON.parse(localStorage.getItem('history')) || []
};

// ==================== Fonctions utilitaires ====================

// Formater un montant en devise
function formatCurrency(amount) {
  const num = parseFloat(amount) || 0;
  return '$' + num.toLocaleString('fr-FR', {
    minimumFractionDigits: 0,
    maximumFractionDigits: 2
  });
}

// Formater une date relative (ex: "il y a 2h")
function formatDate(dateString) {
  if (!dateString) return 'Date inconnue';
  const date = new Date(dateString);
  const diff = (new Date() - date) / 1000;
  if (diff < 60) return "À l'instant";
  if (diff < 3600) return `Il y a ${Math.floor(diff / 60)} min`;
  if (diff < 86400) return `Il y a ${Math.floor(diff / 3600)} h`;
  return date.toLocaleString('fr-FR');
}

// ==================== Solde ====================

function getBalance() {
  return parseFloat(localStorage.getItem('balance')) || 0;
}

function setBalance(amount) {
  localStorage.setItem('balance', parseFloat(amount));
  currentData.balance = parseFloat(amount);
}

function updateBalanceDisplay(selector = '#balance') {
  const el = document.querySelector(selector);
  if (el) el.textContent = formatCurrency(getBalance());
}

// ==================== Historique ====================

function addHistory(action, amount, description = '') {
  const history = JSON.parse(localStorage.getItem('history')) || [];
  const entry = {
    action,
    amount,
    description,
    date: new Date().toISOString()
  };
  history.unshift(entry);
  localStorage.setItem('history', JSON.stringify(history));
}

function loadHistory(containerId = 'historyList') {
  const container = document.getElementById(containerId);
  if (!container) return;

  const history = JSON.parse(localStorage.getItem('history')) || [];

  container.innerHTML = '';
  if (history.length === 0) {
    container.innerHTML = '<li class="history-empty">📭 Aucune transaction récente</li>';
    return;
  }

  history.forEach((h, i) => {
    const li = document.createElement('li');
    li.className = 'history-item';
    li.style.animationDelay = `${i * 0.05}s`;

    const actionIcons = {
      deposit: '💰 Dépôt',
      withdraw: '💵 Retrait',
      transfer: '🔄 Transfert',
      create: '✨ Création de compte'
    };

    const icon = actionIcons[h.action] || '💲 Transaction';
    const sign = ['deposit', 'transfer_in'].includes(h.action) ? '+' : '-';
    const color = ['deposit', 'transfer_in'].includes(h.action) ? 'positive' : 'negative';

    li.innerHTML = `
      <div class="history-info">
        <div class="history-action">${icon}</div>
        <div class="history-description">${h.description}</div>
        <div class="history-date">${formatDate(h.date)}</div>
      </div>
      <div class="history-amount ${color}">
        ${sign}${formatCurrency(h.amount)}
      </div>
    `;
    container.appendChild(li);
  });
}

// ==================== Navigation entre pages ====================

function goTo(page) {
  window.location.href = page;
}

// ==================== Initialisation ====================
document.addEventListener('DOMContentLoaded', () => {
  console.log('[KT Banque] main.js chargé — version pages séparées');

  // Empêcher valeurs négatives
  document.querySelectorAll('input[type="number"]').forEach(input => {
    input.addEventListener('input', () => {
      if (parseFloat(input.value) < 0) input.value = '';
    });
  });

  // Animation des montants
  const style = document.createElement('style');
  style.textContent = `
    @keyframes balance-update {
      0% { transform: scale(1); }
      50% { transform: scale(1.05); color: #10b981; }
      100% { transform: scale(1); }
    }
    .balance-update { animation: balance-update 0.5s ease; }
    .positive { color: #10b981; font-weight: 600; }
    .negative { color: #ef4444; font-weight: 600; }
  `;
  document.head.appendChild(style);
});

// ==================== Export global ====================
window.KTBanque = {
  formatCurrency,
  formatDate,
  getBalance,
  setBalance,
  updateBalanceDisplay,
  addHistory,
  loadHistory,
  goTo,
  currentData
};
