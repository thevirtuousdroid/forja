import { useEffect, useState } from 'react';
import { api, friendlyError } from '../lib/api';
import { useApp } from '../lib/AppData';
import type { Achievement } from '../lib/types';
import { ACHIEVEMENT_CATEGORIES, RARITY, SLOTS } from '../lib/rpg';
import { ATTRIBUTES } from '../lib/game';
import { formatDay } from '../lib/dates';
import { Badge } from '../components/Badge';
import { BackButton, ErrorState, Skeleton } from '../components/ui';

function Detail({ a, onClose }: { a: Achievement; onClose: () => void }) {
  const unlocked = !!a.unlocked_at;
  const secret = a.hidden && !unlocked;
  return (
    <div className="sheet-backdrop" onClick={onClose}>
      <div className="sheet" role="dialog" aria-modal="true" aria-label={secret ? 'Conquista oculta' : a.name} onClick={(e) => e.stopPropagation()}>
        <div className="row" style={{ gap: 14 }}>
          <Badge category={a.category} rarity={a.rarity} locked={!unlocked} hidden={a.hidden} size={76} />
          <div className="stack tight grow">
            <h2>{secret ? 'Conquista oculta' : a.name}</h2>
            <span className="small" style={{ color: RARITY[a.rarity].color }}>{RARITY[a.rarity].label}</span>
          </div>
        </div>
        <p className="muted">{secret ? 'Ela aparece quando você menos esperar. Siga usando o app do seu jeito.' : a.description}</p>
        {!secret && !unlocked && (
          <div className="stack tight">
            <div className="bar thin"><span style={{ width: `${(a.current / a.threshold) * 100}%` }} /></div>
            <span className="small faint num">{a.current} de {a.threshold}</span>
          </div>
        )}
        {unlocked && <span className="small faint">Desbloqueada em {formatDay(a.unlocked_at!.slice(0, 10), { day: 'numeric', month: 'long', year: 'numeric' })}</span>}
        <div className="row" style={{ gap: 8, flexWrap: 'wrap' }}>
          {a.xp > 0 && !secret && <span className="pill accent num">+{a.xp} XP em {ATTRIBUTES[a.attr].label}</span>}
          {!secret && a.rewards.map((r) => (
            <span key={r.id} className="pill" style={{ color: RARITY[r.rarity].color }}>
              {r.kind === 'titulo' ? 'Título' : SLOTS.find((s) => s.id === r.slot)?.label}: {r.name}
            </span>
          ))}
        </div>
        <button className="btn block" onClick={onClose}>Fechar</button>
      </div>
    </div>
  );
}

export function AchievementsScreen() {
  const { events } = useApp();
  const [list, setList] = useState<Achievement[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [open, setOpen] = useState<Achievement | null>(null);

  const load = () => {
    setError(null);
    api.achievements().then(setList).catch((e) => setError(friendlyError(e)));
  };
  useEffect(load, [events.length]);

  if (error) return <div className="screen"><BackButton to="/personagem" /><ErrorState message={error} onRetry={load} /></div>;
  if (!list) return <div className="screen"><BackButton to="/personagem" /><Skeleton height={60} /><Skeleton height={300} /></div>;

  const done = list.filter((a) => a.unlocked_at).length;
  const xp = list.filter((a) => a.unlocked_at).reduce((n, a) => n + a.xp, 0);

  return (
    <div className="screen">
      <BackButton to="/personagem" />
      <div className="row between">
        <h1>Conquistas</h1>
        <span className="small muted num">{done} de {list.length}</span>
      </div>
      <div className="stack tight">
        <div className="bar"><span style={{ width: `${(done / list.length) * 100}%` }} /></div>
        <span className="small faint num">{xp} XP ganhos com conquistas</span>
      </div>

      {ACHIEVEMENT_CATEGORIES.map((cat) => {
        const items = list.filter((a) => a.category === cat.id);
        if (items.length === 0) return null;
        return (
          <section key={cat.id} className="stack tight">
            <div className="row between">
              <h3>{cat.label}</h3>
              <span className="small faint num">{items.filter((a) => a.unlocked_at).length}/{items.length}</span>
            </div>
            <div className="grid-3 wide">
              {items.map((a) => {
                const unlocked = !!a.unlocked_at;
                const secret = a.hidden && !unlocked;
                return (
                  <button key={a.id} className={`badge-cell ${unlocked ? '' : 'locked'}`} onClick={() => setOpen(a)}
                          aria-label={secret ? 'Conquista oculta' : `${a.name}${unlocked ? ', desbloqueada' : `, ${a.current} de ${a.threshold}`}`}>
                    <Badge category={a.category} rarity={a.rarity} locked={!unlocked} hidden={a.hidden} size={58} />
                    <span className="name">{secret ? '???' : a.name}</span>
                    {!unlocked && !secret && (
                      <div className="bar thin" style={{ width: '80%', height: 4 }}><span style={{ width: `${(a.current / a.threshold) * 100}%` }} /></div>
                    )}
                  </button>
                );
              })}
            </div>
          </section>
        );
      })}
      {open && <Detail a={open} onClose={() => setOpen(null)} />}
    </div>
  );
}
