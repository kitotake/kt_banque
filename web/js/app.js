// ==================== KT BANQUE - APPLICATION PRINCIPALE ====================

// État global de l'application
const AppState = {
    currentPage: null,
    currentData: null,
    cardMeta: null,
    isOpen: false
  };
  
  // ==================== NAVIGATION ====================
  function showPage(pageId) {
    document.querySelectorAll('.page').forEach(page => {
      page.classList.add('hidden');
      page.classList.remove('active');
    });
    
    const targetPage = document.getElementById(pageId);
    if (targetPage) {
      targetPage.classList.remove('hidden');
      targetPage.classList.add('active');
      AppState.currentPage = pageId;
      console.log('[KT Banque] Page affichée:', pageId);
    }
  }
  
  // ==================== FORMATAGE ====================
  function formatCurrency(amount) {
    const num = parseFloat(amount) || 0;
    return '$' + num.toLocaleString('fr-FR', {
      minimumFractionDigits: 0,
      maximumFractionDigits: 2
    });
  }
  
  function formatDate(dateString) {
    if (!dateString) return 'Date inconnue';
    const date = new Date(dateString);
    const diff = (new Date() - date) / 1000;
    if (diff < 60) return "À l'instant";
    if (diff < 3600) return `Il y a ${Math.floor(diff / 60)} min`;
    if (diff < 86400) return `Il y a ${Math.floor(diff / 3600)} h`;
    return date.toLocaleString('fr-FR');
  }
  
  // ==================== COMMUNICATION SERVEUR ====================
  function sendToServer(event, data, callback) {
    fetch(`https://${GetParentResourceName()}/${event}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data || {})
    })
    .then(resp => resp.json())
    .then(callback || (() => {}))
    .catch(err => console.error('[KT Banque] Erreur:', err));
  }
  
  function closeUI() {
    sendToServer('close', {});
    document.body.classList.remove('show');
    AppState.isOpen = false;
    AppState.currentData = null;
    AppState.cardMeta = null;
  }
  
  // ==================== PAGE PIN ====================
  function initPinPage() {
    const pinInput = document.getElementById('pinInput');
    const pinSubmit = document.getElementById('pinSubmit');
    const pinError = document.getElementById('pinError');
  
    function showError(message) {
      pinError.textContent = message;
      pinError.classList.remove('hidden');
      pinInput.classList.add('error-shake');
      setTimeout(() => pinInput.classList.remove('error-shake'), 400);
    }
  
    function hideError() {
      pinError.classList.add('hidden');
    }
  
    function validatePin() {
      const pin = pinInput.value.trim();
      
      if (pin.length !== 4 || isNaN(pin)) {
        showError('Le PIN doit contenir 4 chiffres');
        return;
      }
  
      // Vérifier si le PIN correspond aux données reçues
      if (AppState.currentData && AppState.currentData.requiresPin) {
        const storedPin = String(AppState.currentData.pin || '');
        if (pin === storedPin) {
          hideError();
          showPage('account-page');
          loadAccountData(AppState.currentData);
        } else {
          showError('❌ Code PIN incorrect');
          pinInput.value = '';
        }
      } else {
        // Si pas de validation requise, passer directement
        showPage('account-page');
        loadAccountData(AppState.currentData);
      }
    }
  
    pinSubmit.addEventListener('click', validatePin);
    pinInput.addEventListener('keypress', (e) => {
      if (e.key === 'Enter') validatePin();
    });
  
    pinInput.addEventListener('input', function() {
      this.value = this.value.replace(/[^0-9]/g, '').slice(0, 4);
      hideError();
    });
  
    setTimeout(() => pinInput.focus(), 200);
  }
  
  // ==================== PAGE CRÉATION COMPTE ====================
  function initCreatePage() {
    const createBtn = document.getElementById('createBtn');
    const cancelBtn = document.getElementById('cancelCreateBtn');
    const newPin = document.getElementById('newPin');
    const confirmPin = document.getElementById('confirmPin');
    const createError = document.getElementById('createError');
  
    function showError(message) {
      createError.textContent = message;
      createError.classList.remove('hidden');
    }
  
    function hideError() {
      createError.classList.add('hidden');
    }
  
    function validatePins() {
      const pin1 = newPin.value.trim();
      const pin2 = confirmPin.value.trim();
  
      if (pin1.length === 4 && pin2.length === 4) {
        if (pin1 === pin2) {
          createBtn.disabled = false;
          hideError();
          return true;
        } else {
          showError('Les codes PIN ne correspondent pas');
          createBtn.disabled = true;
        }
      } else {
        createBtn.disabled = true;
      }
      return false;
    }
  
    function createAccount() {
      const pin = newPin.value.trim();
      
      if (!validatePins()) return;
      
      sendToServer('createAccount', { pin: pin }, (resp) => {
        if (resp === 'ok') {
          console.log('[KT Banque] Compte créé');
        }
      });
    }
  
    createBtn.addEventListener('click', createAccount);
    cancelBtn.addEventListener('click', () => showPage('pin-page'));
  
    newPin.addEventListener('input', function() {
      this.value = this.value.replace(/[^0-9]/g, '').slice(0, 4);
      validatePins();
    });
  
    confirmPin.addEventListener('input', function() {
      this.value = this.value.replace(/[^0-9]/g, '').slice(0, 4);
      validatePins();
    });
  
    createBtn.disabled = true;
  }
  
  // ==================== PAGE COMPTE ====================
  function loadAccountData(data) {
    if (!data) return;
  
    AppState.currentData = data;
    AppState.cardMeta = data.card_meta;
  
    // Mise à jour du solde
    document.getElementById('balance').textContent = formatCurrency(data.balance);
    
    // Mise à jour des informations de carte
    if (data.card_meta) {
      document.getElementById('cardType').textContent = data.card_meta.card_type || 'Carte Basique';
      const cardNum = data.card_meta.card_number || '****************';
      document.getElementById('cardNumber').textContent = cardNum.replace(/(.{4})/g, '$1 ').trim();
      document.getElementById('cardOwner').textContent = data.card_meta.owner || 'Utilisateur';
    }
  
    if (data.account_info) {
      document.getElementById('accountLabel').textContent = data.account_info.label || 'Compte Personnel';
    }
  
    // Mise à jour des limites
    if (data.limits) {
      document.getElementById('depositLimit').textContent = formatCurrency(data.limits.MaxDeposit);
      document.getElementById('withdrawLimit').textContent = formatCurrency(data.limits.MaxWithdraw);
    }
  
    // Charger l'historique
    if (data.history && data.history.length > 0) {
      loadHistory(data.history);
    }
  }
  
  function loadHistory(history) {
    const container = document.getElementById('historyList');
    if (!container) return;
  
    container.innerHTML = '';
    
    if (!history || history.length === 0) {
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
        transfer_out: '📤 Transfert envoyé',
        transfer_in: '📥 Transfert reçu',
        account_created: '✨ Création',
        card_issued: '💳 Carte émise'
      };
  
      const icon = actionIcons[h.action] || '💲 Transaction';
      const isPositive = ['deposit', 'transfer_in'].includes(h.action);
      const sign = isPositive ? '+' : '-';
      const color = isPositive ? 'positive' : 'negative';
  
      li.innerHTML = `
        <div class="history-info">
          <div class="history-action">${icon}</div>
          <div class="history-description">${h.description || ''}</div>
          <div class="history-date">${formatDate(h.date)}</div>
        </div>
        <div class="history-amount ${color}">
          ${sign}${formatCurrency(Math.abs(h.amount))}
        </div>
      `;
      container.appendChild(li);
    });
  }
  
  function updateBalance(newBalance) {
    const balanceEl = document.getElementById('balance');
    if (balanceEl) {
      balanceEl.textContent = formatCurrency(newBalance);
      balanceEl.classList.add('balance-update');
      setTimeout(() => balanceEl.classList.remove('balance-update'), 500);
    }
  }
  
  function initAccountPage() {
    const closeBtn = document.getElementById('closeBtn');
    const depositBtn = document.getElementById('depositBtn');
    const withdrawBtn = document.getElementById('withdrawBtn');
    const transferBtn = document.getElementById('transferBtn');
  
    closeBtn.addEventListener('click', closeUI);
  
    // Dépôt
    depositBtn.addEventListener('click', () => {
      const amount = document.getElementById('depositAmount').value;
      const pin = prompt('Entrez votre code PIN:');
      
      if (!pin || !amount) return;
      
      sendToServer('deposit', {
        amount: parseFloat(amount),
        cardId: AppState.cardMeta?.id,
        pin: pin
      });
      
      document.getElementById('depositAmount').value = '';
    });
  
    // Retrait
    withdrawBtn.addEventListener('click', () => {
      const amount = document.getElementById('withdrawAmount').value;
      const pin = prompt('Entrez votre code PIN:');
      
      if (!pin || !amount) return;
      
      sendToServer('withdraw', {
        amount: parseFloat(amount),
        cardId: AppState.cardMeta?.id,
        pin: pin
      });
      
      document.getElementById('withdrawAmount').value = '';
    });
  
    // Transfert
    transferBtn.addEventListener('click', () => {
      const amount = document.getElementById('transferAmount').value;
      const target = document.getElementById('transferTarget').value;
      const pin = prompt('Entrez votre code PIN:');
      
      if (!pin || !amount || !target) return;
      
      sendToServer('transfer', {
        amount: parseFloat(amount),
        target: target,
        cardId: AppState.cardMeta?.id,
        pin: pin
      });
      
      document.getElementById('transferAmount').value = '';
      document.getElementById('transferTarget').value = '';
    });
  }
  
  // ==================== MESSAGES NUI ====================
  window.addEventListener('message', (event) => {
    const data = event.data;
    
    switch(data.action) {
      case 'openBank':
        document.body.classList.add('show');
        AppState.isOpen = true;
        AppState.currentData = data.data;
        showPage('pin-page');
        break;
        
      case 'openCreate':
        document.body.classList.add('show');
        AppState.isOpen = true;
        showPage('create-page');
        break;
        
      case 'updateBalance':
        updateBalance(data.balance);
        if (AppState.currentData) {
          AppState.currentData.balance = data.balance;
        }
        break;
        
      case 'close':
        closeUI();
        break;
    }
  });
  
  // ==================== TOUCHE ESC ====================
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && AppState.isOpen) {
      closeUI();
    }
  });
  
  // ==================== INITIALISATION ====================
  document.addEventListener('DOMContentLoaded', () => {
    console.log('[KT Banque] Application chargée');
    initPinPage();
    initCreatePage();
    initAccountPage();
    
    // Empêcher valeurs négatives
    document.querySelectorAll('input[type="number"]').forEach(input => {
      input.addEventListener('input', () => {
        if (parseFloat(input.value) < 0) input.value = '';
      });
    });
  });
  
  // ==================== HELPERS POUR DEV ====================
  function GetParentResourceName() {
    return window.location.hostname === 'nui-frame-name' ? 'kt_banque' : 'kt_banque';
  }