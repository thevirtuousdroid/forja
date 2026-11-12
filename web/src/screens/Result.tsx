import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api, friendlyError } from '../lib/api';
import { useApp } from '../lib/AppData';
import type { Assessment } from '../lib/types';
import { ATTRIBUTES, ATTRIBUTE_KEYS, DIMENSIONS, DIMENSION_KEYS, attributeLevel, formatTarget, phaseForDay, phaseInfo, referenceProfile } from '../lib/game';
import { Avatar } from '../components/Avatar';
import { avatarOf } from '../lib/rpg';
import { BackButton, ErrorState, Loading } from '../components/ui';
import { formatDay } from '../lib/dates';

export function ResultScreen({ revisit = false }: { revisit?: boolean }) {
  const { stats, habits, profile } = useApp();
  const [assessment, setAssessment] = useState<Assessment | null | undefined>(undefined);
  const [error, setError] = useState<string | null>(null);

  const load = () => {
    setError(null);
    api.latestAssessment().then(setAssessment).catch((e) => setError(friendlyError(e)));
  };
  useEffect(load, []);

  if (error) return <div className="screen no-tabs"><ErrorState message={error} onRetry={load} /></div>;
  if (assessment === undefined || !stats) return <div className="screen no-tabs"><Loading label="Preparando sua avaliação…" /></div>;
  if (assessment === null) return <div className="screen no-tabs"><ErrorState message="Nenhuma avaliação encontrada." /></div>;

  const ref = referenceProfile(assessment.scores);
  const plan = [...habits].sort((a, b) => a.start_day - b.start_day);
  const groups = Array.from(new Set(plan.map((h) => h.start_day)));

  return (
    <div className={`screen ${revisit ? '' : 'no-tabs'}`}>
      {revisit && <BackButton to="/perfil" />}
      <div className="card hero stack" style={{ alignItems: 'center', textAlign: 'center' }}>
        <span className="tiny muted">{revisit ? `Avaliação de ${formatDay(assessment.created_at.slice(0, 10), { day: 'numeric', month: 'long' })}` : 'Sua avaliação inicial'}</span>
        <Avatar config={avatarOf(profile)} size={132} />
        <h1>{ref.archetype} em formação</h1>
        <p className="muted">{ref.summary}</p>
        <p className="small faint">Este é um retrato de referência baseado nas suas respostas, não um diagnóstico.</p>
      </div>

      <h2>Ponto de partida</h2>
      <div className="card stack">
        {DIMENSION_KEYS.map((d) => (
          <div key={d} className="stack tight">
            <div className="row between small">
              <span>{DIMENSIONS[d].label}{assessment.priorities.includes(d) && <span className="pill accent" style={{ marginLeft: 8 }}>prioridade</span>}</span>
              <span className="num muted">{assessment.scores[d]}</span>
            </div>
            <div className="bar thin"><span style={{ width: `${assessment.scores[d]}%` }} /></div>
          </div>
        ))}
      </div>

      <h2>Atributos iniciais</h2>
      <div className="card stack">
        {ATTRIBUTE_KEYS.map((a) => (
          <div key={a} className="row between">
            <span><span style={{ color: ATTRIBUTES[a].color }}>●</span> {ATTRIBUTES[a].label}</span>
            <span className="num">Nv. {attributeLevel(stats[a])}</span>
          </div>
        ))}
      </div>

      <h2>Seu plano de 66 dias</h2>
      <p className="muted small">
        Começa com o essencial e cresce por fases. Cada hábito tem um teto: a meta só sobe quando você cumpre 5 dos 7 dias anteriores.
        {profile && ` Meta mínima diária: ${profile.min_daily_missions} ${profile.min_daily_missions === 1 ? 'missão' : 'missões'}.`}
      </p>
      {groups.map((day) => (
        <div key={day} className="card stack">
          <div className="row between">
            <h3>{day === 1 ? 'A partir de hoje' : `A partir do dia ${day}`}</h3>
            <span className="pill">{phaseInfo(phaseForDay(day)).name}</span>
          </div>
          {plan.filter((h) => h.start_day === day).map((h) => (
            <div key={h.id} className="row between">
              <div className="grow">
                <div>{h.name}</div>
                <div className="small faint">{DIMENSIONS[h.dimension].short}</div>
              </div>
              <span className="small muted num">
                {formatTarget(h.current_target, h.unit)}{h.max_value > h.base_value ? ` → até ${formatTarget(h.max_value, h.unit)}` : ''}
              </span>
            </div>
          ))}
        </div>
      ))}

      {!revisit && (
        <div className="sticky-actions">
          <Link to="/" className="btn primary block" replace>Começar o dia 1</Link>
        </div>
      )}
    </div>
  );
}
