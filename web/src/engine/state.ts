import type {
  Assessment, Attribute, CharacterStats, Dimension, Habit, LedgerEntry, Mission, Period, Profile, ProgressionEvent, Unit,
} from '../lib/types';

export interface Template {
  id: string;
  dimension: Dimension;
  name: string;
  description: string;
  attr_primary: Attribute;
  attr_secondary: Attribute;
  difficulty: number;
  unit: Unit;
  base_value: number;
  step: number;
  max_value: number;
  est_minutes: number;
  period: Period;
  tier: number;
  sort: number;
  passive: boolean;
}

/** Habit + campos internos que o app não exibe. */
export interface HabitRow extends Habit {
  est_minutes: number;
  created_at: string;
}

export interface MissionRow extends Mission {
  dedupe_key: string;
  created_at: string;
}

export interface LedgerRow extends LedgerEntry {
  disciplina: number;
  foco: number;
  vitalidade: number;
  conhecimento: number;
  determinacao: number;
}

export type BaseAttributes = Record<Attribute, number>;

/** Tudo o que pertence a uma pessoa. Missões e histórico ficam separados por mês na hora de salvar. */
export interface GameState {
  version: 1;
  profile: Profile;
  base: BaseAttributes;
  assessments: Assessment[];
  habits: HabitRow[];
  missions: MissionRow[];
  ledger: LedgerRow[];
  progression: ProgressionEvent[];
  progressionChecks: number[];
  seq: number;
}

export function emptyState(userId: string, timezone: string): GameState {
  return {
    version: 1,
    profile: {
      id: userId, display_name: '', timezone, program_start: null, onboarding_done: false,
      min_daily_missions: 2, mode: 'normal', plan: 'free',
    },
    base: { disciplina: 0, foco: 0, vitalidade: 0, conhecimento: 0, determinacao: 0 },
    assessments: [], habits: [], missions: [], ledger: [], progression: [], progressionChecks: [], seq: 0,
  };
}

export function statsOf(s: GameState, levelForXp: (xp: number) => number): CharacterStats {
  const sum = (k: keyof LedgerRow) => s.ledger.reduce((n, l) => n + (l[k] as number), 0);
  const total = sum('amount');
  return {
    user_id: s.profile.id,
    total_xp: total,
    level: levelForXp(total),
    disciplina: s.base.disciplina + sum('disciplina'),
    foco: s.base.foco + sum('foco'),
    vitalidade: s.base.vitalidade + sum('vitalidade'),
    conhecimento: s.base.conhecimento + sum('conhecimento'),
    determinacao: s.base.determinacao + sum('determinacao'),
  };
}
