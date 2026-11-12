/**
 * Motor do jogo da versão individual. É uma tradução direta de
 * supabase/migrations/0002_game_engine.sql: as regras precisam continuar iguais nos dois.
 * Todas as funções recebem o estado, alteram-no e devolvem o resultado.
 */
import type { Assessment, Attribute, Dimension, Journey, Mission, MissionKind, Period, Unit, DayStatus } from '../lib/types';
import { levelForXp } from '../lib/game';
import { addDays, localDay } from '../lib/dates';
import { TEMPLATES } from './catalog';
import { statsOf, type GameState, type HabitRow, type LedgerRow, type MissionRow, type Template } from './state';

const DIMS: Dimension[] = ['fisica', 'mental', 'intelectual', 'produtividade', 'digital', 'autocuidado'];
const REQUIRED = ['exercise', 'diet', 'sleep_hours', 'sleep_quality', 'stress', 'rest', 'reflection', 'reading', 'learning',
  'planning', 'procrastination', 'discipline', 'screen_time', 'phone_morning', 'focus', 'water', 'morning_routine', 'environment'];

const fail = (code: string): never => { throw new Error(code); };

// ── Fórmulas ────────────────────────────────────────────────────────────────

export function xpFor(difficulty: number, minutes: number, kind: MissionKind): number {
  const d = ({ 1: 1.0, 2: 1.5, 3: 2.2, 4: 3.0 } as Record<number, number>)[difficulty] ?? 4.0;
  const t = Math.min(2.5, Math.max(0.6, Math.sqrt(Math.max(minutes, 1) / 10)));
  const k = ({ semanal: 2.5, especial: 3.0, surpresa: 1.2, personalizada: 0.8 } as Record<string, number>)[kind] ?? 1.0;
  // arredondamento de numeric do Postgres (meio para longe do zero), com folga para erro de ponto flutuante
  return Math.max(1, Math.round(10 * d * t * k + 1e-9));
}

export function phaseForDay(day: number): number {
  return day <= 7 ? 1 : day <= 21 ? 2 : day <= 33 ? 3 : day <= 45 ? 4 : day <= 60 ? 5 : day <= 66 ? 6 : 7;
}

export function attrForDimension(dim: Dimension): [Attribute, Attribute] {
  const map: Record<Dimension, [Attribute, Attribute]> = {
    fisica: ['vitalidade', 'determinacao'], mental: ['foco', 'vitalidade'], intelectual: ['conhecimento', 'foco'],
    produtividade: ['disciplina', 'foco'], digital: ['foco', 'disciplina'], autocuidado: ['disciplina', 'vitalidade'],
  };
  return map[dim];
}

const estMinutes = (unit: Unit, target: number, est: number) => (unit === 'min' ? target : est);
const timeCost = (t: Template) => (t.passive ? 0 : estMinutes(t.unit, t.base_value, t.est_minutes));
const daysBetween = (a: string, b: string) => Math.round((Date.UTC(+b.slice(0, 4), +b.slice(5, 7) - 1, +b.slice(8, 10)) - Date.UTC(+a.slice(0, 4), +a.slice(5, 7) - 1, +a.slice(8, 10))) / 86400000);

let uuidCounter = 0;
export function newId(): string {
  if (typeof crypto !== 'undefined' && 'randomUUID' in crypto) return crypto.randomUUID();
  uuidCounter++;
  return `${Date.now().toString(16)}-${uuidCounter}-${Math.random().toString(16).slice(2)}`;
}

/** Id numérico para o histórico, sem depender de um contador gravado junto do perfil. */
let lastNum = 0;
function numId(): number {
  lastNum = Math.max(lastNum + 1, Date.now() * 1000 + Math.floor(Math.random() * 1000));
  return lastNum;
}

export function localToday(s: GameState, now: Date = new Date()): string {
  return localDay(now.toISOString(), s.profile.timezone);
}

