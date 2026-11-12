import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import { App } from './App';
import { AppDataProvider } from './lib/AppData';
import { FeedbackProvider } from './components/Feedback';
import { applyAccent } from './lib/theme';
import './styles.css';

applyAccent();

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <BrowserRouter future={{ v7_startTransition: true, v7_relativeSplatPath: true }}>
      <FeedbackProvider>
        <AppDataProvider>
          <div className="app"><App /></div>
        </AppDataProvider>
      </FeedbackProvider>
    </BrowserRouter>
  </StrictMode>,
);
