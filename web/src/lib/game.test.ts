import { describe, expect, it } from 'vitest';
import { attributeLevel, levelForXp, levelProgress, phaseForDay, referenceProfile, xpForLevel } from './game';
import { STEPS, isStepComplete } from '../content/questionnaire';
import { friendlyError } from './api';

describe('curva de níveis (espelha o banco)', () => {
  it('bate com os valores testados no SQL', () => {
    expect(xpForLevel(1)).toBe(0);
    expect(xpForLevel(2)).toBe(100);
    expect(xpForLevel(5)).toBe(1213);
    expect(xpForLevel(12)).toBe(7490);
    expect(levelForXp(99)).toBe(1);
    expect(levelForXp(100)).toBe(2);
    expect(levelForXp(1212)).toBe(4);
    expect(levelForXp(1213)).toBe(5);
  });

  it('cada nível exige mais XP que o anterior', () => {
    for (let l = 2; l < 60; l++) {
      expect(xpForLevel(l + 1) - xpForLevel(l)).toBeGreaterThan(xpForLevel(l) - xpForLevel(l - 1));
    }
  });

  it('progresso dentro do nível', () => {
    const p = levelProgress(150, 2);
    expect(p.current).toBe(50);
    expect(p.needed).toBe(xpForLevel(3) - 100);
    expect(p.ratio).toBeGreaterThan(0);
    expect(p.ratio).toBeLessThan(1);
  });

  it('atributos e fases', () => {
    expect(attributeLevel(0)).toBe(1);
    expect(attributeLevel(30)).toBe(2);
    expect(attributeLevel(119)).toBe(2);
    expect(attributeLevel(120)).toBe(3);
    expect([1, 7, 8, 21, 22, 33, 34, 45, 46, 60, 61, 66, 67].map(phaseForDay)).toEqual([1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7]);
  });
});

describe('questionário', () => {
  // As mesmas chaves que public.submit_assessment exige
  const REQUIRED = ['exercise', 'diet', 'sleep_hours', 'sleep_quality', 'stress', 'rest', 'reflection', 'reading', 'learning',
    'planning', 'procrastination', 'discipline', 'screen_time', 'phone_morning', 'focus', 'water', 'morning_routine', 'environment'];

  it('pergunta tudo o que o servidor exige, com valores de 0 a 3', () => {
    const all = STEPS.flatMap((s) => s.questions);
    for (const key of REQUIRED) {
      const q = all.find((x) => x.key === key);
      expect(q, key).toBeDefined();
      expect(q!.optional).toBeFalsy();
      expect(q!.options.map((o) => o.value).sort()).toEqual([0, 1, 2, 3]);
    }
    expect(all.find((q) => q.key === 'daily_minutes')!.options.map((o) => o.value)).toEqual([15, 30, 45, 60, 90]);
    expect(all.find((q) => q.key === 'main_goal')!.options).toHaveLength(6);
  });

  it('etapas curtas (no máximo 4 perguntas)', () => {
    for (const s of STEPS) expect(s.questions.length).toBeLessThanOrEqual(4);
  });

  it('etapa só fica completa com as obrigatórias respondidas', () => {
    const s = STEPS[1];
    expect(isStepComplete(s, {})).toBe(false);
    expect(isStepComplete(s, { wake_time: 1, free_period: 'noite', daily_minutes: 30 })).toBe(true);
    expect(isStepComplete(STEPS[0], {})).toBe(false); // nome é obrigatório
    expect(isStepComplete(STEPS[0], { display_name: 'Ana' })).toBe(true); // idade é opcional
    expect(isStepComplete(STEPS[0], { display_name: '   ' })).toBe(false);
  });
});

describe('perfil de referência e erros', () => {
  it('aponta ponto forte e frente de evolução', () => {
    const r = referenceProfile({ fisica: 80, mental: 40, intelectual: 20, produtividade: 50, digital: 30, autocuidado: 60 });
    expect(r.archetype).toBe('Guardião');
    expect(r.weakest).toBe('intelectual');
  });

  it('traduz erros do servidor', () => {
    expect(friendlyError(new Error('fora_do_prazo'))).toMatch(/prazo/);
    expect(friendlyError(new Error('TypeError: Failed to fetch'))).toMatch(/conexão/);
    expect(friendlyError(new Error('coisa estranha'))).toMatch(/Algo deu errado/);
  });
});

describe('Caminho Sagrado', () => {
  it('o Sagrado e a vida espiritual só aparecem para quem ativou', async () => {
    const { attributesFor, areasFor, ATTRIBUTE_KEYS, DIMENSION_KEYS } = await import('./game');
    expect(ATTRIBUTE_KEYS).toHaveLength(5);
    expect(attributesFor(false)).not.toContain('sagrado');
    expect(attributesFor(true)).toEqual([...ATTRIBUTE_KEYS, 'sagrado']);
    expect(DIMENSION_KEYS).not.toContain('espiritual');
    expect(areasFor(true)).toContain('espiritual');
    expect(areasFor(undefined)).toHaveLength(6);
  });
});
