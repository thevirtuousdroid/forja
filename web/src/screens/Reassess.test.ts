import { describe, expect, it } from 'vitest';
import { compareAssessments } from './Reassess';
import type { Assessment } from '../lib/types';

const mk = (s: number[]): Assessment => ({
  id: 'x', answers: {}, priorities: [], created_at: '2026-09-01T12:00:00Z',
  scores: { fisica: s[0], mental: s[1], intelectual: s[2], produtividade: s[3], digital: s[4], autocuidado: s[5] },
});

describe('comparação da reavaliação', () => {
  it('calcula média, maior avanço e áreas que caíram', () => {
    const c = compareAssessments(mk([40, 30, 20, 50, 60, 40]), mk([70, 30, 80, 60, 50, 40]));
    expect(c.before).toBe(40);
    expect(c.after).toBe(55);
    expect(c.best).toMatchObject({ d: 'intelectual', delta: 60 });
    expect(c.improved).toBe(3);
    expect(c.dropped.map((r) => r.d)).toEqual(['digital']);
  });
});
