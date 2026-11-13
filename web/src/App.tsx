import { useEffect, useState, type FormEvent } from 'react';
import { Navigate, Route, Routes, useLocation, useNavigate } from 'react-router-dom';
import { isConfigured, supabase } from './lib/supabase';
import { useApp } from './lib/AppData';
import { friendlyError } from './lib/api';
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
import { AvatarEditorScreen } from './screens/AvatarEditor';
import { InventoryScreen } from './screens/Inventory';
import { AttributesScreen } from './screens/Attributes';
import { AchievementsScreen } from './screens/Achievements';
import { BossDetailScreen, BossesScreen } from './screens/Bosses';
import { ModesScreen } from './screens/Modes';
import { RewardOverlay } from './components/RewardOverlay';
import { SocialScreen } from './screens/Social';
import { AddFriendScreen, FriendProfileScreen, NotificationsScreen, PrivacyScreen } from './screens/Friends';
import { GroupDetailScreen, GroupJoinScreen } from './screens/Groups';
import { ChallengeDetailScreen, ChallengesScreen, NewChallengeScreen } from './screens/Challenges';
import { RankingScreen, SeasonScreen } from './screens/Season';
import {
  DiaryScreen, FoodScreen, HabitTrackerScreen, ReadingScreen, ScreenTimeScreen, SleepScreen, ToolsScreen, WaterScreen,
} from './screens/Tools';
import { FocusScreen, MeditationScreen } from './screens/Focus';
import { MentorScreen, PlanScreen, ReportScreen } from './screens/Mentor';

// Convites por link (/amigo/CODIGO, /grupo/CODIGO) abertos antes da avaliação inicial ficam guardados para depois
const PENDING_LINK = 'forja.link';
const INVITE = /^\/(amigo|grupo)\/[0-9A-Za-z-]{4,12}$/;

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

const NO_TABS = [/^\/missoes\/.+/, /^\/resultado/, /^\/personagem\/aparencia/, /^\/jornada\/chefes\/.+/, /^\/social\/desafios\/novo/];

export function App() {
  const { signedIn, authReady, profile, error, refresh } = useApp();
  const [recovery, setRecovery] = useState(false);
  const location = useLocation();
  const nav = useNavigate();

  useEffect(() => {
    if (!profile) return;
    try {
      if (!profile.onboarding_done && INVITE.test(location.pathname)) sessionStorage.setItem(PENDING_LINK, location.pathname);
      if (profile.onboarding_done) {
        const link = sessionStorage.getItem(PENDING_LINK);
        if (link) { sessionStorage.removeItem(PENDING_LINK); if (link !== location.pathname) nav(link); }
      }
    } catch { /* sem armazenamento: o link só vale na hora */ }
  }, [profile?.onboarding_done]); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    const { data } = supabase.auth.onAuthStateChange((event) => { if (event === 'PASSWORD_RECOVERY') setRecovery(true); });
    return () => data.subscription.unsubscribe();
  }, []);

  if (!isConfigured) return <NotConfigured />;
  if (!authReady) return <Splash />;
  if (!signedIn) return <AuthScreen />;
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
        <Route path="/jornada/chefes" element={<BossesScreen />} />
        <Route path="/jornada/chefes/:id" element={<BossDetailScreen />} />
        <Route path="/jornada/modos" element={<ModesScreen />} />
        <Route path="/personagem" element={<CharacterScreen />} />
        <Route path="/personagem/aparencia" element={<AvatarEditorScreen />} />
        <Route path="/personagem/inventario" element={<InventoryScreen />} />
        <Route path="/personagem/atributos" element={<AttributesScreen />} />
        <Route path="/personagem/conquistas" element={<AchievementsScreen />} />
        <Route path="/perfil" element={<ProfileScreen />} />
        <Route path="/perfil/plano" element={<PlanScreen />} />
        <Route path="/social" element={<SocialScreen />} />
        <Route path="/social/avisos" element={<NotificationsScreen />} />
        <Route path="/social/adicionar" element={<AddFriendScreen />} />
        <Route path="/amigo/:code" element={<AddFriendScreen />} />
        <Route path="/social/amigos/:id" element={<FriendProfileScreen />} />
        <Route path="/social/privacidade" element={<PrivacyScreen />} />
        <Route path="/social/grupos/:id" element={<GroupDetailScreen />} />
        <Route path="/grupo/:code" element={<GroupJoinScreen />} />
        <Route path="/social/desafios" element={<ChallengesScreen />} />
        <Route path="/social/desafios/novo" element={<NewChallengeScreen />} />
        <Route path="/social/desafios/:id" element={<ChallengeDetailScreen />} />
        <Route path="/social/temporada" element={<SeasonScreen />} />
        <Route path="/social/ranking" element={<RankingScreen />} />
        <Route path="/ferramentas" element={<ToolsScreen />} />
        <Route path="/ferramentas/foco" element={<FocusScreen />} />
        <Route path="/ferramentas/agua" element={<WaterScreen />} />
        <Route path="/ferramentas/sono" element={<SleepScreen />} />
        <Route path="/ferramentas/alimentacao" element={<FoodScreen />} />
        <Route path="/ferramentas/leitura" element={<ReadingScreen />} />
        <Route path="/ferramentas/meditacao" element={<MeditationScreen />} />
        <Route path="/ferramentas/tela" element={<ScreenTimeScreen />} />
        <Route path="/ferramentas/diario" element={<DiaryScreen />} />
        <Route path="/ferramentas/habitos" element={<HabitTrackerScreen />} />
        <Route path="/mentor" element={<MentorScreen />} />
        <Route path="/mentor/relatorio" element={<ReportScreen />} />
        <Route path="/mentor/relatorio/:week" element={<ReportScreen />} />
        <Route path="/resultado" element={<ResultScreen />} />
        <Route path="/avaliacao/resultado" element={<ResultScreen revisit />} />
        <Route path="/avaliacao" element={<Navigate to="/resultado" replace />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
      {showTabs && <TabBar />}
      <RewardOverlay />
    </>
  );
}