const completedOn = (s: GameState, day: string) =>
  s.missions.filter((m) => m.status === 'concluida' && m.completed_at && localDay(m.completed_at, s.profile.timezone) === day).length;

// ── Avaliação e plano ───────────────────────────────────────────────────────

function addHabit(s: GameState, templateId: string, startDay: number) {
  if (s.habits.some((h) => h.template_id === templateId)) return;
  const t = TEMPLATES.find((x) => x.id === templateId)!;
  s.habits.push({
    id: newId(), template_id: t.id, name: t.name, description: t.description, dimension: t.dimension,
    attr_primary: t.attr_primary, attr_secondary: t.attr_secondary, difficulty: t.difficulty, unit: t.unit,
    base_value: t.base_value, step: t.step, max_value: t.max_value, est_minutes: t.est_minutes,
    current_target: t.base_value, start_day: startDay, period: t.period, is_custom: false, active: true,
    created_at: new Date(Date.now() + s.habits.length).toISOString(),
  });
}

function buildPlan(s: GameState, prio: Dimension[], startBudget: number, fullBudget: number, needWater: boolean, needSleep: boolean) {
  let used = 0;
  for (const dim of prio) {
    const t = TEMPLATES.filter((x) => x.dimension === dim && x.tier === 1).sort((a, b) => a.sort - b.sort)[0];
    const cost = timeCost(t);
    if (used + cost <= startBudget || s.habits.length < 2) { addHabit(s, t.id, 1); used += cost; }
  }
  if (needWater) addHabit(s, 'auto_agua', 1);
  if (needSleep) addHabit(s, 'fis_sono', 1);

  const slots = [8, 22, 34];
  prio.slice(0, 3).forEach((dim, i) => {
    const options = TEMPLATES
      .filter((t) => t.dimension === dim && (t.tier === 1 || t.tier === 2) && !s.habits.some((h) => h.template_id === t.id))
      .sort((a, b) => b.tier - a.tier || a.sort - b.sort);
    for (const t of options) {
      const cost = timeCost(t);
      if (used + cost <= fullBudget) { addHabit(s, t.id, slots[i]); used += cost; break; }
    }
  });
}

export function submitAssessment(s: GameState, answers: Record<string, unknown>, now: Date = new Date()) {
  const n = (k: string) => answers[k] as number;
  for (const q of REQUIRED) {
    const v = answers[q];
    if (typeof v !== 'number' || !Number.isInteger(v) || v < 0 || v > 3) fail(`resposta_invalida: ${q}`);
  }
  const goal = answers.main_goal as Dimension;
  if (!DIMS.includes(goal)) fail('resposta_invalida: main_goal');
  const minutes = n('daily_minutes');
  if (![15, 30, 45, 60, 90].includes(minutes)) fail('resposta_invalida: daily_minutes');

  const r = (x: number) => Math.round(x + 1e-9);
  const scores = {
    fisica: r((n('exercise') + n('diet') + n('sleep_hours') + n('sleep_quality')) / 12 * 100),
    mental: r((n('stress') + n('rest') + n('reflection')) / 9 * 100),
    intelectual: r((n('reading') + n('learning')) / 6 * 100),
    produtividade: r((n('planning') + n('procrastination') + n('discipline')) / 9 * 100),
    digital: r((n('screen_time') + n('phone_morning') + n('focus')) / 9 * 100),
    autocuidado: r((n('water') + n('morning_routine') + n('environment')) / 9 * 100),
  } as Record<Dimension, number>;

  const prio: Dimension[] = [goal, ...DIMS.filter((d) => d !== goal)
    .sort((a, b) => scores[a] - scores[b] || DIMS.indexOf(a) - DIMS.indexOf(b)).slice(0, 2)];
  const firstTime = !s.profile.onboarding_done;

  const a: Assessment = { id: newId(), answers, scores, priorities: prio, created_at: now.toISOString() };
  s.assessments.push(a);
  const name = typeof answers.display_name === 'string' ? answers.display_name.trim().slice(0, 40) : '';
  if (name) s.profile.display_name = name;

  if (firstTime) {
    const today = localToday(s, now);
    s.profile.program_start = today;
    s.profile.onboarding_done = true;
    s.profile.min_daily_missions = n('discipline') <= 1 ? 1 : 2;
    buildPlan(s, prio, Math.round(minutes * 0.6), minutes, n('water') <= 1, n('sleep_hours') <= 1 || n('sleep_quality') <= 1);
    s.base = {
      disciplina: r((scores.produtividade + scores.autocuidado) / 2 * 0.6),
      foco: r((scores.digital + scores.mental) / 2 * 0.6),
      vitalidade: r(scores.fisica * 0.6),
      conhecimento: r(scores.intelectual * 0.6),
      determinacao: r(n('discipline') / 3 * 60),
    };
    ensureDay(s, today);
  }
  return { scores, priorities: prio, first_time: firstTime };
}

