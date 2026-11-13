export type Dimension = 'fisica' | 'mental' | 'intelectual' | 'produtividade' | 'digital' | 'autocuidado';
export type Attribute = 'disciplina' | 'foco' | 'vitalidade' | 'conhecimento' | 'determinacao';
export type MissionKind = 'diaria' | 'semanal' | 'especial' | 'personalizada' | 'surpresa';
export type MissionStatus = 'pendente' | 'concluida' | 'expirada';
export type Period = 'manha' | 'tarde' | 'noite' | 'qualquer';
export type Unit = 'min' | 'copos' | 'paginas' | 'vez';
export type Mode = 'normal' | 'desafio' | 'extremo';
export type Rarity = 'comum' | 'raro' | 'epico' | 'lendario';
export type Slot = 'cabeca' | 'corpo' | 'capa' | 'arma' | 'amuleto' | 'moldura';

export interface AvatarConfig {
  pele: number;
  cabelo: number;
  corCabelo: number;
  barba: number;
  corRoupa: number;
  personalizado?: boolean;
  equip: Partial<Record<Slot, string>>;
}

export interface Profile {
  id: string;
  display_name: string;
  timezone: string;
  program_start: string | null;
  onboarding_done: boolean;
  min_daily_missions: number;
  mode: Mode;
  plan: 'free' | 'premium';
  avatar: AvatarConfig | Record<string, never>;
  active_title: string | null;
  mode_cooldown_until: string | null;
  friend_code?: string;
  privacy?: Partial<Privacy>;
  tool_settings?: Partial<ToolSettings>;
  mentor_enabled?: boolean;
}

export interface CharacterStats {
  user_id: string;
  total_xp: number;
  level: number;
  disciplina: number;
  foco: number;
  vitalidade: number;
  conhecimento: number;
  determinacao: number;
}

export interface Habit {
  id: string;
  template_id: string | null;
  name: string;
  description: string;
  dimension: Dimension;
  attr_primary: Attribute;
  attr_secondary: Attribute;
  difficulty: number;
  unit: Unit;
  base_value: number;
  step: number;
  max_value: number;
  current_target: number;
  start_day: number;
  period: Period;
  is_custom: boolean;
  active: boolean;
}

export interface Mission {
  id: string;
  habit_id: string | null;
  kind: MissionKind;
  name: string;
  description: string;
  dimension: Dimension;
  attr_primary: Attribute;
  attr_secondary: Attribute;
  difficulty: number;
  estimated_minutes: number;
  target_value: number;
  unit: Unit;
  period: Period;
  frequency: 'diaria' | 'semanal' | 'unica';
  xp_reward: number;
  mission_date: string;
  due_date: string;
  status: MissionStatus;
  completed_at: string | null;
}

export interface Assessment {
  id: string;
  answers: Record<string, unknown>;
  scores: Record<Dimension, number>;
  priorities: Dimension[];
  created_at: string;
}

export interface BossSummary {
  fight_id: string;
  boss_id: string;
  name: string;
  epithet: string;
  hit_rule: BossRule;
  dimension: Dimension | null;
  hp: number;
  effective: number;
  today_hit: boolean;
  deadline: string;
  days_left: number;
}

export interface TodayInfo {
  onboarding_done: boolean;
  today: string;
  day: number;
  phase: number;
  week: number;
  mode?: Mode;
  boss?: BossSummary | null;
  /** Avisos sociais ainda não vistos (pedidos, incentivos, convites). */
  social_unseen?: number;
  /** Premium vale agora (plano próprio ou liberação para todos). */
  premium?: boolean;
  /** Sugestões abertas do Mentor. */
  mentor_open?: number;
}

export interface LedgerEntry {
  id: number;
  mission_id: string | null;
  source: 'missao' | 'meta_diaria' | 'retorno' | 'marco' | 'conquista' | 'chefe' | 'desafio' | 'temporada';
  ref: string | null;
  day: string;
  amount: number;
  created_at: string;
}

export interface LedgerAttrRow {
  day: string;
  disciplina: number;
  foco: number;
  vitalidade: number;
  conhecimento: number;
  determinacao: number;
}

export interface ProgressionEvent {
  id: number;
  habit_id: string;
  week: number;
  old_target: number;
  new_target: number;
  completed_days: number;
  created_at: string;
}

export type DayStatus = 'completo' | 'parcial' | 'vazio' | 'protegido' | 'hoje';

export interface JourneyDay {
  date: string;
  status: DayStatus;
  done: number;
  total: number;
  goal?: number;
  mode?: Mode;
  perfect?: boolean;
}

