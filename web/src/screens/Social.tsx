import { useCallback, useEffect, useState } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import { api, friendlyError, isPremiumError } from '../lib/api';
import { useApp } from '../lib/AppData';
import type { Challenge, CheerKind, FeedPost, GroupSummary, SeasonInfo, SocialInfo } from '../lib/types';
import { CHEERS, REACTIONS, metricLabel, metricUnit, plural, postText, prettyCode, relativeTime, friendLink, shareOrCopy } from '../lib/social';
import { formatDay } from '../lib/dates';
import { RARITY } from '../lib/rpg';
import { Badge } from '../components/Badge';
import { BossArt } from '../components/BossArt';
import { LeagueBadge, PersonAvatar, PersonRow, Sheet } from '../components/Social';
import { Empty, ErrorState, Skeleton } from '../components/ui';
import { IconBell, IconChevronRight, IconShare, IconSwords, IconTrash } from '../components/Icons';
import { useFeedback } from '../components/Feedback';

type Tab = 'feed' | 'amigos' | 'grupos';

export function SocialScreen() {
  const { socialUnseen } = useApp();
  const [params, setParams] = useSearchParams();
  const tab = (['feed', 'amigos', 'grupos'].includes(params.get('aba') ?? '') ? params.get('aba') : 'feed') as Tab;
  const [season, setSeason] = useState<SeasonInfo | 'locked' | null>(null);
  const [challenges, setChallenges] = useState<Challenge[] | null>(null);

  useEffect(() => {
    api.season().then(setSeason).catch((e) => setSeason(isPremiumError(e) ? 'locked' : null));
    api.challenges().then(setChallenges).catch(() => setChallenges([]));
  }, []);

  const invites = challenges?.filter((c) => c.my_status === 'convidado' && c.status === 'ativo' && c.phase !== 'encerrando') ?? [];
  const active = challenges?.filter((c) => c.my_status === 'aceito' && c.status === 'ativo') ?? [];

  return (
    <div className="screen">
      <div className="row between">
        <h1>Social</h1>
        <div className="row" style={{ gap: 8 }}>
          <Link to="/social/avisos" className="icon-btn" aria-label={socialUnseen ? `Avisos, ${socialUnseen} novos` : 'Avisos'}>
            <IconBell />{socialUnseen > 0 && <span className="dot-count num">{socialUnseen > 9 ? '9+' : socialUnseen}</span>}
          </Link>
          <Link to="/social/adicionar" className="btn sm primary">Adicionar amigo</Link>
        </div>
      </div>

      {season && season !== 'locked' && (
        <Link to="/social/temporada" className="card hero row" style={{ color: 'inherit', textDecoration: 'none', gap: 14 }}>
          <LeagueBadge league={season.league.id} size={58} />
          <div className="grow stack tight">
            <span className="tiny muted">{season.name} · {plural(season.days_left, 'dia restante', 'dias restantes')}</span>
            <strong style={{ fontSize: 18 }}>Liga {season.league.name}</strong>
            <span className="small muted num">
              {plural(season.points, 'ponto', 'pontos')}{season.next ? ` · faltam ${season.next.min_points - season.points} para ${season.next.name}` : ' · liga máxima'}
            </span>
          </div>
          <IconChevronRight />
        </Link>
      )}

      <Link to="/social/desafios" className="card row between" style={{ color: 'inherit', textDecoration: 'none' }}>
        <span className="row" style={{ gap: 10 }}>
          <IconSwords />
          <span className="stack" style={{ gap: 2 }}>
            <strong>Desafios</strong>
            <span className="small muted">
              {challenges === null ? 'Carregando…'
                : invites.length > 0 ? `${plural(invites.length, 'convite esperando', 'convites esperando')} resposta`
                : active.length > 0 ? `${plural(active.length, 'desafio em andamento', 'desafios em andamento')}`
                : 'Desafie amigos ou combine uma meta em grupo'}
            </span>
          </span>
        </span>
        {invites.length > 0 ? <span className="pill accent">{invites.length}</span> : <IconChevronRight />}
      </Link>

      <div className="seg" role="tablist" aria-label="Seções do social">
        {(['feed', 'amigos', 'grupos'] as Tab[]).map((t) => (
          <button key={t} role="tab" aria-pressed={tab === t} onClick={() => setParams(t === 'feed' ? {} : { aba: t }, { replace: true })}>
            {t === 'feed' ? 'Feed' : t === 'amigos' ? 'Amigos' : 'Grupos'}
          </button>
        ))}
      </div>

      {tab === 'feed' && <FeedList />}
      {tab === 'amigos' && <FriendsList />}
      {tab === 'grupos' && <GroupsList />}
    </div>
  );
}

