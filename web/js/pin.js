// nui/js/pin.js
document.addEventListener("DOMContentLoaded", () => {
  const pinInput = document.getElementById("pinInput");
  const pinSubmit = document.getElementById("pinSubmit");
  const pinError = document.getElementById("pinError");

  if (!pinInput || !pinSubmit) return;

  pinSubmit.addEventListener("click", () => {
    const pin = pinInput.value.trim();
    if (pin.length !== 4 || isNaN(pin)) {
      pinError.textContent = "PIN invalide (4 chiffres)";
      pinError.classList.remove("hidden");
      return;
    }

    // Envoie le PIN au client pour ouverture
    fetch(`https://kt_banque/createAccount`, {
      method: "POST",
      body: JSON.stringify({ pin }),
    });

    document.getElementById("pin-screen").classList.add("hidden");
    document.getElementById("account-screen").classList.remove("hidden");
  });
});