// ── Missões do dia ──────────────────────────────────────────────────────────

interface NewMission {
  habit: string | null; key: string; kind: MissionKind; name: string; desc: string; dim: Dimension;
  a1: Attribute; a2: Attribute; diff: number; target: number; unit: Unit; est: number; period: Period;
  freq: Mission['frequency']; date: string; due: string;
}

function insertMission(s: GameState, m: NewMission) {
  if (s.missions.some((x) => x.dedupe_key === m.key)) return;
  const minutes = estMinutes(m.unit, m.target, m.est);
  s.missions.push({
    id: newId(), habit_id: m.habit, dedupe_key: m.key, kind: m.kind, name: m.name, description: m.desc, dimension: m.dim,
    attr_primary: m.a1, attr_secondary: m.a2, difficulty: m.diff, estimated_minutes: minutes, target_value: m.target,
    unit: m.unit, period: m.period, frequency: m.freq, xp_reward: xpFor(m.diff, minutes, m.kind),
    mission_date: m.date, due_date: m.due, status: 'pendente', completed_at: null,
    created_at: new Date(Date.now() + s.missions.length).toISOString(),
  });
}

export function ensureDay(s: GameState, today: string) {
  const p = s.profile;
  if (!p.onboarding_done || !p.program_start) return { onboarding_done: false, today, day: 0, phase: 0, week: 0 };
  const day = daysBetween(p.program_start, today) + 1;
  const phase = phaseForDay(day);
  const week = Math.floor((day - 1) / 7) + 1;

  for (const m of s.missions) if (m.status === 'pendente' && m.due_date < today) m.status = 'expirada';

  if (day > 1 && (day - 1) % 7 === 0 && !s.progressionChecks.includes(week)) {
    s.progressionChecks.push(week);
    const from = addDays(today, -7);
    const to = addDays(today, -1);
    for (const h of s.habits) {
      if (!h.active || h.step <= 0 || h.current_target >= h.max_value || h.start_day > day - 7) continue;
      const done = s.missions.filter((m) => m.habit_id === h.id && m.status === 'concluida' && m.mission_date >= from && m.mission_date <= to).length;
      if (done >= 5) {
        const next = Math.min(h.current_target + h.step, h.max_value);
        s.progression.push({ id: numId(), habit_id: h.id, week, old_target: h.current_target, new_target: next, completed_days: done, created_at: new Date().toISOString() });
        h.current_target = next;
      }
    }
  }

  for (const h of s.habits) {
    if (!h.active || h.start_day > day) continue;
    insertMission(s, {
      habit: h.id, key: `h:${h.id}:${today}`, kind: 'diaria', name: h.name, desc: h.description, dim: h.dimension,
      a1: h.attr_primary, a2: h.attr_secondary, diff: h.difficulty, target: h.current_target, unit: h.unit,
      est: h.est_minutes, period: h.period, freq: 'diaria', date: today, due: today,
    });
  }

  if ((day - 1) % 7 === 0) {
    insertMission(s, {
      habit: null, key: `sem:${week}`, kind: 'semanal', name: 'Revisão da semana',
      desc: 'Olhe para os últimos dias: o que funcionou, o que travou e qual é a sua prioridade nesta semana. Anote em poucas linhas.',
      dim: 'produtividade', a1: 'disciplina', a2: 'determinacao', diff: 2, target: 15, unit: 'min', est: 15,
      period: 'qualquer', freq: 'semanal', date: today, due: addDays(today, 6),
    });
  }

  if (phase >= 2) {
    const surprises = TEMPLATES.filter((t) => t.tier === 9).sort((a, b) => a.sort - b.sort);
    const t = surprises[day % surprises.length];
    insertMission(s, {
      habit: null, key: `sur:${today}`, kind: 'surpresa', name: t.name, desc: t.description, dim: t.dimension,
      a1: t.attr_primary, a2: t.attr_secondary, diff: t.difficulty, target: t.base_value, unit: t.unit, est: t.est_minutes,
      period: t.period, freq: 'unica', date: today, due: today,
    });
  }

  if (phase >= 3 && (day - 1) % 7 === 3) {
    const doneCount = (h: HabitRow) => s.missions.filter((m) => m.habit_id === h.id && m.status === 'concluida').length;
    const h = s.habits.filter((x) => x.active && x.unit === 'min' && x.start_day <= day)
      .sort((a, b) => doneCount(b) - doneCount(a) || a.created_at.localeCompare(b.created_at))[0];
    if (h) {
      insertMission(s, {
        habit: h.id, key: `esp:${week}`, kind: 'especial', name: `Sessão estendida: ${h.name}`,
        desc: 'Uma vez nesta semana, faça uma sessão maior que a sua meta diária. Vale em qualquer dia até o fim da semana.',
        dim: h.dimension, a1: h.attr_primary, a2: 'determinacao', diff: Math.min(h.difficulty + 1, 5),
        target: Math.min(h.current_target * 2, h.max_value * 2), unit: 'min', est: h.est_minutes, period: h.period,
        freq: 'unica', date: today, due: addDays(today, 3),
      });
    }
  }

  return { onboarding_done: true, today, day, phase, week };
}