// ── Feed ────────────────────────────────────────────────────────────────────

function PostVisual({ post }: { post: FeedPost }) {
  switch (post.kind) {
    case 'conquista':
      return (
        <div className="post-body">
          <Badge category={post.data.category} rarity={post.data.rarity} size={56} />
          <div className="grow stack tight">
            <strong>{post.data.name}</strong>
            <span className="small muted">{post.data.description}</span>
            <span className="small" style={{ color: RARITY[post.data.rarity].color }}>{RARITY[post.data.rarity].label}</span>
          </div>
        </div>
      );
    case 'chefe':
      return (
        <div className="post-body">
          <BossArt id={post.data.boss_id} size={64} defeated damage={1} />
          <div className="grow stack tight">
            <strong>{post.data.name}</strong>
            <span className="small muted">{post.data.epithet} · {plural(post.data.days, 'dia', 'dias')} de batalha</span>
          </div>
        </div>
      );
    case 'nivel':
      return (
        <div className="post-body">
          <span className="post-level num">{post.data.level}</span>
          <span className="small muted">Novo nível alcançado com missões cumpridas de verdade.</span>
        </div>
      );
    case 'temporada':
      return (
        <div className="post-body">
          <LeagueBadge league={post.data.league} size={56} />
          <div className="grow stack tight">
            <strong>Liga {post.data.league_name}</strong>
            <span className="small muted num">{plural(post.data.points, 'ponto', 'pontos')} na {post.data.name.replace('Temporada', 'temporada')}</span>
          </div>
        </div>
      );
  }
}

function PostCard({ post, onChange, onDelete }: { post: FeedPost; onChange: (p: FeedPost) => void; onDelete: (id: number) => void }) {
  const { toast } = useFeedback();
  const { loadEvents } = useApp();
  const [busy, setBusy] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);

  async function react(kind: CheerKind) {
    if (busy || post.mine) return;
    setBusy(true);
    const prev = post;
    // Atualização otimista: troca, adiciona ou tira a reação
    const cheers = { ...post.cheers };
    if (post.my_cheer) cheers[post.my_cheer] = Math.max(0, (cheers[post.my_cheer] ?? 1) - 1);
    const next = post.my_cheer === kind ? null : kind;
    if (next) cheers[next] = (cheers[next] ?? 0) + 1;
    onChange({ ...post, cheers, my_cheer: next });
    try {
      await api.cheer(post.id, null, kind);
      void loadEvents();
    } catch (e) {
      onChange(prev);
      toast(friendlyError(e), 'error');
    } finally {
      setBusy(false);
    }
  }

  async function remove() {
    try {
      await api.deletePost(post.id);
      onDelete(post.id);
    } catch (e) {
      toast(friendlyError(e), 'error');
    }
  }

  const total = Object.values(post.cheers).reduce((n, c) => n + (c ?? 0), 0);
  return (
    <article className="post">
      <div className="post-head">
        <PersonAvatar person={post.author} size={40} />
        <div className="grow small" style={{ minWidth: 0 }}>
          <strong>{post.mine ? 'Você' : post.author.name || 'Sem nome'}</strong> <span className="muted">{postText(post)}</span>
          <div className="faint">{relativeTime(post.created_at)}</div>
        </div>
        {post.mine && (
          <button className="icon-btn" aria-label="Apagar publicação" onClick={() => setConfirmDelete(true)}><IconTrash /></button>
        )}
      </div>
      <PostVisual post={post} />
      {post.mine ? (
        <span className="small faint">
          {total === 0 ? 'Ainda sem reações.' : `${post.cheerers.map((c) => c.name || 'Alguém').slice(0, 3).join(', ')}${post.cheerers.length > 3 ? ' e outros' : ''} reagiram: `}
          {REACTIONS.filter((k) => post.cheers[k]).map((k) => `${CHEERS[k].emoji} ${post.cheers[k]}`).join('  ')}
        </span>
      ) : (
        <div className="reactions" role="group" aria-label="Reagir">
          {REACTIONS.map((k) => (
            <button key={k} className="reaction" aria-pressed={post.my_cheer === k} disabled={busy} onClick={() => react(k)}
                    aria-label={`${CHEERS[k].label}${post.cheers[k] ? `, ${post.cheers[k]}` : ''}`}>
              <span aria-hidden>{CHEERS[k].emoji}</span>{post.cheers[k] ? <span className="num">{post.cheers[k]}</span> : null}
            </button>
          ))}
        </div>
      )}
      {confirmDelete && (
        <Sheet title="Apagar publicação?" onClose={() => setConfirmDelete(false)}>
          <p className="muted">Ela some do feed dos seus amigos. A conquista continua sua.</p>
          <div className="row">
            <button className="btn ghost grow" onClick={() => setConfirmDelete(false)}>Cancelar</button>
            <button className="btn danger grow" onClick={() => { setConfirmDelete(false); void remove(); }}>Apagar</button>
          </div>
        </Sheet>
      )}
    </article>
  );
}