export interface Journey {
  current_streak: number;
  best_streak: number;
  shields: number;
  max_shields: number;
  consistency: number | null;
  milestones: number[];
  days: JourneyDay[];
}

export interface BossHitResult {
  fight_id: string;
  boss_id: string;
  name: string;
  hp: number;
  before: number;
  effective: number;
  today_hit: boolean;
  status: 'ativo' | 'vencido' | 'recuou';
}

export interface CompleteResult {
  ja_concluida: boolean;
  xp?: number;
  bonus?: { tipo: 'meta_diaria' | 'retorno'; xp: number }[];
  nivel_antes?: number;
  nivel?: number;
  xp_total?: number;
  chefe?: BossHitResult | null;
}

// ── Personagem, itens e conquistas ──────────────────────────────────────────

export interface CatalogItem {
  id: string;
  kind: 'equipamento' | 'titulo';
  slot: Slot | null;
  name: string;
  description: string;
  rarity: Rarity;
  unlock_type: 'inicial' | 'nivel' | 'conquista' | 'chefe';
  unlock_level: number | null;
  unlock_ref: string | null;
  sort: number;
}

export interface OwnedItem {
  item_id: string;
  source: string;
  unlocked_at: string;
}

export interface RewardRef {
  id: string;
  name: string;
  kind: 'equipamento' | 'titulo';
  slot: Slot | null;
  rarity: Rarity;
}

export type AchievementCategory =
  | 'missoes' | 'sequencia' | 'programa' | 'nivel' | 'atributos' | 'habitos' | 'chefes' | 'modos'
  | 'social' | 'temporadas' | 'ferramentas';

export interface AchievementDef {
  id: string;
  category: AchievementCategory;
  name: string;
  description: string;
  rarity: Rarity;
  metric: string;
  threshold: number;
  xp: number;
  attr: Attribute;
  hidden: boolean;
  sort: number;
}

export interface Achievement extends AchievementDef {
  unlocked_at: string | null;
  current: number;
  rewards: RewardRef[];
}

// ── Chefes ──────────────────────────────────────────────────────────────────

export type BossRule = 'dimensao' | 'meta_diaria' | 'dia_perfeito';

export interface BossDef {
  id: string;
  name: string;
  epithet: string;
  story: string;
  objective: string;
  difficulty: number;
  hit_rule: BossRule;
  dimension: Dimension | null;
  hp: number;
  window_days: number;
  unlock_day: number;
  requires_victories: number;
  xp_reward: number;
  attr_primary: Attribute;
  attr_secondary: Attribute;
  sort: number;
}

export interface BossDay { date: string; hit: boolean; heal: boolean }

export interface BossFight {
  id: string;
  started_on: string;
  deadline: string;
  hp: number;
  effective: number;
  heals: number;
  today_hit: boolean;
  days: BossDay[];
  days_left: number;
  rematch: boolean;
}

export interface BossLock {
  reason: 'dia' | 'vitorias' | 'habito';
  day?: number;
  needed?: number;
  have?: number;
  dimension?: Dimension;
}

export interface Boss extends BossDef {
  state: 'bloqueado' | 'disponivel' | 'ativo' | 'vencido';
  lock: BossLock | null;
  fight: BossFight | null;
  victories: number;
  last: { status: 'vencido' | 'recuou' | 'desistiu'; finished_at: string | null; hits: number; hp: number } | null;
  rewards: RewardRef[];
}

export interface BossesInfo {
  day: number;
  active: string | null;
  mode: Mode;
  bosses: Boss[];
}

// ── Modos ───────────────────────────────────────────────────────────────────

export interface ModeInfo {
  mode: Mode;
  since: string | null;
  day: number;
  best_streak: number;
  cooldown_until: string | null;
  extremo_failures: number;
  desafio: { available: boolean; unlock_day: number };
  extremo: { available: boolean; unlock_day: number; streak_needed: number };
}

// ── Avisos (recompensas e mudanças que o app mostra uma vez) ────────────────

