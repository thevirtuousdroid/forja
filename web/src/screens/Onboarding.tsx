import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { STEPS, isStepComplete } from '../content/questionnaire';
import { api, friendlyError } from '../lib/api';
import { useApp } from '../lib/AppData';
import { Emblem } from '../components/Emblem';
import { IconChevronLeft } from '../components/Icons';

const SLIDES = [
  {
    title: 'Cada hábito é uma missão',
    text: 'Você cumpre na vida real e marca aqui. Isso gera experiência, fortalece atributos e faz o seu personagem subir de nível.',
  },
  {
    title: 'Um programa de 66 dias',
    text: 'Seis fases, começando leve. As metas só sobem quando você mostra consistência, e você pode ajustar quando precisar.',
  },
  {
    title: 'Falhar faz parte',
    text: 'Um dia ruim não apaga nada. Escudos protegem a sua sequência, e voltar no dia seguinte rende bônus de determinação.',
  },
];

export function WelcomeScreen() {
  const [i, setI] = useState(0);
  const nav = useNavigate();
  const s = SLIDES[i];
  return (
    <div className="screen no-tabs" style={{ minHeight: '100dvh', justifyContent: 'space-between' }}>
      <div className="steps-bar" aria-hidden>{SLIDES.map((_, k) => <i key={k} className={k <= i ? 'on' : ''} />)}</div>
      <div className="stack" style={{ alignItems: 'center', textAlign: 'center', gap: 20 }} key={i}>
        <div style={{ animation: 'pop .4s' }}><Emblem level={[1, 8, 25][i]} size={150} showLevel={false} /></div>
        <h1>{s.title}</h1>
        <p className="muted" style={{ maxWidth: 380 }}>{s.text}</p>
      </div>
      <div className="stack">
        <button className="btn primary block" onClick={() => (i < SLIDES.length - 1 ? setI(i + 1) : nav('/avaliacao'))}>
          {i < SLIDES.length - 1 ? 'Continuar' : 'Fazer minha avaliação'}
        </button>
        {i < SLIDES.length - 1 && <button className="btn ghost block" onClick={() => nav('/avaliacao')}>Pular introdução</button>}
      </div>
    </div>
  );
}

const DRAFT_KEY = 'forja.avaliacao.rascunho';

export function QuestionnaireScreen() {
  const nav = useNavigate();
  const { refresh, profile } = useApp();
  const [step, setStep] = useState(0);
  const [answers, setAnswers] = useState<Record<string, unknown>>(() => {
    let draft: Record<string, unknown> = {};
    try { draft = JSON.parse(localStorage.getItem(DRAFT_KEY) ?? '{}'); } catch { /* sem rascunho */ }
    if (!draft.display_name && profile?.display_name) draft.display_name = profile.display_name;
    return draft;
  });
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    try { localStorage.setItem(DRAFT_KEY, JSON.stringify(answers)); } catch { /* armazenamento indisponível */ }
  }, [answers]);
  useEffect(() => { window.scrollTo({ top: 0 }); }, [step]);

  const s = STEPS[step];
  const complete = isStepComplete(s, answers);
  const last = step === STEPS.length - 1;

  function pick(key: string, value: string | number, multi?: boolean) {
    setAnswers((a) => {
      if (!multi) return { ...a, [key]: value };
      const cur = (a[key] as (string | number)[] | undefined) ?? [];
      return { ...a, [key]: cur.includes(value) ? cur.filter((v) => v !== value) : [...cur, value] };
    });
  }

  async function finish() {
    setBusy(true); setError(null);
    try {
      await api.submitAssessment(answers);
      try { localStorage.removeItem(DRAFT_KEY); } catch { /* ignora */ }
      await refresh();
      nav('/resultado', { replace: true });
    } catch (e) {
      setError(friendlyError(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="screen no-tabs">
      <div className="row between">
        {step > 0 ? (
          <button className="back" onClick={() => setStep(step - 1)}><IconChevronLeft /> Voltar</button>
        ) : <span />}
        <span className="small faint num">{step + 1} de {STEPS.length}</span>
      </div>
      <div className="steps-bar" aria-hidden>{STEPS.map((_, k) => <i key={k} className={k <= step ? 'on' : ''} />)}</div>

      <div className="stack tight">
        <h1>{s.title}</h1>
        <p className="muted">{s.intro}</p>
      </div>

      {s.questions.map((q) => (
        <fieldset key={q.key} className="stack" style={{ border: 0, padding: 0, margin: 0 }}>
          <legend className="stack tight" style={{ marginBottom: 10 }}>
            <h3>{q.title}</h3>
            {q.hint && <span className="small faint">{q.hint}</span>}
          </legend>
          {q.text ? (
            <input className="input" value={(answers[q.key] as string) ?? ''} maxLength={q.text.maxLength} placeholder={q.text.placeholder}
                   aria-label={q.title} autoComplete="nickname" onChange={(e) => setAnswers((a) => ({ ...a, [q.key]: e.target.value }))} />
          ) : (
          <div className={`choice-grid ${q.options.length > 6 || q.options.some((o) => o.label.length > 22) ? 'one' : ''}`}>
            {q.options.map((o) => {
              const cur = answers[q.key];
              const on = q.multi ? Array.isArray(cur) && cur.includes(o.value) : cur === o.value;
              return (
                <button key={String(o.value)} className="choice" aria-pressed={on} onClick={() => pick(q.key, o.value, q.multi)}>
                  {o.label}
                </button>
              );
            })}
          </div>
          )}
        </fieldset>
      ))}

      {error && <p role="alert" style={{ color: 'var(--danger)' }}>{error}</p>}

      <div className="sticky-actions">
        <button className="btn primary block" disabled={!complete || busy} onClick={() => (last ? finish() : setStep(step + 1))}>
          {busy ? 'Montando seu plano…' : last ? 'Ver meu resultado' : 'Continuar'}
        </button>
      </div>
    </div>
  );
}