function FeedList() {
  const [posts, setPosts] = useState<FeedPost[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [more, setMore] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);

  const load = useCallback(() => {
    setError(null);
    api.feed().then((p) => { setPosts(p); setMore(p.length === 30); }).catch((e) => setError(friendlyError(e)));
  }, []);
  useEffect(load, [load]);

  async function loadMore() {
    if (!posts?.length) return;
    setLoadingMore(true);
    try {
      const p = await api.feed(posts[posts.length - 1].id);
      setPosts([...posts, ...p]); setMore(p.length === 30);
    } catch { /* tenta de novo no próximo toque */ } finally {
      setLoadingMore(false);
    }
  }

  if (error) return <ErrorState message={error} onRetry={load} />;
  if (!posts) return <><Skeleton height={150} /><Skeleton height={150} /></>;
  if (posts.length === 0) {
    return (
      <Empty title="Seu feed aparece aqui">
        <span className="small">Conquistas, vitórias sobre chefes, níveis e temporadas seus e dos seus amigos.</span>
        <Link to="/social/adicionar" className="btn sm">Adicionar amigo</Link>
      </Empty>
    );
  }
  return (
    <div className="stack">
      {posts.map((p) => (
        <PostCard key={p.id} post={p}
                  onChange={(np) => setPosts((ps) => ps?.map((x) => (x.id === np.id ? np : x)) ?? ps)}
                  onDelete={(id) => setPosts((ps) => ps?.filter((x) => x.id !== id) ?? ps)} />
      ))}
      {more && <button className="btn ghost" onClick={loadMore} disabled={loadingMore}>{loadingMore ? 'Carregando…' : 'Ver mais'}</button>}
    </div>
  );
}

// ── Amigos ──────────────────────────────────────────────────────────────────

