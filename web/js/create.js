// create.js — Gestion de la création de compte (version pages séparées)

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

    newPin.classList.remove('valid', 'invalid');
    confirmPin.classList.remove('valid', 'invalid');
    hideError();

    // Validation du premier PIN
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

    // Validation de la confirmation
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

  // Vérifie si le PIN n’est pas trop simple
  function isValidPin(pin) {
    const forbidden = [
      '0000','1111','2222','3333','4444','5555','6666','7777','8888','9999',
      '1234','4321','2468','1357'
    ];
    return !(forbidden.includes(pin) || /^(\d)\1{3}$/.test(pin));
  }

  // Création du compte
  function createAccount() {
    const pin = newPin.value.trim();
    const confirmPinValue = confirmPin.value.trim();

    if (pin.length !== 4 || isNaN(pin)) {
      showError('Le PIN doit contenir exactement 4 chiffres.');
      return;
    }

    if (!isValidPin(pin)) {
      showError('Ce PIN est trop simple. Choisissez-en un autre.');
      return;
    }

    if (pin !== confirmPinValue) {
      showError('Les codes PIN ne correspondent pas.');
      return;
    }

    createBtn.disabled = true;
    createBtn.textContent = 'Création en cours...';

    // Enregistrement local (simule une création de compte)
    localStorage.setItem('userPIN', pin);
    localStorage.setItem('balance', '1000'); // solde initial
    alert('✅ Compte créé avec succès !');

    // Redirection vers la page principale
    setTimeout(() => {
      window.location.href = 'index.html';
    }, 500);
  }

  // Affiche une erreur
  function showError(message) {
    if (createError) {
      createError.textContent = message;
      createError.classList.remove('hidden');
      createError.classList.add('error-shake');
      setTimeout(() => createError.classList.remove('error-shake'), 500);
    }
  }

  // Cache l’erreur
  function hideError() {
    if (createError) createError.classList.add('hidden');
  }

  // Réinitialise le formulaire
  function clearForm() {
    newPin.value = '';
    confirmPin.value = '';
    newPin.classList.remove('valid', 'invalid', 'success-animation');
    confirmPin.classList.remove('valid', 'invalid', 'success-animation');
    hideError();
    createBtn.disabled = true;
    createBtn.textContent = 'Créer le compte';
  }

  // Événements
  createBtn.addEventListener('click', createAccount);

  newPin.addEventListener('input', function() {
    this.value = this.value.replace(/[^0-9]/g, '').slice(0, 4);
    validatePins();
  });

  confirmPin.addEventListener('input', function() {
    this.value = this.value.replace(/[^0-9]/g, '').slice(0, 4);
    validatePins();
  });

  // Touche Entrée
  newPin.addEventListener('keypress', (e) => {
    if (e.key === 'Enter' && newPin.value.length === 4) confirmPin.focus();
  });

  confirmPin.addEventListener('keypress', (e) => {
    if (e.key === 'Enter' && confirmPin.value.length === 4 && !createBtn.disabled) {
      createAccount();
    }
  });

  // Bouton Annuler
  if (cancelCreateBtn) {
    cancelCreateBtn.addEventListener('click', () => {
      clearForm();
      window.location.href = 'index.html';
    });
  }

  // Focus auto
  setTimeout(() => {
    newPin.focus();
  }, 100);

  createBtn.disabled = true;
  console.log('[KT Banque] create.js chargé — version pages séparées');
});