interface EventBase { id: number; ref: string; created_at: string }
export interface FightRow {
  id: string;
  boss_id: string;
  started_on: string;
  deadline: string;
  hp: number;
  hits: number;
  heals: number;
  rematch: boolean;
  status: string;
}
export type GameEvent =
  | (EventBase & { kind: 'nivel'; data: { level: number } })
  | (EventBase & { kind: 'conquista'; data: AchievementDef & { rewards: RewardRef[] } })
  | (EventBase & { kind: 'item'; data: CatalogItem })
  | (EventBase & { kind: 'chefe_vencido'; data: { boss: BossDef; fight: FightRow; xp: number | null; rewards: RewardRef[] } })
  | (EventBase & { kind: 'chefe_recuou'; data: { boss: BossDef; fight: FightRow } })
  | (EventBase & { kind: 'modo_rebaixado'; data: { date: string } })
  | (EventBase & { kind: 'temporada'; data: SeasonResultEvent })
  | (EventBase & { kind: 'desafio_fim'; data: ChallengeEndEvent })
  | (EventBase & { kind: 'relatorio'; data: ReportEvent });

// ════════════════════════════════════════════════════════════════════════════
// Etapa 4: social, temporadas, ferramentas e Mentor
// ════════════════════════════════════════════════════════════════════════════

/** Identificação mínima de outra pessoa (nome e aparência). */
export interface Lite { id: string; name: string; avatar: AvatarConfig | Record<string, never> }

export interface Privacy {
  mostrar_nivel: boolean;
  mostrar_sequencia: boolean;
  mostrar_conquistas: boolean;
  mostrar_atributos: boolean;
  mostrar_habitos: boolean;
  publicar_automatico: boolean;
  aceitar_pedidos: boolean;
  participar_ranking: boolean;
}

/** Cartão de uma pessoa: os campos opcionais só vêm se ela deixou mostrar. */
export interface PersonCard extends Lite {
  onboarded: boolean;
  level?: number;
  title?: string;
  streak?: number;
  best_streak?: number;
  today?: { done: number; goal: number; met: boolean } | null;
  last_active?: string | null;
  achievements?: number;
  areas?: Dimension[];
}

export interface FriendCard extends PersonCard { friendship_id: string; since: string | null }
export interface FriendRequest { id: string; created_at: string; user: Lite }

export interface SocialInfo {
  me: { id: string; friend_code: string; privacy: Privacy };
  friends: FriendCard[];
  incoming: FriendRequest[];
  outgoing: FriendRequest[];
  limits: { friends: number; pending: number };
  unseen: number;
}

export interface CodeLookup {
  name: string;
  avatar: AvatarConfig | Record<string, never>;
  status: 'nenhum' | 'amigos' | 'pedido_enviado' | 'pedido_recebido';
  accepts: boolean;
}

export type LeagueId = 'bronze' | 'prata' | 'ouro' | 'platina' | 'diamante' | 'mestre';
export interface League { id: LeagueId; name: string; min_points: number; xp_reward: number; sort: number }

export interface FriendProfile {
  card: PersonCard;
  me: PersonCard;
  relation: 'eu' | 'amigo' | 'grupo';
  friendship_id: string | null;
  since: string | null;
  groups_in_common: { id: string; name: string }[];
  privacy: { nivel: boolean; sequencia: boolean; conquistas: boolean; atributos: boolean };
  attributes?: Record<Attribute, number>;
  my_attributes?: Record<Attribute, number>;
  achievements?: { id: string; name: string; rarity: Rarity; category: AchievementCategory; unlocked_at: string }[];
  bosses?: number;
  my_bosses?: number;
  week?: { date: string; status: DayStatus }[];
  consistency?: number | null;
  season?: { points: number; league: League };
  my_season?: { points: number; league: League };
}

export type CheerKind = 'parabens' | 'forca' | 'brasa' | 'foco' | 'volta';
export type PostKind = 'conquista' | 'chefe' | 'nivel' | 'temporada';

interface PostBase { id: number; ref: string; created_at: string; author: Lite; mine: boolean;
  cheers: Partial<Record<CheerKind, number>>; cheerers: Lite[]; my_cheer: CheerKind | null }
export type FeedPost =
  | (PostBase & { kind: 'conquista'; data: { id: string; name: string; description: string; rarity: Rarity; category: AchievementCategory } })
  | (PostBase & { kind: 'chefe'; data: { boss_id: string; name: string; epithet: string; difficulty: number; rematch: boolean; days: number } })
  | (PostBase & { kind: 'nivel'; data: { level: number } })
  | (PostBase & { kind: 'temporada'; data: { season: number; name: string; league: LeagueId; league_name: string; points: number } });

export type ParticipantStatus = 'convidado' | 'aceito' | 'recusado' | 'saiu';
export type ChallengeKind = 'competitivo' | 'coletivo';
export type ChallengeMetric = 'meta_diaria' | 'missoes' | 'area';
export type ChallengeResult = 'venceu' | 'meta_coletiva' | 'participou';

