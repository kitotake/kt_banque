-- ==================== KT BANQUE v7.5.0 — MIGRATION SQL ====================

CREATE TABLE IF NOT EXISTS `bank_accounts` (
    `id`               INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `account_number`   VARCHAR(12)  NOT NULL,
    `unique_id`        VARCHAR(36)  NOT NULL,
    `owner_identifier` VARCHAR(60)  NOT NULL,
    `iban`             VARCHAR(34)  NOT NULL UNIQUE,
    `label`            VARCHAR(100) DEFAULT 'Compte Personnel',
    `type`             ENUM('personal','business','shared') DEFAULT 'personal',
    `balance`          BIGINT       NOT NULL DEFAULT 0,
    `status`           ENUM('active','suspended','closed') DEFAULT 'active',
    `created_at`       TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    `updated_at`       TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_account_number` (`account_number`),
    UNIQUE KEY `uk_unique_id` (`unique_id`),
    INDEX `idx_owner` (`owner_identifier`),
    INDEX `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `bank_transactions` (
    `id`                INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `account_id`        INT UNSIGNED NOT NULL,
    `transaction_uuid`  VARCHAR(36)  NOT NULL,
    `type`              ENUM('deposit','withdraw','transfer_in','transfer_out','admin','account_created','card_issued') NOT NULL,
    `amount`            BIGINT       NOT NULL DEFAULT 0,
    `balance_after`     BIGINT       NOT NULL DEFAULT 0,
    `description`       VARCHAR(255) DEFAULT NULL,
    `source_identifier` VARCHAR(60)  DEFAULT NULL,
    `target_account_id` INT UNSIGNED DEFAULT NULL,
    `created_at`        TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_transaction_uuid` (`transaction_uuid`),
    INDEX `idx_account` (`account_id`),
    INDEX `idx_account_date` (`account_id`, `created_at` DESC),
    CONSTRAINT `fk_transaction_account`
        FOREIGN KEY (`account_id`) REFERENCES `bank_accounts` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_transaction_target`
        FOREIGN KEY (`target_account_id`) REFERENCES `bank_accounts` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `bank_cards` (
    `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `account_id`  INT UNSIGNED NOT NULL,
    `unique_id`   VARCHAR(36)  NOT NULL,
    `card_number` VARCHAR(19)  NOT NULL,
    `pin_hash`    VARCHAR(64)  NOT NULL,
    `type`        ENUM('card_basic','card_gold','card_diamond') DEFAULT 'card_basic',
    `active`      TINYINT(1)   DEFAULT 1,
    `expires_at`  DATE         NOT NULL,
    `created_at`  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    `updated_at`  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_card_number` (`card_number`),
    INDEX `idx_account` (`account_id`),
    INDEX `idx_unique_id` (`unique_id`),
    CONSTRAINT `fk_card_account`
        FOREIGN KEY (`account_id`) REFERENCES `bank_accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE `bank_cards`
    ADD COLUMN IF NOT EXISTS `updated_at` TIMESTAMP
        DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        AFTER `created_at`;

CREATE TABLE IF NOT EXISTS `bank_limits` (
    `account_id`     INT UNSIGNED NOT NULL,
    `deposit_today`  BIGINT       DEFAULT 0,
    `withdraw_today` BIGINT       DEFAULT 0,
    `last_reset`     DATE         NOT NULL,
    PRIMARY KEY (`account_id`),
    CONSTRAINT `fk_limit_account`
        FOREIGN KEY (`account_id`) REFERENCES `bank_accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `bank_logs` (
    `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `unique_id`  VARCHAR(36)  NOT NULL,
    `action`     VARCHAR(255) NOT NULL,
    `details`    TEXT         DEFAULT NULL,
    `created_at` TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_unique_id` (`unique_id`),
    INDEX `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
