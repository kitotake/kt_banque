// ==================== KT BANQUE v7.4.1 - TYPES ====================
// FIX: CardType aligné avec config.lua (card_basic / card_gold / card_diamond)

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
export type AppPage = 'pin' | 'create' | 'dashboard';

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

export interface AccountData {
  account_id: string;
  balance: number;
  /** Hash du PIN — jamais le PIN brut */
  pin_hash: string;
  requiresPin: boolean;
  card_meta: CardMeta;
  account_info: AccountInfo;
  limits: CardLimits;
  history: Transaction[];
}

export interface NUIMessage {
  action: 'openBank' | 'openCreate' | 'updateBalance' | 'close';
  data?: AccountData | number;
  balance?: number;
}

export interface NUIPayload {
  amount?: number;
  pinHash?: string;
  target?: string;
  pin?: string;
}
