// ==================== KT BANQUE - TYPES ====================

export type CardType = 'carte_basique' | 'carte_or' | 'carte_dimas';
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
  identifier: string;
  description: string;
  date: string;
  balance_after?: number;
}

export interface AccountData {
  account_id: string;
  balance: number;
  pin: string;
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
  cardId?: number;
  pin?: string;
  target?: string;
}
