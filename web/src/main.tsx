import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter, MemoryRouter } from 'react-router-dom';
import { App } from './App';
import { AppDataProvider } from './lib/AppData';
import { FeedbackProvider } from './components/Feedback';
import { applyAccent } from './lib/theme';
import './styles.css';

applyAccent();

// Página publicada no claude.ai roda dentro de um quadro: a navegação fica só em memória
const Router = import.meta.env.VITE_ROUTER === 'memory' ? MemoryRouter : BrowserRouter;

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <Router future={{ v7_startTransition: true, v7_relativeSplatPath: true }}>
      <FeedbackProvider>
        <AppDataProvider>
          <div className="app"><App /></div>
        </AppDataProvider>
      </FeedbackProvider>
    </Router>
  </StrictMode>,
);