interface NotifBase { id: number; seen: boolean; created_at: string }
export type SocialNotification =
  | (NotifBase & { kind: 'pedido_amizade'; data: { request_id: string; status: 'pendente' | 'aceita' | 'recusada'; user: Lite } })
  | (NotifBase & { kind: 'amizade_aceita'; data: { user: Lite } })
  | (NotifBase & { kind: 'incentivo'; data: { cheer: CheerKind; user: Lite; post: { id: number; kind: PostKind; data: FeedPost['data'] } | null } })
  | (NotifBase & { kind: 'desafio_convite'; data: { user: Lite; my_status: ParticipantStatus | null;
      challenge: { id: string; title: string; kind: ChallengeKind; metric: ChallengeMetric; starts_on: string; ends_on: string; status: Challenge['status'] } } })
  | (NotifBase & { kind: 'grupo_entrada'; data: { group: { id: string; name: string }; user: Lite } });

export interface GroupSummary {
  id: string; name: string; description: string; invite_code: string; role: 'dono' | 'membro';
  owner: Lite; members: number; preview: Lite[];
}
export interface GroupMember extends PersonCard { role: 'dono' | 'membro'; joined_at: string; friend: boolean }
export interface GroupDetail {
  id: string; name: string; description: string; invite_code: string; role: 'dono' | 'membro';
  owner: Lite; created_at: string; members: GroupMember[]; challenges: Challenge[];
}

export interface ChallengeParticipant {
  user: Lite; status: ParticipantStatus; me: boolean; score: number; rank: number | null; result: ChallengeResult | null; xp: number;
}
export interface Challenge {
  id: string; title: string; kind: ChallengeKind; metric: ChallengeMetric; dimension: Dimension | null; target: number | null;
  starts_on: string; ends_on: string; status: 'ativo' | 'encerrado' | 'cancelado';
  phase: 'agendado' | 'em_andamento' | 'encerrando' | 'encerrado' | 'cancelado';
  days: number; day_index: number; creator: Lite; is_creator: boolean; group: { id: string; name: string } | null;
  my_status: ParticipantStatus | null; my_result: ChallengeResult | null; my_xp: number | null;
  participants: ChallengeParticipant[]; total: number;
}
export interface NewChallenge {
  kind: ChallengeKind; metric: ChallengeMetric; dimension?: Dimension; days: number; start_tomorrow: boolean;
  title?: string; group_id?: string; friends?: string[]; target?: number;
}

export interface SeasonObjective { id: string; name: string; progress: number; target: number; points: number; done: boolean }
export interface SeasonBreakdown { meta: number; missoes: number; perfeitos: number; chefes: number; desafios: number; objetivos: number }
export interface SeasonHistoryItem { season: number; name: string; year: number; points: number; league: LeagueId; xp: number; rank: number | null; of: number | null }
export interface SeasonInfo {
  id: number; name: string; year: number; starts_on: string; ends_on: string; days_left: number;
  points: number; league: League; next: League | null;
  goal_days: number; perfect_days: number; boss_wins: number; challenges: number;
  breakdown: SeasonBreakdown; objectives: SeasonObjective[]; leagues: League[]; history: SeasonHistoryItem[];
}

export type RankingCategory = 'pontos' | 'constancia' | 'xp' | 'chefes';
export interface RankingRow { user: Lite; value: number; points: number; league: LeagueId; me: boolean; hidden: boolean; level: number | null; rank: number }
export interface Ranking { scope: 'amigos' | 'grupo'; category: RankingCategory; season: { id: number; name: string; days_left: number }; rows: RankingRow[] }

export interface PlanFeature { id: string; name: string; description: string; premium: boolean; allowed: boolean }
export interface PlanInfo { plan: 'free' | 'premium'; premium: boolean; via: 'plano' | 'liberado' | null; open_until: string | null; features: PlanFeature[] }

export interface SeasonResultEvent {
  season: number; name: string; year: number; points: number; xp: number; league: League;
  rank: number | null; of: number | null; goal_days: number; perfect_days: number; boss_wins: number;
}
export interface ChallengeEndEvent {
  challenge: { id: string; title: string; kind: ChallengeKind; metric: ChallengeMetric; dimension: Dimension | null; target: number | null; starts_on: string; ends_on: string };
  score: number; rank: number | null; result: ChallengeResult | null; xp: number; participants: number; total: number; winners: Lite[];
}
export interface ReportEvent { week_start: string; week_end: string; missions: number; goal_days: number; days: number; xp: number; highlight: string }

// ── Ferramentas ─────────────────────────────────────────────────────────────

