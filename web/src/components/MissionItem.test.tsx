import { describe, expect, it, vi, afterEach } from 'vitest';
import { render, screen, fireEvent, cleanup } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { MissionItem } from './ui';
import type { Mission } from '../lib/types';

const base: Mission = {
  id: 'm1', habit_id: 'h1', kind: 'diaria', name: 'Leitura', description: '', dimension: 'intelectual',
  attr_primary: 'conhecimento', attr_secondary: 'foco', difficulty: 2, estimated_minutes: 10, target_value: 10, unit: 'min',
  period: 'noite', frequency: 'diaria', xp_reward: 15, mission_date: '2026-11-11', due_date: '2026-11-11',
  status: 'pendente', completed_at: null,
};

afterEach(cleanup);

describe('MissionItem', () => {
  it('mostra meta, área e XP e chama a ação ao tocar', () => {
    const onToggle = vi.fn();
    render(<MemoryRouter><MissionItem mission={base} onToggle={onToggle} /></MemoryRouter>);
    expect(screen.getByText('10 min')).toBeTruthy();
    expect(screen.getByText('Intelectual')).toBeTruthy();
    expect(screen.getByText('+15 XP')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Concluir Leitura' }));
    expect(onToggle).toHaveBeenCalledWith(base);
  });

  it('bloqueia o botão enquanto processa e em missões expiradas', () => {
    const { rerender } = render(<MemoryRouter><MissionItem mission={base} busy onToggle={() => {}} /></MemoryRouter>);
    expect((screen.getByRole('button') as HTMLButtonElement).disabled).toBe(true);
    rerender(<MemoryRouter><MissionItem mission={{ ...base, status: 'expirada' }} onToggle={() => {}} /></MemoryRouter>);
    expect((screen.getByRole('button') as HTMLButtonElement).disabled).toBe(true);
  });

  it('missão concluída oferece desfazer', () => {
    render(<MemoryRouter><MissionItem mission={{ ...base, status: 'concluida' }} onToggle={() => {}} /></MemoryRouter>);
    expect(screen.getByRole('button', { name: 'Desfazer Leitura' }).getAttribute('aria-pressed')).toBe('true');
  });
});
