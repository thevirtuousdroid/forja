import { describe, expect, it, vi } from 'vitest';
import { fireEvent, render, screen } from '@testing-library/react';
import { HistoryBars, LeagueBadge, Ring, Toggle } from './Social';
import { groupEvents } from './RewardOverlay';
import type { GameEvent } from '../lib/types';

describe('peças da Etapa 4', () => {
  it('brasões das seis ligas', () => {
    for (const l of ['bronze', 'prata', 'ouro', 'platina', 'diamante', 'mestre'] as const) {
      const { container, unmount } = render(<LeagueBadge league={l} size={40} />);
      expect(container.querySelectorAll('path').length).toBe(3);
      unmount();
    }
  });

  it('interruptor acessível', () => {
    const fn = vi.fn();
    render(<Toggle label="Aparecer no ranking" checked={false} onChange={fn} />);
    const sw = screen.getByRole('switch', { name: /Aparecer no ranking/ });
    fireEvent.click(sw);
    expect(fn).toHaveBeenCalledWith(true);
  });

  it('histórico com média só dos dias registrados', () => {
    render(<HistoryBars label="Copos" goal={8} days={[
      { date: '2026-11-10', value: 6 }, { date: '2026-11-11', value: null }, { date: '2026-11-12', value: 8 },
    ]} />);
    expect(screen.getByText('média 7')).toBeTruthy();
    expect(screen.getByLabelText('Copos')).toBeTruthy();
  });

  it('anel limita o progresso entre 0 e 1', () => {
    const { container } = render(<Ring value={3}>x</Ring>);
    const arc = container.querySelectorAll('circle')[1];
    const [filled, total] = arc.getAttribute('stroke-dasharray')!.split(' ').map(Number);
    expect(filled).toBeCloseTo(total);
  });

  it('avisos novos passam pela fila da tela de recompensa', () => {
    const evs = [
      { id: 1, ref: '202610', created_at: '', kind: 'temporada', data: {} },
      { id: 2, ref: '3', created_at: '', kind: 'nivel', data: { level: 3 } },
      { id: 3, ref: 'c', created_at: '', kind: 'desafio_fim', data: {} },
      { id: 4, ref: '4', created_at: '', kind: 'nivel', data: { level: 4 } },
      { id: 5, ref: '2026-11-09', created_at: '', kind: 'relatorio', data: {} },
    ] as unknown as GameEvent[];
    const q = groupEvents(evs);
    expect(q.map((x) => x.event.kind)).toEqual(['temporada', 'nivel', 'desafio_fim', 'relatorio']);
    expect(q[1].ids).toEqual([2, 4]);
  });
});
