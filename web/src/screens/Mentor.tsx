import { useCallback, useEffect, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { api, friendlyError, isPremiumError } from '../lib/api';
import { useApp } from '../lib/AppData';
import type { Dimension, MentorInfo, MentorSuggestion, PlanInfo, WeeklyReport } from '../lib/types';
import { DIMENSIONS } from '../lib/game';
import { formatDay } from '../lib/dates';
import { fmtMinutes, moodOf } from '../lib/tools';
import { plural } from '../lib/social';
import { RARITY } from '../lib/rpg';
import { PremiumLock, Sheet } from '../components/Social';
import { BackButton, ErrorState, Skeleton } from '../components/ui';
import { IconCompass } from '../components/Icons';
import { useFeedback } from '../components/Feedback';

const PRINCIPLES = [
  'Analisa só os seus próprios registros: missões, metas e ferramentas.',
  'Nunca muda uma meta sozinho. Toda sugestão espera você aceitar.',
  'Não faz diagnósticos nem dá orientação médica, psicológica ou nutricional.',
  'Do diário, usa só o número do humor. O texto continua só seu.',
  'Você pode desligar quando quiser, e as sugestões abertas somem.',
];

export function MentorScreen() {
  const nav = useNavigate();
  const { toast } = useFeedback();
  const { refresh, loadEvents } = useApp();
  const [m, setM] = useState<MentorInfo | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [locked, setLocked] = useState(false);
  const [busy, setBusy] = useState<string | null>(null);
  const [confirmOff, setConfirmOff] = useState(false);

  const load = useCallback(() => {
    setError(null);
    api.mentor().then(setM).catch((e) => (isPremiumError(e) ? setLocked(true) : setError(friendlyError(e))));
  }, []);
  useEffect(load, [load]);

  async function enable(on: boolean) {
    setBusy('toggle');
    try {
      await api.setMentor(on);
      setConfirmOff(false);
      toast(on ? 'Mentor ligado.' : 'Mentor desligado.');
      setM(null); load(); void refresh();
    } catch (e) {
      if (isPremiumError(e)) setLocked(true); else toast(friendlyError(e), 'error');
    } finally {
      setBusy(null);
    }
  }

  async function respond(s: MentorSuggestion, accept: boolean) {
    setBusy(s.id);
    try {
      const r = await api.respondSuggestion(s.id, accept);
      setM((x) => (x ? { ...x, suggestions: x.suggestions?.filter((y) => y.id !== s.id) } : x));
      if (accept) {
        if (r.link) { nav(r.link); return; }
        toast(s.kind === 'descansar' ? 'Combinado.' : 'Feito. Vale a partir de hoje.');
        await refresh();
        void loadEvents();
      } else {
        toast('Tudo bem. Essa sugestão não volta tão cedo.');
      }
    } catch (e) {
      toast(friendlyError(e), 'error');
    } finally {
      setBusy(null);
    }
  }

  if (locked) return <div className="screen"><BackButton /><h1>Mentor</h1><PremiumLock what="O Mentor" /></div>;
  if (error) return <div className="screen"><BackButton /><ErrorState message={error} onRetry={load} /></div>;
  if (!m) return <div className="screen"><BackButton /><Skeleton height={120} /><Skeleton height={200} /></div>;

  if (!m.enabled) {
    return (
      <div className="screen">
        <BackButton />
        <div className="row" style={{ gap: 10 }}><IconCompass /><h1>Mentor</h1></div>
        <p className="muted">O Mentor olha para o seu histórico e aponta padrões: seu melhor horário, as áreas que pedem atenção, metas que talvez estejam pesadas. Toda semana ele monta um relatório.</p>
        <div className="card stack tight">
          <h3>Como ele funciona</h3>
          <ul className="small muted" style={{ margin: 0, paddingLeft: 18, display: 'flex', flexDirection: 'column', gap: 6 }}>
            {PRINCIPLES.map((p) => <li key={p}>{p}</li>)}
          </ul>
        </div>
        {m.allowed ? (
          <button className="btn primary block" disabled={busy !== null} onClick={() => enable(true)}>Ligar o Mentor</button>
        ) : <PremiumLock what="O Mentor" />}
        {m.reports_allowed && <span className="small faint center">O relatório semanal sai mesmo com o Mentor desligado.</span>}
      </div>
    );
  }

  const tw = m.this_week;
  return (
    <div className="screen">
      <BackButton />
      <div className="row" style={{ gap: 10 }}><IconCompass /><h1>Mentor</h1></div>

      {(m.suggestions?.length ?? 0) > 0 && (
        <section className="stack tight">
          <h3>Sugestões</h3>
          {m.suggestions!.map((s) => (
            <div key={s.id} className="card stack">
              <strong>{s.data.title}</strong>
              <span className="small muted">{s.data.text}</span>
              <div className="row">
                <button className="btn sm ghost grow" disabled={busy === s.id} onClick={() => respond(s, false)}>Agora não</button>
                <button className="btn sm primary grow" disabled={busy === s.id} onClick={() => respond(s, true)}>{s.data.action}</button>
              </div>
            </div>
          ))}
          <span className="small faint">Nada muda sem o seu toque. Ajustar uma meta para baixo também é evoluir.</span>
        </section>
      )}

      <section className="stack tight">
        <h3>O que os seus dados mostram</h3>
        {(m.insights?.length ?? 0) === 0 ? (
          <span className="small muted">Com mais alguns dias de registros, as análises aparecem aqui.</span>
        ) : m.insights!.map((i) => (
          <div key={i.id} className={`card stack tight insight ${i.tone}`}>
            <strong>{i.title}</strong>
            <span className="small muted">{i.text}</span>
          </div>
        ))}
      </section>

      {m.reports_allowed && tw && (
        <div className="card stack tight">
          <div className="row between"><h3>Esta semana até agora</h3><span className="small faint">{formatDay(tw.week_start)} a {formatDay(tw.until)}</span></div>
          <div className="stat-grid">
            <div className="stat"><div className="small muted">Missões</div><div className="num">{tw.missions}</div></div>
            <div className="stat"><div className="small muted">Dias com meta</div><div className="num">{tw.goal_days}<span className="small muted">/{tw.days}</span></div></div>
          </div>
        </div>
      )}

      {m.reports_allowed && (m.reports?.length ?? 0) > 0 && (
        <section className="stack tight">
          <h3>Relatórios semanais</h3>
          {m.reports!.map((r) => (
            <Link key={r.week_start} to={`/mentor/relatorio/${r.week_start}`} className="card row between" style={{ color: 'inherit', textDecoration: 'none' }}>
              <span>Semana de {formatDay(r.week_start, { day: 'numeric', month: 'long' })}</span>
              <span className="small muted">{plural(r.missions, 'missão', 'missões')} ›</span>
            </Link>
          ))}
        </section>
      )}

      <button className="link small center" onClick={() => setConfirmOff(true)}>Desligar o Mentor</button>
      <p className="disclaimer center">O Mentor segue regras sobre os seus registros. Ele não é um profissional de saúde; se algo pesar de verdade, converse com alguém de confiança ou com um profissional.</p>

      {confirmOff && (
        <Sheet title="Desligar o Mentor?" onClose={() => setConfirmOff(false)}>
          <p className="muted">As sugestões abertas somem e ele para de analisar seus registros. Dá para ligar de novo quando quiser.</p>
          <div className="row">
            <button className="btn ghost grow" onClick={() => setConfirmOff(false)}>Cancelar</button>
            <button className="btn danger grow" disabled={busy !== null} onClick={() => enable(false)}>Desligar</button>
          </div>
        </Sheet>
      )}
    </div>
  );
}

function Delta({ now, before, unit }: { now: number; before: number; unit: string }) {
  if (before === 0 && now === 0) return null;
  const d = now - before;
  return <span className="small" style={{ color: d > 0 ? 'var(--ok)' : d < 0 ? 'var(--warn)' : 'var(--text-3)' }}>
    {d === 0 ? 'igual à semana anterior' : `${d > 0 ? '+' : ''}${d} ${unit} vs. anterior`}
  </span>;
}

export function ReportScreen() {
  const { week } = useParams();
  const [r, setR] = useState<WeeklyReport | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [locked, setLocked] = useState(false);
  const load = useCallback(() => {
    setError(null);
    api.report(week ?? null).then(setR).catch((e) => (isPremiumError(e) ? setLocked(true) : setError(friendlyError(e))));
  }, [week]);
  useEffect(load, [load]);

  if (locked) return <div className="screen"><BackButton to="/mentor" /><h1>Relatório</h1><PremiumLock what="O relatório semanal" /></div>;
  if (error) return <div className="screen"><BackButton to="/mentor" /><ErrorState message={error} onRetry={load} /></div>;
  if (!r) return <div className="screen"><BackButton to="/mentor" /><Skeleton height={160} /><Skeleton height={220} /></div>;

  const areas = Object.entries(r.areas) as [Dimension, number][];
  const maxArea = Math.max(1, ...areas.map(([, n]) => n));
  const t = r.tools;
  const toolRows = [
    t.foco_min > 0 && ['Foco', fmtMinutes(t.foco_min)],
    t.meditacao_min > 0 && ['Meditação', fmtMinutes(t.meditacao_min)],
    t.paginas > 0 && ['Leitura', plural(t.paginas, 'página', 'páginas')],
    t.agua_dias > 0 && ['Água', `meta batida em ${plural(t.agua_dias, 'dia', 'dias')}`],
    t.sono_medio && ['Sono', `média de ${fmtMinutes(t.sono_medio)}`],
    t.diario_dias > 0 && ['Diário', `${plural(t.diario_dias, 'dia', 'dias')}${t.humor_medio ? ` · humor médio ${moodOf(Math.round(t.humor_medio))?.emoji ?? ''} ${String(t.humor_medio).replace('.', ',')}` : ''}`],
  ].filter(Boolean) as [string, string][];

  return (
    <div className="screen">
      <BackButton to="/mentor" />
      <div className="stack tight">
        <span className="tiny muted">Relatório semanal</span>
        <h1>{formatDay(r.week_start, { day: 'numeric', month: 'short' })} a {formatDay(r.week_end, { day: 'numeric', month: 'short' })}</h1>
      </div>
      <div className="card hero stack tight"><strong style={{ fontSize: 17 }}>{r.highlight}</strong>{r.focus && <span className="small muted">{r.focus}</span>}</div>

      <div className="stat-grid">
        <div className="stat"><div className="small muted">Missões</div><div className="num">{r.missions}</div><Delta now={r.missions} before={r.missions_prev} unit="" /></div>
        <div className="stat"><div className="small muted">Dias com meta</div><div className="num">{r.goal_days}<span className="small muted">/{r.days}</span></div>
          <span className="small faint">{plural(r.perfect_days, 'dia perfeito', 'dias perfeitos')}</span></div>
        <div className="stat"><div className="small muted">XP ganho</div><div className="num">{r.xp}</div><Delta now={r.xp} before={r.xp_prev} unit="XP" /></div>
        <div className="stat"><div className="small muted">Sequência</div><div className="num">{r.streak}</div><span className="small faint">no fim da semana</span></div>
      </div>

      {areas.length > 0 && (
        <div className="card stack tight">
          <h3>Missões por área</h3>
          {areas.sort((a, b) => b[1] - a[1]).map(([d, n]) => (
            <div key={d} className="stack" style={{ gap: 4 }}>
              <div className="row between small"><span>{DIMENSIONS[d].label}</span><span className="num">{n}</span></div>
              <div className="bar thin"><span style={{ width: `${(n / maxArea) * 100}%` }} /></div>
            </div>
          ))}
          {r.best_day && <span className="small faint">Melhor dia: {formatDay(r.best_day.date, { weekday: 'long', day: 'numeric' })}, com {plural(r.best_day.done, 'missão', 'missões')}.</span>}
        </div>
      )}

      {(r.achievements.length > 0 || r.bosses.length > 0) && (
        <div className="card stack tight">
          <h3>Conquistas da semana</h3>
          <div className="row" style={{ gap: 6, flexWrap: 'wrap' }}>
            {r.bosses.map((b) => <span key={b} className="pill accent">Venceu {b}</span>)}
            {r.achievements.map((a) => <span key={a.id} className="pill" style={{ color: RARITY[a.rarity].color }}>{a.name}</span>)}
          </div>
        </div>
      )}

      {toolRows.length > 0 && (
        <div className="card stack tight">
          <h3>Ferramentas</h3>
          {toolRows.map(([k, v]) => <div key={k} className="row between small"><span className="muted">{k}</span><span>{v}</span></div>)}
        </div>
      )}
    </div>
  );
}

export function PlanScreen() {
  const [p, setP] = useState<PlanInfo | null>(null);
  const [error, setError] = useState<string | null>(null);
  const load = useCallback(() => { setError(null); api.planInfo().then(setP).catch((e) => setError(friendlyError(e))); }, []);
  useEffect(load, [load]);
  if (error) return <div className="screen"><BackButton to="/perfil" /><ErrorState message={error} onRetry={load} /></div>;
  return (
    <div className="screen">
      <BackButton to="/perfil" />
      <h1>Seu plano</h1>
      {!p ? <Skeleton height={300} /> : (
        <>
          <div className="card hero stack tight">
            <strong style={{ fontSize: 18 }}>{p.premium ? 'Premium ativo' : 'Plano gratuito'}</strong>
            <span className="small muted">
              {p.via === 'plano' ? 'Seu acesso Premium foi liberado pelo administrador.'
                : p.via === 'liberado' ? (p.open_until
                  ? `O Premium está liberado para todos até ${formatDay(p.open_until, { day: 'numeric', month: 'long', year: 'numeric' })}.`
                  : 'O Premium está liberado para todos por tempo limitado.')
                : 'Os recursos marcados com cadeado fazem parte do Premium.'}
            </span>
          </div>
          <div className="card stack tight">
            {p.features.map((f) => (
              <div key={f.id} className="row" style={{ gap: 10, alignItems: 'flex-start' }}>
                <span aria-hidden style={{ width: 22 }}>{f.allowed ? '✓' : '🔒'}</span>
                <span className="grow stack" style={{ gap: 2 }}>
                  <span>{f.name}{!f.premium && <span className="pill" style={{ marginLeft: 6 }}>gratuito</span>}</span>
                  <span className="small faint">{f.description}</span>
                </span>
              </div>
            ))}
          </div>
          <span className="small faint">
            Quando a liberação acabar, nada do que você conquistou é apagado: itens, conquistas, XP e histórico continuam seus.
            Recursos Premium só deixam de poder ser iniciados.
          </span>
        </>
      )}
    </div>
  );
}
