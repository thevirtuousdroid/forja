import { useCallback, useEffect, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { api, friendlyError } from '../lib/api';
import type { GroupDetail, GroupMember } from '../lib/types';
import { groupLink, plural, shareOrCopy } from '../lib/social';
import { PersonRow, Sheet } from '../components/Social';
import { BackButton, ErrorState, Skeleton } from '../components/ui';
import { IconShare } from '../components/Icons';
import { useFeedback } from '../components/Feedback';
import { ChallengeCard } from './Social';

export function GroupDetailScreen() {
  const { id } = useParams();
  const nav = useNavigate();
  const { toast } = useFeedback();
  const [g, setG] = useState<GroupDetail | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [sheet, setSheet] = useState<'leave' | 'edit' | 'code' | { member: GroupMember } | null>(null);
  const [name, setName] = useState('');
  const [desc, setDesc] = useState('');
  const [busy, setBusy] = useState(false);

  const load = useCallback(() => {
    setError(null);
    api.group(id!).then((d) => { setG(d); setName(d.name); setDesc(d.description); }).catch((e) => setError(friendlyError(e)));
  }, [id]);
  useEffect(load, [load]);

  if (error) return <div className="screen"><BackButton to="/social?aba=grupos" /><ErrorState message={error} onRetry={load} /></div>;
  if (!g) return <div className="screen"><BackButton to="/social?aba=grupos" /><Skeleton height={120} /><Skeleton height={240} /></div>;
  const owner = g.role === 'dono';

  async function run(fn: () => Promise<unknown>, done: string, after?: () => void) {
    setBusy(true);
    try { await fn(); toast(done); setSheet(null); after ? after() : load(); } catch (e) { toast(friendlyError(e), 'error'); } finally { setBusy(false); }
  }
  async function share() {
    const r = await shareOrCopy(`Entre no grupo "${g!.name}" na Forja. Código: ${g!.invite_code}.`, groupLink(g!.invite_code));
    if (r === 'copied') toast('Convite copiado. É só colar na conversa.');
  }

  return (
    <div className="screen">
      <BackButton to="/social?aba=grupos" />
      <div className="stack tight">
        <h1>{g.name}</h1>
        {g.description && <p className="muted">{g.description}</p>}
        <span className="small faint">{plural(g.members.length, 'pessoa', 'pessoas')} · criado por {owner ? 'você' : g.owner.name || 'alguém'}</span>
      </div>

      <div className="card stack">
        <div className="row between">
          <div className="stack tight">
            <span className="small muted">Código do grupo</span>
            <span className="num" style={{ fontSize: 22, fontWeight: 700, letterSpacing: '.12em' }}>{g.invite_code}</span>
          </div>
          <button className="btn sm primary" onClick={share}><IconShare /> Convidar</button>
        </div>
        <span className="small faint">Qualquer pessoa com o código entra no grupo, mesmo sem ser sua amiga. Até 30 pessoas.</span>
      </div>

      <div className="grid-2">
        <Link to={`/social/ranking?grupo=${g.id}`} className="tile"><span className="small muted">Ranking</span><strong>Do grupo</strong></Link>
        <Link to={`/social/desafios/novo?grupo=${g.id}`} className="tile"><span className="small muted">Desafio</span><strong>Para o grupo</strong></Link>
      </div>

      {g.challenges.length > 0 && (
        <section className="stack tight">
          <h3>Desafios do grupo</h3>
          {g.challenges.map((c) => <ChallengeCard key={c.id} c={c} />)}
        </section>
      )}

      <section className="stack tight">
        <h3>Pessoas</h3>
        {g.members.map((m) => (
          <PersonRow key={m.id} person={m} to={`/social/amigos/${m.id}`}
            sub={[m.role === 'dono' ? 'Criou o grupo' : null, m.level ? `Nível ${m.level}` : null,
                  m.streak !== undefined ? `🔥 ${plural(m.streak, 'dia', 'dias')}` : null].filter(Boolean).join(' · ') || 'Perfil reservado'}
            right={owner && m.role !== 'dono'
              ? <button className="btn sm ghost" onClick={(e) => { e.preventDefault(); setSheet({ member: m }); }}>Remover</button>
              : m.today?.met ? <span className="pill ok">✓ hoje</span> : null} />
        ))}
      </section>

      <div className="stack tight">
        {owner && <button className="btn" onClick={() => setSheet('edit')}>Editar grupo</button>}
        {owner && <button className="btn ghost" onClick={() => setSheet('code')}>Gerar código novo</button>}
        <button className="btn ghost danger" onClick={() => setSheet('leave')}>Sair do grupo</button>
      </div>

      {sheet === 'leave' && (
        <Sheet title="Sair do grupo?" onClose={() => setSheet(null)}>
          <p className="muted">
            {owner && g.members.length > 1 ? 'A pessoa que está há mais tempo no grupo vira a responsável. '
              : owner ? 'Você é a única pessoa no grupo: ele será apagado. ' : ''}
            Você pode voltar depois com o código.
          </p>
          <div className="row">
            <button className="btn ghost grow" onClick={() => setSheet(null)}>Cancelar</button>
            <button className="btn danger grow" disabled={busy}
                    onClick={() => run(() => api.leaveGroup(g.id), 'Você saiu do grupo.', () => nav('/social?aba=grupos'))}>Sair</button>
          </div>
        </Sheet>
      )}
      {sheet === 'edit' && (
        <Sheet title="Editar grupo" onClose={() => setSheet(null)}>
          <div className="field"><label htmlFor="ge-name">Nome</label>
            <input id="ge-name" className="input" value={name} maxLength={40} onChange={(e) => setName(e.target.value)} /></div>
          <div className="field"><label htmlFor="ge-desc">Descrição</label>
            <input id="ge-desc" className="input" value={desc} maxLength={140} onChange={(e) => setDesc(e.target.value)} /></div>
          <button className="btn primary block" disabled={busy || name.trim().length < 2}
                  onClick={() => run(() => api.updateGroup(g.id, name, desc), 'Grupo atualizado.')}>Salvar</button>
        </Sheet>
      )}
      {sheet === 'code' && (
        <Sheet title="Gerar código novo?" onClose={() => setSheet(null)}>
          <p className="muted">O código atual para de funcionar. Quem já está no grupo continua.</p>
          <button className="btn primary block" disabled={busy}
                  onClick={() => run(() => api.resetGroupCode(g.id), 'Código novo criado.')}>Gerar</button>
        </Sheet>
      )}
      {sheet && typeof sheet === 'object' && (
        <Sheet title={`Remover ${sheet.member.name || 'pessoa'}?`} onClose={() => setSheet(null)}>
          <p className="muted">A pessoa sai do grupo e pode voltar só com um código novo.</p>
          <div className="row">
            <button className="btn ghost grow" onClick={() => setSheet(null)}>Cancelar</button>
            <button className="btn danger grow" disabled={busy}
                    onClick={() => run(() => api.removeMember(g.id, sheet.member.id), 'Pessoa removida do grupo.')}>Remover</button>
          </div>
        </Sheet>
      )}
    </div>
  );
}

/** Link de convite /grupo/CODIGO: confirma e entra. */
export function GroupJoinScreen() {
  const { code } = useParams();
  const nav = useNavigate();
  const { toast } = useFeedback();
  const [busy, setBusy] = useState(false);

  async function join() {
    setBusy(true);
    try {
      const g = await api.joinGroup(code!);
      toast(g.already ? `Você já está em ${g.name}.` : `Você entrou em ${g.name}.`);
      nav(`/social/grupos/${g.id}`, { replace: true });
    } catch (e) {
      toast(friendlyError(e), 'error');
      setBusy(false);
    }
  }

  return (
    <div className="screen">
      <BackButton to="/social?aba=grupos" />
      <h1>Convite para um grupo</h1>
      <div className="card stack center" style={{ alignItems: 'center' }}>
        <span className="small muted">Código do grupo</span>
        <span className="code-box">{(code ?? '').toUpperCase()}</span>
        <span className="small muted">No grupo, todos veem o ranking e podem criar desafios coletivos. Seu perfil segue as suas escolhas de privacidade.</span>
        <button className="btn primary block" disabled={busy} onClick={join}>{busy ? 'Entrando…' : 'Entrar no grupo'}</button>
      </div>
    </div>
  );
}
