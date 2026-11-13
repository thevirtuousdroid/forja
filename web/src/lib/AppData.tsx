import { createContext, useCallback, useContext, useEffect, useRef, useState, type ReactNode } from 'react';
import { supabase } from './supabase';
import { api, friendlyError, type Catalogs } from './api';
import type { CharacterStats, GameEvent, Habit, Mission, Profile, TodayInfo } from './types';
import { useFeedback } from '../components/Feedback';
import { browserTimezone } from './dates';
import { inName } from './rpg';
import { syncPush } from './push';

interface AppData {
  signedIn: boolean;
  authReady: boolean;
  userEmail: string | null;
  profile: Profile | null;
  stats: CharacterStats | null;
  today: TodayInfo | null;
  missions: Mission[];
  habits: Habit[];
  catalogs: Catalogs | null;
  /** Recompensas e avisos ainda não mostrados (conquistas, itens, nível, chefes). */
  events: GameEvent[];
  loading: boolean;
  error: string | null;
  busy: Set<string>;
  refresh: () => Promise<void>;
  complete: (m: Mission) => Promise<void>;
  undo: (m: Mission) => Promise<void>;
  dismissEvents: (ids: number[]) => void;
  /** Avisos sociais não vistos (badge da aba Social). */
  socialUnseen: number;
  setSocialUnseen: (n: number) => void;
  /** Recarrega só os avisos de recompensa (ex.: depois de uma ação social que pode dar conquista). */
  loadEvents: () => Promise<void>;
}

const Ctx = createContext<AppData | null>(null);
export function useApp() {
  const v = useContext(Ctx);
  if (!v) throw new Error('useApp fora do AppDataProvider');
  return v;
}

