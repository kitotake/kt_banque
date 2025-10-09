// nui/js/create.js
document.addEventListener("DOMContentLoaded", () => {
  const createBtn = document.getElementById("createBtn");
  const cancelBtn = document.getElementById("cancelBtn");
  const newPin = document.getElementById("newPin");
  const errorMsg = document.getElementById("createError");

  createBtn?.addEventListener("click", () => {
    const pin = newPin.value.trim();
    if (pin.length !== 4 || isNaN(pin)) {
      errorMsg.textContent = "PIN invalide (4 chiffres)";
      errorMsg.classList.remove("hidden");
      return;
    }

    fetch(`https://kt_banque/createAccount`, {
      method: "POST",
      body: JSON.stringify({ pin }),
    });
  });

  cancelBtn?.addEventListener("click", () => {
    fetch(`https://kt_banque/close`, { method: "POST" });
  });
});
