import { useEffect, useMemo, useRef, useState, type CSSProperties, type ReactNode } from 'react';
import { useNavigate } from 'react-router-dom';
import { useApp } from '../lib/AppData';
import { api, friendlyError } from '../lib/api';
import type { GameEvent, RewardRef } from '../lib/types';
import { RARITY, SLOTS, avatarOf, midName, titleName } from '../lib/rpg';
import { Avatar } from './Avatar';
import { Badge } from './Badge';
import { BossArt } from './BossArt';
import { useFeedback } from './Feedback';
import { LeagueBadge } from './Social';
import { metricUnit, plural } from '../lib/social';
import { formatDay } from '../lib/dates';

interface QueueItem { ids: number[]; event: GameEvent }

/** Junta vários avisos de nível num só (o maior) e mantém a ordem dos demais. */
export function groupEvents(events: GameEvent[]): QueueItem[] {
  const out: QueueItem[] = [];
  let level: QueueItem | null = null;
  for (const e of events) {
    if (e.kind === 'nivel') {
      if (!level) { level = { ids: [e.id], event: e }; out.push(level); }
      else {
        level.ids.push(e.id);
        if (e.data.level > (level.event as Extract<GameEvent, { kind: 'nivel' }>).data.level) level.event = e;
      }
    } else {
      out.push({ ids: [e.id], event: e });
    }
  }
  return out;
}

export function Sparks({ count = 16 }: { count?: number }) {
  return (
    <div className="sparks" aria-hidden>
      {Array.from({ length: count }, (_, i) => (
        <i key={i} style={{ '--a': `${(360 / count) * i}deg`, '--d': `${70 + (i % 3) * 22}px`, '--t': `${0.05 * (i % 4)}s` } as CSSProperties} />
      ))}
    </div>
  );
}

function RewardList({ rewards }: { rewards: RewardRef[] }) {
  if (rewards.length === 0) return null;
  return (
    <div className="reward-list">
      {rewards.map((r) => (
        <span key={r.id} className="pill" style={{ color: RARITY[r.rarity].color }}>
          {r.kind === 'titulo' ? 'Título' : SLOTS.find((s) => s.id === r.slot)?.label}: {r.name}
        </span>
      ))}
    </div>
  );
}

