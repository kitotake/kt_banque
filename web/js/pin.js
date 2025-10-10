// pin.js — Gestion de la vérification du code PIN (version pages séparées)
document.addEventListener('DOMContentLoaded', function() {
  const pinInput = document.getElementById('pinInput');
  const pinSubmit = document.getElementById('pinSubmit');
  const pinCancel = document.getElementById('pinCancel');
  const pinError = document.getElementById('pinError');

  if (!pinInput || !pinSubmit) {
    console.error('[KT Banque] Éléments PIN manquants');
    return;
  }

  // Focus automatique sur le champ PIN
  setTimeout(() => {
    pinInput.focus();
  }, 200);

  // Fonction principale : valider le PIN
  function validatePin() {
    const pin = pinInput.value.trim();
    const storedPIN = localStorage.getItem('userPIN');

    console.log('[KT Banque] Validation PIN...');

    // Vérification du format
    if (pin.length !== 4 || isNaN(pin)) {
      showError('Le PIN doit contenir 4 chiffres');
      return;
    }

    // Vérifier la correspondance
    if (pin === storedPIN) {
      console.log('[KT Banque] PIN correct, accès autorisé');
      hideError();

      // Redirection vers la page principale (dashboard)
      window.location.href = 'index.html';
    } else {
      console.log('[KT Banque] PIN incorrect');
      showError('❌ Code PIN incorrect');
    }
  }

  // Fonction d'affichage d'erreur
  function showError(message) {
    if (pinError) {
      pinError.textContent = message;
      pinError.classList.remove('hidden');

      // Animation visuelle
      pinInput.classList.add('error-shake');
      setTimeout(() => pinInput.classList.remove('error-shake'), 400);
    }
  }

  // Fonction pour masquer l'erreur
  function hideError() {
    if (pinError) pinError.classList.add('hidden');
  }

  // Bouton "Valider"
  pinSubmit.addEventListener('click', function() {
    console.log('[KT Banque] Bouton Valider cliqué');
    validatePin();
  });

  // Touche "Entrée" dans l'input
  pinInput.addEventListener('keypress', function(e) {
    if (e.key === 'Enter') {
      validatePin();
    }
  });

  // Forcer les chiffres uniquement (max 4)
  pinInput.addEventListener('input', function() {
    this.value = this.value.replace(/[^0-9]/g, '').slice(0, 4);
    hideError();
  });

  // Bouton "Annuler"
  if (pinCancel) {
    pinCancel.addEventListener('click', function() {
      console.log('[KT Banque] Bouton Annuler cliqué');
      window.location.href = 'index.html'; // Retour à l'accueil
    });
  }

  console.log('[KT Banque] pin.js chargé — version pages séparées');
});
