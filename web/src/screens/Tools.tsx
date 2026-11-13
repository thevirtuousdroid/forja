import { useCallback, useEffect, useState, type ReactNode } from 'react';
import { Link } from 'react-router-dom';
import { api, friendlyError, isPremiumError } from '../lib/api';
import { useApp } from '../lib/AppData';
import type { Book, DiaryEntry, HabitTrack, ToolDay, ToolHistory, ToolId, ToolMission, ToolsOverview } from '../lib/types';
import {
  FOOD_DISCLAIMER, MEALS, MOODS, SLEEP_DISCLAIMER, SLEEP_QUALITY, TOOLS, fmtMinutes, moodOf, sleepMinutes, toolLine, type ToolDef,
} from '../lib/tools';
import { DIMENSIONS, formatTarget } from '../lib/game';
import { formatDay } from '../lib/dates';
import { plural } from '../lib/social';
import { HistoryBars, PremiumLock, Ring, Sheet } from '../components/Social';
import { BackButton, Empty, ErrorState, Skeleton } from '../components/ui';
import {
  IconBook, IconBowl, IconDrop, IconGrid, IconLotus, IconMoon, IconPen, IconPhone, IconTimer, IconTrash,
} from '../components/Icons';
import { useFeedback } from '../components/Feedback';

const TOOL_ICONS: Record<ToolDef['id'], ReactNode> = {
  foco: <IconTimer />, agua: <IconDrop />, diario: <IconPen />, habitos: <IconGrid />, sono: <IconMoon />,
  leitura: <IconBook />, meditacao: <IconLotus />, tela: <IconPhone />, alimentacao: <IconBowl />,
};

export function ToolsScreen() {
  const [o, setO] = useState<ToolsOverview | null>(null);
  const [error, setError] = useState<string | null>(null);
  const load = useCallback(() => {
    setError(null);
    api.toolsOverview().then(setO).catch((e) => setError(friendlyError(e)));
  }, []);
  useEffect(load, [load]);

  return (
    <div className="screen">
      <BackButton to="/" />
      <h1>Ferramentas</h1>
      <p className="small muted">Registre o que você fez. Quando um registro cumpre uma missão, ela aparece pronta para você concluir.</p>
      {error && <ErrorState message={error} onRetry={load} />}
      {o && o.ready > 0 && (
        <Link to="/missoes" className="notice">
          <span className="grow"><strong>{plural(o.ready, 'missão pronta', 'missões prontas')}</strong> para concluir</span><span aria-hidden>›</span>
        </Link>
      )}
      <div className="grid-2">
        {TOOLS.map((t) => {
          const locked = t.premium && o !== null && !o.extras;
          return (
            <Link key={t.id} to={t.path} className={`tool-tile ${locked ? 'locked' : ''}`}>
              {locked && <span className="lock" aria-label="Premium">🔒</span>}
              <span className="tool-icon">{TOOL_ICONS[t.id]}</span>
              <strong>{t.name}</strong>
              <span className="small muted">{o ? toolLine(t.id, o.summary) || t.desc : t.desc}</span>
            </Link>
          );
        })}
      </div>
    </div>
  );
}

// ── Peças comuns ────────────────────────────────────────────────────────────

/** Carrega o dia de uma ferramenta, com trava do Premium e recarga. */
export function useTool<T extends ToolId>(tool: T) {
  const [day, setDay] = useState<ToolDay<T> | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [locked, setLocked] = useState(false);
  const reload = useCallback(() => {
    setError(null);
    return api.tool(tool).then(setDay).catch((e) => (isPremiumError(e) ? setLocked(true) : setError(friendlyError(e))));
  }, [tool]);
  useEffect(() => { void reload(); }, [reload]);
  return { day, setDay, error, locked, reload };
}

export function useHistory(tool: ToolId, days: number, key: unknown) {
  const [h, setH] = useState<ToolHistory | null>(null);
  useEffect(() => { api.toolHistory(tool, days).then(setH).catch(() => setH(null)); }, [tool, days, key]);
  return h;
}

