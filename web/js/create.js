document.addEventListener('DOMContentLoaded', function() {
  const createBtn = document.getElementById('createBtn');
  const cancelCreateBtn = document.getElementById('cancelCreateBtn');
  const newPin = document.getElementById('newPin');
  const confirmPin = document.getElementById('confirmPin');
  const createError = document.getElementById('createError');

  if (!createBtn || !newPin || !confirmPin) return;

  // Validation en temps réel
  function validatePins() {
    const pin1 = newPin.value.trim();
    const pin2 = confirmPin.value.trim();

    // Réinitialiser les styles
    newPin.classList.remove('valid', 'invalid');
    confirmPin.classList.remove('valid', 'invalid');
    hideError();

    // Valider le premier PIN
    if (pin1.length === 4) {
      if (isValidPin(pin1)) {
        newPin.classList.add('valid');
      } else {
        newPin.classList.add('invalid');
        showError('PIN trop simple (évitez 0000, 1234, etc.)');
        return false;
      }
    } else if (pin1.length > 0) {
      newPin.classList.add('invalid');
      return false;
    }

    // Valider la confirmation
    if (pin2.length === 4) {
      if (pin1 === pin2) {
        confirmPin.classList.add('valid');
        createBtn.disabled = false;
        return true;
      } else {
        confirmPin.classList.add('invalid');
        showError('Les codes PIN ne correspondent pas');
        return false;
      }
    } else if (pin2.length > 0) {
      confirmPin.classList.add('invalid');
      return false;
    }

    createBtn.disabled = true;
    return false;
  }

  // Vérifier si le PIN est valide (pas trop simple)
  function isValidPin(pin) {
    // Interdire les PINs trop simples
    const forbidden = ['0000', '1111', '2222', '3333', '4444', '5555', '6666', '7777', '8888', '9999'];
    if (forbidden.includes(pin)) {
      return false;
    }

    // Vérifier si tous les chiffres sont identiques
    if (/^(\d)\1{3}$/.test(pin)) {
      return false;
    }

    return true;
  }

  // Créer le compte
  function createAccount() {
    const pin = newPin.value.trim();
    const confirmPinValue = confirmPin.value.trim();

    // Validation finale
    if (pin.length !== 4 || isNaN(pin)) {
      showError('Le PIN doit contenir exactement 4 chiffres');
      newPin.focus();
      return;
    }

    if (!isValidPin(pin)) {
      showError('Ce PIN est trop simple. Choisissez-en un autre.');
      newPin.focus();
      return;
    }

    if (pin !== confirmPinValue) {
      showError('Les codes PIN ne correspondent pas');
      confirmPin.focus();
      return;
    }

    // Désactiver le bouton pendant le traitement
    createBtn.disabled = true;
    createBtn.textContent = 'Création en cours...';

    // Envoyer au serveur
    window.KTBanque.postNUI('createAccount', { pin: pin })
      .then(() => {
        // Animation de succès
        newPin.classList.add('success-animation');
        confirmPin.classList.add('success-animation');
        
        // Réinitialiser après un court délai
        setTimeout(() => {
          clearForm();
        }, 1000);
      })
      .catch((error) => {
        console.error('Erreur création compte:', error);
        showError('Erreur lors de la création du compte');
        createBtn.disabled = false;
        createBtn.textContent = 'Créer le compte';
      });
  }

  // Afficher erreur
  function showError(message) {
    if (createError) {
      createError.textContent = message;
      createError.classList.remove('hidden');
      
      // Animation shake
      createError.classList.add('error-shake');
      setTimeout(() => {
        createError.classList.remove('error-shake');
      }, 500);
    }
  }

  // Masquer erreur
  function hideError() {
    if (createError) {
      createError.classList.add('hidden');
    }
  }

  // Réinitialiser le formulaire
  function clearForm() {
    newPin.value = '';
    confirmPin.value = '';
    newPin.classList.remove('valid', 'invalid', 'success-animation');
    confirmPin.classList.remove('valid', 'invalid', 'success-animation');
    hideError();
    createBtn.disabled = true;
    createBtn.textContent = 'Créer le compte';
  }

  // Event listeners
  createBtn.addEventListener('click', createAccount);

  newPin.addEventListener('input', function() {
    // Accepter uniquement les chiffres
    this.value = this.value.replace(/[^0-9]/g, '').slice(0, 4);
    validatePins();
  });

  confirmPin.addEventListener('input', function() {
    // Accepter uniquement les chiffres
    this.value = this.value.replace(/[^0-9]/g, '').slice(0, 4);
    validatePins();
  });

  // Enter pour valider
  newPin.addEventListener('keypress', function(e) {
    if (e.key === 'Enter' && this.value.length === 4) {
      confirmPin.focus();
    }
  });

  confirmPin.addEventListener('keypress', function(e) {
    if (e.key === 'Enter' && this.value.length === 4 && !createBtn.disabled) {
      createAccount();
    }
  });

  // Bouton annuler
  if (cancelCreateBtn) {
    cancelCreateBtn.addEventListener('click', function() {
      clearForm();
      window.KTBanque.postNUI('close', {});
      window.KTBanque.setUIVisible(false);
    });
  }

  // Focus automatique quand la page s'ouvre
  const observer = new MutationObserver((mutations) => {
    mutations.forEach((mutation) => {
      if (mutation.target.id === 'create-page' && mutation.target.classList.contains('active')) {
        setTimeout(() => {
          clearForm();
          newPin.focus();
        }, 100);
      }
    });
  });

  const createPage = document.getElementById('create-page');
  if (createPage) {
    observer.observe(createPage, {
      attributes: true,
      attributeFilter: ['class']
    });
  }

  // Désactiver le bouton par défaut
  createBtn.disabled = true;
});