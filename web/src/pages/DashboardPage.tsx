// ==================== KT BANQUE - Dashboard ====================
import { useState, useCallback, useRef } from 'react';
import { useAppStore } from '../store';
import { useNotification } from '../hooks/useNotification';
import { useClose } from '../hooks/useNUI';
import { sendToServer, formatCurrency, formatDate, maskCardNumber, cardTypeLabel } from '../utils';
import { Transaction, TransactionType } from '../types';
import styles from './DashboardPage.module.scss';

// ---- helpers ----
type NavTab = 'operations' | 'history';

const TX_ICONS: Record<TransactionType | string, string> = {
  deposit:         '⬆',
  withdraw:        '⬇',
  transfer_out:    '→',
  transfer_in:     '←',
  account_created: '✦',
  card_issued:     '◆',
  admin:           '⚙',
};
const TX_LABELS: Record<string, string> = {
  deposit:         'Dépôt',
  withdraw:        'Retrait',
  transfer_out:    'Virement émis',
  transfer_in:     'Virement reçu',
  account_created: 'Création compte',
  card_issued:     'Carte émise',
  admin:           'Opération admin',
};
const POSITIVE_TYPES: TransactionType[] = ['deposit', 'transfer_in', 'account_created'];

// ==================== SUB-COMPONENTS ====================

function BalanceCard() {
  const { state } = useAppStore();
  const [pop, setPop] = useState(false);
  const data = state.accountData!;

  return (
    <div className={styles['balance-card']}>
      <div className={styles['card-top']}>
        <span className={`${styles['card-type-badge']} ${styles[`card-type-badge--${data.card_meta.card_type}`]}`}>
          {cardTypeLabel(data.card_meta.card_type)}
        </span>
        <span className={styles ['card-number']}>{maskCardNumber(data.card_meta.card_number)}</span>
      </div>

      <div className={styles['balance-label']}>Solde disponible</div>
      <div className={`${styles['balance-amount']} ${pop ? styles['balance-amount--updated'] : ''}`}>
        {formatCurrency(data.balance)}
      </div>

      <div className={styles['card-bottom']}>
        <span className={styles['card-owner']}>{data.card_meta.owner}</span>
        <div className={styles['card-limits']}>
          <div className={styles['limit-chip']}>
            <span className={styles['limit-chip__label']}>Dépôt max</span>
            <span className={styles['limit-chip__val']}>{formatCurrency(data.limits.MaxDeposit)}</span>
          </div>
          <div className={styles['limit-chip']}>
            <span className={styles['limit-chip__label']}>Retrait max</span>
            <span className={styles['limit-chip__val']}>{formatCurrency(data.limits.MaxWithdraw)}</span>
          </div>
        </div>
      </div>
    </div>
  );
}

