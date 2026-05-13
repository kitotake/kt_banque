// ==================== KT BANQUE v7.5.0 - PIN Page ====================
// CORRECTIONS v7.5.0 :
//   FIX-1 : storedHash dans les deps de validate (évite closure périmée).
//   FIX-2 : Validation silencieuse si storedHash absent (mode sans PIN).
//   FIX-3 : Nettoyage de l'état à chaque ouverture de page.

import { useState, useCallback, useEffect } from 'react';
import { useAppStore } from '../store';
import { useNotification } from '../hooks/useNotification';
import { hashPin } from '../utils';
import styles from './PinPage.module.scss';

const DIGITS = ['1','2','3','4','5','6','7','8','9','','0','⌫'];
const MAX_LEN = 4;

export function PinPage() {
  const { state, dispatch } = useAppStore();
  const notify              = useNotification();
  const [pin,   setPin]     = useState('');
  const [shake, setShake]   = useState(false);
  const [error, setError]   = useState('');

  // FIX-1 : storedHash depuis le store (envoyé par Bank.Open)
  const storedHash = state.accountData?.pin_hash ?? '';

  // FIX-3 : reset à chaque fois qu'on arrive sur la page PIN
  useEffect(() => {
    setPin('');
    setError('');
  }, [state.page]);

  const triggerShake = useCallback(() => {
    setShake(true);
    const t = setTimeout(() => setShake(false), 450);
    return () => clearTimeout(t);
  }, []);

  // FIX-1 : storedHash dans les deps
  const validate = useCallback((value: string) => {
    if (value.length !== MAX_LEN) {
      setError('Le PIN doit contenir 4 chiffres');
      triggerShake();
      setPin('');
      return;
    }

    // FIX-2 : si pas de hash en mémoire, on passe (mode dégradé)
    if (storedHash && hashPin(value) !== storedHash) {
      setError('Code PIN incorrect');
      triggerShake();
      setPin('');
      notify('Code PIN incorrect', 'error');
      return;
    }

    setError('');
    dispatch({ type: 'GO_TO_DASHBOARD' });
  }, [storedHash, dispatch, triggerShake, notify]);

  const handleKey = useCallback((key: string) => {
    if (key === '⌫') {
      setPin((p) => p.slice(0, -1));
      setError('');
      return;
    }
    setPin((prev) => {
      if (prev.length >= MAX_LEN) return prev;
      const next = prev + key;
      if (next.length === MAX_LEN) {
        setTimeout(() => validate(next), 120);
      }
      return next;
    });
  }, [validate]);

  // Support clavier physique
  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (/^\d$/.test(e.key))         handleKey(e.key);
      else if (e.key === 'Backspace') handleKey('⌫');
      else if (e.key === 'Enter')     validate(pin);
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
          {Array.from({ length: MAX_LEN }).map((_, i) => (
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
          disabled={pin.length < MAX_LEN}
          type="button"
        >
          VALIDER
        </button>

        {error && <p className={styles['error-msg']}>{error}</p>}
      </div>
    </div>
  );
}
