// Peças visuais da Etapa 4: pessoas, ligas, folhas, travas do Premium, anel e gráfico de barras.
import { useEffect, useId, type ReactNode } from 'react';
import { Link } from 'react-router-dom';
import type { LeagueId, Lite, Profile } from '../lib/types';
import { avatarOf } from '../lib/rpg';
import { LEAGUE_COLORS } from '../lib/social';
import { Avatar } from './Avatar';

export function PersonAvatar({ person, size = 44 }: { person: Pick<Lite, 'avatar' | 'name'>; size?: number }) {
  return <Avatar config={avatarOf({ avatar: person.avatar } as Pick<Profile, 'avatar'>)} size={size} label={person.name || 'Pessoa'} />;
}

export function PersonRow({ person, sub, right, to, size = 44 }: {
  person: Pick<Lite, 'avatar' | 'name'>; sub?: ReactNode; right?: ReactNode; to?: string; size?: number;
}) {
  const body = (
    <>
      <PersonAvatar person={person} size={size} />
      <div className="grow stack" style={{ gap: 2 }}>
        <strong className="ellipsis">{person.name || 'Sem nome'}</strong>
        {sub && <span className="small muted">{sub}</span>}
      </div>
      {right}
    </>
  );
  return to
    ? <Link to={to} className="person-row">{body}</Link>
    : <div className="person-row">{body}</div>;
}

const LEAGUE_GLYPH: Record<LeagueId, string> = {
  bronze: 'M32 22 L38 32 L32 42 L26 32 Z',
  prata: 'M24 26 L32 21 L40 26 L32 31 Z M24 34 L32 29 L40 34 L32 39 Z',
  ouro: 'M32 20 L35.5 28 L44 28.5 L37.5 34 L39.5 42.5 L32 38 L24.5 42.5 L26.5 34 L20 28.5 L28.5 28 Z',
  platina: 'M32 19 L42 27 L38 43 L26 43 L22 27 Z',
  diamante: 'M24 24 H40 L45 30 L32 45 L19 30 Z',
  mestre: 'M32 18 C36 24 42 27 42 35 A10 10 0 0 1 22 35 C22 30 25 27.5 27.5 25.5 C28 29 29.5 31 31.5 31.5 C30 27 30.5 22 32 18 Z',
};

/** Brasão de liga desenhado aqui mesmo (cor e símbolo próprios para cada liga). */
export function LeagueBadge({ league, size = 48 }: { league: LeagueId; size?: number }) {
  const uid = useId().replace(/:/g, '');
  const [light, dark] = LEAGUE_COLORS[league];
  return (
    <svg width={size} height={size} viewBox="0 0 64 64" aria-hidden>
      <defs>
        <linearGradient id={`${uid}-l`} x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor={light} /><stop offset="1" stopColor={dark} /></linearGradient>
      </defs>
      <path d="M32 4 L54 12 V31 C54 46 44 55 32 60 C20 55 10 46 10 31 V12 Z" fill={`url(#${uid}-l)`} />
      <path d="M32 9 L49 15.5 V31 C49 43 41 50.5 32 54.5 C23 50.5 15 43 15 31 V15.5 Z" fill="#151821" />
      <path d={LEAGUE_GLYPH[league]} fill={light} />
    </svg>
  );
}

export function Sheet({ title, onClose, children }: { title: string; onClose: () => void; children: ReactNode }) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose(); };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);
  return (
    <div className="sheet-backdrop" onClick={onClose}>
      <div className="sheet" role="dialog" aria-modal="true" aria-label={title} onClick={(e) => e.stopPropagation()}>
        <div className="row between">
          <h2>{title}</h2>
          <button className="link" onClick={onClose}>Fechar</button>
        </div>
        {children}
      </div>
    </div>
  );
}

/** Mostrado quando o servidor diz que o recurso é Premium. */
export function PremiumLock({ what }: { what: string }) {
  return (
    <div className="card stack center" style={{ alignItems: 'center' }}>
      <span style={{ fontSize: 28 }} aria-hidden>🔒</span>
      <strong>{what} faz parte do Premium</strong>
      <span className="small muted">Seu progresso continua guardado. Veja o que está liberado no seu plano.</span>
      <Link to="/perfil/plano" className="btn sm">Ver plano</Link>
    </div>
  );
}

export function Toggle({ checked, onChange, label, desc, disabled }: {
  checked: boolean; onChange: (v: boolean) => void; label: string; desc?: string; disabled?: boolean;
}) {
  return (
    <label className="toggle-row">
      <span className="grow stack" style={{ gap: 2 }}>
        <span>{label}</span>
        {desc && <span className="small faint">{desc}</span>}
      </span>
      <input type="checkbox" role="switch" className="switch" checked={checked} disabled={disabled}
             onChange={(e) => onChange(e.target.checked)} />
    </label>
  );
}

/** Anel de progresso (0 a 1). */
export function Ring({ value, size = 160, stroke = 14, children, color = 'var(--accent)' }: {
  value: number; size?: number; stroke?: number; children?: ReactNode; color?: string;
}) {
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  const v = Math.max(0, Math.min(1, value));
  return (
    <div className="ring" style={{ width: size, height: size }}>
      <svg width={size} height={size} aria-hidden>
        <circle cx={size / 2} cy={size / 2} r={r} stroke="var(--surface-3)" strokeWidth={stroke} fill="none" />
        <circle cx={size / 2} cy={size / 2} r={r} stroke={color} strokeWidth={stroke} fill="none" strokeLinecap="round"
                strokeDasharray={`${c * v} ${c}`} transform={`rotate(-90 ${size / 2} ${size / 2})`} style={{ transition: 'stroke-dasharray .6s ease' }} />
      </svg>
      <div className="ring-center">{children}</div>
    </div>
  );
}

/** Barras dos últimos dias, com uma linha de meta opcional. */
export function HistoryBars({ days, goal, color = 'var(--accent)', label, format }: {
  days: { date: string; value: number | null }[]; goal?: number | null; color?: string; label: string;
  format?: (v: number) => string;
}) {
  const max = Math.max(1, goal ?? 0, ...days.map((d) => d.value ?? 0));
  const withData = days.filter((d) => d.value !== null);
  const avg = withData.length ? withData.reduce((n, d) => n + (d.value ?? 0), 0) / withData.length : null;
  const fmt = format ?? ((v: number) => String(Math.round(v)));
  return (
    <figure className="history" aria-label={label}>
      <div className="history-bars">
        {goal ? <span className="history-goal" style={{ bottom: `${(goal / max) * 100}%` }} aria-hidden /> : null}
        {days.map((d) => (
          <i key={d.date} title={`${d.date}: ${d.value === null ? 'sem registro' : fmt(d.value)}`}
             style={{ height: `${d.value ? Math.max(4, (d.value / max) * 100) : 0}%`, background: color, opacity: d.value === null ? 0 : 1 }} />
        ))}
      </div>
      <figcaption className="row between small faint">
        <span>{days.length} dias</span>
        <span className="num">{avg === null ? 'sem registros' : `média ${fmt(avg)}`}</span>
      </figcaption>
    </figure>
  );
}
