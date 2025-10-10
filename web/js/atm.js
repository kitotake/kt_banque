// atm.js — Gestion de la page Distributeur Automatique (KT Banque)

document.addEventListener('DOMContentLoaded', function() {
  const atmDepositBtn = document.getElementById('atmDepositBtn');
  const atmWithdrawBtn = document.getElementById('atmWithdrawBtn');
  const closeAtmBtn = document.getElementById('closeAtmBtn');

  const atmDepositAmount = document.getElementById('atmDepositAmount');
  const atmWithdrawAmount = document.getElementById('atmWithdrawAmount');
  const atmBalance = document.getElementById('atmBalance');

  // Charger le solde depuis le stockage local
  let balance = parseFloat(localStorage.getItem('balance')) || 1000;
  updateBalanceDisplay();

  // Fonction pour mettre à jour l'affichage du solde
  function updateBalanceDisplay() {
    if (atmBalance) {
      atmBalance.textContent = `$${balance.toFixed(2)}`;
    }
  }

  // Fonction pour enregistrer le solde
  function saveBalance(newBalance) {
    balance = newBalance;
    localStorage.setItem('balance', balance);
    updateBalanceDisplay();
  }

  // Fonction pour valider un montant
  function validateAmount(amount, fieldName = 'Montant') {
    const num = parseFloat(amount);
    if (!amount || amount === '') {
      alert(`❌ Veuillez saisir un ${fieldName.toLowerCase()}`);
      return false;
    }
    if (isNaN(num) || num <= 0) {
      alert(`❌ ${fieldName} invalide ! Doit être un nombre positif.`);
      return false;
    }
    return true;
  }

  // Fonction pour nettoyer les inputs
  function clearATMInputs() {
    if (atmDepositAmount) atmDepositAmount.value = '';
    if (atmWithdrawAmount) atmWithdrawAmount.value = '';
  }

  // Animation bouton
  function animateButton(btn) {
    btn.style.transform = 'scale(0.95)';
    setTimeout(() => {
      btn.style.transform = 'scale(1)';
    }, 150);
  }

  // ➕ Dépôt
  if (atmDepositBtn) {
    atmDepositBtn.addEventListener('click', () => {
      animateButton(atmDepositBtn);
      const amount = atmDepositAmount.value.trim();

      if (!validateAmount(amount, 'Montant de dépôt')) return;

      const newBalance = balance + parseFloat(amount);
      saveBalance(newBalance);

      alert(`✅ Vous avez déposé ${amount}$ sur votre compte.`);
      clearATMInputs();
    });
  }

  // ➖ Retrait
  if (atmWithdrawBtn) {
    atmWithdrawBtn.addEventListener('click', () => {
      animateButton(atmWithdrawBtn);
      const amount = atmWithdrawAmount.value.trim();

      if (!validateAmount(amount, 'Montant de retrait')) return;

      const num = parseFloat(amount);
      if (num > balance) {
        alert('❌ Solde insuffisant pour effectuer ce retrait.');
        return;
      }

      const newBalance = balance - num;
      saveBalance(newBalance);

      alert(`✅ Vous avez retiré ${amount}$ de votre compte.`);
      clearATMInputs();
    });
  }

  // 🔒 Fermeture de l'ATM
  if (closeAtmBtn) {
    closeAtmBtn.addEventListener('click', () => {
      animateButton(closeAtmBtn);
      setTimeout(() => {
        window.location.href = 'index.html'; // Retour à la banque
      }, 150);
    });
  }

  // ⎋ Touche ESC pour quitter
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      window.location.href = 'index.html';
    }
  });

  console.log('[KT Banque] atm.js chargé — mode pages séparées');
});
