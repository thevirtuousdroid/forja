import { useEffect, useRef, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { api, friendlyError } from '../lib/api';
import { useApp } from '../lib/AppData';
import type { Boss, BossesInfo, Mission } from '../lib/types';
import { DIMENSIONS } from '../lib/game';
import { RARITY, SLOTS, avatarOf, midName, modeDef } from '../lib/rpg';
import { addDays, formatDay, parseDay } from '../lib/dates';
import { BossArt } from '../components/BossArt';
import { Avatar } from '../components/Avatar';
import { BackButton, ErrorState, MissionItem, Skeleton } from '../components/ui';
import { useFeedback } from '../components/Feedback';

export function Stars({ n }: { n: number }) {
  return (
    <span className="stars" aria-label={`Dificuldade ${n} de 5`}>
      {[1, 2, 3, 4, 5].map((i) => <span key={i} className={i <= n ? '' : 'off'}>★</span>)}
    </span>
  );
}

export function lockText(b: Boss, day: number): string {
  if (!b.lock) return '';
  switch (b.lock.reason) {
    case 'dia': return `Aparece no dia ${b.lock.day} do programa (faltam ${(b.lock.day ?? 0) - day} ${(b.lock.day ?? 0) - day === 1 ? 'dia' : 'dias'}).`;
    case 'vitorias': return `Vença ${b.lock.needed} chefes antes (você venceu ${b.lock.have}).`;
    case 'habito': return `Precisa de um hábito ativo de ${DIMENSIONS[b.lock.dimension!].label}.`;
  }
}

export function hpLeft(b: Boss) {
  return b.fight ? b.fight.hp - b.fight.effective : b.hp;
}

function useBosses() {
  const { missions } = useApp();
  const [info, setInfo] = useState<BossesInfo | null>(null);
  const [error, setError] = useState<string | null>(null);
  const load = () => {
    setError(null);
    return api.bosses().then(setInfo).catch((e) => setError(friendlyError(e)));
  };
  useEffect(() => { void load(); }, [missions]); // eslint-disable-line react-hooks/exhaustive-deps
  return { info, error, load };
}

export function BossesScreen() {
  const { info, error, load } = useBosses();
  if (error) return <div className="screen"><BackButton to="/jornada" /><ErrorState message={error} onRetry={load} /></div>;
  if (!info) return <div className="screen"><BackButton to="/jornada" /><Skeleton height={40} /><Skeleton height={110} /><Skeleton height={110} /></div>;

  const ordered = [...info.bosses].sort((a, b) => (a.state === 'ativo' ? -1 : b.state === 'ativo' ? 1 : a.sort - b.sort));
  const mode = modeDef(info.mode);

  return (
    <div className="screen">
      <BackButton to="/jornada" />
      <h1>Chefes</h1>
      <p className="muted small">
        Cada chefe representa um obstáculo real. Um golpe é um dia em que você fez o que ele exige, então só a constância vence.
        Você enfrenta um chefe por vez.
      </p>
      {mode.id !== 'normal' && <p className="small" style={{ color: 'var(--warn)' }}>Modo {mode.name}: {mode.consequences[0]}</p>}

      <div className="stack tight">
        {ordered.map((b) => (
          <Link key={b.id} to={`/jornada/chefes/${b.id}`} className={`boss-card ${b.state === 'ativo' ? 'active' : ''}`}>
            <BossArt id={b.id} size={76} locked={b.state === 'bloqueado'} damage={b.fight ? b.fight.effective / b.fight.hp : 0} />
            <div className="grow stack tight">
              <div className="row between" style={{ gap: 6, alignItems: 'flex-start' }}>
                <strong style={{ minWidth: 0 }}>{b.name}</strong>
                <Stars n={b.difficulty} />
              </div>
              <span className="small muted">{b.epithet}</span>
              {b.state === 'ativo' && b.fight && (
                <>
                  <div className="hp" aria-label={`Vida do chefe: ${hpLeft(b)} de ${b.fight.hp}`}><span style={{ width: `${(hpLeft(b) / b.fight.hp) * 100}%` }} /></div>
                  <span className="small faint num">{b.fight.effective}/{b.fight.hp} golpes · {b.fight.days_left} {b.fight.days_left === 1 ? 'dia restante' : 'dias restantes'}</span>
                </>
              )}
              {b.state === 'bloqueado' && <span className="small faint">🔒 {lockText(b, info.day)}</span>}
              {b.state === 'disponivel' && <span className="small" style={{ color: 'var(--accent-2)' }}>Disponível · {b.hp} golpes em {b.window_days} dias</span>}
              {b.state === 'vencido' && <span className="small" style={{ color: 'var(--ok)' }}>Vencido{b.victories > 1 ? ` ${b.victories}×` : ''} · revanche disponível</span>}
            </div>
          </Link>
        ))}
      </div>
    </div>
  );
}

function qualifying(b: Boss, missions: Mission[], today: string): Mission[] {
  const todays = missions.filter((m) => m.status === 'pendente' && m.mission_date <= today && m.due_date >= today);
  if (b.hit_rule === 'dimensao') return todays.filter((m) => m.dimension === b.dimension);
  if (b.hit_rule === 'dia_perfeito') return todays.filter((m) => m.kind === 'diaria' && m.mission_date === today);
  return todays.filter((m) => m.kind !== 'surpresa');
}

export function BossDetailScreen() {
  const { id } = useParams();
  const nav = useNavigate();
  const { info, error, load } = useBosses();
  const { profile, today, missions, busy, complete, undo, refresh } = useApp();
  const { toast } = useFeedback();
  const [confirm, setConfirm] = useState<'start' | 'quit' | null>(null);
  const [acting, setActing] = useState(false);
  const [hitAnim, setHitAnim] = useState(0);
  const lastEff = useRef<number | null>(null);

  const b = info?.bosses.find((x) => x.id === id);
  useEffect(() => {
    const eff = b?.fight?.effective ?? null;
    if (eff !== null && lastEff.current !== null && eff > lastEff.current) setHitAnim((n) => n + 1);
    lastEff.current = eff;
  }, [b?.fight?.effective]);

  if (error) return <div className="screen no-tabs"><BackButton to="/jornada/chefes" /><ErrorState message={error} onRetry={load} /></div>;
  if (!info || !today) return <div className="screen no-tabs"><BackButton to="/jornada/chefes" /><Skeleton height={220} /><Skeleton height={140} /></div>;
  if (!b) return <div className="screen no-tabs"><BackButton to="/jornada/chefes" /><ErrorState message="Chefe não encontrado." /></div>;

  const active = info.bosses.find((x) => x.state === 'ativo');
  const otherActive = active && active.id !== b.id ? active : null;
  const mode = modeDef(info.mode);
  const fight = b.fight;
  const damage = fight ? fight.effective / fight.hp : 0;
  const avatar = avatarOf(profile);
  const deadlineIfStart = addDays(today.today, b.window_days - 1);

  async function start() {
    setActing(true);
    try {
      await api.startBoss(b!.id);
      setConfirm(null);
      await Promise.all([load(), refresh()]);
      toast(`A batalha contra ${midName(b!.name)} começou.`);
    } catch (e) {
      toast(friendlyError(e), 'error');
    } finally {
      setActing(false);
    }
  }
  async function quit() {
    setActing(true);
    try {
      await api.abandonBoss();
      setConfirm(null);
      await Promise.all([load(), refresh()]);
      toast('Você deixou a batalha. Dá para voltar quando quiser.');
    } catch (e) {
      toast(friendlyError(e), 'error');
    } finally {
      setActing(false);
    }
  }

  const strip = fight ? Array.from({ length: Math.round((parseDay(fight.deadline).getTime() - parseDay(fight.started_on).getTime()) / 86400000) + 1 }, (_, i) => {
    const date = addDays(fight.started_on, i);
    const d = fight.days.find((x) => x.date === date);
    const cls = date > today.today ? 'future' : d?.hit ? 'hit' : d?.heal ? 'heal' : date === today.today ? 'today' : '';
    return { date, cls, label: d?.hit ? '✓' : d?.heal ? '↺' : String(i + 1) };
  }) : [];
  const toDo = fight ? qualifying(b, missions, today.today) : [];

  return (
    <div className="screen no-tabs">
      <BackButton to="/jornada/chefes" />
      <div className="stack" style={{ alignItems: 'center', textAlign: 'center' }}>
        <div key={hitAnim} className={hitAnim ? 'boss-hit' : ''}>
          <BossArt id={b.id} size={196} damage={damage} locked={b.state === 'bloqueado'} />
        </div>
        <span className="tiny muted">{b.epithet}</span>
        <h1>{b.name}</h1>
        <Stars n={b.difficulty} />
      </div>

      {fight && (
        <div className="card stack">
          <div className="row between">
            <strong>Vida do chefe</strong>
            <span className="num">{hpLeft(b)} / {fight.hp}</span>
          </div>
          <div className="hp" role="progressbar" aria-valuemin={0} aria-valuemax={fight.hp} aria-valuenow={hpLeft(b)} aria-label="Vida do chefe">
            <span style={{ width: `${(hpLeft(b) / fight.hp) * 100}%` }} />
          </div>
          <div className="day-strip" aria-label="Dias da batalha">
            {strip.map((s) => <i key={s.date} className={s.cls} title={formatDay(s.date)}>{s.label}</i>)}
          </div>
          <span className="small faint">
            Até {formatDay(fight.deadline, { weekday: 'long', day: 'numeric', month: 'short' })} · {fight.days_left} {fight.days_left === 1 ? 'dia restante' : 'dias restantes'}
            {fight.heals > 0 && ` · o chefe se recuperou ${fight.heals}×`}
            {fight.rematch && ' · revanche'}
          </span>
          {fight.today_hit ? (
            <p style={{ color: 'var(--ok)' }}><strong>Golpe de hoje garantido.</strong> Volte amanhã para o próximo.</p>
          ) : (
            <>
              <p className="small">
                <strong>Ainda sem golpe hoje.</strong>{' '}
                {b.hit_rule === 'dimensao' && `Conclua uma missão de ${DIMENSIONS[b.dimension!].label}.`}
                {b.hit_rule === 'meta_diaria' && 'Cumpra a sua meta do dia.'}
                {b.hit_rule === 'dia_perfeito' && 'Conclua todas as missões diárias do plano.'}
              </p>
              {toDo.length > 0 ? (
                <div className="stack tight">
                  {toDo.slice(0, 6).map((m) => (
                    <MissionItem key={m.id} mission={m} busy={busy.has(m.id)} onToggle={(x) => (x.status === 'concluida' ? undo(x) : complete(x))} />
                  ))}
                </div>
              ) : b.hit_rule === 'dimensao' && (
                <p className="small muted">Não há missão dessa área pendente hoje. <Link to="/missoes/nova">Criar uma missão</Link></p>
              )}
            </>
          )}
        </div>
      )}

      <p className="muted">{b.story}</p>

      <div className="card stack">
        <div className="row between"><span className="muted">Objetivo</span></div>
        <p>{b.objective}</p>
        <div className="row between"><span className="muted">Golpes necessários</span><strong className="num">{fight?.hp ?? b.hp}</strong></div>
        <div className="row between"><span className="muted">Prazo</span><strong className="num">{b.window_days} dias</strong></div>
        <div className="row between"><span className="muted">Recompensa</span><strong className="num" style={{ color: 'var(--accent-2)' }}>+{b.victories > 0 ? Math.round(b.xp_reward / 2) : b.xp_reward} XP</strong></div>
        {b.victories > 0 && <span className="small faint">Revanche rende metade do XP. Os itens você já ganhou.</span>}
      </div>

      {b.rewards.length > 0 && (
        <div className="stack tight">
          <h3>Itens da vitória</h3>
          <div className="grid-2">
            {b.rewards.map((r) => (
              <div key={r.id} className="item-card">
                {r.kind === 'equipamento' && r.slot
                  ? <Avatar config={avatar} size={92} preview={{ slot: r.slot, item: r.id }} locked={b.victories === 0} label={r.name} />
                  : <div className="title-plate" style={{ borderColor: RARITY[r.rarity].color, fontSize: 14, padding: '14px 10px' }}>{r.name}</div>}
                <span className="name">{r.name}</span>
                <span className="small" style={{ color: RARITY[r.rarity].color }}>
                  {r.kind === 'titulo' ? 'Título' : SLOTS.find((s) => s.id === r.slot)?.label} · {RARITY[r.rarity].label}
                </span>
              </div>
            ))}
          </div>
        </div>
      )}

      {mode.id !== 'normal' && <p className="small" style={{ color: 'var(--warn)' }}>Modo {mode.name}: {mode.consequences[0]}</p>}

      {b.state === 'bloqueado' && (
        <div className="card stack">
          <strong>🔒 Ainda bloqueado</strong>
          <span className="muted">{lockText(b, info.day)}</span>
          {b.lock?.reason === 'habito' && (
            <span className="small muted">Crie uma missão personalizada recorrente nessa área, ou espere o seu plano incluir uma. <Link to="/missoes/nova">Criar missão</Link></span>
          )}
        </div>
      )}

      {confirm === 'start' && (
        <div className="card stack" role="alertdialog" aria-label="Confirmar batalha">
          <strong>Começar a batalha?</strong>
          <p className="small muted">
            Você terá {b.window_days} dias, até {formatDay(deadlineIfStart, { day: 'numeric', month: 'long' })}, para dar {b.hp} golpes.
            Missões já concluídas hoje contam. Se o prazo acabar antes, o chefe só recua: nada é perdido.
          </p>
          <div className="row">
            <button className="btn ghost grow" onClick={() => setConfirm(null)} disabled={acting}>Agora não</button>
            <button className="btn primary grow" onClick={start} disabled={acting}>{acting ? 'Começando…' : 'Começar'}</button>
          </div>
        </div>
      )}
      {confirm === 'quit' && (
        <div className="card stack" role="alertdialog" aria-label="Confirmar desistência">
          <strong>Deixar esta batalha?</strong>
          <p className="small muted">Os golpes desta batalha não ficam guardados, mas você pode desafiar {midName(b.name)} de novo quando quiser, sem perder XP.</p>
          <div className="row">
            <button className="btn ghost grow" onClick={() => setConfirm(null)} disabled={acting}>Continuar lutando</button>
            <button className="btn danger grow" onClick={quit} disabled={acting}>Deixar batalha</button>
          </div>
        </div>
      )}

      {confirm === null && b.state === 'ativo' && (
        <button className="btn ghost danger" onClick={() => setConfirm('quit')}>Deixar a batalha</button>
      )}
      {confirm === null && (b.state === 'disponivel' || b.state === 'vencido') && (
        <div className="sticky-actions">
          {otherActive ? (
            <button className="btn block" onClick={() => nav(`/jornada/chefes/${otherActive.id}`)}>Você está enfrentando {midName(otherActive.name)}</button>
          ) : (
            <button className="btn primary block" onClick={() => setConfirm('start')}>{b.state === 'vencido' ? 'Revanche' : 'Enfrentar'}</button>
          )}
        </div>
      )}
    </div>
  );
}
