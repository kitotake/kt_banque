// ==================== KT BANQUE - VERSION 7.1 ====================

// Configuration
const RESOURCE_NAME = typeof GetParentResourceName === 'function'
    ? GetParentResourceName()
    : 'kt_banque';

// État de l'application
const AppState = {
    currentPage: null,
    accountData: null,
    isOpen: false,
    cardMeta: null
};

// ==================== UTILITAIRES ====================
const Utils = {
    formatCurrency(amount) {
        const num = parseFloat(amount) || 0;
        return '$' + num.toLocaleString('fr-FR', {
            minimumFractionDigits: 0,
            maximumFractionDigits: 2
        });
    },

    formatDate(dateString) {
        if (!dateString) return 'Date inconnue';
        const date = new Date(dateString);
        const diff = (new Date() - date) / 1000;

        if (diff < 60) return "À l'instant";
        if (diff < 3600) return `Il y a ${Math.floor(diff / 60)} min`;
        if (diff < 86400) return `Il y a ${Math.floor(diff / 3600)}h`;

        return date.toLocaleDateString('fr-FR', {
            day: '2-digit',
            month: '2-digit',
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    },

    sendToServer(event, data = {}) {
        return fetch(`https://${RESOURCE_NAME}/${event}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        })
        .then(resp => resp.ok ? resp.json().catch(() => ({})) : Promise.reject('Réponse serveur invalide'))
        .catch(err => {
            console.error(`[KT Banque] Erreur ${event}:`, err);
            Utils.notify('Erreur de communication avec le serveur', 'error');
        });
    },

    log(message, type = 'info') {
        const styles = {
            info: 'color: #3b82f6',
            success: 'color: #10b981',
            error: 'color: #ef4444',
            warning: 'color: #f59e0b'
        };
        console.log(`%c[KT Banque] ${message}`, styles[type] || styles.info);
    },

    validateAmount(value) {
        const num = parseFloat(value);
        return num > 0 ? num : null;
    },

    notify(message, type = 'info') {
        const container = document.getElementById('notif');
        if (!container) return console.log(`[Notif] ${message}`);
        container.textContent = message;
        container.className = `notif show ${type}`;
        setTimeout(() => container.classList.remove('show'), 2500);
    }
};

// ==================== NAVIGATION ====================
const Navigation = {
    showPage(pageId) {
        document.querySelectorAll('.page').forEach(page => {
            page.classList.add('hidden');
            page.classList.remove('active');
        });

        const targetPage = document.getElementById(pageId);
        if (targetPage) {
            targetPage.classList.remove('hidden');
            setTimeout(() => targetPage.classList.add('active'), 10);
            AppState.currentPage = pageId;
            Utils.log(`Page affichée: ${pageId}`);
        }
    },

    closeUI() {
        Utils.sendToServer('close');
        document.body.classList.remove('show');
        AppState.isOpen = false;
        AppState.accountData = null;
        AppState.cardMeta = null;
        this.resetInputs();
    },

    resetInputs() {
        document.querySelectorAll('input').forEach(input => {
            input.value = '';
            input.classList.remove('error-shake', 'valid', 'invalid');
        });
        document.querySelectorAll('.error').forEach(err => err.classList.add('hidden'));
    }
};

// ==================== ACTIONS BANCAIRES ====================
const BankActions = {
    deposit(amount) {
        return Utils.sendToServer('deposit', {
            amount,
            cardId: AppState.cardMeta?.id,
            pin: AppState.accountData?.pin
        }).then(() => Utils.notify('💰 Dépôt effectué', 'success'));
    },

    withdraw(amount) {
        return Utils.sendToServer('withdraw', {
            amount,
            cardId: AppState.cardMeta?.id,
            pin: AppState.accountData?.pin
        }).then(() => Utils.notify('💵 Retrait effectué', 'success'));
    },

    transfer(amount, target) {
        return Utils.sendToServer('transfer', {
            amount,
            target,
            cardId: AppState.cardMeta?.id,
            pin: AppState.accountData?.pin
        }).then(() => Utils.notify('📤 Transfert envoyé', 'success'));
    }
};

// ==================== PAGE PIN ====================
const PinPage = {
    init() {
        const pinInput = document.getElementById('pinInput');
        const pinSubmit = document.getElementById('pinSubmit');
        const pinError = document.getElementById('pinError');
        if (!pinInput || !pinSubmit || !pinError) return;

        const showError = (message) => {
            pinError.textContent = message;
            pinError.classList.remove('hidden');
            pinInput.classList.add('error-shake');
            setTimeout(() => pinInput.classList.remove('error-shake'), 400);
        };

        const hideError = () => pinError.classList.add('hidden');

        const validatePin = () => {
            const pin = pinInput.value.trim();
            if (pin.length !== 4 || !/^\d{4}$/.test(pin)) {
                showError('❌ Le PIN doit contenir 4 chiffres');
                return;
            }

            const storedPin = String(AppState.accountData?.pin || '');
            if (AppState.accountData?.requiresPin && pin !== storedPin) {
                showError('❌ Code PIN incorrect');
                pinInput.value = '';
                return;
            }

            hideError();
            Navigation.showPage('account-page');
            AccountPage.load(AppState.accountData);
            pinInput.value = '';
        };

        pinSubmit.onclick = validatePin;
        pinInput.oninput = function() {
            this.value = this.value.replace(/\D/g, '').slice(0, 4);
            hideError();
        };
        pinInput.onkeypress = (e) => e.key === 'Enter' && validatePin();
        Utils.log('Page PIN initialisée');
    }
};

// ==================== PAGWE CRÉATION ====================
const CreatePage = {
    init() {
        const createBtn = document.getElementById('createBtn');
        const cancelBtn = document.getElementById('cancelCreateBtn');
        const newPin = document.getElementById('newPin');
        const confirmPin = document.getElementById('confirmPin');
        const createError = document.getElementById('createError');
        if (!createBtn || !newPin || !confirmPin) return;

        const showError = (message) => {
            createError.textContent = message;
            createError.classList.remove('hidden');
        };
        const hideError = () => createError.classList.add('hidden');

        const validatePins = () => {
            const pin1 = newPin.value.trim();
            const pin2 = confirmPin.value.trim();
            if (pin1.length === 4 && pin2.length === 4 && /^\d{4}$/.test(pin1)) {
                if (pin1 === pin2) {
                    createBtn.disabled = false;
                    hideError();
                    return true;
                }
                showError('❌ Les codes PIN ne correspondent pas');
            } else {
                showError('❌ Le PIN doit contenir 4 chiffres');
            }
            createBtn.disabled = true;
            return false;
        };

        const createAccount = () => {
            if (!validatePins()) return;
            const pin = newPin.value.trim();
            Utils.sendToServer('createAccount', { pin }).then(() => {
                Utils.notify('✨ Compte créé avec succès', 'success');
                newPin.value = '';
                confirmPin.value = '';
                hideError();
            });
        };

        createBtn.onclick = createAccount;
        cancelBtn.onclick = () => Navigation.closeUI();
        newPin.oninput = confirmPin.oninput = function() {
            this.value = this.value.replace(/\D/g, '').slice(0, 4);
            validatePins();
        };
        confirmPin.onkeypress = (e) => e.key === 'Enter' && !createBtn.disabled && createAccount();

        createBtn.disabled = true;
        Utils.log('Page création initialisée');
    }
};

// ==================== PAGE COMPTE ====================
const AccountPage = {
    init() {
        const closeBtn = document.getElementById('closeBtn');
        if (closeBtn) closeBtn.onclick = () => Navigation.closeUI();

        const depositBtn = document.getElementById('depositBtn');
        const withdrawBtn = document.getElementById('withdrawBtn');
        const transferBtn = document.getElementById('transferBtn');

        if (depositBtn) depositBtn.onclick = () => {
            const amount = Utils.validateAmount(document.getElementById('depositAmount').value);
            if (!amount) return Utils.notify('Montant invalide', 'warning');
            BankActions.deposit(amount);
        };

        if (withdrawBtn) withdrawBtn.onclick = () => {
            const amount = Utils.validateAmount(document.getElementById('withdrawAmount').value);
            if (!amount) return Utils.notify('Montant invalide', 'warning');
            BankActions.withdraw(amount);
        };

        if (transferBtn) transferBtn.onclick = () => {
            const amount = Utils.validateAmount(document.getElementById('transferAmount').value);
            const target = document.getElementById('transferTarget').value.trim();
            if (!amount) return Utils.notify('Montant invalide', 'warning');
            if (!target) return Utils.notify('Destinataire invalide', 'warning');
            BankActions.transfer(amount, target);
        };

        Utils.log('Page compte initialisée');
    },

    load(data) {
        if (!data) return Utils.log('Aucune donnée de compte', 'error');
        AppState.accountData = data;
        AppState.cardMeta = data.card_meta;
        this.setElement('balance', Utils.formatCurrency(data.balance));

        if (data.card_meta) {
            const cardTypeName = (data.card_meta.card_type || 'carte_basique')
                .replace('carte_', 'Carte ')
                .replace('basique', 'Basique')
                .replace('or', 'Or')
                .replace('dimas', 'Diamant');
            this.setElement('cardType', cardTypeName);
            this.setElement('cardNumber', data.card_meta.card_number || '****************');
            this.setElement('cardOwner', data.card_meta.owner || 'Utilisateur');
        }

        if (data.account_info)
            this.setElement('accountLabel', data.account_info.label || 'Compte Personnel');

        if (data.limits) {
            this.setElement('depositLimit', Utils.formatCurrency(data.limits.MaxDeposit));
            this.setElement('withdrawLimit', Utils.formatCurrency(data.limits.MaxWithdraw));
        }

        this.loadHistory(data.history || []);
    },

    setElement(id, value) {
        const el = document.getElementById(id);
        if (el) el.textContent = value;
    },

    loadHistory(history) {
        const container = document.getElementById('historyList');
        if (!container) return;
        container.innerHTML = '';

        if (!history.length) {
            container.innerHTML = '<li class="history-empty">📭 Aucune transaction récente</li>';
            return;
        }

        const actionIcons = {
            deposit: '💰 Dépôt',
            withdraw: '💵 Retrait',
            transfer_out: '📤 Transfert envoyé',
            transfer_in: '📥 Transfert reçu',
            account_created: '✨ Création compte',
            card_issued: '💳 Carte émise'
        };

        history.forEach((item, index) => {
            const li = document.createElement('li');
            li.className = 'history-item';
            li.style.animationDelay = `${index * 0.05}s`;
            const icon = actionIcons[item.action] || '💲 Transaction';
            const isPositive = ['deposit', 'transfer_in', 'account_created'].includes(item.action);
            const amount = Math.abs(parseFloat(item.amount) || 0);
            const sign = amount > 0 ? (isPositive ? '+' : '-') : '';
            const colorClass = isPositive ? 'positive' : 'negative';

            li.innerHTML = `
                <div class="history-info">
                    <div class="history-action">${icon}</div>
                    <div class="history-description">${item.description || 'Transaction'}</div>
                    <div class="history-date">${Utils.formatDate(item.date)}</div>
                </div>
                <div class="history-amount ${colorClass}">
                    ${sign}${Utils.formatCurrency(amount)}
                </div>
            `;
            container.appendChild(li);
        });
    },

    updateBalance(newBalance) {
        const balanceEl = document.getElementById('balance');
        if (balanceEl) {
            balanceEl.textContent = Utils.formatCurrency(newBalance);
            balanceEl.classList.add('balance-update');
            setTimeout(() => balanceEl.classList.remove('balance-update'), 500);
        }
        if (AppState.accountData) AppState.accountData.balance = newBalance;
    }
};

// ==================== MESSAGES NUI ====================
window.addEventListener('message', (event) => {
    const { action, data } = event.data;

    switch (action) {
        case 'openBank':
            document.body.classList.add('show');
            AppState.isOpen = true;
            AppState.accountData = data;
            Navigation.showPage('pin-page');
            setTimeout(() => document.getElementById('pinInput')?.focus(), 200);
            break;

        case 'openCreate':
            document.body.classList.add('show');
            AppState.isOpen = true;
            Navigation.showPage('create-page');
            setTimeout(() => document.getElementById('newPin')?.focus(), 200);
            break;

            case 'updateBalance':
                if (data && typeof data.balance !== 'undefined') {
                    AccountPage.updateBalance(data.balance);
                } else {
                    console.warn('updateBalance reçu sans données valides :', data);
                }
                break;
            

        case 'close':
            Navigation.closeUI();
            break;
    }
});

// ==================== ÉVÉNEMENTS CLAVIER ====================
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && AppState.isOpen) {
        e.preventDefault();
        Navigation.closeUI();
    }
});

// ==================== INITIALISATION ====================
document.addEventListener('DOMContentLoaded', () => {
    Utils.log('Application chargée', 'success');
    PinPage.init();
    CreatePage.init();
    AccountPage.init();

    document.querySelectorAll('input[type="number"]').forEach(input => {
        input.addEventListener('input', function() {
            if (parseFloat(this.value) < 0) this.value = '';
        });
        input.addEventListener('keypress', (e) => {
            if (['-', 'e', 'E', '+'].includes(e.key)) e.preventDefault();
        });
    });

    // Ajout conteneur notification si absent
    if (!document.getElementById('notif')) {
        const div = document.createElement('div');
        div.id = 'notif';
        document.body.appendChild(div);
    }

    Utils.log('Initialisation terminée', 'success');
});
