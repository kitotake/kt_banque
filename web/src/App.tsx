// ==================== KT BANQUE - App ====================
import { useAppStore } from './store';
import { useNUIMessage, useClose } from './hooks/useNUI';
import { useEscapeKey } from './hooks/useKeyboard';
import { NotificationStack } from './components/ui/Notification';
import { PinPage } from './pages/PinPage';
import { CreatePage } from './pages/CreatePage';
import { DashboardPage } from './pages/DashboardPage';
import styles from './App.module.scss';


function AppInner() {
  const { state } = useAppStore();
  const close = useClose();

  useNUIMessage();
  useEscapeKey(close, state.isOpen);

  if (!state.isOpen) return null;

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
  // AppProvider is in main.tsx wrapping this — see below
  return <AppInner />;
}