export function RewardOverlay() {
  const { events, dismissEvents, profile, stats, catalogs, refresh } = useApp();
  const { toast } = useFeedback();
  const nav = useNavigate();
  const queue = useMemo(() => groupEvents(events), [events]);
  const [acting, setActing] = useState(false);
  const btn = useRef<HTMLButtonElement>(null);
  const current = queue[0];

  useEffect(() => {
    if (!current) return;
    btn.current?.focus();
    if (current.event.kind === 'chefe_vencido' || current.event.kind === 'nivel' || current.event.kind === 'temporada') navigator.vibrate?.([30, 40, 70]);
  }, [current?.ids.join(',')]); // eslint-disable-line react-hooks/exhaustive-deps

  if (!current || !profile) return null;
  const e = current.event;
  const avatar = avatarOf(profile);
  const next = () => dismissEvents(current.ids);
  const skipAll = () => dismissEvents(queue.flatMap((q) => q.ids));

  async function equip(itemId: string, slot: NonNullable<RewardRef['slot']>) {
    setActing(true);
    try {
      await api.updateAvatar({ ...avatar, equip: { ...avatar.equip, [slot]: itemId } });
      await refresh();
      next();
    } catch (err) {
      toast(friendlyError(err), 'error');
    } finally {
      setActing(false);
    }
  }
  async function applyTitle(itemId: string) {
    setActing(true);
    try {
      await api.setTitle(itemId);
      await refresh();
      next();
    } catch (err) {
      toast(friendlyError(err), 'error');
    } finally {
      setActing(false);
    }
  }

  let body: ReactNode;
  let actions: ReactNode = <button ref={btn} className="btn primary block" onClick={next}>Continuar</button>;

  switch (e.kind) {
    case 'nivel':
      body = (
        <>
          <span className="tiny muted">Você subiu de nível</span>
          <div className="reward-art pop"><Sparks /><Avatar config={avatar} size={150} /></div>
          <span className="reward-big num">{e.data.level}</span>
          <span className="muted">{titleName(profile, e.data.level, catalogs?.items)}</span>
        </>
      );
      break;
    case 'conquista':
      body = (
        <>
          <span className="tiny muted">Conquista desbloqueada</span>
          <div className="reward-art pop"><Sparks count={12} /><Badge category={e.data.category} rarity={e.data.rarity} size={112} /></div>
          <h2>{e.data.name}</h2>
          <p className="muted center">{e.data.description}</p>
          <div className="row" style={{ gap: 8, justifyContent: 'center', flexWrap: 'wrap' }}>
            <span className="pill" style={{ color: RARITY[e.data.rarity].color }}>{RARITY[e.data.rarity].label}</span>
            {e.data.xp > 0 && <span className="pill accent num">+{e.data.xp} XP</span>}
          </div>
          <RewardList rewards={e.data.rewards} />
        </>
      );
      break;
    case 'item': {
      const it = e.data;
      body = (
        <>
          <span className="tiny muted">{it.kind === 'titulo' ? 'Novo título' : 'Novo equipamento'}</span>
          <div className="reward-art pop">
            <Sparks count={12} />
            {it.kind === 'equipamento' && it.slot
              ? <Avatar config={avatar} size={150} preview={{ slot: it.slot, item: it.id }} />
              : <div className="title-plate" style={{ borderColor: RARITY[it.rarity].color }}>{it.name}</div>}
          </div>
          <h2>{it.name}</h2>
          <p className="muted center">{it.description}</p>
          <span className="pill" style={{ color: RARITY[it.rarity].color }}>
            {RARITY[it.rarity].label}{it.slot ? ` · ${SLOTS.find((s) => s.id === it.slot)?.label}` : ''}
          </span>
        </>
      );
      const isEquipped = it.slot ? avatar.equip[it.slot] === it.id : profile.active_title === it.id;
      if (!isEquipped) {
        actions = (
          <div className="row" style={{ width: '100%' }}>
            <button className="btn ghost grow" onClick={next} disabled={acting}>Depois</button>
            {it.kind === 'equipamento' && it.slot
              ? <button ref={btn} className="btn primary grow" disabled={acting} onClick={() => equip(it.id, it.slot!)}>Equipar agora</button>
              : <button ref={btn} className="btn primary grow" disabled={acting} onClick={() => applyTitle(it.id)}>Usar título</button>}
          </div>
        );
      }
      break;
    }
    case 'chefe_vencido':
      body = (
        <>
          <span className="tiny muted">{e.data.boss.epithet}</span>
          <div className="reward-art boss-defeat"><Sparks count={20} /><BossArt id={e.data.boss.id} size={170} defeated damage={1} /></div>
          <span className="reward-big">Vitória!</span>
          <p className="muted center">
            Você venceu {midName(e.data.boss.name)} com {e.data.fight.hp} golpes
            {e.data.fight.rematch ? ' de novo. Revanche rende metade do XP.' : '.'}
          </p>
          {e.data.xp ? <span className="pill accent num">+{e.data.xp} XP</span> : null}
          <RewardList rewards={e.data.rewards} />
        </>
      );
      break;
    case 'chefe_recuou':
      body = (
        <>
          <span className="tiny muted">{e.data.boss.epithet}</span>
          <div className="reward-art"><BossArt id={e.data.boss.id} size={150} /></div>
          <h2>{e.data.boss.name} recuou</h2>
          <p className="muted center">
            O prazo acabou com {e.data.fight.hits} de {e.data.fight.hp} golpes. Nada foi perdido: você pode desafiar de novo quando quiser.
          </p>
        </>
      );
      actions = (
        <div className="row" style={{ width: '100%' }}>
          <button className="btn ghost grow" onClick={next}>Fechar</button>
          <button ref={btn} className="btn primary grow" onClick={() => { next(); nav(`/jornada/chefes/${e.data.boss.id}`); }}>Ver chefe</button>
        </div>
      );
      break;
    case 'temporada': {
      const d = e.data;
      body = (
        <>
          <span className="tiny muted">{d.name} de {d.year} encerrada</span>
          <div className="reward-art pop"><Sparks count={18} /><LeagueBadge league={d.league.id} size={130} /></div>
          <h2>Liga {d.league.name}</h2>
          <p className="muted center">
            {plural(d.points, 'ponto', 'pontos')} · meta cumprida em {plural(d.goal_days, 'dia', 'dias')}
            {d.rank && d.of && d.of > 1 ? ` · ${d.rank}º entre ${d.of} amigos` : ''}
          </p>
          {d.xp > 0 && <span className="pill accent num">+{d.xp} XP</span>}
          <p className="small faint center">Uma nova temporada começou e os pontos voltaram a zero. XP, itens e conquistas continuam seus.</p>
        </>
      );
      actions = (
        <div className="row" style={{ width: '100%' }}>
          <button className="btn ghost grow" onClick={next}>Fechar</button>
          <button ref={btn} className="btn primary grow" onClick={() => { next(); nav('/social/temporada'); }}>Ver temporada</button>
        </div>
      );
      break;
    }
    case 'desafio_fim': {
      const d = e.data;
      const c = d.challenge;
      const won = d.result === 'venceu' || d.result === 'meta_coletiva';
      body = (
        <>
          <span className="tiny muted">Desafio encerrado</span>
          {won && <div className="reward-art pop"><Sparks count={14} /><span className="reward-big">{d.result === 'venceu' ? 'Vitória!' : 'Meta batida!'}</span></div>}
          <h2>{c.title}</h2>
          <p className="muted center">
            {c.kind === 'coletivo'
              ? `Juntos: ${d.total} de ${c.target ?? '?'} ${metricUnit(c.metric, d.total)}. Sua parte: ${d.score}.`
              : d.result === 'venceu'
                ? `Você terminou na frente com ${d.score} ${metricUnit(c.metric, d.score)}${d.winners.length > 1 ? ' (empate)' : ''}.`
                : `Você fez ${d.score} ${metricUnit(c.metric, d.score)}. ${d.winners.length ? `Vitória de ${d.winners.map((w) => w.name || 'alguém').join(' e ')}.` : 'Ninguém pontuou.'}`}
          </p>
          {d.xp > 0 ? <span className="pill accent num">+{d.xp} XP</span>
            : won ? <span className="small faint center">Sem XP desta vez: já foram 2 recompensas de desafio nesta semana.</span> : null}
        </>
      );
      actions = (
        <div className="row" style={{ width: '100%' }}>
          <button className="btn ghost grow" onClick={next}>Fechar</button>
          <button ref={btn} className="btn primary grow" onClick={() => { next(); nav(`/social/desafios/${c.id}`); }}>Ver placar</button>
        </div>
      );
      break;
    }
    case 'relatorio': {
      const d = e.data;
      body = (
        <>
          <span className="tiny muted">Relatório semanal</span>
          <h2>Semana de {formatDay(d.week_start, { day: 'numeric', month: 'long' })}</h2>
          <p className="muted center">{d.highlight}</p>
          <div className="row" style={{ gap: 8, justifyContent: 'center', flexWrap: 'wrap' }}>
            <span className="pill num">{plural(d.missions, 'missão', 'missões')}</span>
            <span className="pill num">meta em {d.goal_days} de {d.days} dias</span>
            {d.xp > 0 && <span className="pill accent num">+{d.xp} XP</span>}
          </div>
        </>
      );
      actions = (
        <div className="row" style={{ width: '100%' }}>
          <button className="btn ghost grow" onClick={next}>Depois</button>
          <button ref={btn} className="btn primary grow" onClick={() => { next(); nav(`/mentor/relatorio/${d.week_start}`); }}>Ver relatório</button>
        </div>
      );
      break;
    }
    case 'modo_rebaixado':
      body = (
        <>
          <span className="tiny muted">Modo de dificuldade</span>
          <h2>Você voltou ao modo Desafio</h2>
          <p className="muted center">
            Foram 3 dias abaixo da meta numa mesma semana no modo Extremo. Seu XP, nível, itens e conquistas continuam iguais.
            O Extremo volta a ficar disponível em 7 dias, se você quiser tentar de novo.
          </p>
        </>
      );
      break;
  }

  return (
    <div className="overlay" role="dialog" aria-modal="true" aria-label="Recompensa">
      <div className="reward" key={current.ids.join(',')}>
        {queue.length > 1 && (
          <div className="row between small faint" style={{ width: '100%' }}>
            <span className="num">1 de {queue.length}</span>
            <button className="link small" onClick={skipAll}>Ver tudo depois</button>
          </div>
        )}
        {body}
        <div style={{ width: '100%', marginTop: 8 }}>{actions}</div>
        {stats && e.kind === 'nivel' && <span className="small faint num">{stats.total_xp.toLocaleString('pt-BR')} XP no total</span>}
      </div>
    </div>
  );
}
