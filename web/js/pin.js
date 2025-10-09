document.addEventListener('DOMContentLoaded', function() {
  const pinInput = document.getElementById('pinInput');
  const pinSubmit = document.getElementById('pinSubmit');
  const pinCancel = document.getElementById('pinCancel');
  const pinError = document.getElementById('pinError');

  if (!pinInput || !pinSubmit) return;

  // Focus automatique sur l'input PIN
  const observer = new MutationObserver((mutations) => {
    mutations.forEach((mutation) => {
      if (mutation.target.id === 'pin-screen' && mutation.target.classList.contains('active')) {
        setTimeout(() => {
          pinInput.focus();
          pinInput.value = '';
          if (pinError) {
            pinError.classList.add('hidden');
          }
        }, 100);
      }
    });
  });

  const pinScreen = document.getElementById('pin-screen');
  if (pinScreen) {
    observer.observe(pinScreen, {
      attributes: true,
      attributeFilter: ['class']
    });
  }

  // Valider le PIN
  function validatePin() {
    const pin = pinInput.value.trim();
    
    if (pin.length !== 4) {
      showError('Le PIN doit contenir 4 chiffres');
      return;
    }
    
    if (isNaN(pin)) {
      showError('Le PIN doit contenir uniquement des chiffres');
      return;
    }

    // Envoyer au serveur pour validation
    window.KTBanque.postNUI('validatePin', { pin: pin })
      .then(() => {
        // Le serveur gèrera l'ouverture de l'interface
        hideError();
      })
      .catch(() => {
        showError('Erreur de connexion');
      });
  }

  // Afficher erreur
  function showError(message) {
    if (pinError) {
      pinError.textContent = message;
      pinError.classList.remove('hidden');
      pinInput.classList.add('error-shake');
      
      setTimeout(() => {
        pinInput.classList.remove('error-shake');
      }, 500);
    }
  }

  // Masquer erreur
  function hideError() {
    if (pinError) {
      pinError.classList.add('hidden');
    }
  }

  // Event listeners
  pinSubmit.addEventListener('click', validatePin);

  pinInput.addEventListener('keypress', function(e) {
    if (e.key === 'Enter') {
      validatePin();
    }
  });

  // Accepter uniquement les chiffres
  pinInput.addEventListener('input', function(e) {
    this.value = this.value.replace(/[^0-9]/g, '').slice(0, 4);
    hideError();
  });

  // Bouton annuler
  if (pinCancel) {
    pinCancel.addEventListener('click', function() {
      window.KTBanque.postNUI('close', {});
      window.KTBanque.setUIVisible(false);
    });
  }
});