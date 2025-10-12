-- ==================== KT BANQUE v7.0 - SCHÉMA SQL ====================

-- Table des comptes bancaires
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
  UNIQUE KEY `unique_identifier_active` (`identifier`, `active`),
  FOREIGN KEY (`account_id`) REFERENCES `banking`(`account_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des logs/historique
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
  INDEX `idx_identifier` (`identifier`),
  FOREIGN KEY (`account_id`) REFERENCES `banking`(`account_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==================== DONNÉES DE TEST (OPTIONNEL) ====================
-- Décommentez pour tester
/*
INSERT INTO `banking` (`account_id`, `identifier`, `balance`, `owner_name`, `label`) 
VALUES ('ACC_test_steam_110000000000000', 'steam:110000000000000', 10000.00, 'Jean Test', 'Compte Test');

INSERT INTO `bank_cards` (`identifier`, `account_id`, `card_number`, `pin`, `card_type`, `active`) 
VALUES ('steam:110000000000000', 'ACC_test_steam_110000000000000', '1234 5678 9012 3456', '1234', 'carte_basique', 1);

INSERT INTO `bank_logs` (`account_id`, `action`, `amount`, `identifier`, `description`)
VALUES ('ACC_test_steam_110000000000000', 'account_created', 0, 'steam:110000000000000', 'Création du compte test');
*/

-- ==================== VUES UTILES (OPTIONNEL) ====================

-- Vue des comptes actifs avec leurs cartes
CREATE OR REPLACE VIEW `v_active_accounts` AS
SELECT 
    b.account_id,
    b.identifier,
    b.balance,
    b.owner_name,
    b.label,
    c.card_number,
    c.card_type,
    c.active AS card_active,
    b.created_at
FROM `banking` b
LEFT JOIN `bank_cards` c ON b.account_id = c.account_id AND c.active = 1;

-- Vue des statistiques par compte
CREATE OR REPLACE VIEW `v_account_stats` AS
SELECT 
    b.account_id,
    b.owner_name,
    b.balance,
    COUNT(l.id) AS total_transactions,
    SUM(CASE WHEN l.action = 'deposit' THEN l.amount ELSE 0 END) AS total_deposits,
    SUM(CASE WHEN l.action = 'withdraw' THEN l.amount ELSE 0 END) AS total_withdraws,
    SUM(CASE WHEN l.action = 'transfer_out' THEN l.amount ELSE 0 END) AS total_transfers_out,
    SUM(CASE WHEN l.action = 'transfer_in' THEN l.amount ELSE 0 END) AS total_transfers_in
FROM `banking` b
LEFT JOIN `bank_logs` l ON b.account_id = l.account_id
GROUP BY b.account_id, b.owner_name, b.balance;

-- ==================== PROCÉDURES STOCKÉES (OPTIONNEL) ====================

DELIMITER $

-- Procédure pour nettoyer les anciens logs (> 6 mois)
CREATE PROCEDURE IF NOT EXISTS `sp_cleanup_old_logs`()
BEGIN
    DELETE FROM `bank_logs` 
    WHERE `date` < DATE_SUB(NOW(), INTERVAL 6 MONTH);
    
    SELECT ROW_COUNT() AS deleted_rows;
END$

-- Procédure pour obtenir le top 10 des comptes les plus riches
CREATE PROCEDURE IF NOT EXISTS `sp_get_richest_accounts`()
BEGIN
    SELECT 
        b.account_id,
        b.owner_name,
        b.balance,
        c.card_type
    FROM `banking` b
    LEFT JOIN `bank_cards` c ON b.account_id = c.account_id AND c.active = 1
    ORDER BY b.balance DESC
    LIMIT 10;
END$

-- Procédure pour calculer le solde total de tous les comptes
CREATE PROCEDURE IF NOT EXISTS `sp_get_total_economy`()
BEGIN
    SELECT 
        COUNT(*) AS total_accounts,
        SUM(balance) AS total_balance,
        AVG(balance) AS average_balance,
        MIN(balance) AS min_balance,
        MAX(balance) AS max_balance
    FROM `banking`;
END$

DELIMITER ;

-- ==================== TRIGGERS (OPTIONNEL) ====================

-- Trigger pour empêcher les soldes négatifs
DELIMITER $
CREATE TRIGGER IF NOT EXISTS `trg_prevent_negative_balance`
BEFORE UPDATE ON `banking`
FOR EACH ROW
BEGIN
    IF NEW.balance < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Le solde ne peut pas être négatif';
    END IF;
END$
DELIMITER ;

-- Trigger pour logger automatiquement les modifications de solde
DELIMITER $
CREATE TRIGGER IF NOT EXISTS `trg_log_balance_change`
AFTER UPDATE ON `banking`
FOR EACH ROW
BEGIN
    IF OLD.balance != NEW.balance THEN
        INSERT INTO `bank_logs` (`account_id`, `action`, `amount`, `identifier`, `description`)
        VALUES (
            NEW.account_id,
            IF(NEW.balance > OLD.balance, 'deposit', 'withdraw'),
            ABS(NEW.balance - OLD.balance),
            NEW.identifier,
            CONCAT('Modification automatique: ', OLD.balance, ' -> ', NEW.balance)
        );
    END IF;
END$
DELIMITER ;

-- ==================== INDEX SUPPLÉMENTAIRES POUR PERFORMANCE ====================

-- Index pour recherches fréquentes
ALTER TABLE `banking` ADD INDEX `idx_created_at` (`created_at`);
ALTER TABLE `bank_logs` ADD INDEX `idx_composite_account_date` (`account_id`, `date` DESC);

-- ==================== COMMENTAIRES ====================

ALTER TABLE `banking` COMMENT = 'Table principale des comptes bancaires';
ALTER TABLE `bank_cards` COMMENT = 'Table des cartes bancaires associées aux comptes';
ALTER TABLE `bank_logs` COMMENT = 'Historique des transactions bancaires';