function OperationsPanel() {
  const { state } = useAppStore();
  const notify = useNotification();
  const [depositAmt, setDepositAmt] = useState('');
  const [withdrawAmt, setWithdrawAmt] = useState('');
  const [transferAmt, setTransferAmt] = useState('');
  const [transferTarget, setTransferTarget] = useState('');
  const [loading, setLoading] = useState<string | null>(null);

  const data = state.accountData!;

  const wrap = useCallback(async (
    key: string,
    event: string,
    payload: object,
    successMsg: string
  ) => {
    setLoading(key);
    try {
      await sendToServer(event, payload);
      notify(successMsg, 'success');
    } catch {
      notify('Erreur serveur', 'error');
    } finally {
      setLoading(null);
    }
  }, [notify]);

  return (
    <div>
      <p className={styles['section-title']}>Opérations</p>
      <div className={styles['actions-grid']}>
        {/* Dépôt */}
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
              onChange={e => setDepositAmt(e.target.value)}
            />
            <button
              className={`${styles['action-btn']} ${styles['action-btn--deposit']}`}
              disabled={!depositAmt || loading === 'deposit'}
              onClick={() => {
                wrap('deposit', 'deposit', {
                  amount: parseFloat(depositAmt),
                  cardId: data.card_meta.id,
                  pin: data.pin,
                }, `Dépôt de ${formatCurrency(parseFloat(depositAmt))} effectué`);
                setDepositAmt('');
              }}
            >
              {loading === 'deposit' ? '...' : 'Déposer'}
            </button>
          </div>
        </div>

        {/* Retrait */}
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
              onChange={e => setWithdrawAmt(e.target.value)}
            />
            <button
              className={`${styles['action-btn']} ${styles['action-btn--withdraw']}`}
              disabled={!withdrawAmt || loading === 'withdraw'}
              onClick={() => {
                wrap('withdraw', 'withdraw', {
                  amount: parseFloat(withdrawAmt),
                  cardId: data.card_meta.id,
                  pin: data.pin,
                }, `Retrait de ${formatCurrency(parseFloat(withdrawAmt))} effectué`);
                setWithdrawAmt('');
              }}
            >
              {loading === 'withdraw' ? '...' : 'Retirer'}
            </button>
          </div>
        </div>

        {/* Transfert */}
        <div className={`${styles['action-card']} ${styles['action-card--transfer']}`}>
          <div className={styles['action-header']}>
            <span className={styles['action-header__icon']}>⇄</span>
            <span className={styles['action-header__title']}>Transférer</span>
          </div>
          <div className={styles['input-row']}>
            <input
              className={styles['action-input']}
              type="text"
              placeholder="N° de compte destinataire"
              value={transferTarget}
              onChange={e => setTransferTarget(e.target.value)}
              style={{ flex: 2 }}
            />
            <input
              className={styles['action-input']}
              type="number"
              min={1}
              placeholder="Montant"
              value={transferAmt}
              onChange={e => setTransferAmt(e.target.value)}
            />
            <button
              className={`${styles['action-btn']} ${styles['action-btn--transfer']}`}
              disabled={!transferAmt || !transferTarget || loading === 'transfer'}
              onClick={() => {
                wrap('transfer', 'transfer', {
                  amount: parseFloat(transferAmt),
                  target: transferTarget,
                  cardId: data.card_meta.id,
                  pin: data.pin,
                }, `Virement de ${formatCurrency(parseFloat(transferAmt))} envoyé`);
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

function HistoryPanel({ history }: { history: Transaction[] }) {
  if (!history.length)
    return <p className={styles['history-empty']}>Aucune transaction récente</p>;

  return (
    <div className={styles['history-list']}>
      {history.map((tx) => {
        const isPos = POSITIVE_TYPES.includes(tx.action as TransactionType);
        const isNeu = ['account_created', 'card_issued'].includes(tx.action);
        const iconClass = isNeu ? styles['tx-icon--neutral'] : isPos ? styles['tx-icon--positive'] : styles['tx-icon--negative'];
        const amountClass = isPos ? styles['tx-amount--positive'] : styles['tx-amount--negative'];
        const sign = isPos ? '+' : '-';
        const label = TX_LABELS[tx.action] ?? tx.action;
        const icon = TX_ICONS[tx.action] ?? '•';

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

// ==================== MAIN DASHBOARD ====================
const NAV = [
  { id: 'operations' as NavTab, label: 'Opérations', icon: '◈' },
  { id: 'history' as NavTab,    label: 'Historique',  icon: '⊟' },
] as const;

export function DashboardPage() {
  const { state } = useAppStore();
  const close = useClose();
  const [tab, setTab] = useState<NavTab>('operations');
  const data = state.accountData!;

  return (
    <div className={styles.root}>
      <div className={styles.shell}>
        {/* SIDEBAR */}
        <aside className={styles.sidebar}>
          <div className={styles.brand}>
            <div className={styles.brand__icon}>🏦</div>
            <div>
              <div className={styles.brand__name}>KT Banque</div>
              <div className={styles.brand__version}>v7.3</div>
            </div>
          </div>

          {NAV.map(item => (
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
            {tab === 'operations' ? 'Mon Compte' : 'Historique'}
          </h1>
          <div className={styles['account-badge']}>
            <span className={styles['account-badge__dot']} />
            <span className={styles['account-badge__num']}>
              {data.account_id}
            </span>
          </div>
        </header>

        {/* CONTENT */}
        <main className={styles['content']}>
          <BalanceCard />

          {tab === 'operations' && <OperationsPanel />}
          {tab === 'history' && (
            <div>
              <p className={styles['section-title']}>Transactions récentes</p>
              <HistoryPanel history={data.history ?? []} />
            </div>
          )}
        </main>
      </div>
    </div>
  );
}
