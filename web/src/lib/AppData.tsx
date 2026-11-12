import { createContext, useCallback, useContext, useEffect, useRef, useState, type ReactNode } from 'react';
import { supabase } from './supabase';
import { BACKEND, api, friendlyError, localApi } from './api';
import type { CharacterStats, Habit, Mission, Profile, TodayInfo } from './types';
import { useFeedback } from '../components/Feedback';
import { browserTimezone } from './dates';

interface AppData {
  /** Pessoa identificada: sessão do Supabase, ou dados pessoais carregados na versão individual. */
  signedIn: boolean;
  authReady: boolean;
  userEmail: string | null;
  /** Onde os dados ficam na versão individual. */
  storage: 'nuvem' | 'aparelho' | null;
  profile: Profile | null;
  stats: CharacterStats | null;
  today: TodayInfo | null;
  missions: Mission[];
  habits: Habit[];
  loading: boolean;
  error: string | null;
  busy: Set<string>;
  refresh: () => Promise<void>;
  complete: (m: Mission) => Promise<void>;
  undo: (m: Mission) => Promise<void>;
}

const Ctx = createContext<AppData | null>(null);
export function useApp() {
  const v = useContext(Ctx);
  if (!v) throw new Error('useApp fora do AppDataProvider');
  return v;
}

export function AppDataProvider({ children }: { children: ReactNode }) {
  const { toast, levelUp } = useFeedback();
  const [signedIn, setSignedIn] = useState(false);
  const [userKey, setUserKey] = useState<string | null>(null);
  const [userEmail, setUserEmail] = useState<string | null>(null);
  const [storage, setStorage] = useState<'nuvem' | 'aparelho' | null>(null);
  const [authReady, setAuthReady] = useState(false);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [stats, setStats] = useState<CharacterStats | null>(null);
  const [today, setToday] = useState<TodayInfo | null>(null);
  const [missions, setMissions] = useState<Mission[]>([]);
  const [habits, setHabits] = useState<Habit[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState<Set<string>>(new Set());
  const tzSynced = useRef(false);

  useEffect(() => {
    if (BACKEND === 'local') {
      localApi.onSaveError((e) => toast(friendlyError(e), 'error'));
      localApi.init()
        .then((r) => { setStorage(r.storage); setSignedIn(true); setUserKey('local'); })
        .catch((e) => setError(friendlyError(e)))
        .finally(() => setAuthReady(true));
      return;
    }
    supabase.auth.getSession().then(({ data }) => {
      setSignedIn(!!data.session); setUserKey(data.session?.user.id ?? null); setUserEmail(data.session?.user.email ?? null);
      setAuthReady(true);
    });
    const { data: sub } = supabase.auth.onAuthStateChange((_e, s) => {
      setSignedIn(!!s); setUserKey(s?.user.id ?? null); setUserEmail(s?.user.email ?? null);
    });
    return () => sub.subscription.unsubscribe();
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

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
      setProfile(prof);
      if (!prof.onboarding_done) { setStats(await api.stats()); return; }
      const t = await api.ensureToday();
      const [s, ms, hs] = await Promise.all([api.stats(), api.missionsFor(t.today), api.habits()]);
      setToday(t); setStats(s); setMissions(ms); setHabits(hs);
    } catch (e) {
      setError(friendlyError(e));
    }
  }, []);

  useEffect(() => {
    if (!signedIn) { setProfile(null); setStats(null); setToday(null); setMissions([]); setHabits([]); return; }
    setLoading(true);
    refresh().finally(() => setLoading(false));
  }, [userKey, signedIn, refresh]);

  // Ao voltar para o app (ex.: abriu no dia seguinte), recarrega
  useEffect(() => {
    const onVisible = async () => {
      if (document.visibilityState !== 'visible' || !signedIn) return;
      if (BACKEND === 'local') await localApi.reload().catch(() => {});
      refresh();
    };
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
        const extra = r.bonus?.some((b) => b.tipo === 'retorno') ? ' · bônus de retorno!' : r.bonus?.length ? ' · meta do dia batida!' : '';
        toast(`+${(r.xp ?? 0) + bonus} XP${extra}`, 'xp', { label: 'Desfazer', run: () => undo({ ...m, status: 'concluida' }) });
        if ((r.nivel ?? 0) > (r.nivel_antes ?? 0)) levelUp(r.nivel!);
      }
    } catch (e) {
      toast(friendlyError(e), 'error');
    } finally {
      setBusyFor(m.id, false);
      await refresh();
    }
  }, [busy, refresh, toast, levelUp, undo]);

  return (
    <Ctx.Provider value={{ signedIn, authReady, userEmail, storage, profile, stats, today, missions, habits, loading, error, busy, refresh, complete, undo }}>
      {children}
    </Ctx.Provider>
  );
}
