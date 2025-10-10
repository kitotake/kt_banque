BankMenu = {}

-----------------------------------
-- 📋 MENU PRINCIPAL (OPTIONNEL)
-----------------------------------
-- Ce fichier peut contenir des menus supplémentaires si nécessaire
-- Par exemple: menu de gestion avancée, historique détaillé, etc.

-- Exemple de menu avancé (désactivé par défaut)
function BankMenu.openAdvancedMenu()
    local options = {
        {
            title = "🏧 Ouvrir ATM",
            description = "Accéder à votre compte bancaire",
            icon = "building-columns",
            onSelect = function()
                TriggerServerEvent('bank:server:requestOpen')
            end
        },
        {
            title = "📊 Voir mon historique",
            description = "Consulter les dernières transactions",
            icon = "clock-rotate-left",
            onSelect = function()
                -- À implémenter si besoin
                BankNotifications.info("Fonctionnalité à venir")
            end
        }
    }
    
    lib.registerContext({
        id = 'bank_advanced_menu',
        title = '🏦 Menu Bancaire',
        options = options
    })
    
    lib.showContext('bank_advanced_menu')
end

-- Commande pour ouvrir le menu avancé (optionnel)
RegisterCommand('bankmenu', function()
    BankMenu.openAdvancedMenu()
end, false)

print('^2[KT Banque]^7 Menu bancaire chargé')