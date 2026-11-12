import { Link } from 'react-router-dom';
import { useApp } from '../lib/AppData';
import { PERIOD_LABEL, PERIOD_ORDER } from '../lib/game';
import { formatDay } from '../lib/dates';
import { Empty, ErrorState, MissionItem, Skeleton } from '../components/ui';
import { IconPlus } from '../components/Icons';
import type { Mission } from '../lib/types';

export function MissionsScreen() {
  const { today, missions, busy, complete, undo, error, refresh, loading } = useApp();
  if (error && !today) return <div className="screen"><ErrorState message={error} onRetry={refresh} /></div>;
  if (!today) return <div className="screen"><Skeleton height={40} /><Skeleton /><Skeleton /><Skeleton /></div>;

  const toggle = (m: Mission) => (m.status === 'concluida' ? undo(m) : complete(m));
  const weekly = missions.filter((m) => m.kind === 'semanal' || m.kind === 'especial');
  const surprise = missions.filter((m) => m.kind === 'surpresa');
  const regular = missions.filter((m) => m.kind === 'diaria' || m.kind === 'personalizada');
  const done = regular.filter((m) => m.status === 'concluida').length;

  const list = (ms: Mission[]) => (
    <div className="stack tight">
      {ms.map((m) => <MissionItem key={m.id} mission={m} busy={busy.has(m.id)} onToggle={toggle} />)}
    </div>
  );

  return (
    <div className="screen">
      <div className="row between">
        <div className="stack tight">
          <h1>Missões</h1>
          <span className="small muted">{formatDay(today.today, { weekday: 'long', day: 'numeric', month: 'long' })} · {done} de {regular.length} concluídas</span>
        </div>
        <Link to="/missoes/nova" className="btn sm primary" aria-label="Criar missão"><IconPlus size={18} /> Nova</Link>
      </div>

      {loading && missions.length === 0 && <><Skeleton /><Skeleton /></>}
      {!loading && missions.length === 0 && (
        <Empty title="Nenhuma missão para hoje">
          <span className="small">Crie uma missão personalizada ou volte amanhã.</span>
        </Empty>
      )}

      {PERIOD_ORDER.map((p) => {
        const ms = regular.filter((m) => m.period === p).sort((a, b) => a.name.localeCompare(b.name));
        if (ms.length === 0) return null;
        return (
          <section key={p} className="stack tight">
            <span className="tiny faint">{PERIOD_LABEL[p]}</span>
            {list(ms)}
          </section>
        );
      })}

      {weekly.length > 0 && (
        <section className="stack tight">
          <span className="tiny faint">Desta semana</span>
          {weekly.map((m) => (
            <div key={m.id} className="stack tight">
              <MissionItem mission={m} busy={busy.has(m.id)} onToggle={toggle} />
              {m.status === 'pendente' && <span className="small faint" style={{ paddingLeft: 12 }}>Vale até {formatDay(m.due_date, { weekday: 'long' })}</span>}
            </div>
          ))}
        </section>
      )}

      {surprise.length > 0 && (
        <section className="stack tight">
          <span className="tiny faint">Surpresa · opcional</span>
          {list(surprise)}
        </section>
      )}
    </div>
  );
}
