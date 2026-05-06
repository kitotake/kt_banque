// ==================== KT BANQUE - PIN Page ====================
import { useState, useRef, useCallback, useEffect } from 'react';
import { useAppStore } from '../store';
import { useNotification } from '../hooks/useNotification';
import styles from './PinPage.module.scss';

const DIGITS = ['1','2','3','4','5','6','7','8','9','','0','⌫'];

export function PinPage() {
  const { state, dispatch } = useAppStore();
  const notify = useNotification();
  const [pin, setPin] = useState('');
  const [shake, setShake] = useState(false);
  const [error, setError] = useState('');

  const maxLen = 4;
  const storedPin = String(state.accountData?.pin ?? '');

  // Reset on open
  useEffect(() => {
    setPin('');
    setError('');
  }, [state.page]);

  const triggerShake = useCallback(() => {
    setShake(true);
    setTimeout(() => setShake(false), 450);
  }, []);

  const handleKey = useCallback((key: string) => {
    if (key === '⌫') {
      setPin(p => p.slice(0, -1));
      setError('');
      return;
    }
    if (pin.length >= maxLen) return;
    const next = pin + key;
    setPin(next);

    if (next.length === maxLen) {
      // Auto-validate
      setTimeout(() => validate(next), 120);
    }
  }, [pin]); // eslint-disable-line

  const validate = useCallback((value: string) => {
    if (value.length !== 4) {
      setError('Le PIN doit contenir 4 chiffres');
      triggerShake();
      setPin('');
      return;
    }
    if (state.accountData?.requiresPin && value !== storedPin) {
      setError('Code PIN incorrect');
      triggerShake();
      setPin('');
      return;
    }
    setError('');
    dispatch({ type: 'GO_TO_DASHBOARD' });
  }, [state.accountData, storedPin, dispatch, triggerShake]);

  // Keyboard support
  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (/^\d$/.test(e.key)) handleKey(e.key);
      else if (e.key === 'Backspace') handleKey('⌫');
      else if (e.key === 'Enter' && pin.length === 4) validate(pin);
    }
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [handleKey, validate, pin]);

  return (
    <div className={styles.overlay}>
      <div className={`${styles.panel} ${shake ? styles.shake : ''}`}>
        <div className={styles.logo}>
          <div className={styles.logo__icon}>🏦</div>
        </div>
        <h1 className={styles.title}>Connexion Sécurisée</h1>
        <p className={styles.subtitle}>Entrez votre code PIN à 4 chiffres</p>

        <div className={styles['pin-display']}>
          {Array.from({ length: 4 }).map((_, i) => (
            <div
              key={i}
              className={`${styles['pin-dot']} ${i < pin.length ? styles['pin-dot--filled'] : ''}`}
            />
          ))}
        </div>

        <div className={styles['keypad']}>
          {DIGITS.map((d, i) => {
            if (d === '') return <div key={i} />;
            const isDel = d === '⌫';
            return (
              <button
                key={i}
                className={`${styles.key} ${isDel ? styles['key--del'] : ''}`}
                onClick={() => handleKey(d)}
                type="button"
              >
                {d}
              </button>
            );
          })}
        </div>

        <button
          className={`${styles.key} ${styles['key--ok']}`}
          style={{ width: '100%', height: 52 }}
          onClick={() => validate(pin)}
          disabled={pin.length < 4}
          type="button"
        >
          VALIDER
        </button>

        {error && <p className={styles['error-msg']}>{error}</p>}
      </div>
    </div>
  );
}
