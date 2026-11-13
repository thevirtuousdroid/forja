import { useCallback, useEffect, useRef, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { api } from '../lib/api';
import { MEDITATION_KINDS, fmtMinutes } from '../lib/tools';
import { relativeTime } from '../lib/social';
import { PremiumLock, Ring } from '../components/Social';
import { BackButton, ErrorState, Skeleton } from '../components/ui';
import { useFeedback } from '../components/Feedback';
import { ToolMissions, useTool } from './Tools';

// ── Timer que sobrevive a sair do app (guarda o início, não a contagem) ──────

interface TimerState {
  startedAt: number;
  durationSec: number;
  pausedAt: number | null;
  pausedTotal: number;
  meta: Record<string, string | number | boolean | null>;
}

function readTimer(key: string): TimerState | null {
  try { const v = localStorage.getItem(key); return v ? (JSON.parse(v) as TimerState) : null; } catch { return null; }
}
function writeTimer(key: string, s: TimerState | null) {
  try { if (s) localStorage.setItem(key, JSON.stringify(s)); else localStorage.removeItem(key); } catch { /* sem armazenamento: o timer vale só nesta tela */ }
}

let audio: AudioContext | null = null;
function unlockSound() {
  try {
    const Ctx = window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
    if (Ctx && !audio) audio = new Ctx();
    void audio?.resume();
  } catch { /* sem som */ }
}
function chime() {
  try {
    if (!audio) return;
    const t = audio.currentTime;
    [660, 880].forEach((f, i) => {
      const o = audio!.createOscillator(); const g = audio!.createGain();
      o.frequency.value = f; o.type = 'sine';
      g.gain.setValueAtTime(0.0001, t + i * 0.25); g.gain.exponentialRampToValueAtTime(0.25, t + i * 0.25 + 0.02);
      g.gain.exponentialRampToValueAtTime(0.0001, t + i * 0.25 + 0.9);
      o.connect(g).connect(audio!.destination); o.start(t + i * 0.25); o.stop(t + i * 0.25 + 1);
    });
  } catch { /* sem som */ }
  navigator.vibrate?.([80, 60, 80]);
}

export function useTimer(key: string, onFinish: (s: TimerState) => void) {
  const [state, setState] = useState<TimerState | null>(() => readTimer(key));
  const [now, setNow] = useState(Date.now());
  const finish = useRef(onFinish);
  finish.current = onFinish;

  const save = useCallback((s: TimerState | null) => { setState(s); writeTimer(key, s); }, [key]);

  useEffect(() => {
    if (!state || state.pausedAt) return;
    const t = window.setInterval(() => setNow(Date.now()), 250);
    const onVisible = () => setNow(Date.now());
    document.addEventListener('visibilitychange', onVisible);
    return () => { window.clearInterval(t); document.removeEventListener('visibilitychange', onVisible); };
  }, [state]);

  // Tela acesa enquanto conta (quando o aparelho permite)
  useEffect(() => {
    if (!state || state.pausedAt) return;
    let lock: { release: () => Promise<void> } | null = null;
    const nav = navigator as Navigator & { wakeLock?: { request: (t: 'screen') => Promise<{ release: () => Promise<void> }> } };
    nav.wakeLock?.request('screen').then((l) => { lock = l; }).catch(() => {});
    return () => { void lock?.release().catch(() => {}); };
  }, [state]);

  const elapsed = state ? Math.max(0, ((state.pausedAt ?? now) - state.startedAt - state.pausedTotal) / 1000) : 0;
  const remaining = state ? Math.max(0, state.durationSec - elapsed) : 0;

  // Uma sessão termina uma vez só, mesmo se a tela montar de novo antes de atualizar
  const finished = useRef<number | null>(null);
  useEffect(() => {
    if (state && !state.pausedAt && remaining <= 0) {
      const s = state;
      if (finished.current === s.startedAt) return;
      finished.current = s.startedAt;
      save(null);
      chime();
      finish.current(s);
    }
  }, [remaining, state, save]);

  return {
    state, elapsed, remaining,
    running: !!state && !state.pausedAt,
    start: (durationSec: number, meta: TimerState['meta'] = {}) => {
      unlockSound();
      setNow(Date.now());
      save({ startedAt: Date.now(), durationSec, pausedAt: null, pausedTotal: 0, meta });
    },
    pause: () => state && save({ ...state, pausedAt: Date.now() }),
    resume: () => { if (state?.pausedAt) { unlockSound(); save({ ...state, pausedTotal: state.pausedTotal + (Date.now() - state.pausedAt), pausedAt: null }); } },
    stop: () => { const s = state; save(null); return s; },
  };
}

const clock = (sec: number) => `${String(Math.floor(sec / 60)).padStart(2, '0')}:${String(Math.floor(sec % 60)).padStart(2, '0')}`;

// ── Foco ────────────────────────────────────────────────────────────────────

export function FocusScreen() {
  const [params] = useSearchParams();
  const { toast } = useFeedback();
  const { day, setDay, error, locked, reload } = useTool('foco');
  const [minutes, setMinutes] = useState<number | null>(null);
  const [mission, setMission] = useState<string | null>(params.get('missao'));
  const [last, setLast] = useState<string | null>(null);

  const log = useCallback(async (mins: number, meta: Record<string, unknown>) => {
    if (meta.pausa) { setLast('Pausa encerrada. Bora para o próximo bloco?'); return; }
    if (mins < 1) return;
    try {
      const r = await api.logTool('foco', { minutes: Math.min(180, Math.round(mins)), ...(meta.mission_id ? { mission_id: meta.mission_id } : {}) });
      setDay(r);
      setLast(`Sessão de ${fmtMinutes(Math.round(mins))} registrada.`);
    } catch {
      toast('Não foi possível registrar a sessão. Tente de novo com internet.', 'error');
    }
  }, [setDay, toast]);

  const timer = useTimer('forja.timer.foco', (s) => { void log(s.durationSec / 60, s.meta); });
  const dur = minutes ?? day?.settings.foco_min ?? 25;
  const focusable = day?.focusable ?? [];

  if (locked) return <div className="screen"><BackButton to="/ferramentas" /><h1>Foco</h1><PremiumLock what="O timer de foco" /></div>;
  if (error) return <div className="screen"><BackButton to="/ferramentas" /><ErrorState message={error} onRetry={reload} /></div>;

  const isBreak = !!timer.state?.meta.pausa;
  return (
    <div className="screen">
      <BackButton to="/ferramentas" />
      <h1>Foco</h1>

      <div className="card stack center" style={{ alignItems: 'center' }}>
        <Ring value={timer.state ? 1 - timer.remaining / timer.state.durationSec : 0} size={220} stroke={12}
              color={isBreak ? 'var(--ok)' : 'var(--accent)'}>
          <span className="timer-time">{clock(timer.state ? timer.remaining : dur * 60)}</span>
          <span className="small muted">{isBreak ? 'pausa' : timer.state ? (timer.running ? 'foco' : 'pausado') : 'pronto'}</span>
        </Ring>
        {timer.state ? (
          <div className="row" style={{ width: '100%' }}>
            {timer.running
              ? <button className="btn grow" onClick={timer.pause}>Pausar</button>
              : <button className="btn primary grow" onClick={timer.resume}>Retomar</button>}
            <button className="btn ghost grow" onClick={() => {
              const s = timer.stop();
              if (s && !s.meta.pausa) {
                const mins = timer.elapsed / 60;
                if (mins >= 1) void log(mins, s.meta); else setLast('Sessão descartada (menos de 1 minuto).');
              }
            }}>{isBreak ? 'Pular pausa' : 'Encerrar'}</button>
          </div>
        ) : (
          <>
            <div className="chips" role="group" aria-label="Duração">
              {[15, 25, 45, 60].map((m) => <button key={m} className="chip" aria-pressed={dur === m} onClick={() => setMinutes(m)}>{m} min</button>)}
            </div>
            <button className="btn primary block" onClick={() => { setLast(null); timer.start(dur * 60, { mission_id: mission }); }}>Começar</button>
          </>
        )}
        {timer.state && !isBreak && <span className="small faint">Pode sair do app: ao voltar, o tempo continua certo e a sessão é registrada.</span>}
      </div>

      {last && (
        <div className="notice">
          <span className="grow">{last}</span>
          {!timer.state && !last.startsWith('Pausa') && (
            <button className="btn sm" onClick={() => { setLast(null); timer.start((day?.settings.pausa_min ?? 5) * 60, { pausa: true }); }}>
              Pausa de {day?.settings.pausa_min ?? 5} min
            </button>
          )}
        </div>
      )}

      {!timer.state && focusable.length > 0 && (
        <section className="stack tight">
          <h3>Ligar a uma missão (opcional)</h3>
          <div className="choice-grid one">
            <button className="choice" aria-pressed={mission === null} onClick={() => setMission(null)}>Sem missão</button>
            {focusable.map((m) => (
              <button key={m.id} className="choice" aria-pressed={mission === m.id} onClick={() => setMission(m.id)}>
                {m.name} <span className="small muted">· meta {m.target} min</span>
              </button>
            ))}
          </div>
          <span className="small faint">Os minutos de foco somam na missão escolhida. Ao chegar na meta, ela fica pronta para concluir.</span>
        </section>
      )}

      {day && <ToolMissions missions={day.missions} onDone={reload} />}

      <section className="stack tight">
        <div className="row between"><h3>Hoje</h3>{day && <span className="small muted">{fmtMinutes(day.summary.minutes)} em {day.summary.sessions} {day.summary.sessions === 1 ? 'sessão' : 'sessões'}</span>}</div>
        {!day ? <Skeleton /> : day.entries.length === 0 ? <span className="small muted">Nenhuma sessão ainda.</span> : day.entries.map((e) => (
          <div key={e.id} className="row between small entry" style={{ flexDirection: 'row' }}>
            <span>{fmtMinutes(Number(e.data.minutes))}{e.mission_id ? ` · ${focusable.find((m) => m.id === e.mission_id)?.name ?? day.missions.find((m) => m.id === e.mission_id)?.name ?? 'missão'}` : ''}</span>
            <span className="faint">{relativeTime(e.created_at)}</span>
          </div>
        ))}
      </section>
    </div>
  );
}

// ── Meditação ───────────────────────────────────────────────────────────────

export function MeditationScreen() {
  const { toast } = useFeedback();
  const { day, setDay, error, locked, reload } = useTool('meditacao');
  const [kind, setKind] = useState<(typeof MEDITATION_KINDS)[number]['id']>('respiracao');
  const [minutes, setMinutes] = useState(5);
  const [last, setLast] = useState<string | null>(null);

  const log = useCallback(async (mins: number, k: string) => {
    if (mins < 1) { setLast('Sessão curta demais para registrar.'); return; }
    try {
      const r = await api.logTool('meditacao', { minutes: Math.min(120, Math.round(mins)), kind: k });
      setDay(r);
      setLast(`${fmtMinutes(Math.round(mins))} registrados. Como você está agora?`);
    } catch {
      toast('Não foi possível registrar. Tente de novo com internet.', 'error');
    }
  }, [setDay, toast]);

  const timer = useTimer('forja.timer.meditacao', (s) => { void log(s.durationSec / 60, String(s.meta.kind ?? 'meditacao')); });
  const runningKind = String(timer.state?.meta.kind ?? kind);
  const phase = (timer.elapsed % 10) < 4 ? 'Inspire' : 'Expire';

  if (locked) return <div className="screen"><BackButton to="/ferramentas" /><h1>Meditação</h1><PremiumLock what="A meditação guiada" /></div>;
  if (error) return <div className="screen"><BackButton to="/ferramentas" /><ErrorState message={error} onRetry={reload} /></div>;
  const def = MEDITATION_KINDS.find((k) => k.id === runningKind)!;

  return (
    <div className="screen">
      <BackButton to="/ferramentas" />
      <h1>Meditação</h1>
      {!timer.state && (
        <div className="seg" role="group" aria-label="Tipo">
          {MEDITATION_KINDS.map((k) => <button key={k.id} aria-pressed={kind === k.id} onClick={() => setKind(k.id)}>{k.label}</button>)}
        </div>
      )}
      <p className="small muted center">{def.desc}</p>

      <div className="card stack center" style={{ alignItems: 'center', paddingBlock: 28 }}>
        <div className={`breath ${timer.running ? (runningKind === 'respiracao' ? 'cycle' : 'calm') : ''}`} aria-hidden={!timer.running}>
          <span style={{ fontFamily: 'var(--font-display)', fontWeight: 700 }}>
            {timer.running ? (runningKind === 'respiracao' ? phase : 'Respire') : timer.state ? 'Pausado' : 'Pronto'}
          </span>
        </div>
        <span className="timer-time" style={{ fontSize: 36 }}>{clock(timer.state ? timer.remaining : minutes * 60)}</span>
        {timer.state ? (
          <div className="row" style={{ width: '100%' }}>
            {timer.running
              ? <button className="btn grow" onClick={timer.pause}>Pausar</button>
              : <button className="btn primary grow" onClick={timer.resume}>Retomar</button>}
            <button className="btn ghost grow" onClick={() => { const s = timer.stop(); if (s) void log(timer.elapsed / 60, String(s.meta.kind)); }}>Encerrar</button>
          </div>
        ) : (
          <>
            <div className="chips" role="group" aria-label="Duração">
              {[3, 5, 10, 15, 20].map((m) => <button key={m} className="chip" aria-pressed={minutes === m} onClick={() => setMinutes(m)}>{m} min</button>)}
            </div>
            <button className="btn primary block" onClick={() => { setLast(null); timer.start(minutes * 60, { kind }); }}>Começar</button>
          </>
        )}
      </div>

      {last && <div className="notice"><span className="grow">{last}</span></div>}
      {day && <ToolMissions missions={day.missions} onDone={reload} />}
      {day && <span className="small faint center">Hoje: {fmtMinutes(day.summary.minutes)} em {day.summary.sessions} {day.summary.sessions === 1 ? 'sessão' : 'sessões'}.</span>}
      <p className="disclaimer">Se surgir desconforto, abra os olhos e respire no seu ritmo. Meditação não substitui acompanhamento profissional.</p>
    </div>
  );
}
