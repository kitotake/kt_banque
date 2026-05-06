// ==================== KT BANQUE - useNotification hook ====================
import { useCallback } from 'react';
import { useAppStore } from '../store';
import { NotificationType } from '../types';

let _counter = 0;

export function useNotification() {
  const { dispatch } = useAppStore();

  const notify = useCallback(
    (message: string, type: NotificationType = 'info', duration = 3500) => {
      const id = `notif_${++_counter}`;
      dispatch({ type: 'PUSH_NOTIF', payload: { id, type, message } });
      setTimeout(() => dispatch({ type: 'REMOVE_NOTIF', payload: id }), duration);
    },
    [dispatch]
  );

  return notify;
}
