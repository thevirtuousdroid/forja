import { useEffect, useState } from 'react';
import { api, friendlyError } from '../lib/api';
import { useApp } from '../lib/AppData';
import type { Journey, ProgressionEvent } from '../lib/types';
import { MILESTONES, PHASES, formatTarget } from '../lib/game';
import { modeDef } from '../lib/rpg';
import { Link } from 'react-router-dom';
import { BossArt } from '../components/BossArt';
import { addDays, formatDay, parseDay } from '../lib/dates';
import { ErrorState, ProfileLink, Skeleton } from '../components/ui';
import { IconShield } from '../components/Icons';

const STATUS_TEXT = { completo: 'meta batida', parcial: 'parcial', vazio: 'em branco', protegido: 'protegido por escudo', hoje: 'hoje' } as const;

export function JourneyScreen() {
  const { profile, today, habits, missions } = useApp();
  const [journey, setJourney] = useState<Journey | null>(null);
  const [events, setEvents] = useState<ProgressionEvent[]>([]);
  const [error, setError] = useState<string | null>(null);

  const load = () => {
    setError(null);
    Promise.all([api.journey(), api.progression()])
      .then(([j, ev]) => { setJourney(j); setEvents(ev); })
      .catch((e) => setError(friendlyError(e)));
  };
  useEffect(load, [missions]);

  if (error) return <div className="screen"><ErrorState message={error} onRetry={load} /></div>;
  if (!journey || !today || !profile?.program_start) return <div className="screen"><Skeleton height={40} /><Skeleton height={120} /><Skeleton height={300} /></div>;

  const start = profile.program_start;
  const totalCells = Math.max(66, today.day);
  const byDate = new Map(journey.days.map((d) => [d.date, d]));
  const leading = (parseDay(start).getDay() + 6) % 7; // semana começando na segunda
  const habitName = (id: string) => habits.find((h) => h.id === id);

  return (
    <div className="screen">
      <div className="row between"><h1>Jornada</h1><ProfileLink /></div>

      <div className="grid-2">
        <Link to="/jornada/chefes" className="tile">
          <span className="small muted">Chefes</span>
          {today.boss ? (
            <span className="row" style={{ gap: 8 }}>
              <BossArt id={today.boss.boss_id} size={34} damage={today.boss.effective / today.boss.hp} />
              <span className="small" style={{ minWidth: 0 }}><strong>{today.boss.name}</strong><br /><span className="faint num">{today.boss.effective}/{today.boss.hp} golpes</span></span>
            </span>
          ) : <span className="small faint">Nenhuma batalha ativa</span>}
        </Link>
        <Link to="/jornada/modos" className="tile">
          <span className="small muted">Modo</span>
          <span className="num">{modeDef(today.mode ?? profile.mode).name}</span>
          <span className="small faint">regras e dificuldade</span>
        </Link>
        <Link to="/social/temporada" className="tile">
          <span className="small muted">Temporada</span>
          <span className="num">Ligas</span>
          <span className="small faint">pontos do mês e ranking</span>
        </Link>
        <Link to="/mentor" className="tile">
          <span className="small muted">Mentor</span>
          <span className="num">{profile.mentor_enabled ? 'Análises' : 'Conhecer'}</span>
          <span className="small faint">{(today.mentor_open ?? 0) > 0 ? `${today.mentor_open} sugest${today.mentor_open === 1 ? 'ão' : 'ões'}` : 'relatório semanal'}</span>
        </Link>
      </div>

      <div className="stat-grid four">
        <div className="stat"><div className="small muted">Sequência</div><div className="num">{journey.current_streak}</div></div>
        <div className="stat"><div className="small muted">Melhor</div><div className="num">{journey.best_streak}</div></div>
        <div className="stat"><div className="small muted">Consistência</div><div className="num">{journey.consistency ?? '–'}{journey.consistency !== null && <span className="small">%</span>}</div></div>
        <div className="stat">
          <div className="small muted">Escudos</div>
          <div className="num row" style={{ gap: 4 }}><IconShield size={18} />{journey.shields}<span className="small muted">/{journey.max_shields}</span></div>
        </div>
      </div>
      <p className="small faint">
        A cada 7 dias seguidos você ganha um escudo. Um dia em branco gasta um escudo em vez de zerar a sequência. Perder a sequência nunca apaga XP, nível ou histórico.
      </p>

      <div className="card stack">
        <h3>Marcos de sequência</h3>
        <div className="row" style={{ gap: 6, flexWrap: 'wrap' }}>
          {MILESTONES.map((m) => (
            <span key={m} className={`pill ${journey.milestones.includes(m) ? 'accent' : ''}`}>{journey.milestones.includes(m) ? '✓ ' : ''}{m} dias</span>
          ))}
        </div>
      </div>

      <div className="card stack">
        <div className="row between">
          <h3>Calendário</h3>
          <span className="small muted">desde {formatDay(start)}</span>
        </div>
        <div className="cal" style={{ fontSize: 10 }} aria-hidden>
          {['S', 'T', 'Q', 'Q', 'S', 'S', 'D'].map((d, i) => <span key={i} className="center faint">{d}</span>)}
        </div>
        <div className="cal" role="list" aria-label="Calendário do programa">
          {Array.from({ length: leading }).map((_, i) => <span key={`l${i}`} />)}
          {Array.from({ length: totalCells }).map((_, i) => {
            const date = addDays(start, i);
            const d = byDate.get(date);
            const cls = (d ? d.status : 'futuro') + (d?.mode && d.mode !== 'normal' ? ` m-${d.mode}` : '');
            const label = d ? `Dia ${i + 1}, ${formatDay(date)}: ${STATUS_TEXT[d.status]}, ${d.done} concluídas` : `Dia ${i + 1}, ${formatDay(date)}`;
            return <div key={date} role="listitem" className={`d ${cls}`} title={label} aria-label={label}>{i + 1}</div>;
          })}
        </div>
        <div className="legend">
          <span><i style={{ background: 'var(--accent)' }} />Meta batida</span>
          <span><i style={{ background: 'color-mix(in srgb, var(--accent) 30%, var(--surface-2))' }} />Parcial</span>
          <span><i style={{ background: 'var(--surface-2)', outline: '2px solid var(--attr-foco)', outlineOffset: -2 }} />Protegido</span>
          <span><i style={{ background: 'var(--surface-2)' }} />Em branco</span>
          {journey.days.some((x) => x.mode && x.mode !== 'normal') && <span><i style={{ background: 'var(--warn)', borderRadius: '50%', width: 6, height: 6 }} />Desafio ou Extremo</span>}
        </div>
      </div>

      <h2>Fases do programa</h2>
      <div className="stack tight">
        {PHASES.slice(0, 6).map((p) => {
          const current = today.phase === p.n;
          const past = today.phase > p.n;
          const unlocks = habits.filter((h) => !h.is_custom && h.start_day >= p.days[0] && h.start_day <= p.days[1] && h.start_day > 1);
          return (
            <div key={p.n} className="card stack tight" style={current ? { borderColor: 'var(--accent)' } : past ? { opacity: 0.65 } : undefined}>
              <div className="row between">
                <strong>{p.n}. {p.name}</strong>
                <span className="small faint">dias {p.days[0]}–{p.days[1]}{past ? ' ✓' : ''}</span>
              </div>
              <span className="small muted">{p.goal}</span>
              {unlocks.map((h) => <span key={h.id} className="small" style={{ color: 'var(--accent-2)' }}>+ {h.name} (dia {h.start_day})</span>)}
            </div>
          );
        })}
      </div>

      {events.length > 0 && (
        <>
          <h2>Metas que subiram</h2>
          <div className="card stack">
            {events.map((e) => {
              const h = habitName(e.habit_id);
              return (
                <div key={e.id} className="row between small">
                  <span>{h?.name ?? 'Hábito'} <span className="faint">· semana {e.week}</span></span>
                  <span className="num">{h ? `${formatTarget(e.old_target, h.unit)} → ${formatTarget(e.new_target, h.unit)}` : `${e.old_target} → ${e.new_target}`}</span>
                </div>
              );
            })}
          </div>
        </>
      )}
    </div>
  );
}
