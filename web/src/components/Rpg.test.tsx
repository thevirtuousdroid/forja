import { afterEach, describe, expect, it } from 'vitest';
import { cleanup, render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { Avatar } from './Avatar';
import { BossArt } from './BossArt';
import { Badge } from './Badge';
import { MissionItem } from './ui';
import type { AvatarConfig, Mission, Slot } from '../lib/types';

afterEach(cleanup);

// Todos os equipamentos do catálogo (0004_rpg.sql)
const ITEMS: [Slot, string][] = [
  ['cabeca', 'cab_faixa'], ['cabeca', 'cab_capuz'], ['cabeca', 'cab_elmo_silencio'], ['cabeca', 'cab_elmo_ferro'], ['cabeca', 'cab_coroa'],
  ['corpo', 'cor_tunica'], ['corpo', 'cor_gibao'], ['corpo', 'cor_malha'], ['corpo', 'cor_sentinela'], ['corpo', 'cor_placas'],
  ['capa', 'cap_curta'], ['capa', 'cap_constante'], ['capa', 'cap_fenix'], ['capa', 'cap_mestre'],
  ['arma', 'arm_martelo'], ['arma', 'arm_cajado'], ['arma', 'arm_lamina'], ['arma', 'arm_martelo_juiz'],
  ['amuleto', 'amu_ampulheta'], ['amuleto', 'amu_calma'], ['amuleto', 'amu_equilibrio'],
  ['moldura', 'mol_bronze'], ['moldura', 'mol_ferro'], ['moldura', 'mol_aco'], ['moldura', 'mol_runas'], ['moldura', 'mol_chamas'], ['moldura', 'mol_66'],
];
const base: AvatarConfig = { pele: 0, cabelo: 0, corCabelo: 0, barba: 0, corRoupa: 0, equip: { corpo: 'cor_tunica', moldura: 'mol_bronze' } };

describe('Avatar', () => {
  it('desenha cada equipamento, e cada item muda o desenho', () => {
    const { container: plain } = render(<Avatar config={base} />);
    const without = plain.innerHTML.replace(/id="[^"]*"|url\(#[^)]*\)|clip-path="[^"]*"/g, '');
    cleanup();
    for (const [slot, id] of ITEMS) {
      if (base.equip[slot] === id) continue;
      const { container } = render(<Avatar config={base} preview={{ slot, item: id }} />);
      const html = container.innerHTML.replace(/id="[^"]*"|url\(#[^)]*\)|clip-path="[^"]*"/g, '');
      expect(html, id).not.toBe(without);
      cleanup();
    }
  });

  it('cobre todas as combinações de aparência sem quebrar', () => {
    for (let cabelo = 0; cabelo < 8; cabelo++) {
      for (let barba = 0; barba < 3; barba++) {
        const { container } = render(<Avatar config={{ ...base, cabelo, barba, pele: cabelo % 6, corCabelo: cabelo, corRoupa: barba }} size={40} />);
        expect(container.querySelector('svg')).toBeTruthy();
        cleanup();
      }
    }
  });

  it('ids internos não colidem entre dois avatares na mesma tela', () => {
    const { container } = render(<><Avatar config={base} /><Avatar config={base} /></>);
    const ids = [...container.querySelectorAll('[id]')].map((e) => e.id);
    expect(new Set(ids).size).toBe(ids.length);
  });
});

describe('Chefes e insígnias', () => {
  it('cada chefe tem arte própria', () => {
    const drawings = new Set<string>();
    for (const id of ['tempestade', 'adiador', 'hidra', 'nevoa', 'sentinela', 'errante', 'juiz']) {
      const { container } = render(<BossArt id={id} />);
      drawings.add(container.innerHTML.replace(/id="[^"]*"|url\(#[^)]*\)/g, ''));
      cleanup();
    }
    expect(drawings.size).toBe(7);
  });

  it('rachaduras aparecem conforme o dano', () => {
    const cracks = (d: number) => {
      const { container } = render(<BossArt id="adiador" damage={d} />);
      const n = container.querySelectorAll('g[stroke="#FFF7E6"] path').length;
      cleanup();
      return n;
    };
    expect([cracks(0), cracks(0.3), cracks(0.6), cracks(0.9)]).toEqual([0, 1, 2, 3]);
  });

  it('conquista oculta e bloqueada mostra interrogação', () => {
    const { container } = render(<Badge category="habitos" rarity="comum" locked hidden />);
    expect(container.textContent).toBe('?');
  });
});

describe('MissionItem no RPG', () => {
  const m: Mission = {
    id: 'm1', habit_id: 'h1', kind: 'diaria', name: 'Meditação', description: '', dimension: 'mental',
    attr_primary: 'foco', attr_secondary: 'vitalidade', difficulty: 2, estimated_minutes: 5, target_value: 5, unit: 'min',
    period: 'qualquer', frequency: 'diaria', xp_reward: 15, mission_date: '2026-11-12', due_date: '2026-11-12',
    status: 'pendente', completed_at: null,
  };
  it('mostra o XP com o bônus do modo e o aviso de golpe', () => {
    render(<MemoryRouter><MissionItem mission={m} onToggle={() => {}} multiplier={1.4} bossHit /></MemoryRouter>);
    expect(screen.getByText('+21 XP')).toBeTruthy();
    expect(screen.getByText('⚔ golpe no chefe')).toBeTruthy();
  });
  it('não mostra o aviso em missão concluída', () => {
    render(<MemoryRouter><MissionItem mission={{ ...m, status: 'concluida' }} onToggle={() => {}} bossHit /></MemoryRouter>);
    expect(screen.queryByText('⚔ golpe no chefe')).toBeNull();
  });
});
