// ==================== KT BANQUE - STORE ====================
import { createContext, useContext, useReducer, ReactNode } from 'react';
import { AccountData, AppPage, NotificationType } from '../types';

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
}

type Action =
  | { type: 'OPEN_BANK'; payload: AccountData }
  | { type: 'OPEN_CREATE' }
  | { type: 'CLOSE' }
  | { type: 'GO_TO_DASHBOARD' }
  | { type: 'UPDATE_BALANCE'; payload: number }
  | { type: 'PUSH_NOTIF'; payload: Notification }
  | { type: 'REMOVE_NOTIF'; payload: string }
  | { type: 'SET_LOADING'; payload: boolean };

const initial: AppState = {
  page: null,
  isOpen: false,
  accountData: null,
  notifications: [],
  isLoading: false,
};

function reducer(state: AppState, action: Action): AppState {
  switch (action.type) {
    case 'OPEN_BANK':
      return { ...state, isOpen: true, page: 'pin', accountData: action.payload };
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
    default:
      return state;
  }
}

interface CtxValue {
  state: AppState;
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
