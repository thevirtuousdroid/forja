import { supabase } from './supabase';
// Versão com servidor (Supabase): várias pessoas, regras do jogo no banco.
import type {
  Assessment, CharacterStats, CompleteResult, Habit, Journey, LedgerEntry, Mission, Profile, ProgressionEvent, TodayInfo,
} from './types';

async function rpc<T>(fn: string, args?: Record<string, unknown>): Promise<T> {
  const { data, error } = await supabase.rpc(fn, args);
  if (error) throw new Error(error.message);
  return data as T;
}

async function rows<T>(query: PromiseLike<{ data: unknown; error: { message: string } | null }>): Promise<T> {
  const { data, error } = await query;
  if (error) throw new Error(error.message);
  return data as T;
}

export const api = {
  mode: 'supabase' as const,
  ensureToday: () => rpc<TodayInfo>('ensure_today'),
  submitAssessment: (answers: Record<string, unknown>) =>
    rpc<{ scores: Assessment['scores']; priorities: string[]; first_time: boolean }>('submit_assessment', { p_answers: answers }),
  completeMission: (id: string) => rpc<CompleteResult>('complete_mission', { p_mission: id }),
  undoCompletion: (id: string) => rpc<{ desfeita: boolean }>('undo_completion', { p_mission: id }),
  createCustomMission: (p: { name: string; description: string; dimension: string; difficulty: number; minutes: number; recurring: boolean }) =>
    rpc<unknown>('create_custom_mission', {
      p_name: p.name, p_description: p.description, p_dimension: p.dimension,
      p_difficulty: p.difficulty, p_minutes: p.minutes, p_recurring: p.recurring,
    }),
  adjustHabit: (id: string, target: number, active: boolean) =>
    rpc<unknown>('adjust_habit', { p_habit: id, p_target: target, p_active: active }),
  updateProfile: (p: { displayName?: string; timezone?: string; minDaily?: number }) =>
    rpc<unknown>('update_profile', {
      p_display_name: p.displayName ?? null, p_timezone: p.timezone ?? null, p_min_daily: p.minDaily ?? null,
    }),
  journey: () => rpc<Journey>('get_journey'),

  profile: () => rows<Profile>(supabase.from('profiles').select('*').single()),
  stats: () => rows<CharacterStats>(supabase.from('character_stats').select('*').single()),
  habits: () => rows<Habit[]>(supabase.from('user_habits').select('*').order('start_day').order('created_at')),
  latestAssessment: () =>
    rows<Assessment[]>(supabase.from('assessments').select('*').order('created_at', { ascending: false }).limit(1))
      .then((r) => r[0] ?? null),
  missionsFor: (today: string) =>
    rows<Mission[]>(
      supabase.from('missions').select('*').lte('mission_date', today).gte('due_date', today).order('created_at'),
    ),
  mission: (id: string) => rows<Mission>(supabase.from('missions').select('*').eq('id', id).single()),
  habitHistory: (habitId: string) =>
    rows<Mission[]>(
      supabase.from('missions').select('*').eq('habit_id', habitId).eq('kind', 'diaria')
        .order('mission_date', { ascending: false }).limit(14),
    ),
  ledger: (limit = 30) =>
    rows<LedgerEntry[]>(supabase.from('xp_ledger').select('*').order('created_at', { ascending: false }).limit(limit)),
  missionNames: (ids: string[]) =>
    ids.length === 0
      ? Promise.resolve([] as Pick<Mission, 'id' | 'name'>[])
      : rows<Pick<Mission, 'id' | 'name'>[]>(supabase.from('missions').select('id,name').in('id', ids)),
  progression: () =>
    rows<ProgressionEvent[]>(supabase.from('progression_events').select('*').order('created_at', { ascending: false }).limit(20)),
};
