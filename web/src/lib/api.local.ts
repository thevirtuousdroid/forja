// Versão individual: as regras do jogo rodam no próprio app e os dados ficam no espaço privado da pessoa.
import * as E from '../engine/engine';
import { emptyState, statsOf, type GameState } from '../engine/state';
import { Saver, fromDocs, openStore, type Store } from '../engine/storage';
import { levelForXp } from './game';
import { browserTimezone } from './dates';
import type {
  Assessment, CharacterStats, CompleteResult, Habit, Journey, LedgerEntry, Mission, Profile, ProgressionEvent, TodayInfo,
} from './types';

let state: GameState | null = null;
let store: Store | null = null;
let saver: Saver | null = null;
const listeners = { error: [] as ((e: unknown) => void)[] };

const copy = <T,>(x: T): T => JSON.parse(JSON.stringify(x));
const S = () => state ?? (() => { throw new Error('nao_autenticado'); })();

async function commit<T>(fn: (s: GameState) => T): Promise<T> {
  const s = S();
  const r = fn(s);
  void saver!.persist(s);
  return copy(r);
}

export const localApi = {
  mode: 'local' as const,

  /** Abre o armazenamento e carrega (ou cria) os dados da pessoa. */
  async init(): Promise<{ storage: Store['kind'] }> {
    store = await openStore();
    const docs = await store.load();
    state = fromDocs(docs) ?? emptyState(store.userId, browserTimezone());
    saver = new Saver(store);
    saver.baseline(docs);
    saver.onError = (e) => listeners.error.forEach((l) => l(e));
    return { storage: store.kind };
  },

  /** Recarrega do armazenamento (ex.: ao voltar ao app, para pegar mudanças de outro aparelho). */
  async reload() {
    if (!store || !saver || saver.pending) return;
    const docs = await store.load();
    const loaded = fromDocs(docs);
    if (loaded) { state = loaded; saver.baseline(docs); }
  },

  onSaveError(fn: (e: unknown) => void) { listeners.error.push(fn); },
  storageKind: () => store?.kind ?? 'aparelho',

  exportBackup(): string {
    return JSON.stringify({ app: 'forja', exported_at: new Date().toISOString(), state: S() }, null, 2);
  },
  async importBackup(json: string) {
    const parsed = JSON.parse(json);
    const st = parsed?.state as GameState | undefined;
    if (parsed?.app !== 'forja' || !st || st.version !== 1 || !st.profile) throw new Error('backup_invalido');
    state = { ...st, profile: { ...st.profile, id: store!.userId } };
    await saver!.persist(state);
  },

  // ── Mesmas operações da versão com servidor ──
  ensureToday: async (): Promise<TodayInfo> => commit((s) => E.ensureDay(s, E.localToday(s))),
  submitAssessment: async (answers: Record<string, unknown>) =>
    commit((s) => E.submitAssessment(s, answers)) as Promise<{ scores: Assessment['scores']; priorities: string[]; first_time: boolean }>,
  completeMission: async (id: string): Promise<CompleteResult> => commit((s) => E.completeMission(s, id)),
  undoCompletion: async (id: string) => commit((s) => E.undoCompletion(s, id)),
  createCustomMission: async (p: { name: string; description: string; dimension: string; difficulty: number; minutes: number; recurring: boolean }) =>
    commit((s) => E.createCustomMission(s, p)),
  adjustHabit: async (id: string, target: number, active: boolean) => commit((s) => E.adjustHabit(s, id, target, active)),
  updateProfile: async (p: { displayName?: string; timezone?: string; minDaily?: number }) => commit((s) => E.updateProfile(s, p)),
  journey: async (): Promise<Journey> => copy(E.journey(S(), E.localToday(S()))),

  profile: async (): Promise<Profile> => copy(S().profile),
  stats: async (): Promise<CharacterStats> => statsOf(S(), levelForXp),
  habits: async (): Promise<Habit[]> => copy([...S().habits].sort((a, b) => a.start_day - b.start_day || a.created_at.localeCompare(b.created_at))),
  latestAssessment: async (): Promise<Assessment | null> => copy(S().assessments[S().assessments.length - 1] ?? null),
  missionsFor: async (today: string): Promise<Mission[]> =>
    copy(S().missions.filter((m) => m.mission_date <= today && m.due_date >= today).sort((a, b) => a.created_at.localeCompare(b.created_at))),
  mission: async (id: string): Promise<Mission> => copy(S().missions.find((m) => m.id === id) ?? (() => { throw new Error('missao_nao_encontrada'); })()),
  habitHistory: async (habitId: string): Promise<Mission[]> =>
    copy(S().missions.filter((m) => m.habit_id === habitId && m.kind === 'diaria').sort((a, b) => b.mission_date.localeCompare(a.mission_date)).slice(0, 14)),
  ledger: async (limit = 30): Promise<LedgerEntry[]> => copy([...S().ledger].sort((a, b) => b.created_at.localeCompare(a.created_at) || b.id - a.id).slice(0, limit)),
  missionNames: async (ids: string[]) => S().missions.filter((m) => ids.includes(m.id)).map((m) => ({ id: m.id, name: m.name })),
  progression: async (): Promise<ProgressionEvent[]> => copy([...S().progression].reverse().slice(0, 20)),
};