// ── Concluir e desfazer ─────────────────────────────────────────────────────

function applyDayBonuses(s: GameState, day: string) {
  const p = s.profile;
  const n = completedOn(s, day);
  const bonuses: { tipo: 'meta_diaria' | 'retorno'; xp: number }[] = [];
  const has = (src: LedgerRow['source']) => s.ledger.some((l) => l.source === src && l.day === day);
  const add = (src: 'meta_diaria' | 'retorno', attr: Attribute, xp: number) => {
    s.ledger.push({ id: numId(), mission_id: null, source: src, day, amount: xp, disciplina: 0, foco: 0, vitalidade: 0, conhecimento: 0, determinacao: 0, [attr]: xp, created_at: new Date().toISOString() });
    bonuses.push({ tipo: src, xp });
  };

  if (n >= p.min_daily_missions) {
    if (!has('meta_diaria')) add('meta_diaria', 'disciplina', 15);
    const yesterday = addDays(day, -1);
    if (p.program_start && yesterday >= p.program_start && completedOn(s, yesterday) === 0) {
      const prevAny = s.missions.some((m) => m.status === 'concluida' && m.completed_at && localDay(m.completed_at, p.timezone) < yesterday);
      if (prevAny && !has('retorno')) add('retorno', 'determinacao', 20);
    }
  } else {
    s.ledger = s.ledger.filter((l) => !(l.day === day && (l.source === 'meta_diaria' || l.source === 'retorno')));
  }
  return bonuses;
}

