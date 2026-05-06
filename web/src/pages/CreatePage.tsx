// ==================== KT BANQUE - Create Account Page ====================
import { useState, useCallback } from 'react';
import { sendToServer } from '../utils';
import { useNotification } from '../hooks/useNotification';
import { useClose } from '../hooks/useNUI';
import styles from './CreatePage.module.scss';

export function CreatePage() {
  const notify = useNotification();
  const close = useClose();
  const [pin1, setPin1] = useState('');
  const [pin2, setPin2] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const sanitize = (v: string) => v.replace(/\D/g, '').slice(0, 4);

  const isValid =
    pin1.length === 4 &&
    pin2.length === 4 &&
    pin1 === pin2;

  const matchState = (v: string) => {
    if (v.length < 4) return '';
    if (v === pin1) return styles['field__input--valid'];
    return styles['field__input--invalid'];
  };

  const handleCreate = useCallback(async () => {
    if (!isValid) {
      setError('Les codes PIN ne correspondent pas');
      return;
    }
    setLoading(true);
    try {
      await sendToServer('createAccount', { pin: pin1 });
      notify('Compte créé avec succès !', 'success');
      setPin1(''); setPin2(''); setError('');
    } catch {
      notify('Erreur lors de la création', 'error');
    } finally {
      setLoading(false);
    }
  }, [isValid, pin1, notify]);

  return (
    <div className={styles.overlay}>
      <div className={styles.panel}>
        <div className={styles.header}>
          <span className={styles.header__icon}>✨</span>
          <h1 className={styles.title}>Ouvrir un Compte</h1>
          <p className={styles.subtitle}>Choisissez un code PIN à 4 chiffres</p>
        </div>

        <div className={styles.field}>
          <label className={styles.field__label}>Code PIN</label>
          <input
            className={styles.field__input}
            type="password"
            maxLength={4}
            placeholder="• • • •"
            value={pin1}
            onChange={e => { setPin1(sanitize(e.target.value)); setError(''); }}
            autoComplete="off"
          />
        </div>

        <div className={styles.field}>
          <label className={styles.field__label}>Confirmer le PIN</label>
          <input
            className={`${styles.field__input} ${matchState(pin2)}`}
            type="password"
            maxLength={4}
            placeholder="• • • •"
            value={pin2}
            onChange={e => { setPin2(sanitize(e.target.value)); setError(''); }}
            autoComplete="off"
            onKeyDown={e => e.key === 'Enter' && !loading && isValid && handleCreate()}
          />
        </div>

        {error && <p className={styles['error-msg']}>{error}</p>}

        <div className={styles.actions}>
          <button
            className={styles['btn-create']}
            onClick={handleCreate}
            disabled={!isValid || loading}
          >
            {loading ? 'Création...' : 'Créer mon compte'}
          </button>
          <button className={styles['btn-cancel']} onClick={close}>
            Annuler
          </button>
        </div>
      </div>
    </div>
  );
}
