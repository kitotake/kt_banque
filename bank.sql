-- ==================== KT BANQUE v7.1 - SCHÉMA SQL ====================

CREATE TABLE IF NOT EXISTS `bank_accounts` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,

  `account_number` VARCHAR(20) NOT NULL UNIQUE,
  `unique_id` VARCHAR(36) NOT NULL,

  `label` VARCHAR(100) DEFAULT 'Compte Personnel',

  `type` ENUM('personal','business','shared') DEFAULT 'personal',

  `balance` BIGINT NOT NULL DEFAULT 0,

  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),

  INDEX `idx_unique_id` (`unique_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


CREATE TABLE IF NOT EXISTS `bank_transactions` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,

  `account_id` INT UNSIGNED NOT NULL,
  `unique_id` VARCHAR(36) NOT NULL,

  `type` ENUM('deposit','withdraw','transfer_in','transfer_out','admin') NOT NULL,

  `amount` BIGINT NOT NULL,
  `balance_after` BIGINT NOT NULL,

  `description` VARCHAR(255) DEFAULT NULL,

  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),

  INDEX `idx_account` (`account_id`),
  INDEX `idx_unique_id` (`unique_id`),
  INDEX `idx_date` (`created_at`),

  CONSTRAINT `fk_bank_account`
    FOREIGN KEY (`account_id`)
    REFERENCES `bank_accounts` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


CREATE TABLE IF NOT EXISTS `bank_cards` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,

  `account_id` INT UNSIGNED NOT NULL,
  `unique_id` VARCHAR(36) NOT NULL,

  `card_number` VARCHAR(19) NOT NULL UNIQUE,
  `pin` VARCHAR(4) NOT NULL,

  `type` ENUM('basic','gold','platinum') DEFAULT 'basic',

  `active` TINYINT(1) DEFAULT 1,

  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),

  INDEX `idx_account` (`account_id`),
  INDEX `idx_unique_id` (`unique_id`),

  CONSTRAINT `fk_card_account`
    FOREIGN KEY (`account_id`)
    REFERENCES `bank_accounts` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;



CREATE TABLE IF NOT EXISTS `bank_limits` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,

  `unique_id` VARCHAR(36) NOT NULL,

  `deposit_today` BIGINT DEFAULT 0,
  `withdraw_today` BIGINT DEFAULT 0,

  `last_reset` DATE NOT NULL,

  PRIMARY KEY (`id`),

  INDEX `idx_unique_id` (`unique_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;