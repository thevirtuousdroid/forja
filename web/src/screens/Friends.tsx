import { useCallback, useEffect, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { api, friendlyError } from '../lib/api';
import { useApp } from '../lib/AppData';
import type { Attribute, CodeLookup, FriendProfile, Privacy, SocialInfo, SocialNotification } from '../lib/types';
import {
  CHEERS, DIRECT_CHEERS, PRIVACY_OPTIONS, copyText, friendLink, notificationText, plural, prettyCode, relativeTime, shareOrCopy,
} from '../lib/social';
import { ATTRIBUTES, ATTRIBUTE_KEYS } from '../lib/game';
import { formatDay } from '../lib/dates';
import { Badge } from '../components/Badge';
import { LeagueBadge, PersonAvatar, PersonRow, Sheet, Toggle } from '../components/Social';
import { BackButton, Empty, ErrorState, Skeleton } from '../components/ui';
import { IconCopy, IconShare } from '../components/Icons';
import { useFeedback } from '../components/Feedback';

// ── Adicionar amigo (também abre pelo link /amigo/CODIGO) ──────────────────

export function AddFriendScreen() {
  const { code: linkCode } = useParams();
  const nav = useNavigate();
  const { toast } = useFeedback();
  const { loadEvents } = useApp();
  const [info, setInfo] = useState<SocialInfo | null>(null);
  const [code, setCode] = useState(linkCode ? prettyCode(linkCode.toUpperCase()) : '');
  const [found, setFound] = useState<CodeLookup | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => { api.social().then(setInfo).catch(() => setInfo(null)); }, []);

  const lookup = useCallback(async (c: string) => {
    setError(null); setFound(null);
    if (c.replace(/[^0-9A-Za-z]/g, '').length !== 6) { setError('O código tem 6 caracteres.'); return; }
    setBusy(true);
    try { setFound(await api.lookupCode(c)); } catch (e) { setError(friendlyError(e)); } finally { setBusy(false); }
  }, []);

  useEffect(() => {
    if (!linkCode) return;
    setCode(prettyCode(linkCode.toUpperCase()));
    void lookup(linkCode);
  }, [linkCode, lookup]);

  async function send() {
    setBusy(true);
    try {
      const r = await api.sendFriendRequest(code);
      if (r.status === 'aceita') {
        toast(`Agora você e ${r.name || 'essa pessoa'} são amigos.`);
        void loadEvents();
        nav('/social?aba=amigos');
      } else {
        toast(`Pedido enviado para ${r.name || 'essa pessoa'}.`);
        setFound((f) => (f ? { ...f, status: 'pedido_enviado' } : f));
      }
    } catch (e) {
      toast(friendlyError(e), 'error');
    } finally {
      setBusy(false);
    }
  }

  async function shareMine() {
    if (!info) return;
    const r = await shareOrCopy(`Vamos evoluir juntos na Forja? Meu código é ${prettyCode(info.me.friend_code)}.`, friendLink(info.me.friend_code));
    if (r === 'copied') toast('Convite copiado. É só colar na conversa.');
  }
  async function copyMine() {
    if (info && await copyText(info.me.friend_code)) toast('Código copiado.');
  }

  return (
    <div className="screen">
      <BackButton to="/social?aba=amigos" />
      <h1>Adicionar amigo</h1>

      <div className="card stack">
        <h3>Código de um amigo</h3>
        <form className="row" onSubmit={(e) => { e.preventDefault(); void lookup(code); }}>
          <input className="input code-input grow" value={code} maxLength={7} placeholder="ABC-123" aria-label="Código de amizade"
                 autoCapitalize="characters" autoCorrect="off" spellCheck={false}
                 onChange={(e) => { setCode(e.target.value.toUpperCase()); setFound(null); setError(null); }} />
          <button className="btn" disabled={busy}>Buscar</button>
        </form>
        {error && <span className="small" role="alert" style={{ color: 'var(--danger)' }}>{error}</span>}
        {found && (
          <div className="stack">
            <PersonRow person={found} sub={
              found.status === 'amigos' ? 'Vocês já são amigos'
                : found.status === 'pedido_enviado' ? 'Pedido enviado, esperando resposta'
                : found.status === 'pedido_recebido' ? 'Essa pessoa já mandou um pedido para você'
                : found.accepts ? 'Encontrado' : 'Não está recebendo pedidos agora'} />
            {found.status === 'nenhum' && found.accepts && (
              <button className="btn primary block" disabled={busy} onClick={send}>{busy ? 'Enviando…' : 'Enviar pedido de amizade'}</button>
            )}
            {found.status === 'pedido_recebido' && (
              <button className="btn primary block" disabled={busy} onClick={send}>Aceitar e virar amigos</button>
            )}
          </div>
        )}
      </div>

      <div className="card stack center" style={{ alignItems: 'center' }}>
        <h3>Seu código</h3>
        {info ? <span className="code-box">{prettyCode(info.me.friend_code)}</span> : <Skeleton height={48} />}
        <span className="small muted">Quem tiver seu código ou link pode mandar um pedido. Você aceita ou não.</span>
        <div className="row" style={{ width: '100%' }}>
          <button className="btn grow" onClick={copyMine} disabled={!info}><IconCopy /> Copiar</button>
          <button className="btn primary grow" onClick={shareMine} disabled={!info}><IconShare /> Enviar link</button>
        </div>
      </div>
      <Link to="/social/privacidade" className="link small center">Privacidade e código</Link>
    </div>
  );
}