function FriendsList() {
  const { toast } = useFeedback();
  const { setSocialUnseen, loadEvents } = useApp();
  const [info, setInfo] = useState<SocialInfo | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);

  const load = useCallback(() => {
    setError(null);
    api.social().then((s) => { setInfo(s); setSocialUnseen(s.unseen); }).catch((e) => setError(friendlyError(e)));
  }, [setSocialUnseen]);
  useEffect(load, [load]);

  async function respond(id: string, accept: boolean) {
    setBusy(id);
    try {
      await api.respondFriendRequest(id, accept);
      toast(accept ? 'Agora vocês são amigos.' : 'Pedido recusado.');
      load();
      void loadEvents();
    } catch (e) {
      toast(friendlyError(e), 'error');
    } finally {
      setBusy(null);
    }
  }
  async function cancel(userId: string) {
    setBusy(userId);
    try { await api.removeFriend(userId); load(); } catch (e) { toast(friendlyError(e), 'error'); } finally { setBusy(null); }
  }
  async function share() {
    if (!info) return;
    const r = await shareOrCopy(`Vamos evoluir juntos na Forja? Meu código é ${prettyCode(info.me.friend_code)}.`, friendLink(info.me.friend_code));
    if (r === 'copied') toast('Convite copiado. É só colar na conversa.');
  }

  if (error) return <ErrorState message={error} onRetry={load} />;
  if (!info) return <><Skeleton /><Skeleton /></>;

  return (
    <div className="stack">
      {info.incoming.length > 0 && (
        <section className="stack tight">
          <h3>Pedidos de amizade</h3>
          {info.incoming.map((r) => (
            <PersonRow key={r.id} person={r.user} sub={relativeTime(r.created_at)} right={
              <div className="row" style={{ gap: 6 }}>
                <button className="btn sm ghost" disabled={busy === r.id} onClick={() => respond(r.id, false)}>Recusar</button>
                <button className="btn sm primary" disabled={busy === r.id} onClick={() => respond(r.id, true)}>Aceitar</button>
              </div>
            } />
          ))}
        </section>
      )}

      {info.friends.length === 0 ? (
        <div className="card stack center" style={{ alignItems: 'center' }}>
          <strong>Chame seus amigos</strong>
          <span className="small muted">Mande seu código ou o link. Quando a pessoa aceitar, vocês veem o progresso um do outro e podem se desafiar.</span>
          <span className="code-box">{prettyCode(info.me.friend_code)}</span>
          <button className="btn sm" onClick={share}><IconShare /> Mandar convite</button>
        </div>
      ) : (
        <section className="stack tight">
          <div className="row between"><h3>Amigos</h3><span className="small faint num">{info.friends.length}/{info.limits.friends}</span></div>
          {info.friends.map((f) => (
            <PersonRow key={f.id} person={f} to={`/social/amigos/${f.id}`}
              sub={[f.level ? `Nível ${f.level}` : null, f.streak !== undefined ? `🔥 ${plural(f.streak, 'dia', 'dias')}` : null].filter(Boolean).join(' · ') || 'Perfil reservado'}
              right={f.today?.met ? <span className="pill ok">meta de hoje ✓</span> : <IconChevronRight />} />
          ))}
        </section>
      )}

      {info.outgoing.length > 0 && (
        <section className="stack tight">
          <h3>Pedidos enviados</h3>
          {info.outgoing.map((r) => (
            <PersonRow key={r.id} person={r.user} sub={`Enviado ${relativeTime(r.created_at)}`}
                       right={<button className="btn sm ghost" disabled={busy === r.user.id} onClick={() => cancel(r.user.id)}>Cancelar</button>} />
          ))}
        </section>
      )}

      <Link to="/social/privacidade" className="link small center">Privacidade: o que seus amigos veem</Link>
    </div>
  );
}

// ── Grupos ──────────────────────────────────────────────────────────────────

function GroupsList() {
  const nav = useNavigate();
  const { toast } = useFeedback();
  const [groups, setGroups] = useState<GroupSummary[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);
  const [name, setName] = useState('');
  const [desc, setDesc] = useState('');
  const [code, setCode] = useState('');
  const [busy, setBusy] = useState(false);

  const load = useCallback(() => {
    setError(null);
    api.groups().then(setGroups).catch((e) => setError(friendlyError(e)));
  }, []);
  useEffect(load, [load]);

  async function create() {
    setBusy(true);
    try {
      const g = await api.createGroup(name, desc);
      nav(`/social/grupos/${g.id}`);
    } catch (e) {
      toast(friendlyError(e), 'error');
    } finally {
      setBusy(false);
    }
  }
  async function join() {
    setBusy(true);
    try {
      const g = await api.joinGroup(code);
      toast(g.already ? `Você já está em ${g.name}.` : `Você entrou em ${g.name}.`);
      nav(`/social/grupos/${g.id}`);
    } catch (e) {
      toast(friendlyError(e), 'error');
    } finally {
      setBusy(false);
    }
  }

  if (error) return <ErrorState message={error} onRetry={load} />;
  if (!groups) return <Skeleton />;
  return (
    <div className="stack">
      {groups.length === 0 && (
        <Empty title="Nenhum grupo ainda">
          <span className="small">Grupos têm ranking próprio e desafios coletivos. Crie um para a família, a turma ou o time.</span>
        </Empty>
      )}
      {groups.map((g) => (
        <Link key={g.id} to={`/social/grupos/${g.id}`} className="card stack tight" style={{ color: 'inherit', textDecoration: 'none' }}>
          <div className="row between">
            <strong className="ellipsis">{g.name}</strong>
            {g.role === 'dono' ? <span className="pill accent">Você criou</span> : <IconChevronRight />}
          </div>
          {g.description && <span className="small muted">{g.description}</span>}
          <div className="row" style={{ gap: 0 }}>
            {g.preview.map((p, i) => <span key={p.id} style={{ marginLeft: i ? -10 : 0 }}><PersonAvatar person={p} size={30} /></span>)}
            <span className="small faint" style={{ marginLeft: 8 }}>{plural(g.members, 'pessoa', 'pessoas')}</span>
          </div>
        </Link>
      ))}
      <div className="card stack">
        <h3>Entrar com código</h3>
        <div className="row">
          <input className="input code-input grow" value={code} maxLength={9} placeholder="ABC1234" aria-label="Código do grupo"
                 onChange={(e) => setCode(e.target.value.toUpperCase())} />
          <button className="btn" disabled={busy || code.replace(/[^0-9A-Z]/g, '').length < 7} onClick={join}>Entrar</button>
        </div>
      </div>
      <button className="btn block" onClick={() => setCreating(true)}>Criar grupo</button>
      {creating && (
        <Sheet title="Novo grupo" onClose={() => setCreating(false)}>
          <div className="field">
            <label htmlFor="gname">Nome</label>
            <input id="gname" className="input" value={name} maxLength={40} onChange={(e) => setName(e.target.value)} placeholder="Ex.: Família na Forja" />
          </div>
          <div className="field">
            <label htmlFor="gdesc">Descrição (opcional)</label>
            <input id="gdesc" className="input" value={desc} maxLength={140} onChange={(e) => setDesc(e.target.value)} />
          </div>
          <button className="btn primary block" disabled={busy || name.trim().length < 2} onClick={create}>{busy ? 'Criando…' : 'Criar grupo'}</button>
        </Sheet>
      )}
    </div>
  );
}

