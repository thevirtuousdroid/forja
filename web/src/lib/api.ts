// Acesso ao servidor (Supabase). O app só lê tabelas; toda mudança passa por funções do banco.
import { supabase } from './supabase';
import type {
  Achievement, AchievementDef, Assessment, AvatarConfig, Book, BossDef, BossesInfo, CatalogItem, Challenge, CharacterStats,
  CheerKind, CodeLookup, CompleteResult, DiaryEntry, FeedPost, FriendProfile, GameEvent, GroupDetail, GroupSummary, Habit,
  HabitTrack, Journey, LedgerAttrRow, LedgerEntry, Lite, MentorInfo, Mission, Mode, ModeInfo, NewChallenge, OwnedItem, PlanInfo,
  PostKind, Privacy, Profile, ProgressionEvent, Ranking, RankingCategory, SeasonInfo, SocialInfo, SocialNotification, TodayInfo,
  ToolDay, ToolHistory, ToolId, ToolSettings, ToolsOverview, WeeklyReport,
} from './types';

export { friendlyError, isPremiumError } from './errors';

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

  // ── Plano ──
  planInfo: () => rpc<PlanInfo>('get_plan_info'),

  // ── Amigos, privacidade e avisos sociais ──
  social: () => rpc<SocialInfo>('get_social'),
  updatePrivacy: (p: Partial<Privacy>) => rpc<Privacy>('update_privacy', { p_privacy: p }),
  resetFriendCode: () => rpc<{ friend_code: string }>('reset_friend_code'),
  lookupCode: (code: string) => rpc<CodeLookup>('lookup_friend_code', { p_code: code }),
  sendFriendRequest: (code: string) =>
    rpc<{ status: 'pendente' | 'aceita'; name: string; avatar: Lite['avatar'] }>('send_friend_request', { p_code: code }),
  respondFriendRequest: (id: string, accept: boolean) =>
    rpc<{ status: 'aceita' | 'recusada'; user?: Lite }>('respond_friend_request', { p_id: id, p_accept: accept }),
  removeFriend: (userId: string) => rpc<{ ok: boolean }>('remove_friend', { p_user: userId }),
  friendProfile: (userId: string) => rpc<FriendProfile>('friend_profile', { p_user: userId }),
  notifications: () => rpc<{ unseen: number; items: SocialNotification[] }>('get_notifications'),

  // ── Feed e incentivos ──
  feed: (before?: number) => rpc<FeedPost[]>('friends_feed', { p_before: before ?? null }),
  sharePost: (kind: PostKind, ref: string) => rpc<{ id: number; already: boolean }>('share_post', { p_kind: kind, p_ref: ref }),
  deletePost: (id: number) => rpc<{ ok: boolean }>('delete_post', { p_id: id }),
  cheer: (post: number | null, user: string | null, kind: CheerKind) =>
    rpc<{ state: CheerKind | null }>('send_cheer', { p_post: post, p_user: user, p_kind: kind }),

  // ── Grupos ──
  groups: () => rpc<GroupSummary[]>('get_groups'),
  group: (id: string) => rpc<GroupDetail>('group_detail', { p_group: id }),
  createGroup: (name: string, description: string) =>
    rpc<{ id: string; invite_code: string }>('create_group', { p_name: name, p_description: description }),
  joinGroup: (code: string) => rpc<{ id: string; name: string; already: boolean }>('join_group', { p_code: code }),
  leaveGroup: (id: string) => rpc<{ ok: boolean }>('leave_group', { p_group: id }),
  removeMember: (group: string, user: string) => rpc<{ ok: boolean }>('remove_group_member', { p_group: group, p_user: user }),
  updateGroup: (id: string, name: string, description: string) =>
    rpc<{ ok: boolean }>('update_group', { p_group: id, p_name: name, p_description: description }),
  resetGroupCode: (id: string) => rpc<{ invite_code: string }>('reset_group_code', { p_group: id }),

  // ── Desafios ──
  challenges: () => rpc<Challenge[]>('get_challenges'),
  challenge: (id: string) => rpc<Challenge>('challenge_detail', { p_id: id }),
  createChallenge: (c: NewChallenge) => rpc<{ id: string }>('create_challenge', { p_data: c }),
  respondChallenge: (id: string, accept: boolean) => rpc<{ status: string }>('respond_challenge', { p_id: id, p_accept: accept }),
  leaveChallenge: (id: string) => rpc<{ ok: boolean }>('leave_challenge', { p_id: id }),
  cancelChallenge: (id: string) => rpc<{ ok: boolean }>('cancel_challenge', { p_id: id }),

  // ── Temporada e ranking ──
  season: () => rpc<SeasonInfo>('get_season'),
  ranking: (scope: 'amigos' | 'grupo', group: string | null, category: RankingCategory) =>
    rpc<Ranking>('get_ranking', { p_scope: scope, p_group: group, p_category: category }),

  // ── Ferramentas ──
  toolsOverview: () => rpc<ToolsOverview>('tools_overview'),
  tool: <T extends ToolId>(t: T) => rpc<ToolDay<T>>('get_tool', { p_tool: t }),
  logTool: <T extends ToolId>(t: T, data: Record<string, unknown>) => rpc<ToolDay<T>>('log_tool', { p_tool: t, p_data: data }),
  deleteToolLog: (id: number) => rpc<ToolDay>('delete_tool_log', { p_id: id }),
  toolHistory: (t: ToolId, days: number) => rpc<ToolHistory>('tool_history', { p_tool: t, p_days: days }),
  updateToolSettings: (s: Partial<ToolSettings>) => rpc<ToolSettings>('update_tool_settings', { p_settings: s }),
  diary: (limit = 30) => rpc<DiaryEntry[]>('get_diary', { p_limit: limit }),
  books: () => rpc<Book[]>('get_books'),
  saveBook: (id: string | null, title: string, author: string, totalPages: number | null) =>
    rpc<Book>('save_book', { p_id: id, p_title: title, p_author: author, p_total_pages: totalPages }),
  setBookStatus: (id: string, status: Book['status']) => rpc<Book>('set_book_status', { p_id: id, p_status: status }),
  habitTracker: () => rpc<HabitTrack[]>('habit_tracker'),

  // ── Mentor ──
  mentor: () => rpc<MentorInfo>('get_mentor'),
  setMentor: (enabled: boolean) => rpc<{ enabled: boolean }>('set_mentor', { p_enabled: enabled }),
  respondSuggestion: (id: string, accept: boolean) =>
    rpc<{ status: 'aceita' | 'recusada'; kind: string; link?: string | null }>('respond_suggestion', { p_id: id, p_accept: accept }),
  report: (week: string | null) => rpc<WeeklyReport>('get_report', { p_week: week }),
};
