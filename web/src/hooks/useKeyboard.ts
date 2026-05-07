// ==================== KT BANQUE v7.4.1 - useKeyboard hook ====================
import { useEffect } from 'react';

export function useEscapeKey(callback: () => void, active: boolean) {
  useEffect(() => {
    if (!active) return;
    function onKey(e: KeyboardEvent) {
      if (e.key === 'Escape') {
        e.preventDefault();
        callback();
      }
    }
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [callback, active]);
}
