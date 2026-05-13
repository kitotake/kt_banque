// ==================== KT BANQUE v7.5.0 - useNUI hook ====================
// CORRECTIONS v7.5.0 :
//   FIX-1 : showCardStatus / cardRecoverFailed / cardRecoverSuccess gérés.
//   FIX-2 : updateBalance accepte data ET balance (compatibilité).
//   FIX-3 : useClose envoie 'close' via sendNUI (fire-and-forget).

import { useEffect } from 'react';
import { useAppStore } from '../store';
import { AccountData, NUIMessage, CardStatus } from '../types';
import { sendNUI } from '../utils';

export function useNUIMessage() {
  const { dispatch } = useAppStore();

  useEffect(() => {
    function handleMessage(event: MessageEvent<NUIMessage>) {
      const msg = event.data;
      if (!msg || !msg.action) return;

      switch (msg.action) {
        case 'openBank':
          if (msg.data && typeof msg.data === 'object' && 'balance' in msg.data) {
            dispatch({ type: 'OPEN_BANK', payload: msg.data as AccountData });
          }
          break;

        case 'openCreate':
          dispatch({ type: 'OPEN_CREATE' });
          break;

        case 'updateBalance': {
          // FIX-2 : accepte data (number) ou balance
          const val =
            typeof msg.data === 'number'
              ? msg.data
              : typeof msg.balance === 'number'
              ? msg.balance
              : undefined;
          if (typeof val === 'number') {
            dispatch({ type: 'UPDATE_BALANCE', payload: val });
          }
          break;
        }

        case 'close':
          dispatch({ type: 'CLOSE' });
          break;

        // FIX-1 : card recovery events
        case 'showCardStatus': {
          const cardStatus: CardStatus = {
            status        : (msg.status as 'active' | 'blocked') ?? 'blocked',
            accountNumber : msg.accountNumber ?? '',
            balance       : typeof msg.balance === 'number' ? msg.balance : 0,
            recoveryCost  : msg.recoveryCost ?? 1000,
            expires_at    : msg.expires_at ?? '',
            meta_blocked  : msg.meta_blocked,
            meta_owner    : msg.meta_owner,
          };
          dispatch({ type: 'SHOW_CARD_STATUS', payload: cardStatus });
          break;
        }

        case 'cardRecoverSuccess':
          dispatch({ type: 'CARD_RECOVER_SUCCESS' });
          break;

        case 'cardRecoverFailed':
          dispatch({ type: 'CARD_RECOVER_FAILED', payload: msg.reason ?? 'Erreur inconnue' });
          break;
      }
    }

    window.addEventListener('message', handleMessage);
    return () => window.removeEventListener('message', handleMessage);
  }, [dispatch]);
}

// FIX-3 : fire-and-forget
export function useClose() {
  const { dispatch } = useAppStore();
  return () => {
    sendNUI('close');
    dispatch({ type: 'CLOSE' });
  };
}