export type ToolId = 'foco' | 'agua' | 'sono' | 'alimentacao' | 'leitura' | 'meditacao' | 'tela' | 'diario';
export interface ToolSettings {
  agua_meta: number; agua_ml: number; sono_meta: number; sono_deitar: string; tela_limite: number; foco_min: number; pausa_min: number;
}
export interface ToolMission { id: string; name: string; unit: Unit; target: number; progress: number; status: MissionStatus; ready: boolean }
export interface ToolEntry { id: number; data: Record<string, unknown>; mission_id: string | null; created_at: string }

export interface ToolSummaries {
  foco: { minutes: number; sessions: number };
  agua: { cups: number; goal: number; cup_ml: number };
  sono: { logged: boolean; minutes: number | null; bed: string | null; wake: string | null; quality: number | null; goal: number; bedtime: string };
  alimentacao: { kcal: number; meals: number; with_kcal: number };
  leitura: { pages: number; minutes: number; book: { id: string; title: string; current_page: number; total_pages: number | null } | null };
  meditacao: { minutes: number; sessions: number };
  tela: { logged: boolean; minutes: number | null; limit: number };
  diario: { written: boolean; mood: number | null };
}
export interface ToolDay<T extends ToolId = ToolId> {
  tool: T; day: string; summary: ToolSummaries[T]; entries: ToolEntry[]; missions: ToolMission[];
  focusable: { id: string; name: string; target: number }[] | null; settings: ToolSettings;
}
export interface ToolsOverview { day: string; extras: boolean; settings: ToolSettings; summary: ToolSummaries; ready: number }
export interface ToolHistory { tool: ToolId; days: { date: string; value: number | null; extra: number | null }[]; settings: ToolSettings }
export interface DiaryEntry { id: number; day: string; text: string; mood: number | null; gratitude: string | null }
export interface Book {
  id: string; title: string; author: string; total_pages: number | null; current_page: number;
  status: 'lendo' | 'concluido' | 'pausado'; started_on: string; finished_on: string | null; created_at: string;
}
export type TrackStatus = 'feito' | 'perdido' | 'pendente' | 'sem';
export interface HabitTrack {
  habit: { id: string; name: string; dimension: Dimension; unit: Unit; current_target: number; active: boolean; is_custom: boolean; period: Period };
  days: { date: string; status: TrackStatus }[]; done: number; streak: number;
}

// ── Mentor ──────────────────────────────────────────────────────────────────

export interface MentorInsight { id: string; tone: 'positivo' | 'neutro' | 'atencao'; title: string; text: string }
export type SuggestionKind =
  | 'reduzir_meta' | 'pausar_habito' | 'reduzir_minimo' | 'aumentar_minimo' | 'experimentar_desafio' | 'enfrentar_chefe' | 'descansar';
export interface MentorSuggestion {
  id: string; kind: SuggestionKind; created_on: string;
  data: { title: string; text: string; action: string; link?: string } & Record<string, unknown>;
}
export interface WeeklyReport {
  week_start: string; week_end: string; until: string; complete: boolean;
  missions: number; missions_prev: number; days: number; goal_days: number; perfect_days: number; xp: number; xp_prev: number;
  areas: Partial<Record<Dimension, number>>; strongest: Dimension | null; weakest: Dimension | null;
  best_day: { date: string; done: number } | null;
  achievements: { id: string; name: string; rarity: Rarity }[]; bosses: string[];
  tools: { foco_min: number; meditacao_min: number; paginas: number; diario_dias: number; humor_medio: number | null; sono_medio: number | null; agua_dias: number };
  streak: number; highlight: string; focus: string | null;
}
export interface MentorInfo {
  enabled: boolean; allowed: boolean; reports_allowed: boolean;
  mode?: Mode; insights?: MentorInsight[]; suggestions?: MentorSuggestion[];
  this_week?: WeeklyReport | null; reports?: { week_start: string; missions: number; goal_days: number }[];
}

// ── Notificações ────────────────────────────────────────────────────────────

export interface NotifySettings {
  lembrete: boolean; lembrete_hora: string;   // "09:00"
  risco: boolean; risco_hora: string;
  social: boolean;
}
export interface PushDevice {
  id: string; endpoint: string; device: string; created_at: string;
  last_ok_at: string | null; last_status: number | null; last_error: string | null;
}
export interface NotifyInfo {
  /** O administrador já informou o endereço do app no banco. */
  configured: boolean;
  /** As chaves de envio já existem (a tela pede na primeira abertura). */
  ready: boolean;
  public_key: string | null;
  settings: NotifySettings;
  devices: PushDevice[];
}
