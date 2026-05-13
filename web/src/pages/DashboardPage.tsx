// ==================== KT BANQUE v7.5.0 - Dashboard ====================
// CORRECTIONS v7.5.0 :
//   FIX-1 : sendToServer utilise les noms de NUI callbacks Lua exacts
//            ('deposit', 'withdraw', 'transfer') — pas les server events.
//   FIX-2 : pinHash provient de data.pin_hash (envoyé par Bank.Open serveur).
//   FIX-3 : Guard null complet sur data.card_meta avant rendu.
//   FIX-4 : Onglet "Carte" ajouté pour le blocage volontaire.

import { useState, useCallback } from 'react';
import { useAppStore } from '../store';
import { useNotification } from '../hooks/useNotification';
import { useClose } from '../hooks/useNUI';
import { sendToServer, sendNUI, formatCurrency, formatDate, maskCardNumber, cardTypeLabel } from '../utils';
import { Transaction, TransactionType } from '../types';
import styles from './DashboardPage.module.scss';

type NavTab = 'operations' | 'history' | 'card';

const TX_ICONS: Record<string, string> = {
  deposit        : '⬆',
  withdraw       : '⬇',
  transfer_out   : '→',
  transfer_in    : '←',
  account_created: '✦',
  card_issued    : '◆',
  admin          : '⚙',
};

const TX_LABELS: Record<string, string> = {
  deposit        : 'Dépôt',
  withdraw       : 'Retrait',
  transfer_out   : 'Virement émis',
  transfer_in    : 'Virement reçu',
  account_created: 'Création compte',
  card_issued    : 'Carte émise',
  admin          : 'Opération admin',
};

const POSITIVE_TYPES: TransactionType[] = ['deposit', 'transfer_in', 'account_created', 'card_issued'];

// ==================== BALANCE CARD ====================
function BalanceCard() {
  const { state } = useAppStore();
  const data = state.accountData!;

  return (
    <div className={styles['balance-card']}>
      <div className={styles['card-top']}>
        <span className={`${styles['card-type-badge']} ${styles[`card-type-badge--${data.card_meta.card_type}`]}`}>
          {cardTypeLabel(data.card_meta.card_type)}
        </span>
        <span className={styles['card-number']}>
          {maskCardNumber(data.card_meta.card_number)}
        </span>
      </div>

      <div className={styles['balance-label']}>Solde disponible</div>
      <div className={styles['balance-amount']}>
        {formatCurrency(data.balance)}
      </div>

      <div className={styles['card-bottom']}>
        <span className={styles['card-owner']}>{data.card_meta.owner}</span>
        <div className={styles['card-limits']}>
          <div className={styles['limit-chip']}>
            <span className={styles['limit-chip__label']}>Dépôt max/j</span>
            <span className={styles['limit-chip__val']}>{formatCurrency(data.limits.MaxDeposit)}</span>
          </div>
          <div className={styles['limit-chip']}>
            <span className={styles['limit-chip__label']}>Retrait max/j</span>
            <span className={styles['limit-chip__val']}>{formatCurrency(data.limits.MaxWithdraw)}</span>
          </div>
        </div>
      </div>
    </div>
  );
}

