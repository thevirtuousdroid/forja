import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api, friendlyError } from '../lib/api';
import { useApp } from '../lib/AppData';
import type { AvatarConfig } from '../lib/types';
import { BEARDS, HAIR_COLORS, HAIR_STYLES, OUTFIT_COLORS, SKIN_TONES, avatarOf } from '../lib/rpg';
import { Avatar } from '../components/Avatar';
import { BackButton, Loading } from '../components/ui';
import { useFeedback } from '../components/Feedback';

export function AvatarEditorScreen() {
  const { profile, refresh } = useApp();
  const { toast } = useFeedback();
  const nav = useNavigate();
  const [cfg, setCfg] = useState<AvatarConfig | null>(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => { if (profile && !cfg) setCfg(avatarOf(profile)); }, [profile, cfg]);
  if (!cfg) return <div className="screen no-tabs"><BackButton /><Loading /></div>;

  const set = (patch: Partial<AvatarConfig>) => setCfg({ ...cfg, ...patch });

  async function save() {
    setSaving(true);
    try {
      await api.updateAvatar(cfg!);
      await refresh();
      toast('Aparência salva.');
      nav('/personagem');
    } catch (e) {
      toast(friendlyError(e), 'error');
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="screen no-tabs">
      <BackButton to="/personagem" />
      <h1>Aparência</h1>
      <div className="center" style={{ position: 'sticky', top: 'calc(var(--safe-top) + 4px)', zIndex: 2, background: 'var(--bg)', paddingBlock: 6 }}>
        <Avatar config={cfg} size={168} />
      </div>
      <p className="small faint">A aparência é sua escolha e fica sempre disponível. Os equipamentos você troca no inventário.</p>

      <section className="stack">
        <h3>Pele</h3>
        <div className="swatches" role="group" aria-label="Tom de pele">
          {SKIN_TONES.map((c, i) => (
            <button key={c} className="swatch" style={{ background: c }} aria-pressed={cfg.pele === i} aria-label={`Tom ${i + 1}`} onClick={() => set({ pele: i })} />
          ))}
        </div>
      </section>

      <section className="stack">
        <h3>Cabelo</h3>
        <div className="grid-3 wide" role="group" aria-label="Estilo de cabelo">
          {HAIR_STYLES.map((name, i) => (
            <button key={name} className="style-pick" aria-pressed={cfg.cabelo === i} onClick={() => set({ cabelo: i })}>
              <Avatar config={{ ...cfg, cabelo: i, equip: { corpo: cfg.equip.corpo, moldura: cfg.equip.moldura } }} size={72} label={name} />
              {name}
            </button>
          ))}
        </div>
        <div className="swatches" role="group" aria-label="Cor do cabelo">
          {HAIR_COLORS.map((h, i) => (
            <button key={h.color} className="swatch" style={{ background: h.color }} aria-pressed={cfg.corCabelo === i} aria-label={h.label} title={h.label} onClick={() => set({ corCabelo: i })} />
          ))}
        </div>
      </section>

      <section className="stack">
        <h3>Barba</h3>
        <div className="grid-3" role="group" aria-label="Barba">
          {BEARDS.map((name, i) => (
            <button key={name} className="style-pick" aria-pressed={cfg.barba === i} onClick={() => set({ barba: i })}>
              <Avatar config={{ ...cfg, barba: i, equip: { corpo: cfg.equip.corpo, moldura: cfg.equip.moldura } }} size={72} label={name} />
              {name}
            </button>
          ))}
        </div>
      </section>

      <section className="stack">
        <h3>Cor da roupa</h3>
        <div className="swatches" role="group" aria-label="Cor da roupa">
          {OUTFIT_COLORS.map((o, i) => (
            <button key={o.color} className="swatch" style={{ background: o.color }} aria-pressed={cfg.corRoupa === i} aria-label={o.label} title={o.label} onClick={() => set({ corRoupa: i })} />
          ))}
        </div>
      </section>

      <div className="sticky-actions">
        <button className="btn primary block" disabled={saving} onClick={save}>{saving ? 'Salvando…' : 'Salvar aparência'}</button>
      </div>
    </div>
  );
}
