import { describe, expect, it } from 'vitest';
import { avatarOf, DEFAULT_AVATAR, MODES, inName, midName, titleName, unlockText } from './rpg';
import { groupEvents } from '../components/RewardOverlay';
import { lockText } from '../screens/Bosses';
import type { Boss, CatalogItem, GameEvent } from './types';
import type { Catalogs } from './api';

const item = (p: Partial<CatalogItem>): CatalogItem => ({
  id: 'x', kind: 'equipamento', slot: 'cabeca', name: 'X', description: '', rarity: 'comum',
  unlock_type: 'inicial', unlock_level: null, unlock_ref: null, sort: 0, ...p,
});

const catalogs: Catalogs = {
  items: [
    item({ id: 'tit_aprendiz', kind: 'titulo', slot: null, name: 'Aprendiz da Forja' }),
    item({ id: 'tit_faisca', kind: 'titulo', slot: null, name: 'Faísca Constante', unlock_type: 'nivel', unlock_level: 4 }),
    item({ id: 'tit_aco', kind: 'titulo', slot: null, name: 'Aço Temperado', unlock_type: 'nivel', unlock_level: 8 }),
    item({ id: 'tit_fenix', kind: 'titulo', slot: null, name: 'Fênix', unlock_type: 'conquista', unlock_ref: 'h_fenix' }),
  ],
  achievements: [{ id: 'h_fenix', name: 'Fênix', category: 'habitos', rarity: 'epico' }],
  bosses: [{ id: 'adiador', name: 'O Adiador', epithet: 'Chefe da Procrastinação', dimension: 'produtividade', hit_rule: 'dimensao' }],
};

describe('títulos e itens', () => {
  it('mostra o título escolhido ou o maior título de nível', () => {
    expect(titleName({ active_title: null }, 1, catalogs.items)).toBe('Aprendiz da Forja');
    expect(titleName({ active_title: null }, 9, catalogs.items)).toBe('Aço Temperado');
    expect(titleName({ active_title: 'tit_fenix' }, 9, catalogs.items)).toBe('Fênix');
    expect(titleName({ active_title: 'sumiu' }, 5, catalogs.items)).toBe('Faísca Constante');
    expect(titleName(null, 5, undefined)).toBe('Aprendiz da Forja');
  });

  it('explica como desbloquear cada item', () => {
    expect(unlockText(item({ unlock_type: 'nivel', unlock_level: 12 }), catalogs)).toBe('Alcance o nível 12');
    expect(unlockText(item({ unlock_type: 'chefe', unlock_ref: 'adiador' }), catalogs)).toBe('Vença o Adiador');
    expect(unlockText(item({ unlock_type: 'conquista', unlock_ref: 'h_fenix' }), catalogs)).toBe('Conquista "Fênix"');
    expect(unlockText(item({}), null)).toBe('Item inicial');
  });

  it('completa um avatar vazio ou parcial com valores seguros', () => {
    expect(avatarOf({ avatar: {} })).toEqual(DEFAULT_AVATAR);
    const a = avatarOf({ avatar: { pele: 4, cabelo: 2, corCabelo: 1, barba: 0, corRoupa: 3, equip: { cabeca: 'cab_faixa' } } });
    expect(a.equip).toEqual({ corpo: 'cor_tunica', moldura: 'mol_bronze', cabeca: 'cab_faixa' });
    expect(a.pele).toBe(4);
  });
});

describe('nomes no meio da frase', () => {
  it('ajusta o artigo', () => {
    expect(midName('O Adiador')).toBe('o Adiador');
    expect(midName('A Hidra das Notificações')).toBe('a Hidra das Notificações');
    expect(inName('O Juiz da Bigorna')).toBe('no Juiz da Bigorna');
    expect(inName('A Névoa do Esquecimento')).toBe('na Névoa do Esquecimento');
    expect(inName('Ogro')).toBe('em Ogro');
    expect(midName('Ogro')).toBe('Ogro');
  });
});

describe('modos', () => {
  it('multiplicadores e escudos batem com o servidor', () => {
    expect(MODES.map((m) => [m.id, m.multiplier, m.shields])).toEqual([['normal', 1, 2], ['desafio', 1.2, 1], ['extremo', 1.4, 0]]);
    expect(MODES[0].consequences).toHaveLength(0);
  });
});

describe('fila de recompensas', () => {
  it('junta os avisos de nível e mostra o maior, mantendo a ordem', () => {
    const evs = [
      { id: 1, kind: 'chefe_vencido', ref: 'f', created_at: '', data: {} },
      { id: 2, kind: 'nivel', ref: '3', created_at: '', data: { level: 3 } },
      { id: 3, kind: 'conquista', ref: 'm_1', created_at: '', data: {} },
      { id: 4, kind: 'nivel', ref: '4', created_at: '', data: { level: 4 } },
    ] as unknown as GameEvent[];
    const q = groupEvents(evs);
    expect(q.map((x) => x.event.kind)).toEqual(['chefe_vencido', 'nivel', 'conquista']);
    expect(q[1].ids).toEqual([2, 4]);
    expect((q[1].event as Extract<GameEvent, { kind: 'nivel' }>).data.level).toBe(4);
  });
});

describe('chefes', () => {
  const boss = (lock: Boss['lock']) => ({ lock } as Boss);
  it('explica o bloqueio', () => {
    expect(lockText(boss({ reason: 'dia', day: 8 }), 6)).toBe('Aparece no dia 8 do programa (faltam 2 dias).');
    expect(lockText(boss({ reason: 'dia', day: 8 }), 7)).toBe('Aparece no dia 8 do programa (faltam 1 dia).');
    expect(lockText(boss({ reason: 'vitorias', needed: 3, have: 1 }), 40)).toBe('Vença 3 chefes antes (você venceu 1).');
    expect(lockText(boss({ reason: 'habito', dimension: 'digital' }), 9)).toBe('Precisa de um hábito ativo de Saúde digital.');
  });
});
