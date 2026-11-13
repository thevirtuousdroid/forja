import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { api, friendlyError } from '../lib/api';
import { useApp } from '../lib/AppData';
import type { Mission } from '../lib/types';
import { ATTRIBUTES, DIMENSIONS, KIND_LABEL, PERIOD_LABEL, formatTarget } from '../lib/game';
import { formatDay, localDay, weekdayShort } from '../lib/dates';
import { BackButton, Difficulty, ErrorState, Loading } from '../components/ui';
import { useFeedback } from '../components/Feedback';
import { IconClock } from '../components/Icons';
import { TOOLS, toolForTemplate } from '../lib/tools';

const STATUS_LABEL = { pendente: 'Pendente', concluida: 'Concluída', expirada: 'Expirada' } as const;

export function MissionDetailScreen() {
  const { id } = useParams();
  const { missions, habits, busy, complete, undo, profile, refresh } = useApp();
  const { toast } = useFeedback();
  const [mission, setMission] = useState<Mission | null>(missions.find((m) => m.id === id) ?? null);
  const [history, setHistory] = useState<Mission[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [target, setTarget] = useState<number | null>(null);
  const [saving, setSaving] = useState(false);

  const habit = mission?.habit_id && mission.kind === 'diaria' ? habits.find((h) => h.id === mission.habit_id) : undefined;

  useEffect(() => {
    const fromList = missions.find((m) => m.id === id);
    if (fromList) { setMission(fromList); return; }
    api.mission(id!).then(setMission).catch((e) => setError(friendlyError(e)));
  }, [id, missions]);

  useEffect(() => {
    if (mission?.habit_id && mission.kind === 'diaria') api.habitHistory(mission.habit_id).then(setHistory).catch(() => setHistory([]));
  }, [mission?.habit_id, mission?.kind, mission?.status]);

  useEffect(() => { if (habit) setTarget(habit.current_target); }, [habit?.current_target]); // eslint-disable-line react-hooks/exhaustive-deps

  if (error) return <div className="screen no-tabs"><BackButton /><ErrorState message={error} /></div>;
  if (!mission) return <div className="screen no-tabs"><BackButton /><Loading /></div>;

  const done = mission.status === 'concluida';
  const sourceHabit = mission.habit_id ? habits.find((h) => h.id === mission.habit_id) : undefined;
  const toolId = mission.status === 'pendente' ? toolForTemplate(sourceHabit?.template_id, mission.unit) : null;
  const tool = toolId ? TOOLS.find((t) => t.id === toolId) : undefined;
  const canUndo = done && mission.completed_at && profile && localDay(mission.completed_at, profile.timezone) === localDay(new Date().toISOString(), profile.timezone);

  async function saveHabit(active: boolean) {
    if (!habit || target === null) return;
    setSaving(true);
    try {
      await api.adjustHabit(habit.id, target, active);
      toast(active ? 'Meta atualizada. Vale a partir de agora.' : 'Hábito pausado. Você pode retomar no Perfil.');
      await refresh();
    } catch (e) {
      toast(friendlyError(e), 'error');
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="screen no-tabs">
      <BackButton />
      <div className="stack tight">
        <div className="row" style={{ gap: 8, flexWrap: 'wrap' }}>
          <span className="pill accent">{KIND_LABEL[mission.kind]}</span>
          <span className={`pill ${done ? 'ok' : ''}`}>{STATUS_LABEL[mission.status]}</span>
        </div>
        <h1>{mission.name}</h1>
        {mission.description && <p className="muted">{mission.description}</p>}
      </div>

      <div className="card stack">
        <div className="row between"><span className="muted">Meta</span><strong>{formatTarget(mission.target_value, mission.unit)}</strong></div>
        <div className="row between"><span className="muted">Tempo estimado</span><span className="row" style={{ gap: 4 }}><IconClock /> {mission.estimated_minutes} min</span></div>
        <div className="row between"><span className="muted">Dificuldade</span><Difficulty value={mission.difficulty} /></div>
        <div className="row between"><span className="muted">Área</span><span>{DIMENSIONS[mission.dimension].label}</span></div>
        <div className="row between"><span className="muted">Horário recomendado</span><span>{PERIOD_LABEL[mission.period]}</span></div>
        <div className="row between"><span className="muted">Frequência</span><span>{mission.frequency === 'diaria' ? 'Todo dia' : mission.frequency === 'semanal' ? 'Uma vez na semana' : 'Única'}</span></div>
        <div className="row between">
          <span className="muted">Prazo</span>
          <span>{mission.mission_date === mission.due_date ? formatDay(mission.mission_date) : `${formatDay(mission.mission_date)} a ${formatDay(mission.due_date)}`}</span>
        </div>
        {mission.completed_at && <div className="row between"><span className="muted">Concluída em</span><span>{new Date(mission.completed_at).toLocaleString('pt-BR', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })}</span></div>}
      </div>

      <div className="card stack">
        <div className="row between">
          <span className="muted">Recompensa</span>
          <strong className="num" style={{ color: 'var(--accent-2)' }}>+{mission.xp_reward} XP</strong>
        </div>
        <div className="row" style={{ gap: 8, flexWrap: 'wrap' }}>
          <span className="pill"><span style={{ color: ATTRIBUTES[mission.attr_primary].color }}>●</span> {ATTRIBUTES[mission.attr_primary].label} 70%</span>
          <span className="pill"><span style={{ color: ATTRIBUTES[mission.attr_secondary].color }}>●</span> {ATTRIBUTES[mission.attr_secondary].label} 30%</span>
        </div>
      </div>

      {history.length > 1 && (
        <div className="card stack">
          <h3>Últimos dias</h3>
          <div className="row" style={{ gap: 6 }}>
            {[...history].reverse().map((h) => (
              <div key={h.id} className="stack tight" style={{ alignItems: 'center', flex: 1 }}>
                <span style={{
                  width: '100%', aspectRatio: '1', maxWidth: 26, borderRadius: 6,
                  background: h.status === 'concluida' ? 'var(--accent)' : h.status === 'expirada' ? 'var(--surface-3)' : 'transparent',
                  border: h.status === 'pendente' ? '1px dashed var(--line)' : 'none',
                }} title={`${formatDay(h.mission_date)}: ${STATUS_LABEL[h.status]}`} />
                <span className="faint" style={{ fontSize: 10 }}>{weekdayShort(h.mission_date)}</span>
              </div>
            ))}
          </div>
        </div>
      )}

      {habit && target !== null && (
        <div className="card stack">
          <div className="row between">
            <h3>Ajustar meta</h3>
            <span className="num">{formatTarget(target, habit.unit)}</span>
          </div>
          {habit.max_value > habit.base_value ? (
            <>
              <input type="range" min={habit.base_value} max={habit.max_value} step={habit.step || 1} value={target}
                     onChange={(e) => setTarget(Number(e.target.value))} aria-label="Nova meta" />
              <div className="row between small faint">
                <span>Início: {formatTarget(habit.base_value, habit.unit)}</span>
                <span>Teto: {formatTarget(habit.max_value, habit.unit)}</span>
              </div>
              <p className="small muted">Se a meta está pesada, reduzir não é falhar: é ajustar o plano à sua realidade. A progressão automática só aumenta depois de 5 dias cumpridos na semana.</p>
            </>
          ) : <p className="small muted">Este hábito tem meta fixa.</p>}
          <div className="row">
            {habit.max_value > habit.base_value && (
              <button className="btn sm grow" disabled={saving || target === habit.current_target} onClick={() => saveHabit(true)}>Salvar meta</button>
            )}
            <button className="btn sm ghost danger" disabled={saving} onClick={() => saveHabit(false)}>Pausar hábito</button>
          </div>
        </div>
      )}

      {tool && (
        <Link to={tool.id === 'foco' ? `${tool.path}?missao=${mission.id}` : tool.path} className="btn block">
          {tool.id === 'foco' ? 'Fazer com o timer de foco' : `Registrar em ${tool.name}`}
        </Link>
      )}

      <div className="sticky-actions">
        {mission.status === 'pendente' && (
          <button className="btn primary block" disabled={busy.has(mission.id)} onClick={() => complete(mission)}>Concluir missão</button>
        )}
        {canUndo && (
          <button className="btn block" disabled={busy.has(mission.id)} onClick={() => undo(mission)}>Desfazer conclusão</button>
        )}
      </div>
    </div>
  );
}