export function completeMission(s: GameState, missionId: string, now: Date = new Date()) {
  const today = localToday(s, now);
  const m = s.missions.find((x) => x.id === missionId) ?? fail('missao_nao_encontrada');
  if (m.status === 'concluida') return { ja_concluida: true };
  if (today < m.mission_date || today > m.due_date) fail('fora_do_prazo');

  const before = statsOf(s, levelForXp).level;
  const nToday = completedOn(s, today);
  const nCustom = s.missions.filter((x) => x.status === 'concluida' && x.kind === 'personalizada' && x.completed_at && localDay(x.completed_at, s.profile.timezone) === today).length;

  let xp = m.xp_reward;
  if (m.kind === 'personalizada' && nCustom >= 3) xp = Math.max(1, Math.round(xp * 0.25));
  if (nToday >= 12) xp = Math.max(1, Math.round(xp * 0.5));

  m.status = 'concluida';
  m.completed_at = now.toISOString();

  const p1 = Math.round(xp * 0.7);
  const row: LedgerRow = {
    id: numId(), mission_id: m.id, source: 'missao', day: today, amount: xp,
    disciplina: 0, foco: 0, vitalidade: 0, conhecimento: 0, determinacao: 0, created_at: now.toISOString(),
  };
  row[m.attr_primary] += p1;
  row[m.attr_secondary] += xp - p1;
  s.ledger.push(row);

  const bonus = applyDayBonuses(s, today);
  const stats = statsOf(s, levelForXp);
  return { ja_concluida: false, xp, bonus, nivel_antes: before, nivel: stats.level, xp_total: stats.total_xp };
}

export function undoCompletion(s: GameState, missionId: string, now: Date = new Date()) {
  const today = localToday(s, now);
  const m = s.missions.find((x) => x.id === missionId) ?? fail('missao_nao_encontrada');
  if (m.status !== 'concluida') return { desfeita: false };
  if (!m.completed_at || localDay(m.completed_at, s.profile.timezone) !== today) fail('so_no_mesmo_dia');
  s.ledger = s.ledger.filter((l) => l.mission_id !== m.id);
  m.status = 'pendente';
  m.completed_at = null;
  applyDayBonuses(s, today);
  return { desfeita: true };
}

// ── Personalizadas e ajustes ────────────────────────────────────────────────

export function createCustomMission(s: GameState, p: { name: string; description: string; dimension: string; difficulty: number; minutes: number; recurring: boolean }, now: Date = new Date()) {
  const prof = s.profile;
  if (!prof.onboarding_done || !prof.program_start) fail('conclua_a_avaliacao');
  if (!DIMS.includes(p.dimension as Dimension)) fail('dimensao_invalida');
  if (!Number.isInteger(p.difficulty) || p.difficulty < 1 || p.difficulty > 3) fail('dificuldade_invalida');
  if (!Number.isInteger(p.minutes) || p.minutes < 1 || p.minutes > 120) fail('duracao_invalida');
  const name = (p.name ?? '').trim();
  if (name.length < 1 || name.length > 60) fail('nome_invalido');
  const dim = p.dimension as Dimension;
  const [a1, a2] = attrForDimension(dim);
  const today = localToday(s, now);
  const day = daysBetween(prof.program_start!, today) + 1;
  const desc = (p.description ?? '').slice(0, 280);

  if (p.recurring) {
    const custom = s.habits.filter((h) => h.active && h.is_custom).length;
    if (custom >= 12) fail('limite_habitos');
    if (prof.plan === 'free' && custom >= 2) fail('limite_gratuito_personalizadas');
    const id = newId();
    s.habits.push({
      id, template_id: null, name, description: desc, dimension: dim, attr_primary: a1, attr_secondary: a2,
      difficulty: p.difficulty, unit: 'min', base_value: p.minutes, step: 0, max_value: p.minutes, est_minutes: p.minutes,
      current_target: p.minutes, start_day: Math.max(day, 1), period: 'qualquer', is_custom: true, active: true,
      created_at: now.toISOString(),
    });
    ensureDay(s, today);
    return { habit_id: id };
  }
  if (s.missions.filter((m) => m.kind === 'personalizada' && m.mission_date === today).length >= 5) fail('limite_diario_personalizadas');
  insertMission(s, {
    habit: null, key: `c:${newId()}`, kind: 'personalizada', name, desc, dim, a1, a2, diff: p.difficulty,
    target: p.minutes, unit: 'min', est: p.minutes, period: 'qualquer', freq: 'unica', date: today, due: today,
  });
  return { ok: true };
}