/** Missões ligadas à ferramenta, com o botão de concluir quando o registro já cumpre a meta. */
export function ToolMissions({ missions, onDone }: { missions: ToolMission[]; onDone?: () => void }) {
  const { missions: all, complete, refresh, busy } = useApp();
  const { toast } = useFeedback();
  if (missions.length === 0) return null;
  async function finish(tm: ToolMission) {
    const m = all.find((x) => x.id === tm.id);
    if (m) await complete(m);
    else {
      try { await api.completeMission(tm.id); await refresh(); } catch (e) { toast(friendlyError(e), 'error'); }
    }
    onDone?.();
  }
  return (
    <div className="stack tight">
      {missions.map((m) => (
        <div key={m.id} className="card row" style={{ gap: 12 }}>
          <div className="grow stack tight">
            <strong className="ellipsis">{m.name}</strong>
            <span className="small muted">
              {m.status === 'concluida' ? 'Missão concluída ✓'
                : m.ready ? 'Pronta para concluir'
                : m.unit === 'vez' || m.target === 1 ? 'Ainda não cumprida' : `${m.progress} de ${formatTarget(m.target, m.unit)}`}
            </span>
            {m.status === 'pendente' && m.target > 1 && (
              <div className="bar thin"><span style={{ width: `${Math.min(1, m.progress / m.target) * 100}%` }} /></div>
            )}
          </div>
          {m.status === 'pendente' && (
            <button className={`btn sm ${m.ready ? 'primary' : ''}`} disabled={busy.has(m.id)} onClick={() => finish(m)}>Concluir</button>
          )}
        </div>
      ))}
    </div>
  );
}

function ToolFrame({ title, locked, error, onRetry, children }: {
  title: string; locked: boolean; error: string | null; onRetry: () => void; children: ReactNode;
}) {
  return (
    <div className="screen">
      <BackButton to="/ferramentas" />
      <h1>{title}</h1>
      {locked ? <PremiumLock what={title === 'Tempo de tela' ? 'O registro de tempo de tela' : `A ferramenta ${title}`} />
        : error ? <ErrorState message={error} onRetry={onRetry} /> : children}
    </div>
  );
}

function useSave() {
  const { toast } = useFeedback();
  const { loadEvents } = useApp();
  const [saving, setSaving] = useState(false);
  const run = useCallback(async <R,>(fn: () => Promise<R>, msg?: string): Promise<R | null> => {
    setSaving(true);
    try {
      const r = await fn();
      if (msg) toast(msg);
      void loadEvents();
      return r;
    } catch (e) {
      toast(friendlyError(e), 'error');
      return null;
    } finally {
      setSaving(false);
    }
  }, [toast, loadEvents]);
  return { saving, run };
}

// ── Água ────────────────────────────────────────────────────────────────────

