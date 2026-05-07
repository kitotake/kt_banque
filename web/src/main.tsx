// ==================== KT BANQUE v7.4.1 - Entry Point ====================
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { AppProvider } from './store';
import App from './App';
import './styles/global.scss';

const container = document.getElementById('root')!;
createRoot(container).render(
  <StrictMode>
    <AppProvider>
      <App />
    </AppProvider>
  </StrictMode>
);
