-- amélioration 5.0.0

-- Table principale des comptes bancaires
CREATE TABLE IF NOT EXISTS banking (
  ID INT AUTO_INCREMENT PRIMARY KEY,
  identifier VARCHAR(46) NOT NULL,
  type VARCHAR(50) DEFAULT 'personal',
  amount INT DEFAULT 0,
  balance INT DEFAULT 0,
  label VARCHAR(255),
  time BIGINT(20) DEFAULT NULL,
  INDEX idx_identifier (identifier)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des cartes bancaires
CREATE TABLE IF NOT EXISTS bank_cards (
  id INT AUTO_INCREMENT PRIMARY KEY,
  account_id INT NOT NULL,
  identifier VARCHAR(64) NOT NULL,
  owner_name VARCHAR(64),
  card_number VARCHAR(16) UNIQUE,
  pin VARCHAR(8) NOT NULL,
  expires VARCHAR(8) DEFAULT NULL,
  active BOOLEAN DEFAULT TRUE,
  card_type VARCHAR(50) DEFAULT 'carte_basique',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (account_id) REFERENCES banking(ID) ON DELETE CASCADE,
  INDEX idx_account (account_id),
  INDEX idx_identifier (identifier),
  INDEX idx_active (active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des logs bancaires
CREATE TABLE IF NOT EXISTS bank_logs (
  id INT AUTO_INCREMENT PRIMARY KEY,
  account_id INT NOT NULL,
  action VARCHAR(50),
  amount INT,
  identifier VARCHAR(64),
  description VARCHAR(255),
  date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (account_id) REFERENCES banking(ID) ON DELETE CASCADE,
  INDEX idx_account_date (account_id, date DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;