export function WaterScreen() {
  const { day, setDay, error, locked, reload } = useTool('agua');
  const { saving, run } = useSave();
  const [n, setN] = useState(0);
  const hist = useHistory('agua', 7, n);
  async function add(cups: number) {
    const r = await run(() => api.logTool('agua', { cups }));
    if (r) { setDay(r); setN((x) => x + 1); }
  }
  async function setCup(ml: number) {
    const r = await run(() => api.updateToolSettings({ agua_ml: ml }));
    if (r) void reload();
  }
  async function setGoal(goal: number) {
    const r = await run(() => api.updateToolSettings({ agua_meta: goal }));
    if (r) void reload();
  }
  const s = day?.summary;
  const hasHabit = (day?.missions.length ?? 0) > 0;
  return (
    <ToolFrame title="Água" locked={locked} error={error} onRetry={reload}>
      {!day || !s ? <Skeleton height={300} /> : (
        <>
          <div className="card stack center" style={{ alignItems: 'center' }}>
            <Ring value={s.cups / Math.max(1, s.goal)} color="var(--attr-foco)">
              <span className="num" style={{ fontSize: 40, fontWeight: 700 }}>{s.cups}</span>
              <span className="small muted">de {s.goal} copos</span>
            </Ring>
            <span className="small faint num">{(s.cups * s.cup_ml / 1000).toLocaleString('pt-BR', { maximumFractionDigits: 2 })} litro{s.cups * s.cup_ml >= 2000 ? 's' : ''} · copo de {s.cup_ml} ml</span>
            <div className="row" style={{ width: '100%' }}>
              <button className="btn" disabled={saving || s.cups === 0} onClick={() => add(-1)} aria-label="Tirar um copo">−1</button>
              <button className="btn primary grow" disabled={saving} onClick={() => add(1)}>+1 copo</button>
            </div>
          </div>
          <ToolMissions missions={day.missions} onDone={reload} />
          {hist && <div className="card stack tight"><h3>Últimos 7 dias</h3><HistoryBars label="Copos por dia" days={hist.days} goal={s.goal} color="var(--attr-foco)" /></div>}
          <div className="card stack tight">
            <h3>Ajustes</h3>
            <span className="small muted">Tamanho do copo</span>
            <div className="chips">
              {[200, 250, 300, 350, 500].map((ml) => <button key={ml} className="chip" aria-pressed={s.cup_ml === ml} disabled={saving} onClick={() => setCup(ml)}>{ml} ml</button>)}
            </div>
            {hasHabit ? (
              <span className="small faint">A meta vem do seu hábito de água e sobe com a progressão semanal.</span>
            ) : (
              <>
                <span className="small muted">Meta diária</span>
                <div className="chips">
                  {[4, 6, 8, 10].map((g) => <button key={g} className="chip" aria-pressed={day.settings.agua_meta === g} disabled={saving} onClick={() => setGoal(g)}>{g} copos</button>)}
                </div>
              </>
            )}
          </div>
        </>
      )}
    </ToolFrame>
  );
}

// ── Sono ────────────────────────────────────────────────────────────────────

export function SleepScreen() {
  const { day, setDay, error, locked, reload } = useTool('sono');
  const { saving, run } = useSave();
  const [bed, setBed] = useState('23:00');
  const [wake, setWake] = useState('07:00');
  const [quality, setQuality] = useState<number | null>(null);
  const [n, setN] = useState(0);
  const hist = useHistory('sono', 14, n);

  useEffect(() => {
    if (!day) return;
    if (day.summary.logged) { setBed(day.summary.bed ?? '23:00'); setWake(day.summary.wake ?? '07:00'); setQuality(day.summary.quality); }
    else setBed(day.settings.sono_deitar);
  }, [day?.summary.logged]); // eslint-disable-line react-hooks/exhaustive-deps

  const mins = sleepMinutes(bed, wake);
  const valid = mins >= 60 && mins <= 960;
  async function save() {
    const r = await run(() => api.logTool('sono', { bed, wake, ...(quality ? { quality } : {}) }), 'Noite registrada.');
    if (r) { setDay(r); setN((x) => x + 1); }
  }
  async function setGoal(min: number) {
    if (await run(() => api.updateToolSettings({ sono_meta: min }))) void reload();
  }

  return (
    <ToolFrame title="Sono" locked={locked} error={error} onRetry={reload}>
      {!day ? <Skeleton height={300} /> : (
        <>
          <div className="card stack">
            <h3>{day.summary.logged ? 'Sua última noite' : 'Como foi a última noite?'}</h3>
            <div className="grid-2">
              <div className="field"><label htmlFor="bed">Deitou</label>
                <input id="bed" type="time" className="input" value={bed} onChange={(e) => setBed(e.target.value)} /></div>
              <div className="field"><label htmlFor="wake">Acordou</label>
                <input id="wake" type="time" className="input" value={wake} onChange={(e) => setWake(e.target.value)} /></div>
            </div>
            <span className={`small ${valid ? 'muted' : ''}`} style={valid ? undefined : { color: 'var(--danger)' }}>
              {valid ? `${fmtMinutes(mins)} de sono` : 'Confira os horários (entre 1 e 16 horas de sono).'}
            </span>
            <span className="small muted">Qualidade</span>
            <div className="chips">
              {SLEEP_QUALITY.map((q, i) => <button key={q} className="chip" aria-pressed={quality === i + 1} onClick={() => setQuality(quality === i + 1 ? null : i + 1)}>{q}</button>)}
            </div>
            <button className="btn primary" disabled={saving || !valid} onClick={save}>{day.summary.logged ? 'Atualizar registro' : 'Registrar noite'}</button>
          </div>
          {hist && (
            <div className="card stack tight">
              <h3>Últimas 2 semanas</h3>
              <HistoryBars label="Horas de sono por noite" days={hist.days} goal={day.settings.sono_meta} color="var(--attr-conhecimento)" format={(v) => fmtMinutes(v)} />
            </div>
          )}
          <div className="card stack tight">
            <h3>Sua meta de sono</h3>
            <div className="chips">
              {[360, 420, 450, 480, 540].map((m) => <button key={m} className="chip" aria-pressed={day.settings.sono_meta === m} disabled={saving} onClick={() => setGoal(m)}>{fmtMinutes(m)}</button>)}
            </div>
          </div>
          <p className="disclaimer">{SLEEP_DISCLAIMER}</p>
        </>
      )}
    </ToolFrame>
  );
}

