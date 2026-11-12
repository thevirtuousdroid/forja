import { useState, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { api, friendlyError } from '../lib/api';
import { useApp } from '../lib/AppData';
import { DIMENSIONS, DIMENSION_KEYS } from '../lib/game';
import { BackButton } from '../components/ui';
import { useFeedback } from '../components/Feedback';
import type { Dimension } from '../lib/types';

export function NewMissionScreen() {
  const nav = useNavigate();
  const { refresh, profile } = useApp();
  const { toast } = useFeedback();
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [dimension, setDimension] = useState<Dimension | null>(null);
  const [difficulty, setDifficulty] = useState(1);
  const [minutes, setMinutes] = useState(15);
  const [recurring, setRecurring] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit(e: FormEvent) {
    e.preventDefault();
    if (!dimension) { setError('Escolha uma área.'); return; }
    setBusy(true); setError(null);
    try {
      await api.createCustomMission({ name: name.trim(), description: description.trim(), dimension, difficulty, minutes, recurring });
      await refresh();
      toast(recurring ? 'Hábito criado. Ele aparece todos os dias a partir de hoje.' : 'Missão criada para hoje.');
      nav('/missoes', { replace: true });
    } catch (err) {
      setError(friendlyError(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="screen no-tabs">
      <BackButton />
      <h1>Nova missão</h1>
      <form className="stack" onSubmit={submit}>
        <div className="field">
          <label htmlFor="mname">Nome</label>
          <input id="mname" className="input" value={name} onChange={(e) => setName(e.target.value)} maxLength={60} required placeholder="Ex.: Praticar violão" />
        </div>
        <div className="field">
          <label htmlFor="mdesc">Descrição (opcional)</label>
          <textarea id="mdesc" className="input" value={description} onChange={(e) => setDescription(e.target.value)} maxLength={280} />
        </div>

        <fieldset className="stack tight" style={{ border: 0, padding: 0, margin: 0 }}>
          <legend className="small muted" style={{ marginBottom: 6 }}>Área</legend>
          <div className="choice-grid">
            {DIMENSION_KEYS.map((d) => (
              <button type="button" key={d} className="choice" aria-pressed={dimension === d} onClick={() => setDimension(d)}>
                {DIMENSIONS[d].short}
              </button>
            ))}
          </div>
        </fieldset>

        <fieldset className="stack tight" style={{ border: 0, padding: 0, margin: 0 }}>
          <legend className="small muted" style={{ marginBottom: 6 }}>Dificuldade</legend>
          <div className="choice-grid" style={{ gridTemplateColumns: 'repeat(3, 1fr)' }}>
            {[[1, 'Leve'], [2, 'Moderada'], [3, 'Exigente']].map(([v, l]) => (
              <button type="button" key={v} className="choice center" aria-pressed={difficulty === v} onClick={() => setDifficulty(v as number)}>{l}</button>
            ))}
          </div>
        </fieldset>

        <div className="field">
          <label htmlFor="mmin">Duração: <strong className="num">{minutes} min</strong></label>
          <input id="mmin" type="range" min={5} max={120} step={5} value={minutes} onChange={(e) => setMinutes(Number(e.target.value))} />
        </div>

        <fieldset className="stack tight" style={{ border: 0, padding: 0, margin: 0 }}>
          <legend className="small muted" style={{ marginBottom: 6 }}>Repetição</legend>
          <div className="choice-grid">
            <button type="button" className="choice" aria-pressed={!recurring} onClick={() => setRecurring(false)}>Só hoje</button>
            <button type="button" className="choice" aria-pressed={recurring} onClick={() => setRecurring(true)}>Todo dia</button>
          </div>
          {recurring && profile?.plan === 'free' && <span className="small faint">No plano gratuito, até 2 hábitos personalizados ficam ativos ao mesmo tempo.</span>}
        </fieldset>

        <p className="small faint">Missões criadas por você rendem um pouco menos XP que as do plano, e a partir da 4ª no mesmo dia o XP diminui. Isso mantém a progressão justa.</p>

        {error && <p role="alert" style={{ color: 'var(--danger)' }}>{error}</p>}
        <div className="sticky-actions">
          <button className="btn primary block" disabled={busy || !name.trim() || !dimension}>{busy ? 'Criando…' : 'Criar missão'}</button>
        </div>
      </form>
    </div>
  );
}
