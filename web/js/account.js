document.addEventListener('DOMContentLoaded', function() {
  const depositBtn = document.getElementById('depositBtn');
  const withdrawBtn = document.getElementById('withdrawBtn');
  const transferBtn = document.getElementById('transferBtn');
  const closeBtn = document.getElementById('closeBtn');

  const depositAmount = document.getElementById('depositAmount');
  const withdrawAmount = document.getElementById('withdrawAmount');
  const transferAmount = document.getElementById('transferAmount');
  const transferTarget = document.getElementById('transferTarget');

  // Fonction pour demander le PIN
  function promptPin() {
    return new Promise((resolve, reject) => {
      const pin = prompt('🔐 Entrez votre code PIN à 4 chiffres :');
      
      if (!pin) {
        reject('PIN non fourni');
        return;
      }
      
      if (pin.length !== 4 || isNaN(pin)) {
        alert('❌ Code PIN invalide ! Le PIN doit contenir 4 chiffres.');
        reject('PIN invalide');
        return;
      }
      
      resolve(pin);
    });
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
  function clearInputs() {
    if (depositAmount) depositAmount.value = '';
    if (withdrawAmount) withdrawAmount.value = '';
    if (transferAmount) transferAmount.value = '';
    if (transferTarget) transferTarget.value = '';
  }

  // Animation bouton
  function animateButton(btn) {
    btn.style.transform = 'scale(0.95)';
    setTimeout(() => {
      btn.style.transform = 'scale(1)';
    }, 100);
  }

  // Dépôt
  if (depositBtn) {
    depositBtn.addEventListener('click', async function() {
      const amount = depositAmount.value;
      
      if (!validateAmount(amount, 'Montant à déposer')) {
        return;
      }
      
      try {
        const pin = await promptPin();
        
        animateButton(this);
        
        await window.KTBanque.postNUI('deposit', {
          amount: parseFloat(amount),
          pin: pin
        });
        
        clearInputs();
      } catch (error) {
        console.log('Dépôt annulé:', error);
      }
    });
  }

  // Retrait
  if (withdrawBtn) {
    withdrawBtn.addEventListener('click', async function() {
      const amount = withdrawAmount.value;
      
      if (!validateAmount(amount, 'Montant à retirer')) {
        return;
      }
      
      try {
        const pin = await promptPin();
        
        animateButton(this);
        
        await window.KTBanque.postNUI('withdraw', {
          amount: parseFloat(amount),
          pin: pin
        });
        
        clearInputs();
      } catch (error) {
        console.log('Retrait annulé:', error);
      }
    });
  }

  // Transfert
  if (transferBtn) {
    transferBtn.addEventListener('click', async function() {
      const amount = transferAmount.value;
      const target = transferTarget.value;
      
      if (!target || target.trim() === '') {
        alert('❌ Veuillez saisir le destinataire (numéro de compte ou ID)');
        return;
      }
      
      if (!validateAmount(amount, 'Montant à transférer')) {
        return;
      }
      
      // Confirmation
      const confirmMsg = `Confirmer le transfert de ${window.KTBanque.formatCurrency(amount)} vers ${target} ?`;
      if (!confirm(confirmMsg)) {
        return;
      }
      
      try {
        const pin = await promptPin();
        
        animateButton(this);
        
        await window.KTBanque.postNUI('transfer', {
          amount: parseFloat(amount),
          target: target.trim(),
          pin: pin
        });
        
        clearInputs();
      } catch (error) {
        console.log('Transfert annulé:', error);
      }
    });
  }

  // Fermer
  if (closeBtn) {
    closeBtn.addEventListener('click', function() {
      window.KTBanque.postNUI('close', {});
      window.KTBanque.setUIVisible(false);
      clearInputs();
    });
  }

  // Accepter uniquement les nombres positifs dans les inputs
  const amountInputs = [depositAmount, withdrawAmount, transferAmount];
  amountInputs.forEach(input => {
    if (input) {
      input.addEventListener('input', function() {
        // Supprimer les caractères non numériques sauf le point
        this.value = this.value.replace(/[^0-9.]/g, '');
        
        // S'assurer qu'il n'y a qu'un seul point
        const parts = this.value.split('.');
        if (parts.length > 2) {
          this.value = parts[0] + '.' + parts.slice(1).join('');
        }
        
        // Limiter à 2 décimales
        if (parts[1] && parts[1].length > 2) {
          this.value = parts[0] + '.' + parts[1].slice(0, 2);
        }
      });
      
      // Enter pour valider
      input.addEventListener('keypress', function(e) {
        if (e.key === 'Enter') {
          if (this === depositAmount && depositBtn) {
            depositBtn.click();
          } else if (this === withdrawAmount && withdrawBtn) {
            withdrawBtn.click();
          } else if (this === transferAmount && transferBtn) {
            transferBtn.click();
          }
        }
      });
    }
  });

  // Formatage en temps réel avec séparateurs de milliers
  amountInputs.forEach(input => {
    if (input) {
      input.addEventListener('blur', function() {
        if (this.value) {
          const num = parseFloat(this.value);
          if (!isNaN(num)) {
            // Pas de formatage ici pour éviter les problèmes avec la saisie
          }
        }
      });
    }
  });
});