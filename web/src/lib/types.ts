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
}

export interface LedgerEntry {
  id: number;
  mission_id: string | null;
  source: 'missao' | 'meta_diaria' | 'retorno' | 'marco' | 'conquista' | 'chefe';
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

export type AchievementCategory = 'missoes' | 'sequencia' | 'programa' | 'nivel' | 'atributos' | 'habitos' | 'chefes' | 'modos';

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
  | (EventBase & { kind: 'modo_rebaixado'; data: { date: string } });
