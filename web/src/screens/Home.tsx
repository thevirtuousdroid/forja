import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { useApp } from '../lib/AppData';
import { api } from '../lib/api';
import type { Journey, Mission } from '../lib/types';
import { MILESTONES, PERIOD_ORDER, TIER_TITLES, emblemTier, levelProgress, phaseInfo } from '../lib/game';
import { greeting, localDay } from '../lib/dates';
import { Emblem } from '../components/Emblem';
import { ErrorState, MissionItem, Skeleton, XpBar } from '../components/ui';
import { IconFlame, IconPlus, IconShield } from '../components/Icons';

export function sortMissions(ms: Mission[]) {
  return [...ms].sort((a, b) =>
    PERIOD_ORDER.indexOf(a.period) - PERIOD_ORDER.indexOf(b.period) || a.name.localeCompare(b.name));
}

export function HomeScreen() {
  const { profile, stats, today, missions, habits, busy, complete, undo, error, refresh, loading } = useApp();
  const [journey, setJourney] = useState<Journey | null>(null);

  useEffect(() => { api.journey().then(setJourney).catch(() => setJourney(null)); }, [missions]);

  if (error && !today) return <div className="screen"><ErrorState message={error} onRetry={refresh} /></div>;
  if (!profile || !stats || !today) {
    return <div className="screen"><Skeleton height={60} /><Skeleton height={180} /><Skeleton /><Skeleton /></div>;
  }

  const daily = missions.filter((m) => m.mission_date === today.today && (m.kind === 'diaria' || m.kind === 'personalizada'));
  const doneToday = missions.filter((m) => m.status === 'concluida' && m.completed_at && localDay(m.completed_at, profile.timezone) === today.today);
  const pending = sortMissions(missions.filter((m) => m.status === 'pendente' && m.kind !== 'surpresa'));
  const goal = profile.min_daily_missions;
  const phase = phaseInfo(today.phase);
  const inProgram = today.day <= 66;
  const lp = levelProgress(stats.total_xp, stats.level);

  const nextGoals: { title: string; detail: string }[] = [];
  if (doneToday.length < goal) {
    nextGoals.push({ title: 'Meta do dia', detail: `Faltam ${goal - doneToday.length} ${goal - doneToday.length === 1 ? 'missão' : 'missões'} para garantir o dia e +15 XP.` });
  }
  const nextMilestone = journey ? MILESTONES.find((m) => m > journey.current_streak) : undefined;
  if (journey && nextMilestone) {
    nextGoals.push({ title: `Sequência de ${nextMilestone} dias`, detail: `Faltam ${nextMilestone - journey.current_streak} dias.` });
  }
  nextGoals.push({ title: `Nível ${stats.level + 1}`, detail: `Faltam ${lp.needed - lp.current} XP.` });
  const nextHabit = habits.filter((h) => h.active && h.start_day > today.day).sort((a, b) => a.start_day - b.start_day)[0];
  if (nextHabit) nextGoals.push({ title: `Novo hábito no dia ${nextHabit.start_day}`, detail: nextHabit.name });

  return (
    <div className="screen">
      <div className="row between">
        <div className="stack tight">
          <span className="small muted">{greeting()}{profile.display_name ? `, ${profile.display_name}` : ''}</span>
          <h1>{inProgram ? `Dia ${today.day} de 66` : `Dia ${today.day}`}</h1>
        </div>
        <span className="pill accent">{inProgram ? `Fase ${today.phase} · ${phase.name}` : phase.name}</span>
      </div>

      {inProgram && (
        <div className="stack tight">
          <div className="bar thin" role="progressbar" aria-label="Progresso do programa de 66 dias" aria-valuenow={today.day} aria-valuemax={66}>
            <span style={{ width: `${(today.day / 66) * 100}%` }} />
          </div>
          <span className="small faint">{phase.goal}</span>
        </div>
      )}

      <Link to="/personagem" className="card hero row" style={{ textDecoration: 'none', color: 'inherit', gap: 16 }}>
        <Emblem level={stats.level} size={96} />
        <div className="grow stack tight">
          <span className="tiny muted">{TIER_TITLES[emblemTier(stats.level)]}</span>
          <span className="num" style={{ fontSize: 22, fontWeight: 700 }}>Nível {stats.level}</span>
          <XpBar totalXp={stats.total_xp} level={stats.level} />
        </div>
      </Link>

      <div className="stat-grid">
        <div className="stat">
          <div className="row small muted" style={{ gap: 6 }}><IconFlame size={16} /> Sequência</div>
          <div className="num">{journey ? journey.current_streak : '–'}<span className="small muted"> {journey?.current_streak === 1 ? 'dia' : 'dias'}</span></div>
          {journey && <div className="small faint row" style={{ gap: 4 }}><IconShield size={13} /> {journey.shields} {journey.shields === 1 ? 'escudo' : 'escudos'}</div>}
        </div>
        <div className="stat">
          <div className="small muted">Hoje</div>
          <div className="num">{doneToday.length}<span className="small muted"> / {daily.length} feitas</span></div>
          <div className="small faint">{doneToday.length >= goal ? 'Meta do dia batida ✓' : `Meta: ${goal}`}</div>
        </div>
      </div>

      <div className="section-title">
        <h2>Pendentes</h2>
        <Link to="/missoes">Ver todas</Link>
      </div>
      {loading && missions.length === 0 ? <Skeleton /> : pending.length === 0 ? (
        <div className="card center stack" style={{ alignItems: 'center' }}>
          <strong>Tudo feito por hoje.</strong>
          <span className="muted small">Descanse: recuperação também é parte da evolução.</span>
        </div>
      ) : (
        <div className="stack tight">
          {pending.slice(0, 4).map((m) => (
            <MissionItem key={m.id} mission={m} busy={busy.has(m.id)} onToggle={(x) => (x.status === 'concluida' ? undo(x) : complete(x))} />
          ))}
          {pending.length > 4 && <Link to="/missoes" className="link center small">+{pending.length - 4} missões</Link>}
        </div>
      )}

      {doneToday.length > 0 && (
        <>
          <h2 style={{ marginTop: 8 }}>Concluídas hoje</h2>
          <div className="stack tight">
            {doneToday.map((m) => (
              <MissionItem key={m.id} mission={m} busy={busy.has(m.id)} onToggle={(x) => undo(x)} />
            ))}
          </div>
        </>
      )}

      <h2 style={{ marginTop: 8 }}>Próximos objetivos</h2>
      <div className="card stack">
        {nextGoals.slice(0, 3).map((g) => (
          <div key={g.title} className="stack tight">
            <strong>{g.title}</strong>
            <span className="small muted">{g.detail}</span>
          </div>
        ))}
      </div>

      <Link to="/missoes/nova" className="btn block"><IconPlus size={18} /> Criar missão</Link>
    </div>
  );
}
