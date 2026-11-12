import { describe, expect, it } from 'vitest';
import { Saver, fromDocs, toDocs, type Docs, type Store } from './storage';
import { emptyState } from './state';
import { completeMission, ensureDay, submitAssessment } from './engine';
import { addDays } from '../lib/dates';

const ANSWERS = {
  display_name: 'Ana', daily_minutes: 30, exercise: 1, diet: 2, sleep_hours: 1, sleep_quality: 1, stress: 1, rest: 2,
  reflection: 1, reading: 0, learning: 1, planning: 1, procrastination: 1, discipline: 2, screen_time: 0, phone_morning: 0,
  focus: 1, water: 1, morning_routine: 2, environment: 2, main_goal: 'intelectual',
};

function memoryStore() {
  const docs: Docs = {};
  const writes: string[] = [];
  const store: Store = {
    kind: 'nuvem', userId: 'u1',
    load: async () => JSON.parse(JSON.stringify(docs)),
    save: async (k, b) => { writes.push(k); docs[k] = JSON.parse(JSON.stringify(b)); },
    remove: async (k) => { delete docs[k]; },
  };
  return { store, docs, writes };
}

describe('armazenamento', () => {
  it('separa por mês e reconstrói o mesmo estado', () => {
    const s = emptyState('u1', 'America/Sao_Paulo');
    submitAssessment(s, ANSWERS, new Date('2026-10-28T12:00:00-03:00'));
    for (let i = 0; i < 8; i++) ensureDay(s, addDays('2026-10-28', i));
    const docs = toDocs(s);
    expect(Object.keys(docs).sort()).toEqual(['core', 'm-2026-10', 'm-2026-11']);
    expect(docs.core).not.toHaveProperty('missions');
    expect(fromDocs(JSON.parse(JSON.stringify(docs)))).toEqual(JSON.parse(JSON.stringify(s)));
    expect(JSON.stringify(docs['m-2026-11']).length).toBeLessThan(256 * 1024);
    expect(s.profile.display_name).toBe('Ana');
  });

  it('grava só os documentos que mudaram', async () => {
    const { store, docs, writes } = memoryStore();
    const s = emptyState('u1', 'America/Sao_Paulo');
    submitAssessment(s, ANSWERS, new Date('2026-11-05T12:00:00-03:00'));
    const saver = new Saver(store);
    await saver.persist(s);
    expect(writes.sort()).toEqual(['core', 'm-2026-11']);

    writes.length = 0;
    const m = s.missions.find((x) => x.kind === 'diaria')!;
    completeMission(s, m.id, new Date('2026-11-05T13:00:00-03:00'));
    await saver.persist(s);
    expect(writes).toEqual(['m-2026-11']);

    writes.length = 0;
    await saver.persist(s);
    expect(writes).toEqual([]);
    expect(fromDocs(docs)!.ledger).toHaveLength(1);
  });

  it('tenta de novo o que falhou', async () => {
    const { store, writes } = memoryStore();
    let fail = true;
    const flaky: Store = { ...store, save: async (k, b) => { if (fail) throw new Error('falha_ao_salvar'); return store.save(k, b); } };
    const s = emptyState('u1', 'America/Sao_Paulo');
    submitAssessment(s, ANSWERS, new Date('2026-11-05T12:00:00-03:00'));
    const saver = new Saver(flaky);
    const errors: unknown[] = [];
    saver.onError = (e) => errors.push(e);
    await saver.persist(s);
    expect(errors).toHaveLength(1);
    expect(saver.pending).toBe(true);
    fail = false;
    await saver.persist(s);
    expect(saver.pending).toBe(false);
    expect(writes.sort()).toEqual(['core', 'm-2026-11']);
  });
});