// ── Alimentação ─────────────────────────────────────────────────────────────

export function FoodScreen() {
  const { day, setDay, error, locked, reload } = useTool('alimentacao');
  const { saving, run } = useSave();
  const [meal, setMeal] = useState<(typeof MEALS)[number]['id']>('almoco');
  const [name, setName] = useState('');
  const [kcal, setKcal] = useState('');

  async function add() {
    const k = kcal.trim() === '' ? undefined : Number(kcal);
    const r = await run(() => api.logTool('alimentacao', { meal, name: name.trim(), ...(k !== undefined ? { kcal: k } : {}) }));
    if (r) { setDay(r); setName(''); setKcal(''); }
  }
  async function remove(id: number) {
    const r = await run(() => api.deleteToolLog(id));
    if (r) setDay(r as ToolDay<'alimentacao'>);
  }

  return (
    <ToolFrame title="Alimentação" locked={locked} error={error} onRetry={reload}>
      {!day ? <Skeleton height={300} /> : (
        <>
          <p className="disclaimer">{FOOD_DISCLAIMER}</p>
          <div className="card stack">
            <div className="chips">
              {MEALS.map((m) => <button key={m.id} className="chip" aria-pressed={meal === m.id} onClick={() => setMeal(m.id)}>{m.label}</button>)}
            </div>
            <div className="field"><label htmlFor="food">O que você comeu</label>
              <input id="food" className="input" value={name} maxLength={60} placeholder="Ex.: arroz, feijão e salada" onChange={(e) => setName(e.target.value)} /></div>
            <div className="field"><label htmlFor="kcal">Calorias (opcional)</label>
              <input id="kcal" className="input" inputMode="numeric" value={kcal} onChange={(e) => setKcal(e.target.value.replace(/\D/g, '').slice(0, 4))} /></div>
            <button className="btn primary" disabled={saving || name.trim().length === 0} onClick={add}>Registrar</button>
          </div>
          <section className="stack tight">
            <div className="row between"><h3>Hoje</h3>{day.summary.with_kcal > 0 && <span className="small muted num">≈ {day.summary.kcal.toLocaleString('pt-BR')} kcal registradas</span>}</div>
            {day.entries.length === 0 ? <span className="small muted">Nada registrado hoje.</span> : day.entries.map((e) => (
              <div key={e.id} className="entry">
                <div className="row between">
                  <span><strong>{MEALS.find((m) => m.id === e.data.meal)?.label}</strong> <span className="muted">· {String(e.data.name)}</span></span>
                  <button className="icon-btn" aria-label="Apagar" onClick={() => remove(e.id)}><IconTrash /></button>
                </div>
                {typeof e.data.kcal === 'number' && <span className="small faint num">≈ {e.data.kcal} kcal</span>}
              </div>
            ))}
          </section>
        </>
      )}
    </ToolFrame>
  );
}

