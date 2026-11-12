import { useEffect, useState } from 'react';
import { api, friendlyError } from '../lib/api';
import { useApp } from '../lib/AppData';
import type { Mode, ModeInfo } from '../lib/types';
import { MODES, MODE_SAFETY, type ModeDef } from '../lib/rpg';
import { formatDay } from '../lib/dates';
import { BackButton, ErrorState, Skeleton } from '../components/ui';
import { useFeedback } from '../components/Feedback';

function lockReason(m: Mode, info: ModeInfo): string | null {
  if (m === 'desafio' && !info.desafio.available) {
    const left = info.desafio.unlock_day - info.day;
    return `Liberado no dia ${info.desafio.unlock_day} do programa (faltam ${left} ${left === 1 ? 'dia' : 'dias'}).`;
  }
  if (m === 'extremo' && !info.extremo.available) {
    if (info.day < info.extremo.unlock_day) {
      const left = info.extremo.unlock_day - info.day;
      return `Liberado no dia ${info.extremo.unlock_day} do programa (faltam ${left} ${left === 1 ? 'dia' : 'dias'}).`;
    }
    if (info.best_streak < info.extremo.streak_needed) {
      return `Precisa de uma sequência de ${info.extremo.streak_needed} dias antes (sua melhor: ${info.best_streak}).`;
    }
    if (info.cooldown_until) return `Disponível de novo em ${formatDay(info.cooldown_until, { day: 'numeric', month: 'long' })}.`;
  }
  return null;
}

export function ModesScreen() {
  const { refresh } = useApp();
  const { toast } = useFeedback();
  const [info, setInfo] = useState<ModeInfo | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [picking, setPicking] = useState<Mode | null>(null);
  const [accepted, setAccepted] = useState(false);
  const [saving, setSaving] = useState(false);

  const load = () => {
    setError(null);
    return api.modeInfo().then(setInfo).catch((e) => setError(friendlyError(e)));
  };
  useEffect(() => { void load(); }, []);

  if (error) return <div className="screen"><BackButton to="/jornada" /><ErrorState message={error} onRetry={load} /></div>;
  if (!info) return <div className="screen"><BackButton to="/jornada" /><Skeleton height={80} /><Skeleton height={200} /></div>;

  async function activate(m: ModeDef) {
    setSaving(true);
    try {
      await api.setMode(m.id, accepted);
      await Promise.all([load(), refresh()]);
      setPicking(null); setAccepted(false);
      toast(`Modo ${m.name} ativado a partir de hoje.`);
    } catch (e) {
      toast(friendlyError(e), 'error');
    } finally {
      setSaving(false);
    }
  }

  const current = MODES.find((m) => m.id === info.mode)!;

  return (
    <div className="screen">
      <BackButton to="/jornada" />
      <h1>Modos de dificuldade</h1>
      <div className="card hero stack tight">
        <span className="small muted">Modo atual</span>
        <h2>{current.name}</h2>
        <span className="small muted">
          {info.since ? `Desde ${formatDay(info.since, { day: 'numeric', month: 'long' })}. ` : ''}
          {current.tagline}
        </span>
        {info.mode === 'extremo' && (
          <span className="small" style={{ color: info.extremo_failures >= 2 ? 'var(--danger)' : 'var(--warn)' }}>
            Dias abaixo da meta nos últimos 7: {info.extremo_failures} de 3.
          </span>
        )}
      </div>
      <p className="small faint">{MODE_SAFETY}</p>

      {MODES.map((m) => {
        const isCurrent = m.id === info.mode;
        const lock = lockReason(m.id, info);
        const open = picking === m.id;
        const leavingExtremo = info.mode === 'extremo' && m.id !== 'extremo';
        return (
          <div key={m.id} className={`mode-card ${isCurrent ? 'current' : ''}`}>
            <div className="row between">
              <h2>{m.name}</h2>
              {isCurrent ? <span className="pill accent">Atual</span> : lock ? <span className="pill">🔒 Bloqueado</span> : null}
            </div>
            <span className="small muted">{m.tagline}</span>
            <div className="row" style={{ gap: 6, flexWrap: 'wrap' }}>
              <span className="pill num">XP ×{String(m.multiplier).replace('.', ',')}</span>
              <span className="pill num">{m.shields === 0 ? 'Sem escudos' : `${m.shields} ${m.shields === 1 ? 'escudo' : 'escudos'}`}</span>
            </div>
            <ul>{m.rules.map((r) => <li key={r}>{r}</li>)}</ul>
            {m.consequences.length > 0 && (
              <>
                <strong className="small">Se você não cumprir</strong>
                <ul>{m.consequences.map((r) => <li key={r}>{r}</li>)}</ul>
              </>
            )}
            {lock && !isCurrent && <span className="small faint">{lock}</span>}

            {!isCurrent && !lock && !open && (
              <button className="btn" onClick={() => { setPicking(m.id); setAccepted(false); }}>
                {m.id === 'normal' ? 'Voltar ao Normal' : `Ativar modo ${m.name}`}
              </button>
            )}
            {open && (
              <div className="stack" role="group" aria-label={`Confirmar modo ${m.name}`}>
                {leavingExtremo && (
                  <p className="small" style={{ color: 'var(--warn)' }}>Saindo do Extremo agora, ele só volta a ficar disponível em 7 dias.</p>
                )}
                <p className="small muted">Vale a partir de hoje. Dias anteriores continuam julgados pelas regras que valiam neles.</p>
                {m.id !== 'normal' && (
                  <label className="check-row">
                    <input type="checkbox" checked={accepted} onChange={(e) => setAccepted(e.target.checked)} />
                    <span>Li e entendi as regras e o que acontece se eu não cumprir.</span>
                  </label>
                )}
                <div className="row">
                  <button className="btn ghost grow" onClick={() => setPicking(null)} disabled={saving}>Cancelar</button>
                  <button className="btn primary grow" disabled={saving || (m.id !== 'normal' && !accepted)} onClick={() => activate(m)}>
                    {saving ? 'Ativando…' : 'Confirmar'}
                  </button>
                </div>
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}
