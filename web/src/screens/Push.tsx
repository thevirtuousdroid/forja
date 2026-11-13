// Notificações no celular: ativar neste aparelho, horários dos lembretes e avisos dos amigos.
import { useCallback, useEffect, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { api, friendlyError } from '../lib/api';
import { useApp } from '../lib/AppData';
import type { NotifyInfo, NotifySettings } from '../lib/types';
import { currentSubscription, disablePush, enablePush, isIOS, pushState, type PushState } from '../lib/push';
import { relativeTime } from '../lib/social';
import { useFeedback } from '../components/Feedback';
import { BackButton, ErrorState, Skeleton } from '../components/ui';
import { Toggle } from '../components/Social';
import { IconBell } from '../components/Icons';

const PROMPT_OFF = 'forja.push.prompt';

/** Horário com pequena espera antes de salvar (a roda do iPhone muda o valor várias vezes). */
function TimeField({ label, value, disabled, onSave }: { label: string; value: string; disabled?: boolean; onSave: (v: string) => void }) {
  const [v, setV] = useState(value);
  useEffect(() => setV(value), [value]);
  useEffect(() => {
    if (v === value || !/^\d{2}:\d{2}$/.test(v)) return;
    const t = setTimeout(() => onSave(v), 700);
    return () => clearTimeout(t);
  }, [v]); // eslint-disable-line react-hooks/exhaustive-deps
  return (
    <label className="row between small" style={{ padding: '4px 0 10px' }}>
      <span className="muted">{label}</span>
      <input type="time" className="input" style={{ width: 'auto', minWidth: 110 }} min="05:00" max="23:30" step={300}
             value={v} disabled={disabled} onChange={(e) => setV(e.target.value)} aria-label={label} />
    </label>
  );
}

function DeviceHelp({ state }: { state: PushState }) {
  if (state === 'install') {
    return (
      <div className="card stack">
        <h3>Instale o app para receber notificações</h3>
        <span className="small muted">No iPhone, as notificações só funcionam com a Forja na tela de início:</span>
        <ol className="small muted" style={{ margin: 0, paddingLeft: 18 }}>
          <li>Abra este endereço no <strong>Safari</strong>.</li>
          <li>Toque em <strong>Compartilhar</strong> (quadrado com seta para cima).</li>
          <li>Escolha <strong>Adicionar à Tela de Início</strong>.</li>
          <li>Abra a Forja <strong>pelo ícone</strong> e volte a esta tela.</li>
        </ol>
        <span className="small faint">Precisa do iOS 16.4 ou mais novo.</span>
      </div>
    );
  }
  if (state === 'unsupported') {
    return (
      <div className="card stack">
        <h3>Este navegador não recebe notificações</h3>
        <span className="small muted">
          {isIOS() ? 'Atualize o iPhone para o iOS 16.4 ou mais novo e abra a Forja pelo ícone da tela de início.'
                   : 'Use o Chrome, o Edge, o Firefox ou o Safari atualizados.'}
        </span>
      </div>
    );
  }
  return (
    <div className="card stack">
      <h3>Notificações bloqueadas</h3>
      <span className="small muted">
        {isIOS() ? <>Para liberar: <strong>Ajustes</strong> do iPhone → <strong>Notificações</strong> → <strong>Forja</strong> → <strong>Permitir Notificações</strong>. Depois, volte aqui.</>
                 : 'Libere as notificações deste site nas configurações do navegador e volte aqui.'}
      </span>
    </div>
  );
}

export function PushSettingsScreen() {
  const { profile } = useApp();
  const { toast } = useFeedback();
  const [info, setInfo] = useState<NotifyInfo | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [state, setState] = useState<PushState>(() => pushState());
  const [endpoint, setEndpoint] = useState<string | null | undefined>(undefined);
  const [busy, setBusy] = useState(false);
  const polls = useRef(0);

  const load = useCallback(async () => {
    try {
      setInfo(await api.notify());
      setError(null);
    } catch (e) {
      setError(friendlyError(e));
    }
  }, []);

  const checkDevice = useCallback(() => {
    setState(pushState());
    currentSubscription().then((s) => setEndpoint(s?.endpoint ?? null)).catch(() => setEndpoint(null));
  }, []);

  useEffect(() => { void load(); checkDevice(); }, [load, checkDevice]);
  // Voltando dos Ajustes do iPhone, a permissão pode ter mudado
  useEffect(() => {
    const onVisible = () => { if (document.visibilityState === 'visible') checkDevice(); };
    document.addEventListener('visibilitychange', onVisible);
    return () => document.removeEventListener('visibilitychange', onVisible);
  }, [checkDevice]);
  // Na primeira vez, o servidor prepara as chaves em alguns segundos
  useEffect(() => {
    if (!info || info.ready || !info.configured || polls.current >= 10) return;
    const t = setTimeout(() => { polls.current += 1; void load(); }, 3000);
    return () => clearTimeout(t);
  }, [info, load]);

  const thisDevice = info?.devices.find((d) => d.endpoint === endpoint) ?? null;
  const on = state === 'granted' && !!thisDevice;
  const others = info?.devices.filter((d) => d.endpoint !== endpoint) ?? [];

  async function enable() {
    if (!info?.public_key || !profile) return;
    setBusy(true);
    try {
      await enablePush(info.public_key, profile.id);   // pede a permissão já no toque
      checkDevice();
      await load();
      try { localStorage.setItem(PROMPT_OFF, 'off'); } catch { /* ok */ }
      toast('Notificações ligadas neste aparelho.');
    } catch (e) {
      setState(pushState());
      toast(friendlyError(e), 'error');
    } finally {
      setBusy(false);
    }
  }

  async function disable() {
    setBusy(true);
    try {
      await disablePush();
      setEndpoint(null);
      await load();
      toast('Notificações desligadas neste aparelho.');
    } finally {
      setBusy(false);
    }
  }

  async function test() {
    setBusy(true);
    try {
      await api.pushTest();
      toast('Enviada. Ela chega em alguns segundos.');
      setTimeout(() => void load(), 8000);
    } catch (e) {
      toast(friendlyError(e), 'error');
    } finally {
      setBusy(false);
    }
  }

  async function save(patch: Partial<NotifySettings>) {
    if (!info) return;
    const prev = info.settings;
    setInfo({ ...info, settings: { ...prev, ...patch } });
    try {
      const s = await api.setNotify(patch);
      setInfo((i) => (i ? { ...i, settings: s } : i));
    } catch (e) {
      setInfo((i) => (i ? { ...i, settings: prev } : i));
      toast(friendlyError(e), 'error');
    }
  }

  if (error) return <div className="screen"><BackButton /><ErrorState message={error} onRetry={load} /></div>;
  if (!info) return <div className="screen"><BackButton /><Skeleton height={220} /></div>;
  const s = info.settings;

  return (
    <div className="screen">
      <BackButton />
      <h1>Notificações</h1>
      <span className="small muted">Lembrete da meta do dia, aviso quando a sequência estiver em risco e novidades dos amigos.</span>

      {!info.configured ? (
        <div className="card stack">
          <h3>Ainda não configuradas</h3>
          <span className="small muted">Falta o administrador concluir a configuração no servidor.</span>
        </div>
      ) : state === 'install' || state === 'unsupported' || state === 'denied' ? (
        <DeviceHelp state={state} />
      ) : on ? (
        <div className="card stack">
          <div className="row" style={{ gap: 10 }}>
            <span style={{ color: 'var(--ok)' }}><IconBell /></span>
            <strong className="grow">Ligadas neste aparelho</strong>
          </div>
          {thisDevice.last_ok_at ? (
            <span className="small faint">Última notificação entregue {relativeTime(thisDevice.last_ok_at)}.</span>
          ) : thisDevice.last_status ? (
            <span className="small" style={{ color: 'var(--warn)' }}>
              A última tentativa não chegou (código {thisDevice.last_status}). Envie um teste; se continuar, desligue e ligue de novo.
            </span>
          ) : null}
          <div className="row" style={{ gap: 8 }}>
            <button className="btn sm" disabled={busy} onClick={test}>Enviar teste</button>
            <button className="btn sm ghost" disabled={busy} onClick={disable}>Desligar neste aparelho</button>
          </div>
        </div>
      ) : endpoint === undefined ? (
        <Skeleton height={120} />
      ) : (
        <div className="card stack">
          <h3>Receber notificações neste aparelho</h3>
          <span className="small muted">
            {isIOS() ? 'O iPhone vai perguntar se a Forja pode enviar notificações. Toque em Permitir.'
                     : 'O navegador vai perguntar se a Forja pode enviar notificações.'}
          </span>
          <button className="btn primary" disabled={busy || !info.ready} onClick={enable}>
            {!info.ready ? 'Preparando…' : busy ? 'Ativando…' : 'Ativar notificações'}
          </button>
        </div>
      )}

      {others.length > 0 && (
        <span className="small faint">
          Também ligadas em: {others.map((d) => d.device || 'outro aparelho').join(', ')}.
        </span>
      )}

      {(on || info.devices.length > 0) && (
        <div className="card stack" style={{ gap: 0 }}>
          <Toggle label="Lembrete da meta" checked={s.lembrete} onChange={(v) => save({ lembrete: v })}
                  desc="Só se a meta do dia ainda não estiver cumprida." />
          {s.lembrete && <TimeField label="Horário" value={s.lembrete_hora} onSave={(v) => save({ lembrete_hora: v })} />}
          <Toggle label="Sequência em risco" checked={s.risco} onChange={(v) => save({ risco: v })}
                  desc="À noite, se ainda faltar missão para a meta." />
          {s.risco && <TimeField label="Horário" value={s.risco_hora} onSave={(v) => save({ risco_hora: v })} />}
          <Toggle label="Amigos e desafios" checked={s.social} onChange={(v) => save({ social: v })}
                  desc="Pedidos de amizade, convites, incentivos e reações." />
        </div>
      )}

      <span className="small faint">
        Na fase Domínio (dias 46 a 60), o lembrete da manhã só aparece se a meta do dia anterior ficou para trás.
        O diário e os detalhes dos hábitos nunca aparecem nas notificações.
      </span>
      <Link to="/perfil" className="link small center">Voltar ao perfil</Link>
    </div>
  );
}

/** Convite discreto no Início para ligar as notificações (some depois de ativar ou de "Agora não"). */
export function PushPrompt() {
  const [show, setShow] = useState(false);
  useEffect(() => {
    let off = false;
    try { off = localStorage.getItem(PROMPT_OFF) === 'off'; } catch { /* sem armazenamento */ }
    if (off || pushState() !== 'default') return;
    let alive = true;
    api.notify().then((n) => { if (alive) setShow(n.configured); }).catch(() => {});
    return () => { alive = false; };
  }, []);
  if (!show) return null;
  function dismiss() {
    try { localStorage.setItem(PROMPT_OFF, 'off'); } catch { /* ok */ }
    setShow(false);
  }
  return (
    <div className="notice" role="region" aria-label="Notificações">
      <IconBell />
      <span className="grow small"><strong>Lembretes no celular</strong> · um aviso da meta do dia e dos amigos</span>
      <div className="stack tight" style={{ alignItems: 'flex-end' }}>
        <Link to="/perfil/notificacoes" className="btn sm">Ativar</Link>
        <button className="link small" onClick={dismiss}>Agora não</button>
      </div>
    </div>
  );
}
