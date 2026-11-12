import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../lib/api';
import { useApp } from '../lib/AppData';
import type { LedgerEntry } from '../lib/types';
import { ATTRIBUTES, ATTRIBUTE_KEYS, attributeLevel } from '../lib/game';
import { avatarOf, midName, modeDef, titleName } from '../lib/rpg';
import { formatDay } from '../lib/dates';
import { Avatar } from '../components/Avatar';
import { Empty, Skeleton, XpBar } from '../components/ui';

const SOURCE_LABEL: Record<string, string> = {
  meta_diaria: 'Bônus: meta do dia', retorno: 'Bônus: retorno', marco: 'Marco de sequência',
};

interface Counts { items: number; achievements: number; bosses: number }

export function CharacterScreen() {
  const { stats, profile, missions, catalogs, today } = useApp();
  const [ledger, setLedger] = useState<(LedgerEntry & { label: string })[] | null>(null);
  const [counts, setCounts] = useState<Counts | null>(null);

  useEffect(() => {
    Promise.all([api.ownedItems(), api.unlockedAchievements(), api.defeatedBosses()])
      .then(([it, ach, b]) => setCounts({ items: it.length, achievements: ach.length, bosses: new Set(b.map((x) => x.boss_id)).size }))
      .catch(() => setCounts(null));
    api.ledger(30).then(async (rows) => {
      const [names, fights, cats] = await Promise.all([
        api.missionNames(rows.filter((r) => r.mission_id).map((r) => r.mission_id!)),
        api.fightBosses(rows.filter((r) => r.source === 'chefe' && r.ref).map((r) => r.ref!)),
        api.catalogs(),
      ]);
      const mission = new Map(names.map((n) => [n.id, n.name]));
      const fightBoss = new Map(fights.map((f) => [f.id, f.boss_id]));
      setLedger(rows.map((r) => {
        let label = SOURCE_LABEL[r.source] ?? 'XP';
        if (r.source === 'missao') label = mission.get(r.mission_id!) ?? 'Missão';
        if (r.source === 'conquista') label = `Conquista: ${cats.achievements.find((a) => a.id === r.ref)?.name ?? ''}`;
        if (r.source === 'chefe') label = `Vitória: ${cats.bosses.find((b) => b.id === fightBoss.get(r.ref!))?.name ?? 'chefe'}`;
        return { ...r, label };
      }));
    }).catch(() => setLedger([]));
  }, [missions]);

  if (!stats || !profile) return <div className="screen"><Skeleton height={300} /><Skeleton height={160} /></div>;
  const avatar = avatarOf(profile);
  const strongest = [...ATTRIBUTE_KEYS].sort((a, b) => stats[b] - stats[a])[0];
  const mode = modeDef(today?.mode ?? profile.mode);
  const totalItems = catalogs?.items.length;

  return (
    <div className="screen">
      <h1>Personagem</h1>

      <div className="card hero stack" style={{ alignItems: 'center', textAlign: 'center' }}>
        <Avatar config={avatar} size={176} label={`Personagem de ${profile.display_name || 'você'}`} />
        <div className="stack tight" style={{ alignItems: 'center' }}>
          <h2>{profile.display_name || 'Sem nome'}</h2>
          <Link to="/personagem/inventario?aba=titulos" className="pill accent" style={{ textDecoration: 'none' }}>
            {titleName(profile, stats.level, catalogs?.items)}
          </Link>
        </div>
        <div className="stack tight" style={{ width: '100%' }}>
          <div className="row between">
            <span className="num" style={{ fontSize: 22, fontWeight: 700 }}>Nível {stats.level}</span>
            <span className="small muted num">{stats.total_xp.toLocaleString('pt-BR')} XP</span>
          </div>
          <XpBar totalXp={stats.total_xp} level={stats.level} />
        </div>
        <Link to="/personagem/aparencia" className="btn sm" style={{ alignSelf: 'stretch' }}>Editar aparência</Link>
        {!avatar.personalizado && (
          <p className="small muted">Seu personagem ainda está com a aparência sorteada. Ajuste pele, cabelo e roupa para ele ficar com a sua cara.</p>
        )}
      </div>

      <div className="grid-2">
        <Link to="/personagem/atributos" className="tile">
          <span className="small muted">Atributos</span>
          <span className="num" style={{ color: ATTRIBUTES[strongest].color }}>{ATTRIBUTES[strongest].label}</span>
          <span className="small faint">mais forte · nível {attributeLevel(stats[strongest])}</span>
        </Link>
        <Link to="/personagem/inventario" className="tile">
          <span className="small muted">Inventário</span>
          <span className="num">{counts ? counts.items : '–'}{totalItems ? <span className="small muted"> / {totalItems}</span> : null}</span>
          <span className="small faint">equipamentos e títulos</span>
        </Link>
        <Link to="/personagem/conquistas" className="tile">
          <span className="small muted">Conquistas</span>
          <span className="num">{counts ? counts.achievements : '–'}<span className="small muted"> / {catalogs?.achievements.length ?? 44}</span></span>
          <span className="small faint">desbloqueadas</span>
        </Link>
        <Link to="/jornada/chefes" className="tile">
          <span className="small muted">Chefes</span>
          <span className="num">{counts ? counts.bosses : '–'}<span className="small muted"> / {catalogs?.bosses.length ?? 7}</span></span>
          <span className="small faint">{today?.boss ? `enfrentando ${midName(today.boss.name)}` : 'vencidos'}</span>
        </Link>
      </div>

      <Link to="/jornada/modos" className="card row between" style={{ color: 'inherit', textDecoration: 'none' }}>
        <span>Modo <strong>{mode.name}</strong>{mode.multiplier > 1 && <span className="small muted"> · XP ×{String(mode.multiplier).replace('.', ',')}</span>}</span>
        <span className="faint">›</span>
      </Link>

      <h2>Histórico de evolução</h2>
      {ledger === null ? <Skeleton height={160} /> : ledger.length === 0 ? (
        <Empty title="Nenhum XP ainda"><span className="small">Conclua sua primeira missão para começar o histórico.</span></Empty>
      ) : (
        <div className="card stack">
          {ledger.map((l) => (
            <div key={l.id} className="row between small">
              <div className="grow" style={{ minWidth: 0 }}>
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
