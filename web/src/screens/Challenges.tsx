import { useCallback, useEffect, useMemo, useState } from 'react';
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom';
import { api, friendlyError } from '../lib/api';
import { useApp } from '../lib/AppData';
import type { Challenge, ChallengeKind, ChallengeMetric, Dimension, FriendCard, GroupSummary, NewChallenge } from '../lib/types';
import { CHALLENGE_KINDS, METRICS, metricLabel, metricUnit, plural, collectiveLeft } from '../lib/social';
import { DIMENSIONS, areasFor } from '../lib/game';
import { formatDay } from '../lib/dates';
import { PersonAvatar, Sheet } from '../components/Social';
import { BackButton, Empty, ErrorState, Skeleton } from '../components/ui';
import { useFeedback } from '../components/Feedback';
import { ChallengeCard } from './Social';

export function ChallengesScreen() {
  const [list, setList] = useState<Challenge[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const load = useCallback(() => {
    setError(null);
    api.challenges().then(setList).catch((e) => setError(friendlyError(e)));
  }, []);
  useEffect(load, [load]);

  if (error) return <div className="screen"><BackButton to="/social" /><ErrorState message={error} onRetry={load} /></div>;
  const invites = list?.filter((c) => c.my_status === 'convidado' && c.status === 'ativo') ?? [];
  const running = list?.filter((c) => c.my_status === 'aceito' && c.status === 'ativo') ?? [];
  const past = list?.filter((c) => c.status !== 'ativo' || (c.my_status !== 'aceito' && c.my_status !== 'convidado')) ?? [];

  return (
    <div className="screen">
      <BackButton to="/social" />
      <div className="row between">
        <h1>Desafios</h1>
        <Link to="/social/desafios/novo" className="btn sm primary">Criar</Link>
      </div>
      <p className="small muted">Desafios contam o que você já faz no seu plano: não há missões extras. Cada um vale no seu próprio fuso e no seu próprio modo.</p>
      {!list ? <><Skeleton /><Skeleton /></> : list.length === 0 ? (
        <Empty title="Nenhum desafio ainda">
          <span className="small">Chame amigos para ver quem cumpre mais a meta numa semana, ou combinem uma meta coletiva.</span>
          <Link to="/social/desafios/novo" className="btn sm">Criar desafio</Link>
        </Empty>
      ) : (
        <>
          {invites.length > 0 && <section className="stack tight"><h3>Convites</h3>{invites.map((c) => <ChallengeCard key={c.id} c={c} />)}</section>}
          {running.length > 0 && <section className="stack tight"><h3>Em andamento</h3>{running.map((c) => <ChallengeCard key={c.id} c={c} />)}</section>}
          {past.length > 0 && <section className="stack tight"><h3>Anteriores</h3>{past.map((c) => <ChallengeCard key={c.id} c={c} />)}</section>}
        </>
      )}
    </div>
  );
}

const DURATIONS = [3, 5, 7, 14, 21, 30];

export function NewChallengeScreen() {
  const [params] = useSearchParams();
  const nav = useNavigate();
  const { profile } = useApp();
  const { toast } = useFeedback();
  const [friends, setFriends] = useState<FriendCard[] | null>(null);
  const [groups, setGroups] = useState<GroupSummary[] | null>(null);
  const [kind, setKind] = useState<ChallengeKind>('competitivo');
  const [metric, setMetric] = useState<ChallengeMetric>('meta_diaria');
  const [dimension, setDimension] = useState<Dimension>('fisica');
  const [days, setDays] = useState(7);
  const [tomorrow, setTomorrow] = useState(false);
  const [who, setWho] = useState<'amigos' | 'grupo'>(params.get('grupo') ? 'grupo' : 'amigos');
  const [picked, setPicked] = useState<Set<string>>(new Set(params.get('amigo') ? [params.get('amigo')!] : []));
  const [group, setGroup] = useState<string | null>(params.get('grupo'));
  const [target, setTarget] = useState<number | null>(null);
  const [title, setTitle] = useState('');
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    api.social().then((s) => setFriends(s.friends)).catch(() => setFriends([]));
    api.groups().then(setGroups).catch(() => setGroups([]));
  }, []);

  const people = who === 'grupo' ? (groups?.find((g) => g.id === group)?.members ?? 0) : picked.size + 1;
  const cap = metric === 'missoes' ? 12 : 1;
  const maxTarget = days * Math.max(people, 2) * cap;
  const suggested = Math.max(1, Math.round(days * Math.max(people, 2) * (metric === 'missoes' ? 3 : metric === 'meta_diaria' ? 0.7 : 0.6)));
  const goal = Math.min(target ?? suggested, maxTarget);
  const autoTitle = useMemo(() => {
    const m = metric === 'area' ? `${DIMENSIONS[dimension].short}` : metric === 'missoes' ? 'Missões' : 'Meta do dia';
    return `${m}: ${days} dias${kind === 'coletivo' ? ' juntos' : ''}`;
  }, [metric, dimension, days, kind]);

  const ready = who === 'grupo' ? !!group && people >= 2 : picked.size >= 1;

  async function create() {
    setBusy(true);
    const body: NewChallenge = {
      kind, metric, days, start_tomorrow: tomorrow, title: title.trim() || autoTitle,
      ...(metric === 'area' ? { dimension } : {}),
      ...(who === 'grupo' ? { group_id: group! } : { friends: [...picked] }),
      ...(kind === 'coletivo' ? { target: goal } : {}),
    };
    try {
      const r = await api.createChallenge(body);
      toast('Desafio criado. Os convites foram enviados.');
      nav(`/social/desafios/${r.id}`, { replace: true });
    } catch (e) {
      toast(friendlyError(e), 'error');
      setBusy(false);
    }
  }

  return (
    <div className="screen">
      <BackButton />
      <h1>Novo desafio</h1>

      <section className="stack tight">
        <h3>Tipo</h3>
        <div className="seg">
          {(['competitivo', 'coletivo'] as ChallengeKind[]).map((k) => (
            <button key={k} aria-pressed={kind === k} onClick={() => setKind(k)}>{CHALLENGE_KINDS[k].label}</button>
          ))}
        </div>
        <span className="small muted">{CHALLENGE_KINDS[kind].desc}</span>
      </section>

      <section className="stack tight">
        <h3>O que conta</h3>
        <div className="choice-grid one">
          {(Object.keys(METRICS) as ChallengeMetric[]).map((m) => (
            <button key={m} className="choice" aria-pressed={metric === m} onClick={() => setMetric(m)}>
              <strong>{METRICS[m].label}</strong><br /><span className="small muted">{METRICS[m].desc}</span>
            </button>
          ))}
        </div>
        {metric === 'area' && (
          <div className="chips" role="group" aria-label="Área">
            {areasFor(profile?.sagrado).map((d) => <button key={d} className="chip" aria-pressed={dimension === d} onClick={() => setDimension(d)}>{DIMENSIONS[d].short}</button>)}
          </div>
        )}
      </section>

      <section className="stack tight">
        <h3>Duração</h3>
        <div className="chips">
          {DURATIONS.map((d) => <button key={d} className="chip" aria-pressed={days === d} onClick={() => setDays(d)}>{d} dias</button>)}
        </div>
        <div className="seg">
          <button aria-pressed={!tomorrow} onClick={() => setTomorrow(false)}>Começa hoje</button>
          <button aria-pressed={tomorrow} onClick={() => setTomorrow(true)}>Começa amanhã</button>
        </div>
      </section>

      <section className="stack tight">
        <h3>Com quem</h3>
        <div className="seg">
          <button aria-pressed={who === 'amigos'} onClick={() => setWho('amigos')}>Amigos</button>
          <button aria-pressed={who === 'grupo'} onClick={() => setWho('grupo')}>Um grupo</button>
        </div>
        {who === 'amigos' ? (
          friends === null ? <Skeleton /> : friends.length === 0 ? (
            <span className="small muted">Você ainda não tem amigos na Forja. <Link to="/social/adicionar">Adicionar amigo</Link></span>
          ) : (
            <div className="stack tight">
              {friends.map((f) => (
                <label key={f.id} className="person-row" style={{ cursor: 'pointer' }}>
                  <PersonAvatar person={f} size={36} />
                  <span className="grow ellipsis">{f.name || 'Sem nome'}</span>
                  <input type="checkbox" className="switch" checked={picked.has(f.id)} aria-label={`Convidar ${f.name}`}
                         onChange={(e) => setPicked((s) => { const n = new Set(s); if (e.target.checked) n.add(f.id); else n.delete(f.id); return n; })} />
                </label>
              ))}
            </div>
          )
        ) : (
          groups === null ? <Skeleton /> : groups.length === 0 ? (
            <span className="small muted">Você não está em nenhum grupo. <Link to="/social?aba=grupos">Ver grupos</Link></span>
          ) : (
            <div className="choice-grid one">
              {groups.map((g) => (
                <button key={g.id} className="choice" aria-pressed={group === g.id} onClick={() => setGroup(g.id)}>
                  <strong>{g.name}</strong> <span className="small muted">· {plural(g.members, 'pessoa', 'pessoas')}</span>
                </button>
              ))}
            </div>
          )
        )}
      </section>

      {kind === 'coletivo' && (
        <section className="stack tight">
          <h3>Meta coletiva</h3>
          <div className="row">
            <button className="btn sm" onClick={() => setTarget(Math.max(1, goal - (metric === 'missoes' ? 5 : 1)))} aria-label="Diminuir">−</button>
            <span className="grow center num" style={{ fontSize: 26, fontWeight: 700 }}>{goal}</span>
            <button className="btn sm" onClick={() => setTarget(Math.min(maxTarget, goal + (metric === 'missoes' ? 5 : 1)))} aria-label="Aumentar">+</button>
          </div>
          <span className="small muted center">{metricUnit(metric, goal)} somando todo mundo · sugestão: {suggested}</span>
        </section>
      )}

      <div className="field">
        <label htmlFor="ch-title">Nome (opcional)</label>
        <input id="ch-title" className="input" value={title} maxLength={50} placeholder={autoTitle} onChange={(e) => setTitle(e.target.value)} />
      </div>

      <button className="btn primary block" disabled={busy || !ready} onClick={create}>{busy ? 'Criando…' : 'Criar e convidar'}</button>
      <span className="small faint center">Vencer (ou bater a meta coletiva) rende XP para no máximo 2 desafios por semana, para ninguém criar desafios só pelo XP.</span>
    </div>
  );
}