export function adjustHabit(s: GameState, habitId: string, target: number, active: boolean, now: Date = new Date()) {
  const h = s.habits.find((x) => x.id === habitId) ?? fail('habito_nao_encontrado');
  if (s.profile.mode === 'extremo') fail('modo_extremo_bloqueia_ajustes');
  if (!Number.isInteger(target) || target < h.base_value || target > h.max_value) fail('meta_fora_do_intervalo');
  h.current_target = target;
  h.active = active;
  const today = localToday(s, now);
  for (const m of s.missions) {
    if (m.habit_id === h.id && m.kind === 'diaria' && m.mission_date === today && m.status === 'pendente') {
      m.target_value = target;
      m.estimated_minutes = estMinutes(h.unit, target, h.est_minutes);
      m.xp_reward = xpFor(m.difficulty, m.estimated_minutes, m.kind);
    }
  }
  if (!active) {
    s.missions = s.missions.filter((m) => !(m.habit_id === h.id && m.mission_date === today && m.status === 'pendente' && m.kind === 'diaria'));
  }
  return { ok: true };
}

export function updateProfile(s: GameState, p: { displayName?: string; timezone?: string; minDaily?: number }) {
  if (p.timezone) {
    try { new Intl.DateTimeFormat('en', { timeZone: p.timezone }); } catch { fail('fuso_invalido'); }
  }
  if (p.minDaily !== undefined && (p.minDaily < 1 || p.minDaily > 10)) fail('meta_invalida');
  if (p.displayName !== undefined) s.profile.display_name = p.displayName.trim().slice(0, 40);
  if (p.timezone) s.profile.timezone = p.timezone;
  if (p.minDaily !== undefined) s.profile.min_daily_missions = p.minDaily;
  return { ok: true };
}

// ── Jornada ─────────────────────────────────────────────────────────────────

export function journey(s: GameState, today: string): Journey {
  const p = s.profile;
  const days: Journey['days'] = [];
  const maxShields = p.mode === 'normal' ? 2 : p.mode === 'desafio' ? 1 : 0;
  if (!p.program_start) return { current_streak: 0, best_streak: 0, shields: 0, max_shields: maxShields, consistency: null, milestones: [], days };

  let streak = 0, best = 0, shields = 0, good = 0, past = 0;
  for (let d = p.program_start; d <= today; d = addDays(d, 1)) {
    const done = completedOn(s, d);
    const total = s.missions.filter((m) => m.mission_date === d && m.kind === 'diaria').length;
    let st: DayStatus;
    if (done >= p.min_daily_missions) {
      st = 'completo'; streak++;
      if (streak % 7 === 0 && shields < maxShields) shields++;
    } else if (d === today) {
      st = done > 0 ? 'parcial' : 'hoje';
    } else if (done > 0) {
      st = 'parcial'; streak = 0;
    } else if (shields > 0) {
      st = 'protegido'; shields--;
    } else {
      st = 'vazio'; streak = 0;
    }
    best = Math.max(best, streak);
    if (d < today) { past++; if (st === 'completo') good++; }
    days.push({ date: d, status: st, done, total });
  }
  if (days.some((x) => x.date === today && x.status === 'completo')) { past++; good++; }

  return {
    current_streak: streak, best_streak: best, shields, max_shields: maxShields,
    consistency: past === 0 ? null : Math.round(good * 100 / past),
    milestones: [7, 14, 21, 33, 45, 66, 90, 132].filter((m) => m <= best),
    days,
  };
}

export type { GameState, MissionRow };
