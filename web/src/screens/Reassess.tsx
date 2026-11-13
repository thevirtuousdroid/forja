// Reavaliação do fim do programa (a partir do dia 61): as mesmas perguntas e a comparação com o começo.
import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api, friendlyError } from '../lib/api';
import { useApp } from '../lib/AppData';
import type { Assessment } from '../lib/types';
import { DIMENSIONS, DIMENSION_KEYS } from '../lib/game';
import { formatDay } from '../lib/dates';
import { BackButton, ErrorState, Skeleton } from '../components/ui';

export const REASSESS_FROM_DAY = 61;

/** Diferença entre duas avaliações, por área, da maior alta para a maior queda. */
export function compareAssessments(first: Assessment, last: Assessment) {
  const rows = DIMENSION_KEYS.map((d) => ({ d, before: first.scores[d], after: last.scores[d], delta: last.scores[d] - first.scores[d] }));
  const avg = (a: Assessment) => Math.round(DIMENSION_KEYS.reduce((s, d) => s + a.scores[d], 0) / DIMENSION_KEYS.length);
  return {
    rows,
    before: avg(first),
    after: avg(last),
    best: [...rows].sort((a, b) => b.delta - a.delta)[0],
    improved: rows.filter((r) => r.delta > 0).length,
    dropped: rows.filter((r) => r.delta < 0),
  };
}

const signed = (n: number) => (n > 0 ? `+${n}` : String(n));
const dayOf = (a: Assessment) => formatDay(a.created_at.slice(0, 10), { day: 'numeric', month: 'long' });

export function ReassessResultScreen() {
  const { stats, today } = useApp();
  const [list, setList] = useState<Assessment[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const load = () => { setError(null); api.assessments().then(setList).catch((e) => setError(friendlyError(e))); };
  useEffect(load, []);

  if (error) return <div className="screen"><BackButton to="/perfil" /><ErrorState message={error} onRetry={load} /></div>;
  if (!list) return <div className="screen"><BackButton to="/perfil" /><Skeleton height={320} /></div>;

  const day = today?.day ?? 1;
  if (list.length < 2) {
    const open = day >= REASSESS_FROM_DAY;
    return (
      <div className="screen">
        <BackButton to="/perfil" />
        <h1>Reavaliação</h1>
        <div className="card stack">
          <span className="muted">
            {open
              ? 'Responda de novo as perguntas do começo e veja, área por área, o quanto você mudou. Leva uns 3 minutos e não altera o seu plano.'
              : `A reavaliação abre no dia ${REASSESS_FROM_DAY} do programa, na fase Conclusão. Você está no dia ${day}.`}
          </span>
          {open && <Link to="/reavaliacao" className="btn primary">Fazer a reavaliação</Link>}
        </div>
      </div>
    );
  }

  const first = list[0];
  const last = list[list.length - 1];
  const c = compareAssessments(first, last);
  return (
    <div className="screen">
      <BackButton to="/perfil" />
      <div className="card hero stack" style={{ alignItems: 'center', textAlign: 'center' }}>
        <span className="tiny muted">{dayOf(first)} → {dayOf(last)}</span>
        <h1>{c.after > c.before ? 'Você evoluiu' : c.after === c.before ? 'Você se manteve' : 'Um retrato honesto'}</h1>
        <div className="row" style={{ gap: 14, alignItems: 'baseline' }}>
          <span className="num muted" style={{ fontSize: 26 }}>{c.before}</span>
          <span className="faint">→</span>
          <strong className="num" style={{ fontSize: 40 }}>{c.after}</strong>
        </div>
        <span className="small muted">
          Média das seis áreas, de 0 a 100.
          {c.best.delta > 0 && ` Maior avanço: ${DIMENSIONS[c.best.d].label} (${signed(c.best.delta)}).`}
        </span>
      </div>

      <h2>Área por área</h2>
      <div className="card stack">
        {c.rows.map((r) => (
          <div key={r.d} className="stack tight">
            <div className="row between small">
              <span>{DIMENSIONS[r.d].label}</span>
              <span className="num">
                <span className="muted">{r.before} → </span>{r.after}{' '}
                <strong style={{ color: r.delta > 0 ? 'var(--ok)' : r.delta < 0 ? 'var(--warn)' : 'var(--text-3)' }}>{r.delta === 0 ? '=' : signed(r.delta)}</strong>
              </span>
            </div>
            <div className="bar thin" style={{ position: 'relative' }}>
              <span style={{ width: `${r.after}%` }} />
              <i aria-hidden style={{ position: 'absolute', left: `${r.before}%`, top: -3, bottom: -3, width: 2, background: 'var(--text)', opacity: 0.55 }} />
            </div>
          </div>
        ))}
        <span className="small faint">O risco marca onde você estava no começo.</span>
      </div>

      {c.dropped.length > 0 && (
        <div className="card stack tight">
          <strong>Para olhar com calma</strong>
          <span className="small muted">
            {c.dropped.map((r) => DIMENSIONS[r.d].label).join(', ')} {c.dropped.length === 1 ? 'ficou' : 'ficaram'} abaixo do começo.
            Isso acontece: às vezes a gente passa a se avaliar com mais rigor. Vale escolher um hábito pequeno dessa área para a próxima fase.
          </span>
        </div>
      )}

      {stats && today && (
        <div className="card row" style={{ justifyContent: 'space-around', textAlign: 'center' }}>
          <div className="stack tight"><strong className="num" style={{ fontSize: 22 }}>{today.day}</strong><span className="tiny muted">dias</span></div>
          <div className="stack tight"><strong className="num" style={{ fontSize: 22 }}>{stats.level}</strong><span className="tiny muted">nível</span></div>
          <div className="stack tight"><strong className="num" style={{ fontSize: 22 }}>{stats.total_xp.toLocaleString('pt-BR')}</strong><span className="tiny muted">XP</span></div>
        </div>
      )}

      <span className="small faint">
        É uma comparação das suas próprias respostas, não um diagnóstico. Depois do dia 66 o plano continua, com temporadas e desafios.
      </span>
      <Link to="/reavaliacao" className="link small center">Refazer a reavaliação</Link>
    </div>
  );
}

/** Convite no Início, do dia 61 em diante, enquanto a reavaliação não foi feita. */
export function ReassessCard({ day }: { day: number }) {
  const [show, setShow] = useState(false);
  useEffect(() => {
    if (day < REASSESS_FROM_DAY) return;
    let alive = true;
    api.assessments().then((l) => { if (alive) setShow(l.length === 1); }).catch(() => {});
    return () => { alive = false; };
  }, [day]);
  if (!show) return null;
  return (
    <Link to="/reavaliacao" className="card row" style={{ color: 'inherit', textDecoration: 'none', gap: 12 }}>
      <span className="grow stack tight">
        <strong>Hora da reavaliação</strong>
        <span className="small muted">Responda de novo as perguntas do começo e veja o quanto você mudou.</span>
      </span>
      <span className="faint">›</span>
    </Link>
  );
}
