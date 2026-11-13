import { useEffect, useState } from 'react';
import { api } from '../lib/api';
import { useApp } from '../lib/AppData';
import type { Attribute, LedgerAttrRow } from '../lib/types';
import { ATTRIBUTES, ATTRIBUTE_KEYS, attributeProgress } from '../lib/game';
import { addDays, formatDay } from '../lib/dates';
import { BackButton, Skeleton } from '../components/ui';

/** Pentágono com o nível de cada atributo. */
function Radar({ levels }: { levels: Record<Attribute, number> }) {
  const max = Math.max(5, ...Object.values(levels));
  const cx = 110, cy = 104, R = 76;
  const pt = (k: number, r: number) => {
    const a = (-90 + k * 72) * (Math.PI / 180);
    return [cx + Math.cos(a) * r, cy + Math.sin(a) * r] as const;
  };
  const ring = (f: number) => ATTRIBUTE_KEYS.map((_, k) => pt(k, R * f).join(',')).join(' ');
  const shape = ATTRIBUTE_KEYS.map((a, k) => pt(k, R * (levels[a] / max)).join(',')).join(' ');
  return (
    <svg viewBox="-70 0 360 214" className="radar" role="img" style={{ width: '100%', maxWidth: 360 }}
         aria-label={ATTRIBUTE_KEYS.map((a) => `${ATTRIBUTES[a].label} nível ${levels[a]}`).join(', ')}>
      {[1, 0.66, 0.33].map((f) => <polygon key={f} points={ring(f)} fill="none" stroke="var(--line)" strokeWidth="1" />)}
      {ATTRIBUTE_KEYS.map((_, k) => { const [x, y] = pt(k, R); return <line key={k} x1={cx} y1={cy} x2={x} y2={y} stroke="var(--line)" />; })}
      <polygon points={shape} fill="var(--accent)" fillOpacity="0.25" stroke="var(--accent)" strokeWidth="2" strokeLinejoin="round" />
      {ATTRIBUTE_KEYS.map((a, k) => { const [x, y] = pt(k, R * (levels[a] / max)); return <circle key={a} cx={x} cy={y} r="3.5" fill={ATTRIBUTES[a].color} />; })}
      {ATTRIBUTE_KEYS.map((a, k) => {
        // Rótulos dos lados crescem para fora, para não entrar no desenho
        const [x, y] = pt(k, R + 12);
        const anchor = x > cx + 5 ? 'start' : x < cx - 5 ? 'end' : 'middle';
        return (
          <text key={a} x={x} y={k === 0 ? y - 6 : y} textAnchor={anchor} dominantBaseline="middle">
            <tspan fill={ATTRIBUTES[a].color} fontWeight="700">{levels[a]}</tspan> {ATTRIBUTES[a].label}
          </text>
        );
      })}
    </svg>
  );
}

export function AttributesScreen() {
  const { stats, habits, today } = useApp();
  const [rows, setRows] = useState<LedgerAttrRow[] | null>(null);
  const todayStr = today?.today;

  useEffect(() => {
    if (!todayStr) return;
    api.ledgerSince(addDays(todayStr, -13)).then(setRows).catch(() => setRows([]));
  }, [todayStr]);

  if (!stats || !todayStr) return <div className="screen"><BackButton to="/personagem" /><Skeleton height={260} /></div>;

  const levels = Object.fromEntries(ATTRIBUTE_KEYS.map((a) => [a, attributeProgress(stats[a]).level])) as Record<Attribute, number>;
  const days = Array.from({ length: 14 }, (_, i) => addDays(todayStr, i - 13));
  const perDay = (a: Attribute) => days.map((d) => (rows ?? []).filter((r) => r.day === d).reduce((n, r) => n + r[a], 0));
  const active = habits.filter((h) => h.active);

  return (
    <div className="screen">
      <BackButton to="/personagem" />
      <h1>Atributos</h1>
      <div className="card center"><Radar levels={levels} /></div>
      <p className="small faint">Cada missão fortalece dois atributos: 70% do XP vai para o principal e 30% para o secundário.</p>

      {ATTRIBUTE_KEYS.map((a) => {
        const p = attributeProgress(stats[a]);
        const series = perDay(a);
        const week = series.slice(7).reduce((n, v) => n + v, 0);
        const peak = Math.max(1, ...series);
        const feeds = active.filter((h) => h.attr_primary === a || h.attr_secondary === a);
        return (
          <div key={a} className="card stack">
            <div className="row between">
              <strong style={{ color: ATTRIBUTES[a].color, fontSize: 17 }}>{ATTRIBUTES[a].label}</strong>
              <span className="num">Nível {p.level}</span>
            </div>
            <span className="small muted">{ATTRIBUTES[a].hint}</span>
            <div className="bar thin"><span style={{ width: `${p.ratio * 100}%`, background: ATTRIBUTES[a].color }} /></div>
            <div className="row between small faint num">
              <span>{stats[a].toLocaleString('pt-BR')} XP</span>
              <span>+{week} nos últimos 7 dias</span>
            </div>
            {rows === null ? <Skeleton height={40} /> : (
              <div className="mini-bars" role="img" aria-label={`XP de ${ATTRIBUTES[a].label} por dia nas últimas duas semanas`}>
                {series.map((v, i) => (
                  <i key={days[i]} title={`${formatDay(days[i])}: ${v} XP`}
                     style={{ height: `${Math.max(4, (v / peak) * 100)}%`, background: v ? ATTRIBUTES[a].color : 'var(--surface-3)', opacity: i === 13 ? 1 : 0.75 }} />
                ))}
              </div>
            )}
            <div className="small">
              {feeds.length === 0 ? <span className="faint">Nenhum hábito ativo alimenta este atributo agora.</span> : (
                <span className="muted">
                  Alimentado por {feeds.map((h, i) => (
                    <span key={h.id}>{i > 0 && ', '}<span style={{ color: 'var(--text)' }}>{h.name}</span>{h.attr_primary === a ? '' : ' (secundário)'}</span>
                  ))}
                </span>
              )}
            </div>
          </div>
        );
      })}
    </div>
  );
}
