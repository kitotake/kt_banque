// ==================== KT BANQUE v7.5.0 - App ====================
// CORRECTIONS v7.5.0 :
//   FIX-1 : CardRecoveryPage intégrée (absente en v7.4.x).
//   FIX-2 : showCardStatus dispatche vers SHOW_CARD_STATUS dans le store.
//           La page card_recovery s'ouvre quand cardStatus est défini hors dashboard.

import { useAppStore } from './store';
import { useNUIMessage, useClose } from './hooks/useNUI';
import { useEscapeKey } from './hooks/useKeyboard';
import { NotificationStack } from './components/ui/Notification';
import { PinPage }          from './pages/PinPage';
import { CreatePage }       from './pages/CreatePage';
import { DashboardPage }    from './pages/DashboardPage';
import { CardRecoveryPage } from './pages/CardRecoveryPage';

function AppInner() {
  const { state } = useAppStore();
  const close     = useClose();

  useNUIMessage();
  useEscapeKey(close, state.isOpen);

  if (!state.isOpen) {
    // FIX-1 : card recovery peut être ouverte sans isOpen (depuis le NPC)
    // showCardStatus met cardStatus dans le store — on affiche la page directement
    if (state.cardStatus) {
      return (
        <>
          <CardRecoveryPage />
          <NotificationStack />
        </>
      );
    }
    return null;
  }

  return (
    <>
      {state.page === 'pin'       && <PinPage />}
      {state.page === 'create'    && <CreatePage />}
      {state.page === 'dashboard' && <DashboardPage />}
      <NotificationStack />
    </>
  );
}

export default function App() {
  return <AppInner />;
}
