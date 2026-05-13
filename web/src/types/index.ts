// ==================== KT BANQUE v7.5.0 - TYPES ====================
// CORRECTIONS v7.5.0 :
//   FIX-1 : CardType aligné avec config.lua (card_basic / card_gold / card_diamond).
//   FIX-2 : AccountData — pin_hash explicitement requis (envoyé par le serveur).
//   FIX-3 : NUIMessage étendu (showCardStatus, cardRecoverFailed, cardRecoverSuccess).
//   FIX-4 : CardStatus ajouté pour le composant CardRecovery.

export type CardType = 'card_basic' | 'card_gold' | 'card_diamond';

export type TransactionType =
  | 'deposit'
  | 'withdraw'
  | 'transfer_out'
  | 'transfer_in'
  | 'account_created'
  | 'card_issued'
  | 'admin';

export type NotificationType = 'success' | 'error' | 'warning' | 'info';
export type AppPage = 'pin' | 'create' | 'dashboard' | 'card_recovery';

export interface CardMeta {
  id: number;
  card_number: string;
  card_type: CardType;
  owner: string;
  active: number;
}

export interface AccountInfo {
  label: string;
  created: string;
}

export interface CardLimits {
  MaxDeposit: number;
  MaxWithdraw: number;
  Price: number;
  DisplayName: string;
}

export interface Transaction {
  id: number;
  account_id: string;
  action: TransactionType;
  amount: number;
  balance_after?: number;
  description: string;
  date: string;
}

// FIX-2 : pin_hash requis — envoyé par Bank.Open côté serveur
export interface AccountData {
  account_id: string;
  balance: number;
  /** Hash SHA-like du PIN — jamais le PIN brut */
  pin_hash: string;
  requiresPin: boolean;
  card_meta: CardMeta;
  account_info: AccountInfo;
  limits: CardLimits;
  history: Transaction[];
}

// FIX-4 : statut carte pour le composant CardRecovery
export interface CardStatus {
  status: 'active' | 'blocked';
  accountNumber: string;
  balance: number;
  recoveryCost: number;
  expires_at: string;
  meta_blocked?: boolean;
  meta_owner?: string;
}

// FIX-3 : NUIMessage complet
export type NUIAction =
  | 'openBank'
  | 'openCreate'
  | 'updateBalance'
  | 'close'
  | 'showCardStatus'
  | 'cardRecoverFailed'
  | 'cardRecoverSuccess';

export interface NUIMessage {
  action: NUIAction;
  data?: AccountData | number | CardStatus;
  balance?: number;
  status?: string;
  accountNumber?: string;
  recoveryCost?: number;
  expires_at?: string;
  reason?: string;
  meta_blocked?: boolean;
  meta_owner?: string;
}

export interface NUIPayload {
  amount?: number;
  pinHash?: string;
  target?: string;
  pin?: string;
}
