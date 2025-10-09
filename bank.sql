-- Table principale des comptes bancaires
CREATE TABLE IF NOT EXISTS banking (
  ID INT AUTO_INCREMENT PRIMARY KEY,
  identifier VARCHAR(46) NOT NULL,
  type VARCHAR(50) DEFAULT 'personal',
  amount INT DEFAULT 0,
  balance INT DEFAULT 0,
  label VARCHAR(255),
  time BIGINT(20) DEFAULT NULL
);

-- Table des cartes bancaires
CREATE TABLE IF NOT EXISTS bank_cards (
  id INT AUTO_INCREMENT PRIMARY KEY,
  account_id INT NOT NULL,
  identifier VARCHAR(64) NOT NULL,
  owner_name VARCHAR(64),
  card_number VARCHAR(16) UNIQUE,
  pin VARCHAR(8),
  expires VARCHAR(8) DEFAULT NULL,
  active BOOLEAN DEFAULT TRUE,
  FOREIGN KEY (account_id) REFERENCES banking(ID) ON DELETE CASCADE
);

-- Table des logs bancaires
CREATE TABLE IF NOT EXISTS bank_logs (
  id INT AUTO_INCREMENT PRIMARY KEY,
  account_id INT NOT NULL,
  action VARCHAR(50),
  amount INT,
  identifier VARCHAR(64),
  description VARCHAR(255),
  date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (account_id) REFERENCES banking(ID) ON DELETE CASCADE
);
