import { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { api, friendlyError } from '../lib/api';
import { useApp } from '../lib/AppData';
import type { SagradoState } from '../lib/types';
import { attributeProgress, formatTarget } from '../lib/game';
import { BackButton, ErrorState, Skeleton } from '../components/ui';
import { useFeedback } from '../components/Feedback';

const INVITE_OFF = 'forja.sagrado.convite';

/** Caminho Sagrado: práticas espirituais que fazem crescer o atributo Sagrado (dedicação entregue a Deus). */
export function SagradoScreen() {
  const nav = useNavigate();
  const { toast } = useFeedback();
  const { refresh, loadEvents } = useApp();
  const [s, setS] = useState<SagradoState | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pick, setPick] = useState<string[]>([]);
  const [busy, setBusy] = useState(false);
  const [editing, setEditing] = useState(false);

  function load() {
    setError(null);
    api.getSagrado()
      .then((r) => {
        setS(r);
        const active = r.practices.filter((p) => p.active).map((p) => p.id);
        setPick(active.length ? active : ['esp_devocional', 'esp_biblia', 'esp_gratidao']);
      })
      .catch((e) => setError(friendlyError(e)));
  }
  useEffect(load, []);

  async function save(enabled: boolean) {
    setBusy(true);
    try {
      const r = await api.setSagrado(enabled, enabled ? pick : []);
      setS(r);
      setEditing(false);
      try { localStorage.setItem(INVITE_OFF, 'off'); } catch { /* ok */ }
      await refresh();
      loadEvents();
      toast(enabled ? 'Caminho Sagrado ativado. As práticas já estão nas missões de hoje.' : 'Caminho Sagrado pausado. Seu nível de Sagrado continua guardado.');
      if (enabled && !s?.enabled) nav('/missoes');
    } catch (e) {
      toast(friendlyError(e), 'error');
    } finally {
      setBusy(false);
    }
  }

  if (error) return <div className="screen"><BackButton to="/personagem/atributos" /><ErrorState message={error} onRetry={load} /></div>;
  if (!s) return <div className="screen"><BackButton to="/personagem/atributos" /><Skeleton height={180} /><Skeleton height={300} /></div>;

  const prog = attributeProgress(s.xp);
  const choosing = !s.enabled || editing;
  const toggle = (id: string) => setPick((p) => (p.includes(id) ? p.filter((x) => x !== id) : [...p, id]));

  return (
    <div className="screen">
      <BackButton to="/personagem/atributos" />
      <div className="card hero stack sagrado-hero">
        <span className="tag-mono">Caminho Sagrado</span>
        <h1>Buscar a Deus acima de todas as coisas</h1>
        <p className="muted">
          Práticas diárias de devoção que entram nas suas missões. Cada uma faz crescer o <strong>Sagrado</strong>,
          o atributo que mostra o quanto de dedicação você tem entregado a Deus.
        </p>
        {(s.enabled || s.xp > 0) && (
          <div className="stack tight">
            <div className="row between">
              <strong style={{ color: 'var(--attr-sagrado)', fontSize: 17 }}>Sagrado</strong>
              <span className="num">Nível {prog.level}</span>
            </div>
            <div className="bar"><span style={{ width: `${prog.ratio * 100}%`, background: 'var(--attr-sagrado)' }} /></div>
            <div className="row between small faint num">
              <span>{s.xp.toLocaleString('pt-BR')} XP</span>
              <span>{s.days} {s.days === 1 ? 'dia' : 'dias'} de prática</span>
            </div>
            {s.enabled && s.today_total > 0 && (
              <span className="small">Hoje: <span className="num">{s.today_done} de {s.today_total}</span> práticas</span>
            )}
          </div>
        )}
      </div>

      <section className="stack tight">
        <h2>{choosing ? 'Escolha suas práticas' : 'Suas práticas'}</h2>
        {choosing && <p className="small muted">Comece com poucas. Dá para mudar quando quiser.</p>}
        <div className="stack tight">
          {s.practices.map((p) => {
            const on = choosing ? pick.includes(p.id) : p.active;
            if (!choosing && !on) return null;
            return (
              <button key={p.id} type="button" className={`card practice ${on ? 'on' : ''}`} disabled={!choosing}
                      aria-pressed={choosing ? on : undefined} onClick={() => choosing && toggle(p.id)}>
                <span className="practice-check" aria-hidden>{on ? '✓' : ''}</span>
                <span className="stack tight grow" style={{ textAlign: 'left' }}>
                  <span className="row between">
                    <strong>{p.name}</strong>
                    <span className="small faint num">{formatTarget(p.target ?? p.base_value, p.unit)}</span>
                  </span>
                  <span className="small muted">{p.description}</span>
                </span>
              </button>
            );
          })}
        </div>
      </section>

      {choosing ? (
        <div className="stack tight">
          <button className="btn primary block" disabled={busy || pick.length === 0} onClick={() => save(true)}>
            {s.enabled ? 'Salvar práticas' : 'Ativar o Caminho Sagrado'}
          </button>
          {editing && <button className="btn ghost block" disabled={busy} onClick={() => { setEditing(false); load(); }}>Cancelar</button>}
        </div>
      ) : (
        <div className="stack tight">
          <Link to="/missoes" className="btn primary block">Ver as práticas de hoje</Link>
          <button className="btn block" onClick={() => setEditing(true)}>Mudar práticas</button>
          <button className="btn ghost block" disabled={busy} onClick={() => save(false)}>Pausar o Caminho Sagrado</button>
        </div>
      )}

      <ul className="small faint stack tight" style={{ paddingLeft: 18, margin: 0 }}>
        <li>As práticas seguem as regras das outras missões: metas sobem aos poucos e você confirma cada uma.</li>
        <li>Pausar não apaga nada: o nível de Sagrado e as conquistas continuam com você.</li>
        <li>Seus amigos só veem o Sagrado se você ativar, e só se seus atributos estiverem visíveis.</li>
      </ul>
    </div>
  );
}

/** Convite discreto no Início para quem ainda não conhece o Caminho Sagrado. */
export function SagradoPrompt() {
  const { profile } = useApp();
  const [off, setOff] = useState(() => {
    try { return localStorage.getItem(INVITE_OFF) === 'off'; } catch { return false; }
  });
  if (off || !profile || profile.sagrado || profile.sagrado === undefined) return null;
  function dismiss() {
    try { localStorage.setItem(INVITE_OFF, 'off'); } catch { /* ok */ }
    setOff(true);
  }
  return (
    <div className="notice sagrado-notice" role="region" aria-label="Caminho Sagrado">
      <span className="sagrado-mark" aria-hidden>✦</span>
      <span className="grow small"><strong>Caminho Sagrado</strong> · devocional, Bíblia, louvor e gratidão a Deus nas suas missões</span>
      <div className="stack tight" style={{ alignItems: 'flex-end' }}>
        <Link to="/sagrado" className="btn sm">Conhecer</Link>
        <button className="link small" onClick={dismiss}>Agora não</button>
      </div>
    </div>
  );
}
