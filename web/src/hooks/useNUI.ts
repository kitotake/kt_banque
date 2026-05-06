// ==================== KT BANQUE - useNUI hook ====================
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
        case 'openBank':
          dispatch({ type: 'OPEN_BANK', payload: data as AccountData });
          break;
        case 'openCreate':
          dispatch({ type: 'OPEN_CREATE' });
          break;
        case 'updateBalance': {
          const val = typeof data === 'number' ? data : (balance ?? (data as any));
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
