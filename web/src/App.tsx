import { useEffect, useState, type FormEvent } from 'react';
import { Navigate, Route, Routes, useLocation } from 'react-router-dom';
import { isConfigured, supabase } from './lib/supabase';
import { useApp } from './lib/AppData';
import { BACKEND, friendlyError } from './lib/api';
import { ErrorState, TabBar } from './components/ui';
import { Emblem } from './components/Emblem';
import { AuthScreen } from './screens/Auth';
import { QuestionnaireScreen, WelcomeScreen } from './screens/Onboarding';
import { ResultScreen } from './screens/Result';
import { HomeScreen } from './screens/Home';
import { MissionsScreen } from './screens/Missions';
import { MissionDetailScreen } from './screens/MissionDetail';
import { NewMissionScreen } from './screens/NewMission';
import { JourneyScreen } from './screens/Journey';
import { CharacterScreen } from './screens/Character';
import { ProfileScreen } from './screens/Profile';

function Splash() {
  return (
    <div className="splash" aria-busy="true">
      <div className="splash-inner">
        <Emblem level={1} size={96} showLevel={false} />
        <span className="num" style={{ fontSize: 22, fontWeight: 700, letterSpacing: '0.04em' }}>FORJA</span>
      </div>
    </div>
  );
}

function NotConfigured() {
  return (
    <div className="screen no-tabs">
      <h1>Falta conectar o banco</h1>
      <p className="muted">
        Crie o arquivo <code>web/.env</code> com <code>VITE_SUPABASE_URL</code> e <code>VITE_SUPABASE_ANON_KEY</code> (veja o README) e reinicie o app.
      </p>
    </div>
  );
}

function NewPassword({ onDone }: { onDone: () => void }) {
  const [pw, setPw] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  async function submit(e: FormEvent) {
    e.preventDefault();
    setBusy(true); setError(null);
    const { error } = await supabase.auth.updateUser({ password: pw });
    setBusy(false);
    if (error) setError(friendlyError(error)); else onDone();
  }
  return (
    <form className="screen no-tabs" onSubmit={submit}>
      <h1>Nova senha</h1>
      <input className="input" type="password" minLength={6} required value={pw} onChange={(e) => setPw(e.target.value)} autoComplete="new-password" aria-label="Nova senha" />
      {error && <p role="alert" style={{ color: 'var(--danger)' }}>{error}</p>}
      <button className="btn primary block" disabled={busy}>Salvar senha</button>
    </form>
  );
}

const NO_TABS = [/^\/missoes\/.+/, /^\/resultado/];

export function App() {
  const { signedIn, authReady, profile, error, refresh } = useApp();
  const [recovery, setRecovery] = useState(false);
  const location = useLocation();

  useEffect(() => {
    const { data } = supabase.auth.onAuthStateChange((event) => { if (event === 'PASSWORD_RECOVERY') setRecovery(true); });
    return () => data.subscription.unsubscribe();
  }, []);

  if (BACKEND === 'supabase' && !isConfigured) return <NotConfigured />;
  if (!authReady) return <Splash />;
  if (!signedIn) {
    if (BACKEND === 'local') {
      return <div className="screen no-tabs"><ErrorState message={error ?? 'Não foi possível abrir seus dados.'} onRetry={() => window.location.reload()} /></div>;
    }
    return <AuthScreen />;
  }
  if (recovery) return <NewPassword onDone={() => setRecovery(false)} />;
  if (!profile) return error ? <div className="screen no-tabs"><ErrorState message={error} onRetry={refresh} /></div> : <Splash />;

  if (!profile.onboarding_done) {
    return (
      <Routes>
        <Route path="/avaliacao" element={<QuestionnaireScreen />} />
        <Route path="*" element={<WelcomeScreen />} />
      </Routes>
    );
  }

  const showTabs = !NO_TABS.some((r) => r.test(location.pathname));
  return (
    <>
      <Routes>
        <Route path="/" element={<HomeScreen />} />
        <Route path="/missoes" element={<MissionsScreen />} />
        <Route path="/missoes/nova" element={<NewMissionScreen />} />
        <Route path="/missoes/:id" element={<MissionDetailScreen />} />
        <Route path="/jornada" element={<JourneyScreen />} />
        <Route path="/personagem" element={<CharacterScreen />} />
        <Route path="/perfil" element={<ProfileScreen />} />
        <Route path="/resultado" element={<ResultScreen />} />
        <Route path="/avaliacao/resultado" element={<ResultScreen revisit />} />
        <Route path="/avaliacao" element={<Navigate to="/resultado" replace />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
      {showTabs && <TabBar />}
    </>
  );
}