// ==================== OPERATIONS ====================
function OperationsPanel() {
  const { state }  = useAppStore();
  const notify     = useNotification();
  const [depositAmt,    setDepositAmt]    = useState('');
  const [withdrawAmt,   setWithdrawAmt]   = useState('');
  const [transferAmt,   setTransferAmt]   = useState('');
  const [transferTarget,setTransferTarget]= useState('');
  const [loading,       setLoading]       = useState<string | null>(null);

  const data = state.accountData!;
  // FIX-2 : pin_hash fourni par Bank.Open côté serveur
  const pinHash = data.pin_hash;

  const wrap = useCallback(async (
    key: string,
    // FIX-1 : noms des NUI callbacks Lua (RegisterNUICallback dans ui.lua)
    nuiEvent: string,
    payload: object,
    successMsg: string
  ) => {
    setLoading(key);
    try {
      await sendToServer(nuiEvent, payload);
      notify(successMsg, 'success');
    } catch {
      notify('Erreur serveur — réessayez', 'error');
    } finally {
      setLoading(null);
    }
  }, [notify]);

  return (
    <div>
      <p className={styles['section-title']}>Opérations</p>
      <div className={styles['actions-grid']}>

        {/* Dépôt — FIX-1 : event 'deposit' (NUI callback Lua) */}
        <div className={styles['action-card']}>
          <div className={styles['action-header']}>
            <span className={styles['action-header__icon']}>⬆</span>
            <span className={styles['action-header__title']}>Déposer</span>
          </div>
          <div className={styles['input-row']}>
            <input
              className={styles['action-input']}
              type="number"
              min={1}
              placeholder="Montant"
              value={depositAmt}
              onChange={(e) => setDepositAmt(e.target.value)}
            />
            <button
              className={`${styles['action-btn']} ${styles['action-btn--deposit']}`}
              disabled={!depositAmt || Number(depositAmt) <= 0 || loading === 'deposit'}
              onClick={() => {
                const amount = Math.floor(parseFloat(depositAmt));
                if (amount <= 0) return;
                wrap('deposit', 'deposit', { amount, pinHash },
                  `Dépôt de ${formatCurrency(amount)} effectué`);
                setDepositAmt('');
              }}
            >
              {loading === 'deposit' ? '...' : 'Déposer'}
            </button>
          </div>
        </div>

        {/* Retrait — FIX-1 : event 'withdraw' */}
        <div className={styles['action-card']}>
          <div className={styles['action-header']}>
            <span className={styles['action-header__icon']}>⬇</span>
            <span className={styles['action-header__title']}>Retirer</span>
          </div>
          <div className={styles['input-row']}>
            <input
              className={styles['action-input']}
              type="number"
              min={1}
              placeholder="Montant"
              value={withdrawAmt}
              onChange={(e) => setWithdrawAmt(e.target.value)}
            />
            <button
              className={`${styles['action-btn']} ${styles['action-btn--withdraw']}`}
              disabled={!withdrawAmt || Number(withdrawAmt) <= 0 || loading === 'withdraw'}
              onClick={() => {
                const amount = Math.floor(parseFloat(withdrawAmt));
                if (amount <= 0) return;
                wrap('withdraw', 'withdraw', { amount, pinHash },
                  `Retrait de ${formatCurrency(amount)} effectué`);
                setWithdrawAmt('');
              }}
            >
              {loading === 'withdraw' ? '...' : 'Retirer'}
            </button>
          </div>
        </div>

        {/* Transfert — FIX-1 : event 'transfer' */}
        <div className={`${styles['action-card']} ${styles['action-card--transfer']}`}>
          <div className={styles['action-header']}>
            <span className={styles['action-header__icon']}>⇄</span>
            <span className={styles['action-header__title']}>Virement</span>
          </div>
          <div className={styles['input-row']}>
            <input
              className={styles['action-input']}
              type="text"
              placeholder="N° compte ou IBAN (ex: UN12345678)"
              value={transferTarget}
              onChange={(e) => setTransferTarget(e.target.value.toUpperCase())}
              style={{ flex: 2 }}
            />
            <input
              className={styles['action-input']}
              type="number"
              min={1}
              placeholder="Montant"
              value={transferAmt}
              onChange={(e) => setTransferAmt(e.target.value)}
            />
            <button
              className={`${styles['action-btn']} ${styles['action-btn--transfer']}`}
              disabled={!transferAmt || !transferTarget || Number(transferAmt) <= 0 || loading === 'transfer'}
              onClick={() => {
                const amount = Math.floor(parseFloat(transferAmt));
                if (amount <= 0 || !transferTarget) return;
                wrap('transfer', 'transfer',
                  { amount, target: transferTarget, pinHash },
                  `Virement de ${formatCurrency(amount)} envoyé`);
                setTransferAmt('');
                setTransferTarget('');
              }}
            >
              {loading === 'transfer' ? '...' : 'Envoyer'}
            </button>
          </div>
        </div>

      </div>
    </div>
  );
}

// ==================== HISTORIQUE ====================
function HistoryPanel({ history }: { history: Transaction[] }) {
  if (!history.length)
    return <p className={styles['history-empty']}>Aucune transaction récente</p>;

  return (
    <div className={styles['history-list']}>
      {history.map((tx) => {
        const isPos = POSITIVE_TYPES.includes(tx.action as TransactionType);
        const isNeu = ['account_created', 'card_issued'].includes(tx.action);
        const iconClass   = isNeu
          ? styles['tx-icon--neutral']
          : isPos ? styles['tx-icon--positive'] : styles['tx-icon--negative'];
        const amountClass = isPos ? styles['tx-amount--positive'] : styles['tx-amount--negative'];
        const sign  = isPos ? '+' : '-';
        const label = TX_LABELS[tx.action] ?? tx.action;
        const icon  = TX_ICONS[tx.action]  ?? '•';

        return (
          <div key={tx.id} className={styles['tx-item']}>
            <div className={`${styles['tx-icon']} ${iconClass}`}>{icon}</div>
            <div className={styles['tx-meta']}>
              <div className={styles['tx-action']}>{label}</div>
              {tx.description && <div className={styles['tx-desc']}>{tx.description}</div>}
            </div>
            <div className={styles['tx-right']}>
              <div className={`${styles['tx-amount']} ${amountClass}`}>
                {tx.amount > 0 ? `${sign}${formatCurrency(tx.amount)}` : '—'}
              </div>
              <div className={styles['tx-date']}>{formatDate(tx.date)}</div>
            </div>
          </div>
        );
      })}
    </div>
  );
}

