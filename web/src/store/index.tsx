// ==================== KT BANQUE v7.5.0 - STORE ====================
// CORRECTIONS v7.5.0 :
//   FIX-1 : Actions SHOW_CARD_STATUS / CARD_RECOVER_SUCCESS / CARD_RECOVER_FAILED ajoutées.
//   FIX-2 : cardStatus dans AppState pour le composant CardRecovery.
//   FIX-3 : Page 'card_recovery' ajoutée dans AppPage.

import { createContext, useContext, useReducer, ReactNode } from 'react';
import { AccountData, AppPage, NotificationType, CardStatus } from '../types';

export interface Notification {
  id: string;
  type: NotificationType;
  message: string;
}

export interface AppState {
  page: AppPage | null;
  isOpen: boolean;
  accountData: AccountData | null;
  notifications: Notification[];
  isLoading: boolean;
  // FIX-2 : état card recovery
  cardStatus: CardStatus | null;
  cardRecoverLoading: boolean;
  cardRecoverError: string | null;
}

type Action =
  | { type: 'OPEN_BANK';             payload: AccountData }
  | { type: 'OPEN_CREATE' }
  | { type: 'CLOSE' }
  | { type: 'GO_TO_DASHBOARD' }
  | { type: 'UPDATE_BALANCE';        payload: number }
  | { type: 'PUSH_NOTIF';            payload: Notification }
  | { type: 'REMOVE_NOTIF';          payload: string }
  | { type: 'SET_LOADING';           payload: boolean }
  // FIX-1 : card recovery actions
  | { type: 'SHOW_CARD_STATUS';      payload: CardStatus }
  | { type: 'CARD_RECOVER_SUCCESS' }
  | { type: 'CARD_RECOVER_FAILED';   payload: string }
  | { type: 'CARD_RECOVER_LOADING' };

const initial: AppState = {
  page              : null,
  isOpen            : false,
  accountData       : null,
  notifications     : [],
  isLoading         : false,
  cardStatus        : null,
  cardRecoverLoading: false,
  cardRecoverError  : null,
};

function reducer(state: AppState, action: Action): AppState {
  switch (action.type) {

    case 'OPEN_BANK':
      return {
        ...state,
        isOpen     : true,
        page       : action.payload.requiresPin ? 'pin' : 'dashboard',
        accountData: action.payload,
      };

    case 'OPEN_CREATE':
      return { ...state, isOpen: true, page: 'create', accountData: null };

    case 'CLOSE':
      return { ...initial };

    case 'GO_TO_DASHBOARD':
      return { ...state, page: 'dashboard' };

    case 'UPDATE_BALANCE':
      if (!state.accountData) return state;
      return {
        ...state,
        accountData: { ...state.accountData, balance: action.payload },
      };

    case 'PUSH_NOTIF':
      return { ...state, notifications: [...state.notifications, action.payload] };

    case 'REMOVE_NOTIF':
      return {
        ...state,
        notifications: state.notifications.filter((n) => n.id !== action.payload),
      };

    case 'SET_LOADING':
      return { ...state, isLoading: action.payload };

    // FIX-1 : card recovery reducers
    case 'SHOW_CARD_STATUS':
      return {
        ...state,
        cardStatus        : action.payload,
        cardRecoverLoading: false,
        cardRecoverError  : null,
      };

    case 'CARD_RECOVER_LOADING':
      return { ...state, cardRecoverLoading: true, cardRecoverError: null };

    case 'CARD_RECOVER_SUCCESS':
      return {
        ...state,
        cardRecoverLoading: false,
        cardRecoverError  : null,
        cardStatus        : state.cardStatus
          ? { ...state.cardStatus, status: 'active' }
          : null,
      };

    case 'CARD_RECOVER_FAILED':
      return {
        ...state,
        cardRecoverLoading: false,
        cardRecoverError  : action.payload,
      };

    default:
      return state;
  }
}

interface CtxValue {
  state   : AppState;
  dispatch: React.Dispatch<Action>;
}

const Ctx = createContext<CtxValue | null>(null);

export function AppProvider({ children }: { children: ReactNode }) {
  const [state, dispatch] = useReducer(reducer, initial);
  return <Ctx.Provider value={{ state, dispatch }}>{children}</Ctx.Provider>;
}

export function useAppStore() {
  const ctx = useContext(Ctx);
  if (!ctx) throw new Error('useAppStore must be inside AppProvider');
  return ctx;
}