// ── Avisos sociais ──────────────────────────────────────────────────────────

export function NotificationsScreen() {
  const { toast } = useFeedback();
  const { setSocialUnseen, loadEvents } = useApp();
  const [items, setItems] = useState<SocialNotification[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState<number | null>(null);

  const load = useCallback(() => {
    setError(null);
    api.notifications().then((r) => {
      setItems(r.items);
      const unseen = r.items.filter((i) => !i.seen).map((i) => i.id);
      if (unseen.length) api.markEventsSeen(unseen).then(() => setSocialUnseen(0)).catch(() => {});
      else setSocialUnseen(0);
    }).catch((e) => setError(friendlyError(e)));
  }, [setSocialUnseen]);
  useEffect(load, [load]);

  async function respond(n: SocialNotification, accept: boolean) {
    if (n.kind !== 'pedido_amizade') return;
    setBusy(n.id);
    try {
      await api.respondFriendRequest(n.data.request_id, accept);
      toast(accept ? `Agora você e ${n.data.user.name || 'essa pessoa'} são amigos.` : 'Pedido recusado.');
      void loadEvents();
      load();
    } catch (e) {
      toast(friendlyError(e), 'error');
    } finally {
      setBusy(null);
    }
  }

  if (error) return <div className="screen"><BackButton to="/social" /><ErrorState message={error} onRetry={load} /></div>;
  return (
    <div className="screen">
      <BackButton to="/social" />
      <h1>Avisos</h1>
      {!items ? <><Skeleton /><Skeleton /></> : items.length === 0 ? (
        <Empty title="Nada por aqui">
          <span className="small">Pedidos de amizade, incentivos e convites para desafios aparecem aqui.</span>
        </Empty>
      ) : (
        <div className="stack tight">
          {items.map((n) => {
            const user = n.data.user;
            let right = null;
            let to: string | undefined;
            if (n.kind === 'pedido_amizade' && n.data.status === 'pendente') {
              right = (
                <div className="stack tight">
                  <button className="btn sm primary" disabled={busy === n.id} onClick={() => respond(n, true)}>Aceitar</button>
                  <button className="btn sm ghost" disabled={busy === n.id} onClick={() => respond(n, false)}>Recusar</button>
                </div>
              );
            } else if (n.kind === 'desafio_convite') {
              to = `/social/desafios/${n.data.challenge.id}`;
            } else if (n.kind === 'grupo_entrada') {
              to = `/social/grupos/${n.data.group.id}`;
            } else if (n.kind === 'amizade_aceita' || (n.kind === 'pedido_amizade' && n.data.status === 'aceita')) {
              to = `/social/amigos/${user.id}`;
            }
            return (
              <PersonRow key={n.id} person={user} to={to} right={right}
                sub={<><span style={{ color: 'var(--text)' }}>{notificationText(n)}</span> <span className="faint">· {relativeTime(n.created_at)}</span>
                  {!n.seen && <span className="pill accent" style={{ marginLeft: 6 }}>novo</span>}</>} />
            );
          })}
        </div>
      )}
    </div>
  );
}

// ── Perfil de um amigo (ou colega de grupo) ────────────────────────────────

function CompareRow({ label, mine, theirs, max }: { label: string; mine: number; theirs: number; max: number }) {
  return (
    <>
      <div className="bar-l" aria-hidden><span style={{ width: `${(theirs / max) * 100}%` }} /></div>
      <div className="label"><span className="num">{theirs}</span> {label} <span className="num">{mine}</span></div>
      <div className="bar-r" aria-hidden><span style={{ width: `${(mine / max) * 100}%` }} /></div>
    </>
  );
}

export function FriendProfileScreen() {
  const { id } = useParams();
  const nav = useNavigate();
  const { toast } = useFeedback();
  const { loadEvents } = useApp();
  const [p, setP] = useState<FriendProfile | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [sheet, setSheet] = useState<'cheer' | 'remove' | null>(null);
  const [busy, setBusy] = useState(false);

  const load = useCallback(() => {
    setError(null);
    api.friendProfile(id!).then(setP).catch((e) => setError(friendlyError(e)));
  }, [id]);
  useEffect(load, [load]);

  if (error) return <div className="screen"><BackButton /><ErrorState message={error} onRetry={load} /></div>;
  if (!p) return <div className="screen"><BackButton /><Skeleton height={220} /><Skeleton height={160} /></div>;

  const c = p.card;
  const name = c.name || 'Sem nome';

  async function cheer(kind: (typeof DIRECT_CHEERS)[number]) {
    setBusy(true);
    try {
      await api.cheer(null, c.id, kind);
      toast(`${CHEERS[kind].emoji} enviado para ${name}.`);
      setSheet(null);
      void loadEvents();
    } catch (e) {
      toast(friendlyError(e), 'error');
    } finally {
      setBusy(false);
    }
  }
  async function remove() {
    setBusy(true);
    try {
      await api.removeFriend(c.id);
      toast('Amizade desfeita.');
      nav('/social?aba=amigos');
    } catch (e) {
      toast(friendlyError(e), 'error');
    } finally {
      setBusy(false);
    }
  }

  const attrMax = p.attributes && p.my_attributes
    ? Math.max(1, ...ATTRIBUTE_KEYS.map((k) => Math.max(p.attributes![k], p.my_attributes![k]))) : 1;

  return (
    <div className="screen">
      <BackButton />
      <div className="card hero stack center" style={{ alignItems: 'center' }}>
        <PersonAvatar person={c} size={150} />
        <h2>{name}</h2>
        {c.title && <span className="pill accent">{c.title}</span>}
        <span className="small muted">
          {p.relation === 'amigo' ? `Amizade desde ${p.since ? formatDay(p.since.slice(0, 10), { day: 'numeric', month: 'long' }) : 'há pouco'}`
            : p.relation === 'grupo' ? `Do grupo ${p.groups_in_common.map((g) => g.name).join(', ')}` : 'Você'}
        </span>
      </div>

      <div className="stat-grid four">
        <div className="stat"><div className="small muted">Nível</div><div className="num">{c.level ?? '–'}</div></div>
        <div className="stat"><div className="small muted">Sequência</div><div className="num">{c.streak ?? '–'}</div></div>
        <div className="stat"><div className="small muted">Conquistas</div><div className="num">{c.achievements ?? '–'}</div></div>
        <div className="stat"><div className="small muted">Chefes</div><div className="num">{p.bosses ?? '–'}</div></div>
      </div>
      {(!p.privacy.nivel || !p.privacy.sequencia || !p.privacy.conquistas) && (
        <span className="small faint">{name} preferiu não mostrar algumas informações.</span>
      )}

      {p.week && (
        <div className="card stack tight">
          <div className="row between"><h3>Últimos dias</h3>{c.today?.met && <span className="pill ok">meta de hoje ✓</span>}</div>
          <div className="week-dots" aria-label="Últimos 7 dias">
            {p.week.map((d) => <i key={d.date} className={d.status} title={`${formatDay(d.date)}: ${d.status}`} />)}
          </div>
          {p.consistency !== null && p.consistency !== undefined && <span className="small faint">Consistência geral: {p.consistency}%</span>}
        </div>
      )}

      {p.season && p.my_season && (
        <div className="card row" style={{ gap: 12 }}>
          <LeagueBadge league={p.season.league.id} size={46} />
          <div className="grow stack tight">
            <strong>Liga {p.season.league.name} · <span className="num">{plural(p.season.points, 'ponto', 'pontos')}</span></strong>
            <span className="small muted num">Você: liga {p.my_season.league.name}, {plural(p.my_season.points, 'ponto', 'pontos')}</span>
          </div>
        </div>
      )}

      {p.attributes && p.my_attributes && (
        <div className="card stack">
          <div className="row between small"><strong>{name}</strong><h3>Atributos</h3><strong>Você</strong></div>
          <div className="compare">
            {ATTRIBUTE_KEYS.map((k: Attribute) => (
              <CompareRow key={k} label={ATTRIBUTES[k].label} theirs={p.attributes![k]} mine={p.my_attributes![k]} max={attrMax} />
            ))}
          </div>
          <span className="small faint">Nível de cada atributo. Cada um evolui no seu ritmo.</span>
        </div>
      )}

      {p.achievements && p.achievements.length > 0 && (
        <div className="card stack">
          <h3>Conquistas recentes</h3>
          <div className="grid-3">
            {p.achievements.slice(0, 6).map((a) => (
              <div key={a.id} className="badge-cell" style={{ cursor: 'default' }}>
                <Badge category={a.category} rarity={a.rarity} size={52} />
                <span className="name">{a.name}</span>
              </div>
            ))}
          </div>
        </div>
      )}

      {p.relation !== 'eu' && (
        <div className="stack tight">
          {p.relation === 'amigo' && <button className="btn primary block" onClick={() => setSheet('cheer')}>Mandar incentivo</button>}
          {p.relation === 'amigo' && <Link to={`/social/desafios/novo?amigo=${c.id}`} className="btn block">Desafiar {name.split(' ')[0]}</Link>}
          {p.relation === 'amigo' && <button className="btn ghost danger block" onClick={() => setSheet('remove')}>Desfazer amizade</button>}
        </div>
      )}

      {sheet === 'cheer' && (
        <Sheet title={`Incentivo para ${name}`} onClose={() => setSheet(null)}>
          <span className="small muted">Um por dia para cada amigo. A pessoa recebe um aviso.</span>
          <div className="stack tight">
            {DIRECT_CHEERS.map((k) => (
              <button key={k} className="choice" disabled={busy} onClick={() => cheer(k)}>
                <span aria-hidden style={{ marginRight: 8 }}>{CHEERS[k].emoji}</span>{CHEERS[k].label}
              </button>
            ))}
          </div>
        </Sheet>
      )}
      {sheet === 'remove' && (
        <Sheet title="Desfazer amizade?" onClose={() => setSheet(null)}>
          <p className="muted">Vocês deixam de ver o progresso um do outro. Nada do que cada um conquistou é perdido.</p>
          <div className="row">
            <button className="btn ghost grow" onClick={() => setSheet(null)}>Cancelar</button>
            <button className="btn danger grow" disabled={busy} onClick={remove}>Desfazer</button>
          </div>
        </Sheet>
      )}
    </div>
  );
}

// ── Privacidade ─────────────────────────────────────────────────────────────

export function PrivacyScreen() {
  const { toast } = useFeedback();
  const [info, setInfo] = useState<SocialInfo | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [confirmReset, setConfirmReset] = useState(false);

  const load = useCallback(() => {
    setError(null);
    api.social().then(setInfo).catch((e) => setError(friendlyError(e)));
  }, []);
  useEffect(load, [load]);

  async function set(key: keyof Privacy, value: boolean) {
    if (!info) return;
    const prev = info;
    setInfo({ ...info, me: { ...info.me, privacy: { ...info.me.privacy, [key]: value } } });
    try {
      await api.updatePrivacy({ [key]: value });
    } catch (e) {
      setInfo(prev);
      toast(friendlyError(e), 'error');
    }
  }
  async function resetCode() {
    try {
      const r = await api.resetFriendCode();
      setInfo((i) => (i ? { ...i, me: { ...i.me, friend_code: r.friend_code } } : i));
      setConfirmReset(false);
      toast('Código novo criado. O antigo parou de funcionar.');
    } catch (e) {
      toast(friendlyError(e), 'error');
    }
  }

  if (error) return <div className="screen"><BackButton /><ErrorState message={error} onRetry={load} /></div>;
  return (
    <div className="screen">
      <BackButton />
      <h1>Privacidade</h1>
      <p className="small muted">Só amigos e pessoas dos seus grupos veem o seu perfil. Seu diário, suas anotações e os detalhes dos seus hábitos nunca são mostrados.</p>
      {!info ? <Skeleton height={400} /> : (
        <>
          <div className="card" style={{ paddingBlock: 4 }}>
            {PRIVACY_OPTIONS.map((o) => (
              <Toggle key={o.id} label={o.label} desc={o.desc} checked={info.me.privacy[o.id]} onChange={(v) => set(o.id, v)} />
            ))}
          </div>
          <div className="card stack">
            <h3>Seu código de amizade</h3>
            <span className="code-box">{prettyCode(info.me.friend_code)}</span>
            <button className="btn" onClick={() => setConfirmReset(true)}>Gerar código novo</button>
          </div>
        </>
      )}
      {confirmReset && (
        <Sheet title="Gerar código novo?" onClose={() => setConfirmReset(false)}>
          <p className="muted">Links e códigos que você já mandou param de funcionar. Suas amizades continuam iguais.</p>
          <div className="row">
            <button className="btn ghost grow" onClick={() => setConfirmReset(false)}>Cancelar</button>
            <button className="btn primary grow" onClick={resetCode}>Gerar</button>
          </div>
        </Sheet>
      )}
    </div>
  );
}
