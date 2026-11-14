import { useEffect, useRef, useState } from 'react';
import type { AvatarConfig, Slot } from '../lib/types';
import { FULL, P, composeAvatar, drawFull, drawPortrait, layerOrder, loadPixelData } from '../lib/pixelAvatar';

// Personagem · pixel art cyberpunk (art/pixel). Mesmo AvatarConfig e mesmos ids de item de sempre.
// O retrato (rosto e ombros dentro da moldura) é o padrão; `full` mostra o corpo inteiro.

/** Mistura uma cor hex com preto (amt > 0) ou branco (amt < 0). */
export function shade(hex: string, amt: number): string {
  const n = parseInt(hex.slice(1), 16);
  const target = amt > 0 ? 0 : 255;
  const a = Math.abs(amt);
  const ch = (v: number) => Math.round(v + (target - v) * a);
  const r = ch((n >> 16) & 255), g = ch((n >> 8) & 255), b = ch(n & 255);
  return `#${((1 << 24) | (r << 16) | (g << 8) | b).toString(16).slice(1)}`;
}

interface Props {
  config: AvatarConfig;
  size?: number;
  /** Mostra este item no lugar do equipado (prévia no inventário). null tira o item do espaço. */
  preview?: { slot: Slot; item: string | null };
  locked?: boolean;
  className?: string;
  label?: string;
  /** Corpo inteiro, com piscada (tela do personagem) */
  full?: boolean;
}

// Composições prontas, para a mesma aparência não ser recalculada a cada tela
const cache = new Map<string, Uint8ClampedArray>();

export function Avatar({ config, size = 160, preview, locked, className, label, full }: Props) {
  const ref = useRef<HTMLCanvasElement>(null);
  const [blink, setBlink] = useState(false);
  const equip = { ...config.equip };
  if (preview) {
    if (preview.item) equip[preview.slot] = preview.item;
    else delete equip[preview.slot];
  }
  const cfg: AvatarConfig = { ...config, equip };
  const order = layerOrder(cfg).join(' ');
  const key = `${order}|${cfg.pele}|${cfg.corCabelo}|${cfg.corRoupa}|${cfg.olhos ?? ''}|${blink ? 1 : 0}`;

  useEffect(() => {
    let alive = true;
    loadPixelData().then((d) => {
      const ctx = alive ? ref.current?.getContext('2d') : null;
      if (!ctx) return;
      let img = cache.get(key);
      if (!img) {
        img = composeAvatar(d, cfg, blink);
        if (cache.size > 80) cache.clear();
        cache.set(key, img);
      }
      if (full) drawFull(ctx, img); else drawPortrait(ctx, img, equip.moldura);
    }).catch(() => { /* sem os dados, fica o fundo */ });
    return () => { alive = false; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key, full, equip.moldura]);

  useEffect(() => {
    if (!full) return;
    let t: ReturnType<typeof setTimeout>;
    const loop = () => { t = setTimeout(() => { setBlink(true); t = setTimeout(() => { setBlink(false); loop(); }, 150); }, 2800 + Math.random() * 2400); };
    loop();
    return () => clearTimeout(t);
  }, [full]);

  const w = size, h = full ? Math.round(size * FULL.h / FULL.w) : size;
  return (
    <span role="img" aria-label={label ?? 'Personagem'} className={`px-avatar${className ? ` ${className}` : ''}`}
          data-layers={order} data-frame={equip.moldura ?? 'mol_bronze'}
          style={{ display: 'inline-block', width: w, height: h, lineHeight: 0, flex: 'none',
                   borderRadius: full ? 0 : '50%', background: full ? undefined : 'radial-gradient(circle at 50% 38%, #1c2630, #080c10 72%)',
                   filter: locked ? 'grayscale(1) brightness(.72)' : undefined, opacity: locked ? 0.8 : undefined }}>
      <canvas ref={ref} width={full ? FULL.w : P} height={full ? FULL.h : P}
              style={{ width: '100%', height: '100%', imageRendering: 'pixelated' }} />
    </span>
  );
}