// ==================== ONGLET CARTE ====================
// FIX-4 : panneau de gestion de carte (blocage volontaire)
function CardPanel() {
  const { state }  = useAppStore();
  const notify     = useNotification();
  const [blocking, setBlocking] = useState(false);
  const data = state.accountData!;
  const isActive = data.card_meta.active === 1;

  const handleBlock = async () => {
    if (!window.confirm('Bloquer votre carte ? Vous pourrez la remplacer au guichet.')) return;
    setBlocking(true);
    try {
      await sendToServer('selfBlockCard', {});
      notify('Carte bloquée avec succès.', 'success');
    } catch {
      notify('Erreur lors du blocage.', 'error');
    } finally {
      setBlocking(false);
    }
  };

  return (
    <div>
      <p className={styles['section-title']}>Ma Carte</p>
      <div className={styles['action-card']}>
        <div className={styles['action-header']}>
          <span className={styles['action-header__icon']}>◆</span>
          <span className={styles['action-header__title']}>
            {cardTypeLabel(data.card_meta.card_type)}
          </span>
        </div>
        <div style={{ marginBottom: 14, color: 'var(--text-2)', fontSize: 13 }}>
          <div>Numéro : {maskCardNumber(data.card_meta.card_number)}</div>
          <div>Propriétaire : {data.card_meta.owner}</div>
          <div>Statut : {isActive ? '🟢 Active' : '🔴 Bloquée'}</div>
        </div>
        {isActive && (
          <button
            className={`${styles['action-btn']} ${styles['action-btn--withdraw']}`}
            style={{ width: '100%' }}
            onClick={handleBlock}
            disabled={blocking}
          >
            {blocking ? 'Blocage...' : '🔒 Bloquer ma carte'}
          </button>
        )}
        {!isActive && (
          <p style={{ color: 'var(--red)', fontSize: 13, textAlign: 'center' }}>
            Votre carte est bloquée. Rendez-vous au guichet pour la remplacer.
          </p>
        )}
      </div>
    </div>
  );
}

// ==================== DASHBOARD PRINCIPAL ====================
const NAV = [
  { id: 'operations' as NavTab, label: 'Opérations', icon: '◈' },
  { id: 'history'    as NavTab, label: 'Historique',  icon: '⊟' },
  { id: 'card'       as NavTab, label: 'Ma Carte',    icon: '◆' },
] as const;

export function DashboardPage() {
  const { state } = useAppStore();
  const close     = useClose();
  const [tab, setTab] = useState<NavTab>('operations');

  const data = state.accountData;

  // FIX-3 : guard complet
  if (!data || !data.card_meta) {
    return (
      <div className={styles.root}>
        <div style={{ color: 'white', textAlign: 'center' }}>Chargement…</div>
      </div>
    );
  }

  return (
    <div className={styles.root}>
      <div className={styles.shell}>

        {/* SIDEBAR */}
        <aside className={styles.sidebar}>
          <div className={styles.brand}>
            <div className={styles.brand__icon}>🏦</div>
            <div>
              <div className={styles.brand__name}>KT Banque</div>
              <div className={styles.brand__version}>v7.5</div>
            </div>
          </div>

          {NAV.map((item) => (
            <div
              key={item.id}
              className={`${styles['nav-item']} ${tab === item.id ? styles['nav-item--active'] : ''}`}
              onClick={() => setTab(item.id)}
            >
              <span className={styles['nav-item__icon']}>{item.icon}</span>
              {item.label}
            </div>
          ))}

          <div className={styles['sidebar-footer']}>
            <button className={styles['close-btn']} onClick={close}>
              ✕ Fermer
            </button>
          </div>
        </aside>

        {/* TOPBAR */}
        <header className={styles['topbar']}>
          <h1 className={styles['topbar-title']}>
            {tab === 'operations' ? 'Mon Compte'  :
             tab === 'history'    ? 'Historique'  : 'Ma Carte'}
          </h1>
          <div className={styles['account-badge']}>
            <span className={styles['account-badge__dot']} />
            <span className={styles['account-badge__num']}>
              {data.account_id}
            </span>
          </div>
        </header>

        {/* CONTENU */}
        <main className={styles['content']}>
          <BalanceCard />

          {tab === 'operations' && <OperationsPanel />}

          {tab === 'history' && (
            <div>
              <p className={styles['section-title']}>Transactions récentes</p>
              <HistoryPanel history={data.history ?? []} />
            </div>
          )}

          {tab === 'card' && <CardPanel />}
        </main>

      </div>
    </div>
  );
}
