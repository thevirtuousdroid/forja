// Espelha supabase/tests/10_engine_test.sql: as duas versões do motor precisam se comportar igual.
import { describe, expect, it } from 'vitest';
import {
  adjustHabit, completeMission, createCustomMission, ensureDay, journey, submitAssessment, undoCompletion, xpFor,
} from './engine';
import { emptyState, statsOf, type GameState } from './state';
import { levelForXp } from '../lib/game';
import { addDays } from '../lib/dates';
import xpParity from './xp-parity.json';
import levelParity from './level-parity.json';

const TZ = 'America/Sao_Paulo';
const ANSWERS = {
  age_range: '25-34', wake_time: 1, free_period: 'noite', daily_minutes: 30, exercise: 1, diet: 2, sleep_hours: 1,
  sleep_quality: 1, stress: 1, rest: 2, reflection: 1, reading: 0, learning: 1, planning: 1, procrastination: 1,
  discipline: 2, screen_time: 0, phone_morning: 0, focus: 1, water: 1, morning_routine: 2, environment: 2,
  main_goal: 'intelectual', difficulties: ['procrastinacao', 'celular'],
};
/** Meio-dia no fuso do usuário para a data AAAA-MM-DD. */
const noon = (day: string) => new Date(`${day}T12:00:00-03:00`);

function freshUser(start = '2026-11-01'): GameState {
  const s = emptyState('u1', TZ);
  submitAssessment(s, { ...ANSWERS }, noon(start));
  return s;
}

describe('fórmulas iguais às do banco', () => {
  it('XP: 3.250 combinações de dificuldade × minutos × tipo', () => {
    for (const [d, m, k, expected] of xpParity as [number, number, string, number][]) {
      expect(xpFor(d, m, k as never), `${d}/${m}/${k}`).toBe(expected);
    }
  });
  it('níveis', () => {
    for (const [xp, lvl] of levelParity as [number, number][]) expect(levelForXp(xp), String(xp)).toBe(lvl);
  });
});

describe('avaliação e plano', () => {
  it('monta o plano como o servidor', () => {
    const s = freshUser();
    const a = s.assessments[0];
    expect(a.priorities[0]).toBe('intelectual');
    expect(a.priorities).toHaveLength(3);
    const day1 = s.habits.filter((h) => h.start_day === 1);
    expect(day1.length).toBe(4);
    expect(s.habits.some((h) => h.template_id === 'auto_agua')).toBe(true);
    expect(s.habits.some((h) => h.template_id === 'fis_sono')).toBe(true);
    expect(s.habits.some((h) => h.start_day > 1)).toBe(true);
    expect(s.missions.length).toBe(day1.length + 1);
    expect(statsOf(s, levelForXp).vitalidade).toBeGreaterThan(0);
  });

  it('recusa respostas incompletas', () => {
    const s = emptyState('u1', TZ);
    expect(() => submitAssessment(s, { main_goal: 'intelectual', daily_minutes: 30 })).toThrow(/resposta_invalida/);
  });

  it('ensureDay é idempotente', () => {
    const s = freshUser();
    const n = s.missions.length;
    ensureDay(s, '2026-11-01'); ensureDay(s, '2026-11-01');
    expect(s.missions.length).toBe(n);
  });
});

describe('concluir, duplicidade, bônus e desfazer', () => {
  it('funciona como no banco', () => {
    const s = freshUser('2026-11-01');
    const [m1, m2] = s.missions.filter((m) => m.kind === 'diaria').sort((a, b) => a.name.localeCompare(b.name));
    const t = noon('2026-11-01');

    const r = completeMission(s, m1.id, t);
    expect(r.xp).toBeGreaterThan(0);
    expect(completeMission(s, m1.id, t).ja_concluida).toBe(true);
    expect(s.ledger.filter((l) => l.source === 'missao')).toHaveLength(1);

    const r2 = completeMission(s, m2.id, t);
    expect(r2.bonus).toEqual([{ tipo: 'meta_diaria', xp: 15 }]);
    const xpTwo = statsOf(s, levelForXp).total_xp;

    expect(undoCompletion(s, m2.id, t).desfeita).toBe(true);
    expect(s.ledger.some((l) => l.source === 'meta_diaria')).toBe(false);
    expect(statsOf(s, levelForXp).total_xp).toBeLessThan(xpTwo);
    expect(() => completeMission(s, m2.id, noon('2026-11-02'))).toThrow('fora_do_prazo');
  });
});