export function AppDataProvider({ children }: { children: ReactNode }) {
  const { toast } = useFeedback();
  const [signedIn, setSignedIn] = useState(false);
  const [userKey, setUserKey] = useState<string | null>(null);
  const [userEmail, setUserEmail] = useState<string | null>(null);
  const [authReady, setAuthReady] = useState(false);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [stats, setStats] = useState<CharacterStats | null>(null);
  const [today, setToday] = useState<TodayInfo | null>(null);
  const [missions, setMissions] = useState<Mission[]>([]);
  const [habits, setHabits] = useState<Habit[]>([]);
  const [catalogs, setCatalogs] = useState<Catalogs | null>(null);
  const [events, setEvents] = useState<GameEvent[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState<Set<string>>(new Set());
  const [socialUnseen, setSocialUnseen] = useState(0);
  const tzSynced = useRef(false);
  const dismissed = useRef<Set<number>>(new Set());

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSignedIn(!!data.session); setUserKey(data.session?.user.id ?? null); setUserEmail(data.session?.user.email ?? null);
      setAuthReady(true);
    });
    const { data: sub } = supabase.auth.onAuthStateChange((_e, s) => {
      setSignedIn(!!s); setUserKey(s?.user.id ?? null); setUserEmail(s?.user.email ?? null);
    });
    return () => sub.subscription.unsubscribe();
  }, []);

  const loadEvents = useCallback(async () => {
    try {
      const evs = await api.pendingEvents();
      setEvents(evs.filter((e) => !dismissed.current.has(e.id)));
    } catch {
      /* Avisos são extras: se falharem, o resto do app segue normal */
    }
  }, []);

  const refresh = useCallback(async () => {
    setError(null);
    try {
      let prof = await api.profile();
      // Mantém o fuso do servidor igual ao do aparelho (define quando o "dia" vira)
      const tz = browserTimezone();
      if (!tzSynced.current && prof.timezone !== tz) {
        tzSynced.current = true;
        await api.updateProfile({ timezone: tz }).catch(() => {});
        prof = await api.profile();
      }
      tzSynced.current = true;
      if (!prof.onboarding_done) { setProfile(prof); setStats(await api.stats()); return; }
      const t = await api.ensureToday();
      // ensure_today pode liberar itens e mudar o avatar: relê o perfil depois dele
      const [p2, s, ms, hs] = await Promise.all([api.profile(), api.stats(), api.missionsFor(t.today), api.habits()]);
      setProfile(p2); setToday(t); setStats(s); setMissions(ms); setHabits(hs);
      setSocialUnseen(t.social_unseen ?? 0);
      void loadEvents();
      void syncPush(p2.id);
      api.catalogs().then(setCatalogs).catch(() => {});
    } catch (e) {
      setError(friendlyError(e));
    }
  }, [loadEvents]);

  useEffect(() => {
    if (!signedIn) {
      setProfile(null); setStats(null); setToday(null); setMissions([]); setHabits([]); setEvents([]); setSocialUnseen(0);
      return;
    }
    setLoading(true);
    refresh().finally(() => setLoading(false));
  }, [userKey, signedIn, refresh]);

  // Ao voltar para o app (ex.: abriu no dia seguinte), recarrega
  useEffect(() => {
    const onVisible = () => { if (document.visibilityState === 'visible' && signedIn) refresh(); };
    document.addEventListener('visibilitychange', onVisible);
    return () => document.removeEventListener('visibilitychange', onVisible);
  }, [signedIn, refresh]);

  const setBusyFor = (id: string, on: boolean) =>
    setBusy((b) => { const n = new Set(b); if (on) n.add(id); else n.delete(id); return n; });

  const undo = useCallback(async (m: Mission) => {
    setBusyFor(m.id, true);
    setMissions((ms) => ms.map((x) => (x.id === m.id ? { ...x, status: 'pendente', completed_at: null } : x)));
    try {
      await api.undoCompletion(m.id);
      toast('Conclusão desfeita.');
    } catch (e) {
      toast(friendlyError(e), 'error');
    } finally {
      setBusyFor(m.id, false);
      await refresh();
    }
  }, [refresh, toast]);

  const complete = useCallback(async (m: Mission) => {
    if (busy.has(m.id) || m.status !== 'pendente') return;
    setBusyFor(m.id, true);
    // Atualização otimista: o servidor confirma e recalcula
    setMissions((ms) => ms.map((x) => (x.id === m.id ? { ...x, status: 'concluida', completed_at: new Date().toISOString() } : x)));
    try {
      const r = await api.completeMission(m.id);
      if (!r.ja_concluida) {
        const bonus = (r.bonus ?? []).reduce((n, b) => n + b.xp, 0);
        const parts = [`+${(r.xp ?? 0) + bonus} XP`];
        if (r.bonus?.some((b) => b.tipo === 'retorno')) parts.push('bônus de retorno');
        else if (r.bonus?.length) parts.push('meta do dia batida');
        const c = r.chefe;
        if (c && c.status === 'ativo' && c.effective > c.before) parts.push(`golpe ${inName(c.name)} (${c.effective}/${c.hp})`);
        toast(parts.join(' · '), 'xp', { label: 'Desfazer', run: () => undo({ ...m, status: 'concluida' }) });
      }
    } catch (e) {
      toast(friendlyError(e), 'error');
    } finally {
      setBusyFor(m.id, false);
      await refresh();
    }
  }, [busy, refresh, toast, undo]);

  const dismissEvents = useCallback((ids: number[]) => {
    ids.forEach((id) => dismissed.current.add(id));
    setEvents((evs) => evs.filter((e) => !ids.includes(e.id)));
    api.markEventsSeen(ids).catch(() => {});
  }, []);

  return (
    <Ctx.Provider value={{
      signedIn, authReady, userEmail, profile, stats, today, missions, habits, catalogs, events,
      loading, error, busy, refresh, complete, undo, dismissEvents, socialUnseen, setSocialUnseen, loadEvents,
    }}>
      {children}
    </Ctx.Provider>
  );
}
