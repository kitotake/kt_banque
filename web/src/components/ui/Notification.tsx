// ==================== KT BANQUE v7.4.1 - Notification ====================
import { useAppStore } from '../../store';
import styles from './Notification.module.scss';

const ICONS: Record<string, string> = {
  success: '✓',
  error  : '✕',
  warning: '⚠',
  info   : 'ℹ',
};

export function NotificationStack() {
  const { state } = useAppStore();

  return (
    <div className={styles['notif-stack']}>
      {state.notifications.map((n) => (
        <div key={n.id} className={`${styles.notif} ${styles[`notif--${n.type}`]}`}>
          <span className={styles.notif__icon}>{ICONS[n.type]}</span>
          <span className={styles.notif__msg}>{n.message}</span>
        </div>
      ))}
    </div>
  );
}
