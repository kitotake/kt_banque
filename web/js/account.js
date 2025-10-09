// nui/js/account.js
document.addEventListener("DOMContentLoaded", () => {
  const depositBtn = document.getElementById("depositBtn");
  const withdrawBtn = document.getElementById("withdrawBtn");
  const transferBtn = document.getElementById("transferBtn");
  const closeBtn = document.getElementById("closeBtn");

  // Fermer l’UI
  closeBtn?.addEventListener("click", () => {
    fetch(`https://kt_banque/close`, { method: "POST" });
  });

  // Dépôt
  depositBtn?.addEventListener("click", () => {
    const amount = parseFloat(document.getElementById("depositAmount").value);
    const pin = prompt("Entrez votre PIN :");
    fetch(`https://kt_banque/deposit`, {
      method: "POST",
      body: JSON.stringify({ amount, pin }),
    });
  });

  // Retrait
  withdrawBtn?.addEventListener("click", () => {
    const amount = parseFloat(document.getElementById("withdrawAmount").value);
    const pin = prompt("Entrez votre PIN :");
    fetch(`https://kt_banque/withdraw`, {
      method: "POST",
      body: JSON.stringify({ amount, pin }),
    });
  });

  // Transfert
  transferBtn?.addEventListener("click", () => {
    const amount = parseFloat(document.getElementById("transferAmount").value);
    const target = document.getElementById("transferTarget").value;
    const pin = prompt("Entrez votre PIN :");
    fetch(`https://kt_banque/transfer`, {
      method: "POST",
      body: JSON.stringify({ amount, target, pin }),
    });
  });
});
