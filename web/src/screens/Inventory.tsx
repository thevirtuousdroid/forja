import { useEffect, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { api, friendlyError } from '../lib/api';
import { useApp } from '../lib/AppData';
import type { CatalogItem, Slot } from '../lib/types';
import { RARITY, SLOTS, avatarOf, titleName, unlockText } from '../lib/rpg';
import { Avatar } from '../components/Avatar';
import { BackButton, ErrorState, Skeleton } from '../components/ui';
import { useFeedback } from '../components/Feedback';

export function InventoryScreen() {
  const { profile, stats, catalogs, refresh } = useApp();
  const { toast } = useFeedback();
  const [params, setParams] = useSearchParams();
  const tab = params.get('aba') === 'titulos' ? 'titulos' : 'equipamentos';
  const [owned, setOwned] = useState<Set<string> | null>(null);
  const [items, setItems] = useState<CatalogItem[] | null>(catalogs?.items ?? null);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState<string | null>(null);

  const load = () => {
    setError(null);
    Promise.all([api.ownedItems(), api.catalogs()])
      .then(([o, c]) => { setOwned(new Set(o.map((x) => x.item_id))); setItems(c.items); })
      .catch((e) => setError(friendlyError(e)));
  };
  useEffect(load, []);

  if (error) return <div className="screen"><BackButton to="/personagem" /><ErrorState message={error} onRetry={load} /></div>;
  if (!owned || !items || !profile || !stats) return <div className="screen"><BackButton to="/personagem" /><Skeleton height={40} /><Skeleton height={260} /></div>;

  const avatar = avatarOf(profile);
  const equipment = items.filter((i) => i.kind === 'equipamento');
  const titles = items.filter((i) => i.kind === 'titulo');
  const ownedCount = items.filter((i) => owned.has(i.id)).length;

  async function equip(slot: Slot, itemId: string | null) {
    setSaving(itemId ?? `${slot}:none`);
    const nextEquip = { ...avatar.equip };
    if (itemId) nextEquip[slot] = itemId; else delete nextEquip[slot];
    try {
      await api.updateAvatar({ ...avatar, equip: nextEquip });
      await refresh();
    } catch (e) {
      toast(friendlyError(e), 'error');
    } finally {
      setSaving(null);
    }
  }

  async function chooseTitle(id: string | null) {
    setSaving(id ?? 'auto');
    try {
      await api.setTitle(id);
      await refresh();
    } catch (e) {
      toast(friendlyError(e), 'error');
    } finally {
      setSaving(null);
    }
  }

  return (
    <div className="screen">
      <BackButton to="/personagem" />
      <div className="row between">
        <h1>Inventário</h1>
        <span className="small muted num">{ownedCount} de {items.length}</span>
      </div>
      <div className="seg" role="tablist">
        <button role="tab" aria-pressed={tab === 'equipamentos'} onClick={() => setParams({}, { replace: true })}>Equipamentos</button>
        <button role="tab" aria-pressed={tab === 'titulos'} onClick={() => setParams({ aba: 'titulos' }, { replace: true })}>Títulos</button>
      </div>

      {tab === 'equipamentos' ? (
        <>
          <p className="small faint">Equipamentos mudam só a aparência: mostram a sua trajetória, não dão XP extra.</p>
          {SLOTS.map((slot) => {
            const list = equipment.filter((i) => i.slot === slot.id);
            const have = list.filter((i) => owned.has(i.id)).length;
            return (
              <section key={slot.id} className="stack tight">
                <div className="row between">
                  <h3>{slot.label}</h3>
                  <span className="small faint num">{have}/{list.length}</span>
                </div>
                <div className="grid-2">
                  {list.map((it) => {
                    const isOwned = owned.has(it.id);
                    const equipped = avatar.equip[slot.id] === it.id;
                    return (
                      <div key={it.id} className={`item-card ${equipped ? 'equipped' : ''}`}>
                        <Avatar config={avatar} size={104} preview={{ slot: slot.id, item: it.id }} locked={!isOwned} label={it.name} />
                        <span className="name">{it.name}</span>
                        <span className="small" style={{ color: RARITY[it.rarity].color }}>{RARITY[it.rarity].label}</span>
                        {isOwned ? (
                          equipped ? (
                            slot.optional
                              ? <button className="btn sm ghost" disabled={saving !== null} onClick={() => equip(slot.id, null)}>Tirar</button>
                              : <span className="pill ok">Equipado</span>
                          ) : (
                            <button className="btn sm" disabled={saving !== null} onClick={() => equip(slot.id, it.id)}>
                              {saving === it.id ? 'Equipando…' : 'Equipar'}
                            </button>
                          )
                        ) : (
                          <span className="why">🔒 {unlockText(it, catalogs)}</span>
                        )}
                      </div>
                    );
                  })}
                </div>
              </section>
            );
          })}
        </>
      ) : (
        <div className="stack tight">
          <p className="small faint">O título aparece abaixo do seu nome.</p>
          <div className={`card row between ${profile.active_title === null ? '' : ''}`}>
            <div className="grow">
              <strong>Automático</strong>
              <div className="small muted">Usa o título do seu nível: {titleName(null, stats.level, items)}</div>
            </div>
            {profile.active_title === null
              ? <span className="pill ok">Em uso</span>
              : <button className="btn sm" disabled={saving !== null} onClick={() => chooseTitle(null)}>Usar</button>}
          </div>
          {titles.map((t) => {
            const isOwned = owned.has(t.id);
            const inUse = profile.active_title === t.id;
            return (
              <div key={t.id} className="card row between" style={isOwned ? undefined : { opacity: 0.6 }}>
                <div className="grow" style={{ minWidth: 0 }}>
                  <strong><span className="rarity-dot" style={{ background: RARITY[t.rarity].color }} />{t.name}</strong>
                  <div className="small muted">{isOwned ? `${RARITY[t.rarity].label} · ${unlockText(t, catalogs)}` : `🔒 ${unlockText(t, catalogs)}`}</div>
                </div>
                {isOwned && (inUse
                  ? <span className="pill ok">Em uso</span>
                  : <button className="btn sm" disabled={saving !== null} onClick={() => chooseTitle(t.id)}>Usar</button>)}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
