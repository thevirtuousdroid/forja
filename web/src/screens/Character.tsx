import { useEffect, useState } from 'react';
import { api } from '../lib/api';
import { useApp } from '../lib/AppData';
import type { LedgerEntry } from '../lib/types';
import { ATTRIBUTES, ATTRIBUTE_KEYS, TIER_TITLES, attributeProgress, emblemTier, xpForLevel } from '../lib/game';
import { formatDay } from '../lib/dates';
import { Emblem } from '../components/Emblem';
import { Empty, Skeleton, XpBar } from '../components/ui';

const SOURCE_LABEL = { meta_diaria: 'Bônus: meta do dia', retorno: 'Bônus: retorno', marco: 'Marco de sequência' } as const;
const NEXT_TIERS = [4, 8, 15, 25];

export function CharacterScreen() {
  const { stats, missions } = useApp();
  const [ledger, setLedger] = useState<(LedgerEntry & { label: string })[] | null>(null);

  useEffect(() => {
    api.ledger(30).then(async (rows) => {
      const names = await api.missionNames(rows.filter((r) => r.mission_id).map((r) => r.mission_id!));
      const map = new Map(names.map((n) => [n.id, n.name]));
      setLedger(rows.map((r) => ({ ...r, label: r.source === 'missao' ? map.get(r.mission_id!) ?? 'Missão' : SOURCE_LABEL[r.source] })));
    }).catch(() => setLedger([]));
  }, [missions]);

  if (!stats) return <div className="screen"><Skeleton height={240} /><Skeleton height={200} /></div>;
  const tier = emblemTier(stats.level);
  const nextTierLevel = NEXT_TIERS.find((l) => l > stats.level);

  return (
    <div className="screen">
      <h1>Personagem</h1>
      <div className="card hero stack" style={{ alignItems: 'center', textAlign: 'center' }}>
        <Emblem level={stats.level} size={150} />
        <div className="stack tight">
          <span className="tiny muted">{TIER_TITLES[tier]}</span>
          <span className="num" style={{ fontSize: 28, fontWeight: 700 }}>Nível {stats.level}</span>
          <span className="small muted num">{stats.total_xp.toLocaleString('pt-BR')} XP no total</span>
        </div>
        <div style={{ width: '100%' }}><XpBar totalXp={stats.total_xp} level={stats.level} /></div>
        {nextTierLevel && (
          <span className="small faint">
            O emblema evolui no nível {nextTierLevel} ({TIER_TITLES[emblemTier(nextTierLevel)]}) · faltam {(xpForLevel(nextTierLevel) - stats.total_xp).toLocaleString('pt-BR')} XP
          </span>
        )}
      </div>

      <h2>Atributos</h2>
      <div className="card stack">
        {ATTRIBUTE_KEYS.map((a) => {
          const p = attributeProgress(stats[a]);
          return (
            <div key={a} className="stack tight">
              <div className="row between">
                <strong style={{ color: ATTRIBUTES[a].color }}>{ATTRIBUTES[a].label}</strong>
                <span className="num">Nv. {p.level}</span>
              </div>
              <div className="bar thin"><span style={{ width: `${p.ratio * 100}%`, background: ATTRIBUTES[a].color }} /></div>
              <span className="small faint">{ATTRIBUTES[a].hint}</span>
            </div>
          );
        })}
      </div>

      <h2>Histórico de evolução</h2>
      {ledger === null ? <Skeleton height={160} /> : ledger.length === 0 ? (
        <Empty title="Nenhum XP ainda"><span className="small">Conclua sua primeira missão para começar o histórico.</span></Empty>
      ) : (
        <div className="card stack">
          {ledger.map((l) => (
            <div key={l.id} className="row between small">
              <div className="grow">
                <div style={{ whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{l.label}</div>
                <div className="faint">{formatDay(l.day)}</div>
              </div>
              <span className="num" style={{ color: 'var(--accent-2)' }}>+{l.amount}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
