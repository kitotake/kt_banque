BankNotifications = {}

-----------------------------------
-- 📢 NOTIFICATION SUCCESS
-----------------------------------
function BankNotifications.success(description)
    lib.notify({
        title = "Succès",
        description = description,
        type = "success",
        duration = 5000
    })
end

-----------------------------------
-- ❌ NOTIFICATION ERROR
-----------------------------------
function BankNotifications.error(description)
    lib.notify({
        title = "Erreur",
        description = description,
        type = "error",
        duration = 5000
    })
end

-----------------------------------
-- ℹ️ NOTIFICATION INFO
-----------------------------------
function BankNotifications.info(description)
    lib.notify({
        title = "Information",
        description = description,
        type = "info",
        duration = 5000
    })
end

-----------------------------------
-- ⚠️ NOTIFICATION WARNING
-----------------------------------
function BankNotifications.warning(description)
    lib.notify({
        title = "Attention",
        description = description,
        type = "warning",
        duration = 5000
    })
end

print('^2[KT Banque]^7 Notifications chargées')