export function ChallengeCard({ c }: { c: Challenge }) {
  const me = c.participants.find((p) => p.me);
  const accepted = c.participants.filter((p) => p.status === 'aceito');
  const leader = [...accepted].sort((a, b) => b.score - a.score)[0];
  return (
    <Link to={`/social/desafios/${c.id}`} className="card stack tight" style={{ color: 'inherit', textDecoration: 'none' }}>
      <div className="row between">
        <strong className="ellipsis">{c.title}</strong>
        <span className={`pill ${c.my_status === 'convidado' && c.status === 'ativo' ? 'accent' : ''}`}>
          {c.my_status === 'convidado' && c.status === 'ativo' ? 'Convite'
            : c.phase === 'agendado' ? 'Começa amanhã' : c.phase === 'em_andamento' ? `Dia ${c.day_index} de ${c.days}`
            : c.phase === 'encerrando' ? 'Encerrando' : c.status === 'cancelado' ? 'Cancelado' : 'Encerrado'}
        </span>
      </div>
      <span className="small muted">
        {c.kind === 'coletivo' ? 'Coletivo' : 'Competitivo'} · {metricLabel(c.metric, c.dimension)}{c.group ? ` · ${c.group.name}` : ''}
      </span>
      {c.kind === 'coletivo' && c.target ? (
        <div className="stack tight">
          <div className="bar thin"><span style={{ width: `${Math.min(1, c.total / c.target) * 100}%` }} /></div>
          <span className="small faint num">{c.total} de {c.target}</span>
        </div>
      ) : c.phase === 'agendado' ? (
        <span className="small faint">Começa {formatDay(c.starts_on, { weekday: 'long', day: 'numeric', month: 'short' })}</span>
      ) : me && leader ? (
        <span className="small faint num">
          Você: {me.score} {metricUnit(c.metric, me.score)}
          {c.status !== 'ativo'
            ? (me.rank ? ` · ${me.rank}º de ${accepted.length}` : '')
            : leader.me ? ' · você lidera' : ` · na frente: ${leader.user.name || 'alguém'} com ${leader.score}`}
        </span>
      ) : null}
      {c.my_result && c.status === 'encerrado' && (
        <span className="small" style={{ color: c.my_result === 'participou' ? 'var(--text-2)' : 'var(--ok)' }}>
          {c.my_result === 'venceu' ? 'Você venceu' : c.my_result === 'meta_coletiva' ? 'Meta coletiva batida' : 'Você participou'}
          {c.my_xp ? ` · +${c.my_xp} XP` : ''}
        </span>
      )}
    </Link>
  );
}
