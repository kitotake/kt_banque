-- ==================== KT BANQUE - SCHÉMA SQL ====================

-- Table principale des comptes bancaires
CREATE TABLE IF NOT EXISTS `banking` (
  `account_id` VARCHAR(100) NOT NULL PRIMARY KEY,
  `identifier` VARCHAR(60) NOT NULL,
  `balance` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  `owner_name` VARCHAR(100) NOT NULL,
  `label` VARCHAR(100) DEFAULT 'Compte Personnel',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_identifier` (`identifier`),
  INDEX `idx_balance` (`balance`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des cartes bancaires
CREATE TABLE IF NOT EXISTS `bank_cards` (
  `id` INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `identifier` VARCHAR(60) NOT NULL,
  `account_id` VARCHAR(100) NOT NULL,
  `card_number` VARCHAR(20) NOT NULL,
  `pin` VARCHAR(4) NOT NULL,
  `card_type` ENUM('carte_basique', 'carte_or', 'carte_dimas') DEFAULT 'carte_basique',
  `active` TINYINT(1) DEFAULT 1,
  `issued_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_identifier` (`identifier`),
  INDEX `idx_account` (`account_id`),
  INDEX `idx_active` (`active`),
  UNIQUE KEY `unique_identifier` (`identifier`),
  FOREIGN KEY (`account_id`) REFERENCES `banking`(`account_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des logs / historique
CREATE TABLE IF NOT EXISTS `bank_logs` (
  `id` INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `account_id` VARCHAR(100) NOT NULL,
  `action` ENUM('deposit', 'withdraw', 'transfer_in', 'transfer_out', 'account_created', 'card_issued') NOT NULL,
  `amount` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  `identifier` VARCHAR(60) NOT NULL,
  `description` TEXT DEFAULT NULL,
  `date` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_account` (`account_id`),
  INDEX `idx_action` (`action`),
  INDEX `idx_date` (`date`),
  FOREIGN KEY (`account_id`) REFERENCES `banking`(`account_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des transactions en attente (optionnel)
CREATE TABLE IF NOT EXISTS `bank_pending_transactions` (
  `id` INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `from_account` VARCHAR(100) NOT NULL,
  `to_account` VARCHAR(100) NOT NULL,
  `amount` DECIMAL(15,2) NOT NULL,
  `status` ENUM('pending', 'completed', 'failed') DEFAULT 'pending',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `completed_at` TIMESTAMP NULL DEFAULT NULL,
  INDEX `idx_from` (`from_account`),
  INDEX `idx_to` (`to_account`),
  INDEX `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==================== DONNÉES DE TEST (OPTIONNEL) ====================

-- Exemple de compte test (à supprimer en production)
-- INSERT INTO `banking` (`account_id`, `identifier`, `balance`, `owner_name`, `label`) 
-- VALUES ('ACC_test', 'steam:110000000000000', 5000.00, 'John Doe', 'Compte Test');

-- INSERT INTO `bank_cards` (`identifier`, `account_id`, `card_number`, `pin`, `card_type`, `active`) 
-- VALUES ('steam:110000000000000', 'ACC_test', '1234 5678 9012 3456', '1234', 'carte_basique', 1);