export function ChallengeDetailScreen() {
  const { id } = useParams();
  const nav = useNavigate();
  const { toast } = useFeedback();
  const { loadEvents } = useApp();
  const [c, setC] = useState<Challenge | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [confirm, setConfirm] = useState<'leave' | 'cancel' | null>(null);

  const load = useCallback(() => {
    setError(null);
    api.challenge(id!).then(setC).catch((e) => setError(friendlyError(e)));
  }, [id]);
  useEffect(load, [load]);

  async function act(fn: () => Promise<unknown>, msg: string, back = false) {
    setBusy(true);
    try {
      await fn(); toast(msg); setConfirm(null);
      void loadEvents();
      if (back) nav('/social/desafios'); else load();
    } catch (e) {
      toast(friendlyError(e), 'error');
    } finally {
      setBusy(false);
    }
  }

  if (error) return <div className="screen"><BackButton to="/social/desafios" /><ErrorState message={error} onRetry={load} /></div>;
  if (!c) return <div className="screen"><BackButton to="/social/desafios" /><Skeleton height={140} /><Skeleton height={220} /></div>;

  const accepted = c.participants.filter((p) => p.status === 'aceito');
  const invited = c.participants.filter((p) => p.status === 'convidado');
  const ended = c.status !== 'ativo';
  const unit = (n: number) => metricUnit(c.metric, n);
  const sorted = [...accepted].sort((a, b) => b.score - a.score);
  let lastScore = -1; let lastRank = 0;
  const ranks = sorted.map((p, i) => { if (p.score !== lastScore) { lastRank = i + 1; lastScore = p.score; } return p.rank ?? lastRank; });

  return (
    <div className="screen">
      <BackButton to="/social/desafios" />
      <div className="stack tight">
        <span className="tiny muted">{c.kind === 'coletivo' ? 'Desafio coletivo' : 'Desafio competitivo'}{c.group ? ` · ${c.group.name}` : ''}</span>
        <h1>{c.title}</h1>
        <span className="small muted">
          {metricLabel(c.metric, c.dimension)} · {formatDay(c.starts_on)} a {formatDay(c.ends_on)}
          {c.phase === 'em_andamento' ? ` · dia ${c.day_index} de ${c.days}` : c.phase === 'agendado' ? ' · começa em breve'
            : c.status === 'cancelado' ? ' · cancelado' : ended ? ' · encerrado' : ' · encerrando'}
        </span>
        <span className="small faint">Criado por {c.is_creator ? 'você' : c.creator.name || 'alguém'}.</span>
      </div>

      {c.my_status === 'convidado' && !ended && (
        <div className="card stack">
          <strong>Você foi convidado</strong>
          <span className="small muted">{METRICS[c.metric].desc}</span>
          <div className="row">
            <button className="btn ghost grow" disabled={busy} onClick={() => act(() => api.respondChallenge(c.id, false), 'Convite recusado.')}>Recusar</button>
            <button className="btn primary grow" disabled={busy} onClick={() => act(() => api.respondChallenge(c.id, true), 'Você entrou no desafio.')}>Aceitar</button>
          </div>
        </div>
      )}

      {ended && c.my_result && (
        <div className="card hero stack center" style={{ alignItems: 'center' }}>
          <strong style={{ fontSize: 18 }}>
            {c.my_result === 'venceu' ? 'Você venceu!' : c.my_result === 'meta_coletiva' ? 'Meta coletiva batida!' : 'Desafio encerrado'}
          </strong>
          {c.my_xp ? <span className="pill accent num">+{c.my_xp} XP</span> : c.my_result !== 'participou'
            ? <span className="small faint">Sem XP desta vez: já foram 2 recompensas de desafio nesta semana.</span> : null}
        </div>
      )}

      {c.kind === 'coletivo' && c.target ? (
        <div className="card stack">
          <div className="row between"><h3>Juntos</h3><span className="num">{c.total} / {c.target}</span></div>
          <div className="bar"><span style={{ width: `${Math.min(1, c.total / c.target) * 100}%` }} /></div>
          <span className="small muted">
            {c.total >= c.target ? 'Meta alcançada!' : collectiveLeft(c.metric, c.target - c.total)} Quem contribuir com pelo menos 1 ganha 30 XP se a meta for batida.
          </span>
        </div>
      ) : null}

      <section className="stack tight">
        <h3>{c.kind === 'coletivo' ? 'Contribuições' : 'Placar'}</h3>
        {accepted.length === 0 ? <span className="small muted">Ninguém aceitou ainda.</span> : (
          <div className="scoreboard">
            {sorted.map((p, i) => (
              <Link key={p.user.id} to={p.me ? '/personagem' : `/social/amigos/${p.user.id}`} className={`score-row ${p.me ? 'me' : ''}`}>
                <span className={`score-rank r${ranks[i]}`}>{c.kind === 'competitivo' ? ranks[i] : '•'}</span>
                <PersonAvatar person={p.user} size={36} />
                <span className="grow ellipsis">{p.me ? 'Você' : p.user.name || 'Sem nome'}{p.result === 'venceu' ? ' 🏆' : ''}</span>
                <span className="score-value">{p.score} <span className="small muted">{unit(p.score)}</span></span>
              </Link>
            ))}
          </div>
        )}
        {invited.length > 0 && <span className="small faint">Esperando resposta: {invited.map((p) => (p.me ? 'você' : p.user.name || 'alguém')).join(', ')}.</span>}
      </section>

      <div className="card stack tight">
        <h3>Regras</h3>
        <span className="small muted">{METRICS[c.metric].desc}</span>
        <span className="small muted">
          {c.kind === 'competitivo'
            ? 'Quem tiver mais no fim vence e ganha 40 XP (empates vencem juntos).'
            : 'Se a soma de todos chegar à meta, cada participante que contribuiu ganha 30 XP.'}
        </span>
        <span className="small faint">O resultado sai no primeiro acesso depois do último dia. Desafios também valem pontos na temporada.</span>
      </div>

      {!ended && c.my_status === 'aceito' && !c.is_creator && (
        <button className="btn ghost danger" onClick={() => setConfirm('leave')}>Sair do desafio</button>
      )}
      {!ended && c.is_creator && <button className="btn ghost danger" onClick={() => setConfirm('cancel')}>Cancelar desafio</button>}

      {confirm && (
        <Sheet title={confirm === 'cancel' ? 'Cancelar desafio?' : 'Sair do desafio?'} onClose={() => setConfirm(null)}>
          <p className="muted">{confirm === 'cancel' ? 'O desafio acaba para todos, sem resultado e sem XP.' : 'Seu placar deixa de contar. O desafio continua para os outros.'}</p>
          <div className="row">
            <button className="btn ghost grow" onClick={() => setConfirm(null)}>Voltar</button>
            <button className="btn danger grow" disabled={busy}
                    onClick={() => confirm === 'cancel'
                      ? act(() => api.cancelChallenge(c.id), 'Desafio cancelado.', true)
                      : act(() => api.leaveChallenge(c.id), 'Você saiu do desafio.', true)}>
              {confirm === 'cancel' ? 'Cancelar desafio' : 'Sair'}
            </button>
          </div>
        </Sheet>
      )}
    </div>
  );
}
