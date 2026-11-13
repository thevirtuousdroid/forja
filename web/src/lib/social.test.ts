import { describe, expect, it } from 'vitest';
import { metricUnit, notificationText, plural, postText, prettyCode, relativeTime } from './social';
import { fmtMinutes, minToTime, sleepMinutes, toolForTemplate, toolLine } from './tools';
import { friendlyError, isPremiumError } from './errors';
import type { FeedPost, SocialNotification, ToolSummaries } from './types';

const lite = { id: 'u1', name: 'Ana', avatar: {} };
const base = { id: 1, ref: 'x', created_at: '2026-11-12T12:00:00Z', author: lite, mine: false, cheers: {}, cheerers: [], my_cheer: null };

describe('social', () => {
  it('formata códigos e plurais', () => {
    expect(prettyCode('ABC234')).toBe('ABC-234');
    expect(plural(1, 'dia', 'dias')).toBe('1 dia');
    expect(plural(1200, 'ponto', 'pontos')).toBe('1.200 pontos');
    expect(metricUnit('missoes', 1)).toBe('missão');
    expect(metricUnit('meta_diaria', 3)).toBe('dias');
  });

  it('tempo relativo em português', () => {
    const now = new Date('2026-11-12T12:00:00Z').getTime();
    expect(relativeTime('2026-11-12T11:59:40Z', now)).toBe('agora');
    expect(relativeTime('2026-11-12T11:55:00Z', now)).toBe('há 5 min');
    expect(relativeTime('2026-11-12T09:00:00Z', now)).toBe('há 3 h');
    expect(relativeTime('2026-11-11T09:00:00Z', now)).toBe('ontem');
  });

  it('textos de publicação com o nome do chefe no meio da frase', () => {
    const boss = { ...base, kind: 'chefe', data: { boss_id: 'adiador', name: 'O Adiador', epithet: '', difficulty: 1, rematch: false, days: 5 } } as FeedPost;
    expect(postText(boss)).toBe('venceu o Adiador');
    const lvl = { ...base, kind: 'nivel', data: { level: 10 } } as FeedPost;
    expect(postText(lvl)).toBe('chegou ao nível 10');
    const season = { ...base, kind: 'temporada', data: { season: 202610, name: 'Temporada de outubro', league: 'ouro', league_name: 'Ouro', points: 300 } } as FeedPost;
    expect(postText(season)).toBe('terminou a temporada de outubro na liga Ouro');
  });

  it('textos de avisos', () => {
    const n = { id: 1, seen: false, created_at: '', kind: 'incentivo', data: { cheer: 'forca', user: lite, post: null } } as SocialNotification;
    expect(notificationText(n)).toBe('mandou 💪 força para você.');
    const p = { id: 2, seen: false, created_at: '', kind: 'pedido_amizade', data: { request_id: 'r', status: 'pendente', user: lite } } as SocialNotification;
    expect(notificationText(p)).toBe('quer ser seu amigo na Forja.');
  });
});

describe('ferramentas', () => {
  it('minutos e horários', () => {
    expect(fmtMinutes(45)).toBe('45 min');
    expect(fmtMinutes(120)).toBe('2h');
    expect(fmtMinutes(470)).toBe('7h50');
    expect(fmtMinutes(null)).toBe('–');
    expect(sleepMinutes('23:10', '07:00')).toBe(470);
    expect(sleepMinutes('01:00', '06:00')).toBe(300);
    expect(minToTime(1410)).toBe('23:30');
  });

  it('cada missão do plano aponta para a ferramenta certa', () => {
    expect(toolForTemplate('auto_agua', 'copos')).toBe('agua');
    expect(toolForTemplate('men_respiracao', 'min')).toBe('meditacao');
    expect(toolForTemplate('dig_redes', 'vez')).toBe('tela');
    expect(toolForTemplate(null, 'min')).toBe('foco');
    expect(toolForTemplate('fis_sono', 'vez')).toBeNull();
  });

  it('resumo curto das ferramentas', () => {
    const s = {
      foco: { minutes: 50, sessions: 2 }, agua: { cups: 3, goal: 8, cup_ml: 250 },
      sono: { logged: true, minutes: 450, bed: '23:00', wake: '06:30', quality: 4, goal: 480, bedtime: '23:00' },
      alimentacao: { kcal: 0, meals: 1, with_kcal: 0 }, leitura: { pages: 0, minutes: 0, book: null },
      meditacao: { minutes: 0, sessions: 0 }, tela: { logged: false, minutes: null, limit: 120 }, diario: { written: true, mood: 4 },
    } as ToolSummaries;
    expect(toolLine('agua', s)).toBe('3 de 8 copos');
    expect(toolLine('sono', s)).toBe('7h30 esta noite');
    expect(toolLine('alimentacao', s)).toBe('1 refeição');
    expect(toolLine('tela', s)).toBe('Registre o dia');
  });
});

describe('erros', () => {
  it('código mais longo vence o mais curto', () => {
    expect(friendlyError(new Error('limite_grupos_criados'))).toBe('Você já criou 5 grupos.');
    expect(friendlyError(new Error('limite_grupos'))).toBe('Você já participa de 10 grupos.');
    expect(friendlyError(new Error('limite_desafios_criados'))).toBe('Você já tem 3 desafios criados em andamento.');
  });
  it('reconhece recurso premium', () => {
    expect(isPremiumError(new Error('recurso_premium'))).toBe(true);
    expect(isPremiumError(new Error('codigo_invalido'))).toBe(false);
    expect(friendlyError(new Error('recurso_premium'))).toBe('Esse recurso faz parte do Premium.');
  });
});