// ── Tempo de tela ───────────────────────────────────────────────────────────

export function ScreenTimeScreen() {
  const { day, setDay, error, locked, reload } = useTool('tela');
  const { saving, run } = useSave();
  const [h, setH] = useState(2);
  const [m, setM] = useState(0);
  const [n, setN] = useState(0);
  const hist = useHistory('tela', 14, n);
  useEffect(() => {
    if (day?.summary.logged && day.summary.minutes !== null) { setH(Math.floor(day.summary.minutes / 60)); setM(day.summary.minutes % 60); }
  }, [day?.summary.logged]); // eslint-disable-line react-hooks/exhaustive-deps

  const total = h * 60 + m;
  async function save() {
    const r = await run(() => api.logTool('tela', { minutes: total }), 'Tempo de tela registrado.');
    if (r) { setDay(r); setN((x) => x + 1); }
  }
  async function setLimit(v: number) {
    if (await run(() => api.updateToolSettings({ tela_limite: v }))) void reload();
  }
  const limit = day?.summary.limit ?? 120;

  return (
    <ToolFrame title="Tempo de tela" locked={locked} error={error} onRetry={reload}>
      {!day ? <Skeleton height={300} /> : (
        <>
          <p className="small muted">O iPhone não deixa outros apps lerem o tempo de uso. Veja em <strong>Ajustes › Tempo de Uso</strong> e registre aqui.</p>
          <div className="card stack">
            <h3>Hoje</h3>
            <div className="grid-2">
              <div className="field"><label htmlFor="th">Horas</label>
                <input id="th" className="input" type="number" min={0} max={24} inputMode="numeric" value={h} onChange={(e) => setH(Math.max(0, Math.min(24, Number(e.target.value) || 0)))} /></div>
              <div className="field"><label htmlFor="tm">Minutos</label>
                <input id="tm" className="input" type="number" min={0} max={59} step={5} inputMode="numeric" value={m} onChange={(e) => setM(Math.max(0, Math.min(59, Number(e.target.value) || 0)))} /></div>
            </div>
            <span className="small" style={{ color: total <= limit ? 'var(--ok)' : 'var(--warn)' }}>
              {total <= limit ? `Dentro do seu limite de ${fmtMinutes(limit)}.` : `${fmtMinutes(total - limit)} acima do seu limite de ${fmtMinutes(limit)}.`}
            </span>
            <button className="btn primary" disabled={saving || total > 1440} onClick={save}>{day.summary.logged ? 'Atualizar' : 'Registrar'}</button>
          </div>
          <ToolMissions missions={day.missions} onDone={reload} />
          {hist && <div className="card stack tight"><h3>Últimas 2 semanas</h3><HistoryBars label="Tempo de tela por dia" days={hist.days} goal={limit} color="var(--attr-disciplina)" format={(v) => fmtMinutes(v)} /></div>}
          <div className="card stack tight">
            <h3>Seu limite diário</h3>
            <div className="chips">
              {[60, 90, 120, 180, 240].map((v) => <button key={v} className="chip" aria-pressed={limit === v} disabled={saving} onClick={() => setLimit(v)}>{fmtMinutes(v)}</button>)}
            </div>
          </div>
        </>
      )}
    </ToolFrame>
  );
}

// ── Leitura ─────────────────────────────────────────────────────────────────

