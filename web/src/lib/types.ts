export type Dimension = 'fisica' | 'mental' | 'intelectual' | 'produtividade' | 'digital' | 'autocuidado';
export type Attribute = 'disciplina' | 'foco' | 'vitalidade' | 'conhecimento' | 'determinacao';
export type MissionKind = 'diaria' | 'semanal' | 'especial' | 'personalizada' | 'surpresa';
export type MissionStatus = 'pendente' | 'concluida' | 'expirada';
export type Period = 'manha' | 'tarde' | 'noite' | 'qualquer';
export type Unit = 'min' | 'copos' | 'paginas' | 'vez';

export interface Profile {
  id: string;
  display_name: string;
  timezone: string;
  program_start: string | null;
  onboarding_done: boolean;
  min_daily_missions: number;
  mode: 'normal' | 'desafio' | 'extremo';
  plan: 'free' | 'premium';
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

export interface TodayInfo {
  onboarding_done: boolean;
  today: string;
  day: number;
  phase: number;
  week: number;
}

export interface LedgerEntry {
  id: number;
  mission_id: string | null;
  source: 'missao' | 'meta_diaria' | 'retorno' | 'marco';
  day: string;
  amount: number;
  created_at: string;
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

export interface Journey {
  current_streak: number;
  best_streak: number;
  shields: number;
  max_shields: number;
  consistency: number | null;
  milestones: number[];
  days: { date: string; status: DayStatus; done: number; total: number }[];
}

export interface CompleteResult {
  ja_concluida: boolean;
  xp?: number;
  bonus?: { tipo: 'meta_diaria' | 'retorno'; xp: number }[];
  nivel_antes?: number;
  nivel?: number;
  xp_total?: number;
}
