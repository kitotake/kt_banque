// ==================== KT BANQUE v7.5.0 - Card Recovery Page ====================
// Page manquante côté web — affichée quand showCardStatus est reçu.
// CORRECTIONS v7.5.0 :
//   FIX-1 : Composant entièrement nouveau (absent dans v7.4.x).
//   FIX-2 : Utilise cardStatus du store (dispatché par useNUI showCardStatus).
//   FIX-3 : NUI callback 'recoverCard' aligné avec RegisterNUICallback Lua.
//   FIX-4 : NUI callback 'selfBlockCard' pour le blocage volontaire.

import { useState } from 'react';
import { useAppStore } from '../store';
import { useNotification } from '../hooks/useNotification';
import { useClose } from '../hooks/useNUI';
import { sendToServer, formatCurrency, formatDate } from '../utils';
import styles from './CardRecoveryPage.module.scss';

export function CardRecoveryPage() {
  const { state, dispatch } = useAppStore();
  const notify              = useNotification();
  const close               = useClose();
  const [loading, setLoading] = useState(false);

  const cs = state.cardStatus;

  if (!cs) {
    return (
      <div className={styles.overlay}>
        <div className={styles.panel}>
          <p style={{ color: 'white', textAlign: 'center' }}>Chargement du statut…</p>
        </div>
      </div>
    );
  }

  const isActive  = cs.status === 'active';
  const isBlocked = !isActive;

  // FIX-3 : event 'recoverCard' = RegisterNUICallback('recoverCard', ...) dans card_recovery.lua
  const handleRecover = async () => {
    if (cs.balance < cs.recoveryCost) {
      notify(`Solde insuffisant (${formatCurrency(cs.recoveryCost)} requis)`, 'error');
      return;
    }
    setLoading(true);
    dispatch({ type: 'CARD_RECOVER_LOADING' });
    try {
      await sendToServer('recoverCard', {});
      // Le résultat arrive via cardRecoverResult → useNUI → CARD_RECOVER_SUCCESS/FAILED
    } catch {
      notify('Erreur de communication', 'error');
      dispatch({ type: 'CARD_RECOVER_FAILED', payload: 'Erreur réseau' });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className={styles.overlay}>
      <div className={styles.panel}>

        {/* Header */}
        <div className={styles.header}>
          <div className={`${styles['status-badge']} ${styles[`status-badge--${cs.status}`]}`}>
            {isActive ? '🟢 Carte Active' : '🔴 Carte Bloquée'}
          </div>
          <h1 className={styles.title}>Gestion de Carte</h1>
        </div>

        {/* Infos */}
        <div className={styles['info-grid']}>
          <div className={styles['info-item']}>
            <span className={styles['info-item__label']}>IBAN</span>
            <span className={styles['info-item__value']}>{cs.accountNumber || '—'}</span>
          </div>
          <div className={styles['info-item']}>
            <span className={styles['info-item__label']}>Solde</span>
            <span className={styles['info-item__value']}>{formatCurrency(cs.balance)}</span>
          </div>
          {cs.expires_at && (
            <div className={styles['info-item']}>
              <span className={styles['info-item__label']}>Expiration</span>
              <span className={styles['info-item__value']}>{formatDate(cs.expires_at)}</span>
            </div>
          )}
          {cs.meta_owner && (
            <div className={styles['info-item']}>
              <span className={styles['info-item__label']}>Propriétaire</span>
              <span className={styles['info-item__value']}>{cs.meta_owner}</span>
            </div>
          )}
        </div>

        {/* Actions selon statut */}
        {isBlocked && (
          <div className={styles['recover-block']}>
            <p className={styles['recover-desc']}>
              Votre carte est bloquée. Vous pouvez la remplacer pour{' '}
              <strong>{formatCurrency(cs.recoveryCost)}</strong>.
            </p>
            {state.cardRecoverError && (
              <p className={styles['error-msg']}>{state.cardRecoverError}</p>
            )}
            <button
              className={styles['btn-recover']}
              onClick={handleRecover}
              disabled={loading || state.cardRecoverLoading || cs.balance < cs.recoveryCost}
            >
              {loading || state.cardRecoverLoading
                ? 'Traitement...'
                : `Remplacer ma carte (${formatCurrency(cs.recoveryCost)})`}
            </button>
          </div>
        )}

        {isActive && (
          <div className={styles['active-block']}>
            <p className={styles['active-desc']}>
              Votre carte est active et fonctionnelle.
            </p>
          </div>
        )}

        <button className={styles['btn-close']} onClick={close}>
          Fermer
        </button>
      </div>
    </div>
  );
}
