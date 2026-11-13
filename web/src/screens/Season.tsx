import { useCallback, useEffect, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { api, friendlyError, isPremiumError } from '../lib/api';
import type { GroupSummary, Ranking, RankingCategory, SeasonInfo } from '../lib/types';
import { LEAGUE_COLORS, RANKING_CATEGORIES, plural } from '../lib/social';
import { formatDay } from '../lib/dates';
import { LeagueBadge, PersonAvatar, PremiumLock } from '../components/Social';
import { BackButton, ErrorState, Skeleton } from '../components/ui';

const BREAKDOWN: { id: keyof SeasonInfo['breakdown']; label: string }[] = [
  { id: 'meta', label: 'Dias com a meta cumprida' },
  { id: 'missoes', label: 'Missões do plano' },
  { id: 'perfeitos', label: 'Dias perfeitos' },
  { id: 'chefes', label: 'Chefes vencidos' },
  { id: 'desafios', label: 'Desafios' },
  { id: 'objetivos', label: 'Objetivos da temporada' },
];

export function SeasonScreen() {
  const [s, setS] = useState<SeasonInfo | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [locked, setLocked] = useState(false);
  const load = useCallback(() => {
    setError(null);
    api.season().then(setS).catch((e) => (isPremiumError(e) ? setLocked(true) : setError(friendlyError(e))));
  }, []);
  useEffect(load, [load]);

  if (locked) return <div className="screen"><BackButton to="/social" /><h1>Temporada</h1><PremiumLock what="A temporada" /></div>;
  if (error) return <div className="screen"><BackButton to="/social" /><ErrorState message={error} onRetry={load} /></div>;
  if (!s) return <div className="screen"><BackButton to="/social" /><Skeleton height={200} /><Skeleton height={200} /></div>;

  const toNext = s.next ? s.next.min_points - s.points : 0;
  const span = s.next ? s.next.min_points - s.league.min_points : 1;
  return (
    <div className="screen">
      <BackButton to="/social" />
      <div className="stack tight">
        <span className="tiny muted">{formatDay(s.starts_on, { day: 'numeric', month: 'short' })} a {formatDay(s.ends_on, { day: 'numeric', month: 'short' })} · {plural(s.days_left, 'dia restante', 'dias restantes')}</span>
        <h1>{s.name}</h1>
      </div>

      <div className="card hero stack center" style={{ alignItems: 'center' }}>
        <LeagueBadge league={s.league.id} size={110} />
        <h2 style={{ color: LEAGUE_COLORS[s.league.id][0] }}>Liga {s.league.name}</h2>
        <span className="num" style={{ fontSize: 28, fontWeight: 700 }}>{s.points.toLocaleString('pt-BR')} <span className="small muted">pontos</span></span>
        {s.next ? (
          <div className="stack tight" style={{ width: '100%' }}>
            <div className="bar"><span style={{ width: `${Math.max(0, Math.min(1, 1 - toNext / span)) * 100}%` }} /></div>
            <span className="small muted">Faltam {plural(toNext, 'ponto', 'pontos')} para a liga {s.next.name}</span>
          </div>
        ) : <span className="small muted">Você está na liga mais alta.</span>}
        <Link to="/social/ranking" className="btn sm">Ver ranking</Link>
      </div>

      <section className="stack tight">
        <h3>Objetivos da temporada</h3>
        {s.objectives.map((o) => (
          <div key={o.id} className="card stack tight">
            <div className="row between">
              <span className={o.done ? '' : 'muted'}>{o.done ? '✓ ' : ''}{o.name}</span>
              <span className={`pill ${o.done ? 'ok' : ''} num`}>+{o.points}</span>
            </div>
            <div className="bar thin"><span style={{ width: `${(o.progress / o.target) * 100}%` }} /></div>
            <span className="small faint num">{o.progress} de {o.target}</span>
          </div>
        ))}
      </section>

      <div className="card stack tight">
        <h3>De onde vieram seus pontos</h3>
        {BREAKDOWN.map((b) => (
          <div key={b.id} className="row between small">
            <span className="muted">{b.label}</span><span className="num">{s.breakdown[b.id]}</span>
          </div>
        ))}
      </div>

      <div className="card stack tight">
        <h3>Como pontuar</h3>
        <ul className="small muted" style={{ margin: 0, paddingLeft: 18, display: 'flex', flexDirection: 'column', gap: 4 }}>
          <li>Meta do dia cumprida: +10</li>
          <li>Cada missão do plano: +2 (até 5 por dia)</li>
          <li>Dia perfeito (todas as diárias): +5</li>
          <li>Chefe vencido: +15 (revanche +5)</li>
          <li>Desafio vencido ou meta coletiva: +10 (até 4 por temporada)</li>
        </ul>
        <span className="small faint">Missões avulsas não pontuam, e cada dia vale no máximo 25 pontos. Assim o ranking mede constância, não volume.</span>
      </div>

      <div className="card stack tight">
        <h3>Ligas e recompensas</h3>
        {s.leagues.map((l) => (
          <div key={l.id} className="row" style={{ gap: 10, opacity: l.sort <= s.league.sort ? 1 : 0.65 }}>
            <LeagueBadge league={l.id} size={34} />
            <span className="grow">{l.name}</span>
            <span className="small faint num">{l.min_points}+ pts</span>
            <span className="small num" style={{ width: 64, textAlign: 'right' }}>{l.xp_reward ? `+${l.xp_reward} XP` : '–'}</span>
          </div>
        ))}
        <span className="small faint">A liga é definida no fim do mês, e o XP da liga entra no primeiro acesso do mês seguinte.</span>
      </div>

      {s.history.length > 0 && (
        <section className="stack tight">
          <h3>Temporadas anteriores</h3>
          {s.history.map((h) => (
            <div key={h.season} className="card row" style={{ gap: 12 }}>
              <LeagueBadge league={h.league} size={38} />
              <div className="grow stack tight">
                <strong>{h.name} de {h.year}</strong>
                <span className="small muted num">{plural(h.points, 'ponto', 'pontos')}{h.of && h.of > 1 ? ` · ${h.rank}º de ${h.of} amigos` : ''}</span>
              </div>
              {h.xp > 0 && <span className="pill accent num">+{h.xp} XP</span>}
            </div>
          ))}
        </section>
      )}
    </div>
  );
}

export function RankingScreen() {
  const [params, setParams] = useSearchParams();
  const group = params.get('grupo');
  const category = (RANKING_CATEGORIES.some((c) => c.id === params.get('por')) ? params.get('por') : 'pontos') as RankingCategory;
  const [groups, setGroups] = useState<GroupSummary[]>([]);
  const [r, setR] = useState<Ranking | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [locked, setLocked] = useState(false);

  useEffect(() => { api.groups().then(setGroups).catch(() => setGroups([])); }, []);
  const load = useCallback(() => {
    setError(null); setR(null);
    api.ranking(group ? 'grupo' : 'amigos', group, category).then(setR)
      .catch((e) => (isPremiumError(e) ? setLocked(true) : setError(friendlyError(e))));
  }, [group, category]);
  useEffect(load, [load]);

  const set = (next: { grupo?: string | null; por?: string }) => {
    const p: Record<string, string> = {};
    const g = next.grupo !== undefined ? next.grupo : group;
    const c = next.por ?? category;
    if (g) p.grupo = g;
    if (c !== 'pontos') p.por = c;
    setParams(p, { replace: true });
  };
  const cat = RANKING_CATEGORIES.find((c) => c.id === category)!;

  if (locked) return <div className="screen"><BackButton to="/social" /><h1>Ranking</h1><PremiumLock what="O ranking" /></div>;
  return (
    <div className="screen">
      <BackButton to="/social/temporada" />
      <div className="stack tight">
        <h1>Ranking</h1>
        {r && <span className="small muted">{r.season.name} · {plural(r.season.days_left, 'dia restante', 'dias restantes')}</span>}
      </div>

      <div className="chips" role="group" aria-label="Quem aparece">
        <button className="chip" aria-pressed={!group} onClick={() => set({ grupo: null })}>Amigos</button>
        {groups.map((g) => <button key={g.id} className="chip" aria-pressed={group === g.id} onClick={() => set({ grupo: g.id })}>{g.name}</button>)}
      </div>
      <div className="seg" role="group" aria-label="Critério">
        {RANKING_CATEGORIES.map((c) => <button key={c.id} aria-pressed={category === c.id} onClick={() => set({ por: c.id })}>{c.label}</button>)}
      </div>

      {error ? <ErrorState message={error} onRetry={load} /> : !r ? <><Skeleton height={60} /><Skeleton height={60} /><Skeleton height={60} /></> : (
        <>
          <div className="scoreboard">
            {r.rows.map((row) => (
              <Link key={row.user.id} to={row.me ? '/social/temporada' : `/social/amigos/${row.user.id}`} className={`score-row ${row.me ? 'me' : ''}`}>
                <span className={`score-rank r${row.rank}`}>{row.rank}</span>
                <PersonAvatar person={row.user} size={38} />
                <span className="grow stack" style={{ gap: 0, minWidth: 0 }}>
                  <span className="ellipsis">{row.me ? 'Você' : row.user.name || 'Sem nome'}</span>
                  {row.level !== null && <span className="small faint">Nível {row.level}</span>}
                </span>
                <LeagueBadge league={row.league} size={26} />
                <span className="score-value" style={{ minWidth: 56 }}>{row.value.toLocaleString('pt-BR')} <span className="small muted">{row.value === 1 ? cat.unit[0] : cat.unit[1]}</span></span>
              </Link>
            ))}
          </div>
          {r.rows.length <= 1 && (
            <div className="card stack center" style={{ alignItems: 'center' }}>
              <span className="small muted">{group ? 'Chame mais gente para o grupo.' : 'Adicione amigos para comparar a constância de vocês.'}</span>
              <Link to={group ? `/social/grupos/${group}` : '/social/adicionar'} className="btn sm">{group ? 'Convidar para o grupo' : 'Adicionar amigo'}</Link>
            </div>
          )}
          {r.rows.some((x) => x.me && x.hidden) && (
            <span className="small faint">Você escolheu não aparecer no ranking: só você se vê aqui. Dá para mudar em <Link to="/social/privacidade">Privacidade</Link>.</span>
          )}
          <span className="small faint">Quem escolheu não aparecer no ranking fica de fora. Pontos e constância vêm só de missões confirmadas no servidor.</span>
        </>
      )}
    </div>
  );
}
