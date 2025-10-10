// Gestion de la page Account.js (version pages séparées)

document.addEventListener('DOMContentLoaded', function() {
  const depositBtn = document.getElementById('depositBtn');
  const withdrawBtn = document.getElementById('withdrawBtn');
  const transferBtn = document.getElementById('transferBtn');
  const closeBtn = document.getElementById('closeBtn');

  const depositAmount = document.getElementById('depositAmount');
  const withdrawAmount = document.getElementById('withdrawAmount');
  const transferAmount = document.getElementById('transferAmount');
  const transferTarget = document.getElementById('transferTarget');

  // Récupérer solde initial
  let balance = parseFloat(localStorage.getItem('balance')) || 1000;
  const balanceDisplay = document.getElementById('balance');

  const updateBalance = (newBalance) => {
    balance = newBalance;
    localStorage.setItem('balance', balance);
    if (balanceDisplay) balanceDisplay.textContent = `$${balance.toFixed(2)}`;
  };

  if (balanceDisplay) balanceDisplay.textContent = `$${balance.toFixed(2)}`;

  // Fonction de validation du montant
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
  function clearInputs() {
    if (depositAmount) depositAmount.value = '';
    if (withdrawAmount) withdrawAmount.value = '';
    if (transferAmount) transferAmount.value = '';
    if (transferTarget) transferTarget.value = '';
  }

  // Animation des boutons
  function animateButton(btn) {
    btn.style.transform = 'scale(0.95)';
    setTimeout(() => {
      btn.style.transform = 'scale(1)';
    }, 100);
  }

  // Dépôt
  if (depositBtn) {
    depositBtn.addEventListener('click', () => {
      const amount = depositAmount.value;
      if (!validateAmount(amount, 'Montant à déposer')) return;

      animateButton(depositBtn);
      const newBalance = balance + parseFloat(amount);
      updateBalance(newBalance);
      alert(`✅ Vous avez déposé $${amount}`);
      clearInputs();
    });
  }

  // Retrait
  if (withdrawBtn) {
    withdrawBtn.addEventListener('click', () => {
      const amount = withdrawAmount.value;
      if (!validateAmount(amount, 'Montant à retirer')) return;

      if (parseFloat(amount) > balance) {
        alert("❌ Solde insuffisant !");
        return;
      }

      animateButton(withdrawBtn);
      const newBalance = balance - parseFloat(amount);
      updateBalance(newBalance);
      alert(`✅ Vous avez retiré $${amount}`);
      clearInputs();
    });
  }

  // Transfert
  if (transferBtn) {
    transferBtn.addEventListener('click', () => {
      const amount = transferAmount.value;
      const target = transferTarget.value.trim();

      if (!target) {
        alert('❌ Veuillez saisir un destinataire (numéro de compte ou ID)');
        return;
      }

      if (!validateAmount(amount, 'Montant à transférer')) return;

      const confirmMsg = `Confirmer le transfert de $${amount} vers ${target} ?`;
      if (!confirm(confirmMsg)) return;

      animateButton(transferBtn);

      if (parseFloat(amount) > balance) {
        alert("❌ Solde insuffisant !");
        return;
      }

      updateBalance(balance - parseFloat(amount));
      alert(`✅ Transfert de $${amount} vers ${target} effectué.`);
      clearInputs();
    });
  }

  // Fermer → retour à la page PIN
  if (closeBtn) {
    closeBtn.addEventListener('click', () => {
      window.location.href = "index.html";
    });
  }

  // Empêcher les caractères invalides dans les montants
  const amountInputs = [depositAmount, withdrawAmount, transferAmount];
  amountInputs.forEach(input => {
    if (input) {
      input.addEventListener('input', function() {
        this.value = this.value.replace(/[^0-9.]/g, '');
        const parts = this.value.split('.');
        if (parts.length > 2) {
          this.value = parts[0] + '.' + parts.slice(1).join('');
        }
        if (parts[1] && parts[1].length > 2) {
          this.value = parts[0] + '.' + parts[1].slice(0, 2);
        }
      });
    }
  });

  console.log('[KT Banque] account.js (version pages séparées) chargé');
});
