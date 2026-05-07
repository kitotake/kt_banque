// ==================== KT BANQUE v7.4.1 - useNUI hook ====================
import { useEffect } from 'react';
import { useAppStore } from '../store';
import { AccountData, NUIMessage } from '../types';
import { sendToServer } from '../utils';

export function useNUIMessage() {
  const { dispatch } = useAppStore();

  useEffect(() => {
    function handleMessage(event: MessageEvent<NUIMessage>) {
      const { action, data, balance } = event.data;

      switch (action) {
        // FIX: aligné avec l'event serveur 'bank:client:openBank'
        case 'openBank':
          if (data) {
            dispatch({ type: 'OPEN_BANK', payload: data as AccountData });
          }
          break;

        // FIX: aligné avec 'bank:client:openCreate'
        case 'openCreate':
          dispatch({ type: 'OPEN_CREATE' });
          break;

        case 'updateBalance': {
          const val = typeof data === 'number' ? data : (typeof balance === 'number' ? balance : undefined);
          if (typeof val === 'number') dispatch({ type: 'UPDATE_BALANCE', payload: val });
          break;
        }

        case 'close':
          dispatch({ type: 'CLOSE' });
          break;
      }
    }

    window.addEventListener('message', handleMessage);
    return () => window.removeEventListener('message', handleMessage);
  }, [dispatch]);
}

export function useClose() {
  const { dispatch } = useAppStore();
  return () => {
    sendToServer('close').catch(() => {});
    dispatch({ type: 'CLOSE' });
  };
}
