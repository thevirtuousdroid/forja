import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api, friendlyError } from '../lib/api';
import { modeDef } from '../lib/rpg';
import { useApp } from '../lib/AppData';
import { supabase } from '../lib/supabase';
import { COMMON_TIMEZONES } from '../lib/dates';
import { formatTarget } from '../lib/game';
import { useFeedback } from '../components/Feedback';
import { Skeleton } from '../components/ui';
import { getAccent, setAccent, ACCENTS, type Accent } from '../lib/theme';

export function ProfileScreen() {
  const { profile, habits, refresh, userEmail } = useApp();
  const { toast } = useFeedback();
  const [name, setName] = useState('');
  const [minDaily, setMinDaily] = useState(2);
  const [tz, setTz] = useState('America/Sao_Paulo');
  const [accent, setAccentState] = useState<Accent>(getAccent());
  const [saving, setSaving] = useState(false);
  const [standalone] = useState(() => window.matchMedia?.('(display-mode: standalone)').matches || (navigator as { standalone?: boolean }).standalone === true);

  useEffect(() => {
    if (!profile) return;
    setName(profile.display_name); setMinDaily(profile.min_daily_missions); setTz(profile.timezone);
  }, [profile]);

  if (!profile) return <div className="screen"><Skeleton height={300} /></div>;

  const dirty = name !== profile.display_name || minDaily !== profile.min_daily_missions || tz !== profile.timezone;
  const paused = habits.filter((h) => !h.active);
  const tzOptions = COMMON_TIMEZONES.includes(tz) ? COMMON_TIMEZONES : [tz, ...COMMON_TIMEZONES];

  async function save() {
    setSaving(true);
    try {
      await api.updateProfile({ displayName: name, minDaily, timezone: tz });
      await refresh();
      toast('Perfil salvo.');
    } catch (e) {
      toast(friendlyError(e), 'error');
    } finally {
      setSaving(false);
    }
  }

  async function resume(id: string, target: number) {
    try {
      await api.adjustHabit(id, target, true);
      await refresh();
      toast('Hábito retomado. Ele volta às missões de hoje.');
    } catch (e) {
      toast(friendlyError(e), 'error');
    }
  }

  return (
    <div className="screen">
      <div className="row between">
        <h1>Perfil</h1>
        <span className={`pill ${profile.plan === 'premium' ? 'accent' : ''}`}>{profile.plan === 'premium' ? 'Premium' : 'Gratuito'}</span>
      </div>
      {userEmail && <span className="small faint">{userEmail}</span>}

      <div className="card stack">
        <div className="field">
          <label htmlFor="pname">Nome</label>
          <input id="pname" className="input" value={name} maxLength={40} onChange={(e) => setName(e.target.value)} />
        </div>
        <div className="field">
          <label>Meta mínima diária: <strong className="num">{minDaily} {minDaily === 1 ? 'missão' : 'missões'}</strong></label>
          <input type="range" min={1} max={6} value={minDaily} onChange={(e) => setMinDaily(Number(e.target.value))} aria-label="Meta mínima diária"
                 disabled={profile.mode === 'extremo'} />
          <span className="small faint">
            {profile.mode === 'extremo'
              ? 'No modo Extremo a meta é concluir todas as missões diárias, e o mínimo fica travado.'
              : profile.mode === 'desafio'
                ? 'No modo Desafio vale o maior entre este mínimo e 60% das missões diárias. Mudanças valem a partir de hoje.'
                : 'Bater essa meta mantém a sequência e rende +15 XP de Disciplina. Mudanças valem a partir de hoje.'}
          </span>
        </div>
        <div className="field">
          <label htmlFor="ptz">Fuso horário</label>
          <select id="ptz" className="input" value={tz} onChange={(e) => setTz(e.target.value)}>
            {tzOptions.map((t) => <option key={t} value={t}>{t.replace('_', ' ')}</option>)}
          </select>
          <span className="small faint">Define quando o seu dia vira.</span>
        </div>
        <button className="btn primary" disabled={!dirty || saving} onClick={save}>{saving ? 'Salvando…' : 'Salvar'}</button>
      </div>

      <div className="card stack">
        <h3>Cor de destaque</h3>
        <div className="row">
          {ACCENTS.map((a) => (
            <button key={a.id} className="accent-swatch" style={{ background: a.color }} aria-label={a.label} aria-pressed={accent === a.id}
                    onClick={() => { setAccent(a.id); setAccentState(a.id); }} />
          ))}
        </div>
      </div>

      {paused.length > 0 && (
        <div className="card stack">
          <h3>Hábitos pausados</h3>
          {paused.map((h) => (
            <div key={h.id} className="row between">
              <div className="grow"><div>{h.name}</div><div className="small faint">{formatTarget(h.current_target, h.unit)}</div></div>
              <button className="btn sm" onClick={() => resume(h.id, h.current_target)}>Retomar</button>
            </div>
          ))}
        </div>
      )}

      <div className="card stack">
        <Link to="/jornada/modos" className="row between" style={{ color: 'inherit', textDecoration: 'none' }}>
          <span>Modo de dificuldade: <strong>{modeDef(profile.mode).name}</strong></span><span className="faint">›</span>
        </Link>
        <Link to="/personagem/aparencia" className="row between" style={{ color: 'inherit', textDecoration: 'none' }}>
          <span>Aparência do personagem</span><span className="faint">›</span>
        </Link>
        <Link to="/avaliacao/resultado" className="row between" style={{ color: 'inherit', textDecoration: 'none' }}>
          <span>Minha avaliação e plano</span><span className="faint">›</span>
        </Link>
      </div>

      {!standalone && (
        <div className="card stack">
          <h3>Instalar no iPhone</h3>
          <ol className="small muted" style={{ margin: 0, paddingLeft: 18 }}>
            <li>Abra o link desta página no <strong>Safari</strong>.</li>
            <li>Toque em <strong>Compartilhar</strong> (quadrado com seta para cima).</li>
            <li>Escolha <strong>Adicionar à Tela de Início</strong>.</li>
          </ol>
          <span className="small faint">No Android, use o menu do Chrome → Instalar app.</span>
        </div>
      )}

      <button className="btn ghost danger" onClick={() => supabase.auth.signOut()}>Sair da conta</button>
      <span className="small faint center">Forja · versão 0.3 (Etapa 3)</span>
    </div>
  );
}

