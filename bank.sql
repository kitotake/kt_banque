-- ==================== KT BANQUE v7.4 SUPPORT UNION - SCHÉMA SQL ====================

-- ============================================
-- BANK ACCOUNTS (KT Banque v7.4 + Union)
-- ============================================
CREATE TABLE IF NOT EXISTS `bank_accounts` (
    `id`               INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `account_number`   VARCHAR(10)  NOT NULL,
    `unique_id`        VARCHAR(36)  NOT NULL,
    `owner_identifier` VARCHAR(60)  NOT NULL,

    `label`    VARCHAR(100) DEFAULT 'Compte Personnel',
    `type`     ENUM('personal','business','shared') DEFAULT 'personal',
    `balance`  BIGINT       NOT NULL DEFAULT 0,
    `status`   ENUM('active','suspended','closed') DEFAULT 'active',

    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_account_number` (`account_number`),
    INDEX `idx_unique_id` (`unique_id`),
    INDEX `idx_owner` (`owner_identifier`),

    CONSTRAINT `fk_bankaccount_char`
        FOREIGN KEY (`unique_id`)
        REFERENCES `characters` (`unique_id`)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- BANK TRANSACTIONS (KT Banque v7.4)
-- ============================================
CREATE TABLE IF NOT EXISTS `bank_transactions` (
    `id`                INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `account_id`        INT UNSIGNED NOT NULL,
    `transaction_uuid`  VARCHAR(36)  NOT NULL,
    `type`              ENUM('deposit','withdraw','transfer_in','transfer_out','admin') NOT NULL,
    `amount`            BIGINT       NOT NULL,
    `balance_after`     BIGINT       NOT NULL,
    `description`       VARCHAR(255) DEFAULT NULL,
    `source_identifier` VARCHAR(60)  DEFAULT NULL,
    `target_account_id` INT UNSIGNED DEFAULT NULL,
    `created_at`        TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_transaction_uuid` (`transaction_uuid`),
    INDEX `idx_account` (`account_id`),
    INDEX `idx_account_date` (`account_id`, `created_at` DESC),

    CONSTRAINT `fk_transaction_account`
        FOREIGN KEY (`account_id`)
        REFERENCES `bank_accounts` (`id`)
        ON DELETE CASCADE,

    CONSTRAINT `fk_transaction_target`
        FOREIGN KEY (`target_account_id`)
        REFERENCES `bank_accounts` (`id`)
        ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- BANK CARDS (KT Banque v7.4)
-- ============================================
CREATE TABLE IF NOT EXISTS `bank_cards` (
    `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `account_id`  INT UNSIGNED NOT NULL,
    `unique_id`   VARCHAR(36)  NOT NULL,
    `card_number` VARCHAR(19)  NOT NULL,
    `pin`         CHAR(4)      NOT NULL,
    `type`        ENUM('basic','gold','diamond') DEFAULT 'basic',
    `active`      TINYINT(1)   DEFAULT 1,
    `expires_at`  DATE         NOT NULL,
    `created_at`  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_card_number` (`card_number`),
    INDEX `idx_account` (`account_id`),

    CONSTRAINT `fk_card_account`
        FOREIGN KEY (`account_id`)
        REFERENCES `bank_accounts` (`id`)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- BANK LIMITS (KT Banque v7.4)
-- ============================================
CREATE TABLE IF NOT EXISTS `bank_limits` (
    `account_id`    INT UNSIGNED NOT NULL,
    `deposit_today`  BIGINT DEFAULT 0,
    `withdraw_today` BIGINT DEFAULT 0,
    `last_reset`    DATE NOT NULL,

    PRIMARY KEY (`account_id`),

    CONSTRAINT `fk_limit_account`
        FOREIGN KEY (`account_id`)
        REFERENCES `bank_accounts` (`id`)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- BANK LOGS (KT Banque v7.4)
-- ============================================
CREATE TABLE IF NOT EXISTS `bank_logs` (
    `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `unique_id`  VARCHAR(36)  NOT NULL,
    `action`     VARCHAR(255) NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    INDEX `idx_unique_id` (`unique_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;