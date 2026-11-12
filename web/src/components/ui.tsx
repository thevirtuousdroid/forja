import type { ReactNode } from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { IconCheck, IconChevronLeft, IconHome, IconMap, IconShield, IconTarget, IconUser } from './Icons';
import type { Mission } from '../lib/types';
import { DIMENSIONS, KIND_LABEL, formatTarget, levelProgress } from '../lib/game';

export function Loading({ label = 'Carregando…' }: { label?: string }) {
  return <div className="state"><div className="spinner" aria-hidden /><span>{label}</span></div>;
}

export function ErrorState({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return (
    <div className="state" role="alert">
      <strong style={{ color: 'var(--text)' }}>Não foi possível carregar</strong>
      <span>{message}</span>
      {onRetry && <button className="btn sm" onClick={onRetry}>Tentar de novo</button>}
    </div>
  );
}

export function Empty({ title, children }: { title: string; children?: ReactNode }) {
  return (
    <div className="state">
      <strong style={{ color: 'var(--text)' }}>{title}</strong>
      {children}
    </div>
  );
}

export function Skeleton({ height = 72 }: { height?: number }) {
  return <div className="skeleton" style={{ height }} aria-hidden />;
}

export function BackButton({ to }: { to?: string }) {
  const nav = useNavigate();
  return (
    <button className="back" onClick={() => (to ? nav(to) : nav(-1))}>
      <IconChevronLeft /> Voltar
    </button>
  );
}

export function TabBar() {
  const items = [
    { to: '/', label: 'Início', icon: <IconHome />, end: true },
    { to: '/missoes', label: 'Missões', icon: <IconTarget /> },
    { to: '/jornada', label: 'Jornada', icon: <IconMap /> },
    { to: '/personagem', label: 'Personagem', icon: <IconShield /> },
    { to: '/perfil', label: 'Perfil', icon: <IconUser /> },
  ];
  return (
    <div className="tabbar">
      <nav aria-label="Navegação principal">
        {items.map((i) => (
          <NavLink key={i.to} to={i.to} end={i.end} className={({ isActive }) => (isActive ? 'active' : '')}>
            {i.icon}
            {i.label}
          </NavLink>
        ))}
      </nav>
    </div>
  );
}

export function XpBar({ totalXp, level }: { totalXp: number; level: number }) {
  const p = levelProgress(totalXp, level);
  return (
    <div className="stack tight">
      <div className="bar" role="progressbar" aria-valuemin={0} aria-valuemax={p.needed} aria-valuenow={p.current} aria-label="Progresso até o próximo nível">
        <span style={{ width: `${p.ratio * 100}%` }} />
      </div>
      <div className="row between small faint">
        <span className="num">{p.current} / {p.needed} XP</span>
        <span>Nível {level + 1}</span>
      </div>
    </div>
  );
}

export function Difficulty({ value }: { value: number }) {
  return (
    <span className="dots" aria-label={`Dificuldade ${value} de 5`}>
      {[1, 2, 3, 4, 5].map((i) => <i key={i} className={i <= value ? 'on' : ''} />)}
    </span>
  );
}

export function MissionItem({ mission, busy, onToggle, multiplier = 1, bossHit = false }: {
  mission: Mission; busy?: boolean; onToggle: (m: Mission) => void;
  /** Multiplicador de XP do modo de dificuldade (só exibição; o servidor calcula). */
  multiplier?: number;
  /** Esta missão daria o golpe de hoje no chefe ativo. */
  bossHit?: boolean;
}) {
  const done = mission.status === 'concluida';
  const expired = mission.status === 'expirada';
  return (
    <div className={`mission ${done ? 'done' : ''}`}>
      <NavLink to={`/missoes/${mission.id}`} className="mission-body">
        <div className="mission-name">{mission.name}</div>
        <div className="row small muted" style={{ gap: 8, marginTop: 2, flexWrap: 'wrap' }}>
          <span>{formatTarget(mission.target_value, mission.unit)}</span>
          <span className="faint">·</span>
          <span>{DIMENSIONS[mission.dimension].short}</span>
          {mission.kind !== 'diaria' && <span className="pill accent">{KIND_LABEL[mission.kind]}</span>}
          <span className="num faint">+{done ? mission.xp_reward : Math.max(1, Math.round(mission.xp_reward * multiplier))} XP</span>
          {bossHit && !done && <span className="pill" style={{ color: 'var(--hp)' }}>⚔ golpe no chefe</span>}
        </div>
      </NavLink>
      <button
        className={`check ${done ? 'on' : ''}`}
        onClick={() => onToggle(mission)}
        disabled={busy || expired}
        aria-pressed={done}
        aria-label={done ? `Desfazer ${mission.name}` : `Concluir ${mission.name}`}
      >
        <IconCheck />
      </button>
    </div>
  );
}