export function ReadingScreen() {
  const { day, setDay, error, locked, reload } = useTool('leitura');
  const { saving, run } = useSave();
  const [books, setBooks] = useState<Book[] | null>(null);
  const [pages, setPages] = useState('');
  const [minutes, setMinutes] = useState('');
  const [bookId, setBookId] = useState<string | null>(null);
  const [adding, setAdding] = useState(false);
  const [title, setTitle] = useState('');
  const [author, setAuthor] = useState('');
  const [total, setTotal] = useState('');
  const [n, setN] = useState(0);
  const hist = useHistory('leitura', 14, n);

  const loadBooks = useCallback(() => {
    api.books().then((b) => { setBooks(b); setBookId((id) => id ?? b.find((x) => x.status === 'lendo')?.id ?? null); }).catch(() => setBooks([]));
  }, []);
  useEffect(loadBooks, [loadBooks]);

  async function log() {
    const r = await run(() => api.logTool('leitura', {
      pages: Number(pages) || 0, minutes: Number(minutes) || 0, ...(bookId ? { book_id: bookId } : {}),
    }), 'Leitura registrada.');
    if (r) { setDay(r); setPages(''); setMinutes(''); setN((x) => x + 1); loadBooks(); }
  }
  async function addBook() {
    const b = await run(() => api.saveBook(null, title.trim(), author.trim(), total ? Number(total) : null), 'Livro adicionado.');
    if (b) { setAdding(false); setTitle(''); setAuthor(''); setTotal(''); setBookId(b.id); loadBooks(); }
  }
  async function setStatus(b: Book, status: Book['status']) {
    if (await run(() => api.setBookStatus(b.id, status), status === 'concluido' ? 'Livro concluído!' : undefined)) { loadBooks(); void reload(); }
  }
  const reading = books?.filter((b) => b.status === 'lendo') ?? [];

  return (
    <ToolFrame title="Leitura" locked={locked} error={error} onRetry={reload}>
      {!day ? <Skeleton height={300} /> : (
        <>
          <div className="card stack">
            <h3>Registrar leitura</h3>
            <div className="grid-2">
              <div className="field"><label htmlFor="pg">Páginas</label>
                <input id="pg" className="input" inputMode="numeric" value={pages} onChange={(e) => setPages(e.target.value.replace(/\D/g, '').slice(0, 4))} /></div>
              <div className="field"><label htmlFor="mn">Minutos</label>
                <input id="mn" className="input" inputMode="numeric" value={minutes} onChange={(e) => setMinutes(e.target.value.replace(/\D/g, '').slice(0, 3))} /></div>
            </div>
            {reading.length > 0 && (
              <div className="chips" role="group" aria-label="Livro">
                <button className="chip" aria-pressed={bookId === null} onClick={() => setBookId(null)}>Sem livro</button>
                {reading.map((b) => <button key={b.id} className="chip" aria-pressed={bookId === b.id} onClick={() => setBookId(b.id)}>{b.title}</button>)}
              </div>
            )}
            <button className="btn primary" disabled={saving || (!Number(pages) && !Number(minutes))} onClick={log}>Registrar</button>
            <span className="small faint">Hoje: {plural(day.summary.pages, 'página', 'páginas')} · {fmtMinutes(day.summary.minutes)}</span>
          </div>
          <ToolMissions missions={day.missions} onDone={reload} />
          <section className="stack tight">
            <div className="row between"><h3>Livros</h3><button className="link" onClick={() => setAdding(true)}>Adicionar livro</button></div>
            {books === null ? <Skeleton /> : books.length === 0 ? <span className="small muted">Cadastre o livro que você está lendo para acompanhar as páginas.</span> : books.map((b) => (
              <div key={b.id} className="card stack tight">
                <div className="row between">
                  <strong className="ellipsis">{b.title}</strong>
                  <span className={`pill ${b.status === 'concluido' ? 'ok' : ''}`}>{b.status === 'lendo' ? 'Lendo' : b.status === 'concluido' ? 'Concluído' : 'Pausado'}</span>
                </div>
                {b.author && <span className="small muted">{b.author}</span>}
                {b.total_pages ? (
                  <>
                    <div className="bar thin"><span style={{ width: `${Math.min(1, b.current_page / b.total_pages) * 100}%` }} /></div>
                    <span className="small faint num">Página {b.current_page} de {b.total_pages}</span>
                  </>
                ) : <span className="small faint num">{plural(b.current_page, 'página lida', 'páginas lidas')}</span>}
                <div className="row" style={{ gap: 6 }}>
                  {b.status !== 'concluido' && <button className="btn sm" disabled={saving} onClick={() => setStatus(b, 'concluido')}>Terminei</button>}
                  {b.status === 'lendo' && <button className="btn sm ghost" disabled={saving} onClick={() => setStatus(b, 'pausado')}>Pausar</button>}
                  {b.status !== 'lendo' && <button className="btn sm ghost" disabled={saving} onClick={() => setStatus(b, 'lendo')}>Voltar a ler</button>}
                </div>
              </div>
            ))}
          </section>
          {hist && <div className="card stack tight"><h3>Páginas nas últimas 2 semanas</h3><HistoryBars label="Páginas por dia" days={hist.days} color="var(--attr-conhecimento)" /></div>}
          {adding && (
            <Sheet title="Novo livro" onClose={() => setAdding(false)}>
              <div className="field"><label htmlFor="bt">Título</label><input id="bt" className="input" value={title} maxLength={120} onChange={(e) => setTitle(e.target.value)} /></div>
              <div className="field"><label htmlFor="ba">Autor (opcional)</label><input id="ba" className="input" value={author} maxLength={80} onChange={(e) => setAuthor(e.target.value)} /></div>
              <div className="field"><label htmlFor="bp">Total de páginas (opcional)</label>
                <input id="bp" className="input" inputMode="numeric" value={total} onChange={(e) => setTotal(e.target.value.replace(/\D/g, '').slice(0, 4))} /></div>
              <button className="btn primary block" disabled={saving || !title.trim()} onClick={addBook}>Adicionar</button>
            </Sheet>
          )}
        </>
      )}
    </ToolFrame>
  );
}

