// nui/js/main.js
window.addEventListener("message", function (event) {
  const data = event.data;

  switch (data.action) {
    case "openPin":
      document.getElementById("pin-screen")?.classList.remove("hidden");
      document.getElementById("loading")?.classList.add("hidden");
      break;

    case "updateBalance":
      updateBalanceUI(data.balance);
      break;

    case "openATM":
      openAtmUI(data);
      break;

    default:
      console.log("NUI: action inconnue", data.action);
      break;
  }
});

// Fermer l'UI (ESC)
document.addEventListener("keydown", (e) => {
  if (e.key === "Escape") {
    fetch(`https://kt_banque/close`, { method: "POST" });
  }
});

function closeAllScreens() {
  document.querySelectorAll(".screen").forEach((el) => el.classList.add("hidden"));
}

// Helper pour mettre à jour solde (utilisé par account.js et atm)
function updateBalanceUI(balance) {
  const el1 = document.getElementById("balance");
  const el2 = document.getElementById("atmBalance");
  if (el1) el1.textContent = `$${balance.toLocaleString()}`;
  if (el2) el2.textContent = `$${balance.toLocaleString()}`;
}

// Afficher UI ATM (si tu veux ouvrir une page séparée ou une div dédiée)
function openAtmUI(payload) {
  closeAllScreens();
  const atm = document.getElementById("atm-screen");
  if (!atm) return;
  atm.classList.remove("hidden");
  updateBalanceUI(payload.balance || 0);
  document.getElementById("depositLimit").textContent = `$${payload.limits?.MaxDeposit || 0}`;
  document.getElementById("withdrawLimit").textContent = `$${payload.limits?.MaxWithdraw || 0}`;
}