describe('personalizadas e ajuste de meta', () => {
  it('aplica os limites', () => {
    const s = freshUser('2026-11-01');
    const t = noon('2026-11-01');
    expect(() => createCustomMission(s, { name: 'Super', description: '', dimension: 'fisica', difficulty: 5, minutes: 30, recurring: false }, t)).toThrow('dificuldade_invalida');
    createCustomMission(s, { name: 'Tocar violão', description: '', dimension: 'intelectual', difficulty: 2, minutes: 20, recurring: true }, t);
    createCustomMission(s, { name: 'Regar plantas', description: '', dimension: 'autocuidado', difficulty: 1, minutes: 5, recurring: true }, t);
    expect(() => createCustomMission(s, { name: 'Terceira', description: '', dimension: 'mental', difficulty: 1, minutes: 5, recurring: true }, t)).toThrow('limite_gratuito_personalizadas');
    expect(s.missions.some((m) => m.name === 'Tocar violão')).toBe(true);
  });

  it('ajusta a missão de hoje junto com a meta', () => {
    const s = freshUser('2026-11-01');
    const t = noon('2026-11-01');
    const h = s.habits.find((x) => x.template_id === 'int_leitura')!;
    expect(() => adjustHabit(s, h.id, h.max_value + 1, true, t)).toThrow('meta_fora_do_intervalo');
    const before = s.missions.find((m) => m.habit_id === h.id)!.xp_reward;
    adjustHabit(s, h.id, h.max_value, true, t);
    expect(s.missions.find((m) => m.habit_id === h.id)!.xp_reward).toBeGreaterThan(before);
  });
});

describe('simulação de 30 dias (mesmo roteiro do teste do banco)', () => {
  it('chega aos mesmos números do servidor', () => {
    const start = '2026-10-01';
    const s = freshUser(start);
    s.missions = []; s.ledger = [];
    const leitura0 = s.habits.find((h) => h.template_id === 'int_leitura')!.current_target;
    let comeback = false;

    for (let i = 1; i <= 30; i++) {
      const d = addDays(start, i - 1);
      ensureDay(s, d);
      if ([12, 20, 21].includes(i)) continue;
      for (const m of s.missions.filter((x) => x.mission_date === d && x.kind === 'diaria' && x.status === 'pendente')) {
        const r = completeMission(s, m.id, noon(d));
        if (i === 13 && r.bonus?.some((b) => b.tipo === 'retorno')) comeback = true;
      }
    }

    const j = journey(s, addDays(start, 29));
    const leitura = s.habits.find((h) => h.template_id === 'int_leitura')!;
    const st = statsOf(s, levelForXp);
    expect(leitura.current_target).toBeGreaterThan(leitura0);
    expect(leitura.current_target).toBeLessThanOrEqual(leitura.max_value);
    expect(j.days[11].status).toBe('protegido');
    expect(comeback).toBe(true);
    expect(j.best_streak).toBe(18);
    expect(j.current_streak).toBe(9);
    expect(j.consistency).toBe(90);
    expect(s.missions.some((m) => m.kind === 'surpresa')).toBe(true);
    expect(s.missions.some((m) => m.kind === 'especial')).toBe(true);
    expect(s.missions.some((m) => m.status === 'expirada')).toBe(true);
    // Valores obtidos do motor SQL com o mesmo roteiro
    expect(st.total_xp).toBe(3125);
    expect(st.level).toBe(7);
  });
});