// ── Diário ──────────────────────────────────────────────────────────────────

const PROMPTS = ['O que deu certo hoje?', 'O que pesou hoje?', 'O que você quer lembrar deste dia?', 'O que você faria diferente amanhã?'];

export function DiaryScreen() {
  const { day, setDay, error, locked, reload } = useTool('diario');
  const { saving, run } = useSave();
  const [mood, setMood] = useState<number | null>(null);
  const [text, setText] = useState('');
  const [gratitude, setGratitude] = useState('');
  const [past, setPast] = useState<DiaryEntry[] | null>(null);
  const [open, setOpen] = useState<number | null>(null);
  const prompt = PROMPTS[new Date().getDate() % PROMPTS.length];

  const loadPast = useCallback(() => { api.diary(30).then(setPast).catch(() => setPast([])); }, []);
  useEffect(loadPast, [loadPast]);
  useEffect(() => {
    const e = day?.entries[0];
    if (e) { setText(String(e.data.text ?? '')); setMood(typeof e.data.mood === 'number' ? e.data.mood : null); setGratitude(String(e.data.gratitude ?? '')); }
  }, [day?.entries[0]?.id]); // eslint-disable-line react-hooks/exhaustive-deps

  async function save() {
    const r = await run(() => api.logTool('diario', { text, ...(mood ? { mood } : {}), ...(gratitude.trim() ? { gratitude } : {}) }), 'Diário salvo.');
    if (r) { setDay(r); loadPast(); }
  }

  return (
    <ToolFrame title="Diário" locked={locked} error={error} onRetry={reload}>
      {!day ? <Skeleton height={300} /> : (
        <>
          <div className="card stack">
            <span className="small muted">Como você está?</span>
            <div className="chips" role="group" aria-label="Humor">
              {MOODS.map((m) => (
                <button key={m.value} className="chip" aria-pressed={mood === m.value} aria-label={m.label} onClick={() => setMood(mood === m.value ? null : m.value)}>
                  <span style={{ fontSize: 20 }} aria-hidden>{m.emoji}</span>
                </button>
              ))}
            </div>
            <div className="field"><label htmlFor="dtext">{prompt}</label>
              <textarea id="dtext" className="input" rows={6} maxLength={2000} value={text} onChange={(e) => setText(e.target.value)} /></div>
            <div className="field"><label htmlFor="dgrat">Pelo que você é grato hoje? (opcional)</label>
              <input id="dgrat" className="input" maxLength={280} value={gratitude} onChange={(e) => setGratitude(e.target.value)} /></div>
            <button className="btn primary" disabled={saving || !text.trim()} onClick={save}>{day.summary.written ? 'Atualizar' : 'Salvar'}</button>
            <span className="small faint">Só você lê o seu diário. O Mentor usa apenas o número do humor, nunca o texto.</span>
          </div>
          <ToolMissions missions={day.missions} onDone={reload} />
          <section className="stack tight">
            <h3>Dias anteriores</h3>
            {past === null ? <Skeleton /> : past.filter((e) => e.day !== day.day).length === 0 ? <span className="small muted">As próximas entradas aparecem aqui.</span>
              : past.filter((e) => e.day !== day.day).map((e) => (
                <button key={e.id} className="entry" style={{ textAlign: 'left', cursor: 'pointer', color: 'inherit' }} onClick={() => setOpen(open === e.id ? null : e.id)} aria-expanded={open === e.id}>
                  <div className="row between">
                    <strong>{formatDay(e.day, { weekday: 'short', day: 'numeric', month: 'short' })}</strong>
                    <span aria-label={moodOf(e.mood)?.label}>{moodOf(e.mood)?.emoji ?? ''}</span>
                  </div>
                  <p style={open === e.id ? undefined : { display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>{e.text}</p>
                  {open === e.id && e.gratitude && <span className="small faint">Gratidão: {e.gratitude}</span>}
                </button>
              ))}
          </section>
        </>
      )}
    </ToolFrame>
  );
}

// ── Rastreador de hábitos ───────────────────────────────────────────────────

export function HabitTrackerScreen() {
  const [list, setList] = useState<HabitTrack[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const load = useCallback(() => { setError(null); api.habitTracker().then(setList).catch((e) => setError(friendlyError(e))); }, []);
  useEffect(load, [load]);
  return (
    <div className="screen">
      <BackButton to="/ferramentas" />
      <h1>Hábitos</h1>
      <p className="small muted">Cada quadrado é um dia das últimas 4 semanas.</p>
      <div className="legend">
        <span><i style={{ background: 'var(--accent)' }} />feito</span>
        <span><i style={{ background: 'color-mix(in srgb, var(--danger) 22%, var(--surface-2))' }} />não feito</span>
        <span><i style={{ border: '1px solid var(--line)' }} />antes de começar ou pausado</span>
      </div>
      {error ? <ErrorState message={error} onRetry={load} /> : !list ? <><Skeleton height={150} /><Skeleton height={150} /></> : list.length === 0 ? (
        <Empty title="Nenhum hábito ainda" />
      ) : list.map((h) => (
        <div key={h.habit.id} className="card stack tight" style={h.habit.active ? undefined : { opacity: 0.65 }}>
          <div className="row between">
            <strong className="ellipsis">{h.habit.name}</strong>
            {h.streak > 0 ? <span className="pill accent num">🔥 {h.streak}</span> : !h.habit.active ? <span className="pill">Pausado</span> : null}
          </div>
          <span className="small muted">{DIMENSIONS[h.habit.dimension].short} · meta {formatTarget(h.habit.current_target, h.habit.unit)} · {h.done} de 28 dias</span>
          <div className="track-grid" aria-label={`${h.habit.name}: feito em ${h.done} dos últimos 28 dias`}>
            {h.days.map((d) => <i key={d.date} className={d.status} title={`${formatDay(d.date)}: ${d.status}`} />)}
          </div>
        </div>
      ))}
    </div>
  );
}
