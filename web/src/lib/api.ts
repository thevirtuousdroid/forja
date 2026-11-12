// Acesso ao servidor (Supabase). O app só lê tabelas; toda mudança passa por funções do banco.
import { supabase } from './supabase';
import type {
  Achievement, AchievementDef, Assessment, AvatarConfig, BossDef, BossesInfo, CatalogItem, CharacterStats, CompleteResult,
  GameEvent, Habit, Journey, LedgerAttrRow, LedgerEntry, Mission, Mode, ModeInfo, OwnedItem, Profile, ProgressionEvent, TodayInfo,
} from './types';

export { friendlyError } from './errors';

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

export interface Catalogs {
  items: CatalogItem[];
  achievements: Pick<AchievementDef, 'id' | 'name' | 'category' | 'rarity'>[];
  bosses: Pick<BossDef, 'id' | 'name' | 'epithet' | 'dimension' | 'hit_rule'>[];
}

// Os catálogos mudam só com uma nova versão do banco: carregados uma vez por sessão.
let catalogsCache: Promise<Catalogs> | null = null;

export const api = {
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
    rows<LedgerEntry[]>(supabase.from('xp_ledger').select('*').order('created_at', { ascending: false }).order('id', { ascending: false }).limit(limit)),
  ledgerSince: (day: string) =>
    rows<LedgerAttrRow[]>(
      supabase.from('xp_ledger').select('day,disciplina,foco,vitalidade,conhecimento,determinacao').gte('day', day),
    ),
  missionNames: (ids: string[]) =>
    ids.length === 0
      ? Promise.resolve([] as Pick<Mission, 'id' | 'name'>[])
      : rows<Pick<Mission, 'id' | 'name'>[]>(supabase.from('missions').select('id,name').in('id', ids)),
  fightBosses: (ids: string[]) =>
    ids.length === 0
      ? Promise.resolve([] as { id: string; boss_id: string }[])
      : rows<{ id: string; boss_id: string }[]>(supabase.from('user_bosses').select('id,boss_id').in('id', ids)),
  progression: () =>
    rows<ProgressionEvent[]>(supabase.from('progression_events').select('*').order('created_at', { ascending: false }).limit(20)),

  // ── Personagem ──
  catalogs: (): Promise<Catalogs> => {
    catalogsCache ??= Promise.all([
      rows<CatalogItem[]>(supabase.from('item_catalog').select('*').order('sort')),
      rows<Catalogs['achievements']>(supabase.from('achievement_catalog').select('id,name,category,rarity').order('sort')),
      rows<Catalogs['bosses']>(supabase.from('boss_catalog').select('id,name,epithet,dimension,hit_rule').order('sort')),
    ]).then(([items, achievements, bosses]) => ({ items, achievements, bosses }))
      .catch((e) => { catalogsCache = null; throw e; });
    return catalogsCache;
  },
  ownedItems: () => rows<OwnedItem[]>(supabase.from('user_items').select('item_id,source,unlocked_at')),
  updateAvatar: (cfg: AvatarConfig) => rpc<AvatarConfig>('update_avatar', { p_avatar: cfg }),
  setTitle: (id: string | null) => rpc<unknown>('set_title', { p_title: id }),
  achievements: () => rpc<{ items: Achievement[] }>('get_achievements').then((r) => r.items),
  unlockedAchievements: () => rows<{ achievement_id: string }[]>(supabase.from('user_achievements').select('achievement_id')),
  defeatedBosses: () => rows<{ boss_id: string }[]>(supabase.from('user_bosses').select('boss_id').eq('status', 'vencido')),

  // ── Chefes ──
  bosses: () => rpc<BossesInfo>('get_bosses'),
  startBoss: (id: string) => rpc<{ fight_id: string }>('start_boss', { p_boss: id }),
  abandonBoss: () => rpc<{ ok: boolean }>('abandon_boss'),

  // ── Modos ──
  modeInfo: () => rpc<ModeInfo>('get_mode_info'),
  setMode: (mode: Mode, accept: boolean) => rpc<{ mode: Mode; changed: boolean }>('set_mode', { p_mode: mode, p_accept: accept }),

  // ── Avisos ──
  pendingEvents: () => rpc<GameEvent[]>('pending_events'),
  markEventsSeen: (ids: number[]) => rpc<{ marked: number }>('mark_events_seen', { p_ids: ids }),
};
