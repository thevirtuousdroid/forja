// Personagem em pixel art (camadas geradas em art/pixel, servidas em /pixel/avatar.json).
// A ordem das camadas e a composição (sombra entre peças, contorno e luz neon de borda) são as mesmas da página de teste.
import type { AvatarConfig } from './types';

export const W = 192;
export const STYLES = ['raspado', 'curto', 'franja', 'cacheado', 'longo', 'coque', 'volumoso', 'sem'];
export const EYES = ['castanho', 'mel', 'verde', 'azul', 'cinza', 'ciano'] as const;
export const EYE_LABEL: Record<string, string> = { castanho: 'Castanho', mel: 'Mel', verde: 'Verde', azul: 'Azul', cinza: 'Cinza', ciano: 'Ciano' };
export const EYE_SWATCH: Record<string, string> = { castanho: '#6e4020', mel: '#a8721e', verde: '#2e6e36', azul: '#285c96', cinza: '#5e6874', ciano: '#16a6a8' };
const SHOULDER = new Set(['arm_martelo', 'arm_martelo_juiz']);
const COAT: Record<string, string> = { cap_curta: 'C', cap_constante: 'V', cap_fenix: 'F', cap_mestre: 'D' };

type Cell = [string, number] | null;
interface Data { pal: { fixed: Record<string, string[]>; skins: string[][]; hairs: string[][]; outfits: string[][]; eyes: Record<string, string[]> }; dec: Record<string, { a: Cell[]; head: boolean }> }
type RGB = [number, number, number];

const hex = (h: string): RGB => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16)) as RGB;

let loading: Promise<Data> | null = null;
let ready: Data | null = null;

/** Carrega as camadas uma vez (o arquivo fica em cache no navegador). */
export function loadPixelData(): Promise<Data> {
  if (ready) return Promise.resolve(ready);
  if (!loading) {
    loading = fetch('/pixel/avatar.json')
      .then((r) => { if (!r.ok) throw new Error('pixel_data'); return r.json(); })
      .then((raw: { layers: Record<string, { r: string; h: number }>; pal: Data['pal'] }) => {
        const dec: Data['dec'] = {};
        for (const [k, v] of Object.entries(raw.layers)) {
          const a: Cell[] = new Array(W * W).fill(null), s = v.r;
          for (let i = 0; i < s.length; i += 7) {
            const at = parseInt(s.slice(i, i + 3), 36), n = parseInt(s.slice(i + 3, i + 5), 36), cell: Cell = [s[i + 5], +s[i + 6]];
            for (let j = 0; j < n; j++) a[at + j] = cell;
          }
          dec[k] = { a, head: v.h === 1 };
        }
        ready = { pal: raw.pal, dec };
        return ready;
      })
      .catch((e) => { loading = null; throw e; });
  }
  return loading;
}

export function pixelDataReady(): boolean { return ready !== null; }

/** Lista de camadas, de trás para a frente (não depende dos dados: serve também para testes). */
export function layerOrder(cfg: AvatarConfig, blink = false): string[] {
  const g = cfg.tipo === 'f' ? 'f' : 'm', s = STYLES[cfg.cabelo] ?? 'curto', e = cfg.equip ?? {}, out: string[] = [];
  const cab = e.cabeca, cor = e.corpo, cap = e.capa, arm = e.arma, amu = e.amuleto;
  const pose = arm && SHOULDER.has(arm) ? 'ombro' : 'solto';
  const sleeve = cor === 'cor_gibao' ? 'J' : cap ? COAT[cap] : undefined;
  const covers = cab === 'cab_capuz' || cab === 'cab_elmo_ferro';
  if (cap) out.push(`${cap}_tras_${g}`);
  const hideBack = cab === 'cab_elmo_silencio' && (s === 'coque' || s === 'volumoso');
  if (!hideBack && !covers) out.push(`cabelo_${s}_tras_${g}`);
  if (pose === 'ombro') out.push(`${arm}_tras_${g}`);
  out.push(`pescoco_${g}`, `corpo_${g}`, `cyber_${g}`, `detalhe_${g}`, `luva_esq_${g}`);
  if (arm && pose !== 'ombro') out.push(`${arm}_tras_${g}`);
  out.push(pose === 'ombro' ? `braco_ombro_${g}` : `braco_${g}`);
  if (pose === 'solto') out.push(`luva_solto_${g}`);
  if (sleeve) out.push(`manga_${sleeve}_esq_${g}`, `manga_${sleeve}_${pose}_${g}`);
  if (cor && cor !== 'cor_tunica') out.push(`${cor}_${g}`);
  if (amu) out.push(`${amu}_${g}`);
  if (cap) out.push(`${cap}_${g}`);
  if (pose === 'ombro') {
    out.push(`antebraco_ombro_${g}`);
    if (sleeve) out.push(`manga_${sleeve}_ombro_ante_${g}`);
    out.push(`${arm}_${g}`, `mao_ombro_${g}`, `luva_ombro_${g}`);
  }
  out.push(`cabeca_${g}`, `implante_${g}`, blink ? `rosto_${g}_piscar` : `rosto_${g}`);
  if (cfg.barba) out.push(`barba_${cfg.barba}_${g}`);
  if (!covers) out.push(`cabelo_${s}_${g}`);
  if (cab) out.push(`${cab}_${g}`);
  return out;
}

function palette(d: Data, cfg: AvatarConfig): Record<string, RGB[]> {
  const p: Record<string, RGB[]> = {};
  for (const [k, v] of Object.entries(d.pal.fixed)) p[k] = v.map(hex);
  p.S = (d.pal.skins[cfg.pele] ?? d.pal.skins[2]).map(hex);
  p.H = (d.pal.hairs[cfg.corCabelo] ?? d.pal.hairs[1]).map(hex);
  p.I = (d.pal.eyes[cfg.olhos ?? 'castanho'] ?? d.pal.eyes.castanho).map(hex);
  p.C = (d.pal.outfits[cfg.corRoupa] ?? d.pal.outfits[0]).map(hex);
  const red = hex('#b3404a');
  p.L = p.S.map((c) => c.map((x, i) => x * 0.55 + red[i] * 0.45) as RGB);
  return p;
}

/** Compõe o personagem inteiro em RGBA (192×192). */
export function composeAvatar(d: Data, cfg: AvatarConfig, blink = false, headDy = 0): Uint8ClampedArray {
  const list = layerOrder(cfg, blink).filter((n) => d.dec[n]);
  const pal = palette(d, cfg);
  const rgb = new Float32Array(W * W * 3), on = new Uint8Array(W * W);
  for (const n of list) {
    const { a: L, head } = d.dec[n], dy = head ? headDy : 0, inL = new Uint8Array(W * W);
    for (let i = 0; i < W * W; i++) if (L[i]) { const y = ((i / W) | 0) + dy; if (y >= 0 && y < W) inL[y * W + (i % W)] = 1; }
    for (let i = 0; i < W * W; i++) {
      const c = L[i]; if (!c) continue;
      const x = i % W, y = ((i / W) | 0) + dy; if (y < 0 || y >= W) continue;
      const j = y * W + x; let lvl = c[1];
      for (const [ddx, ddy] of [[0, 1], [-1, 0], [1, 0]]) {
        const xx = x + ddx, yy = y + ddy;
        if (xx >= 0 && xx < W && yy < W && !inL[yy * W + xx] && on[yy * W + xx]) { lvl = Math.max(0, lvl - 1); break; }
      }
      const col = (pal[c[0]] ?? pal.D)[lvl];
      rgb[j * 3] = col[0]; rgb[j * 3 + 1] = col[1]; rgb[j * 3 + 2] = col[2]; on[j] = 1;
    }
  }
  const out = new Uint8ClampedArray(W * W * 4);
  const ink = hex('#070b12'), cyan = hex('#39d5d0'), ember = hex('#ff3fa8');
  const filled = (x: number, y: number) => x >= 0 && x < W && y >= 0 && y < W && on[y * W + x] === 1;
  for (let y = 0; y < W; y++) for (let x = 0; x < W; x++) {
    const j = y * W + x;
    if (on[j]) {
      let c = [rgb[j * 3], rgb[j * 3 + 1], rgb[j * 3 + 2]];
      if (!filled(x + 1, y)) c = c.map((v, i) => v * 0.5 + cyan[i] * 0.5);
      else if (!filled(x - 1, y)) c = c.map((v, i) => v * 0.55 + ember[i] * 0.45);
      out[j * 4] = c[0]; out[j * 4 + 1] = c[1]; out[j * 4 + 2] = c[2]; out[j * 4 + 3] = 255;
    } else {
      const nb = [[1, 0], [-1, 0], [0, 1], [0, -1]].filter(([a, b]) => filled(x + a, y + b));
      if (nb.length) {
        const m = [0, 0, 0];
        for (const [a, b] of nb) { const k = (y + b) * W + x + a; for (let i = 0; i < 3; i++) m[i] += rgb[k * 3 + i] / nb.length; }
        out[j * 4] = m[0] * 0.28 + ink[0] * 0.72; out[j * 4 + 1] = m[1] * 0.28 + ink[1] * 0.72; out[j * 4 + 2] = m[2] * 0.28 + ink[2] * 0.72; out[j * 4 + 3] = 255;
      }
    }
  }
  return out;
}

// ── Molduras em pixel ───────────────────────────────────────────────────────

interface Frame { ramp: string[]; gaps?: number; inner?: string; bolts?: string; double?: boolean; ticks?: [string, number]; arcs?: string; plasma?: boolean; stars?: boolean; bg: [string, string] }
const FRAMES: Record<string, Frame> = {
  mol_bronze: { ramp: ['#3e2410', '#6e4420', '#a06a36', '#c88c4e', '#ecc08a'], gaps: 8, inner: '#ff7138', bg: ['#1c2630', '#080c10'] },
  mol_ferro: { ramp: ['#20262e', '#3a434e', '#5e6a78', '#8794a2', '#b9c4ce'], gaps: 4, bolts: '#39d5d0', inner: '#13838a', bg: ['#1a2733', '#080c10'] },
  mol_aco: { ramp: ['#2c3640', '#56626e', '#8a98a6', '#c2ccd6', '#f2f6fa'], double: true, inner: '#8ff0ea', ticks: ['#39d5d0', 32], bg: ['#182836', '#070b10'] },
  mol_runas: { ramp: ['#0e2440', '#1c4070', '#2e64a4', '#5c94d2', '#a6d0f6'], inner: '#39d5d0', ticks: ['#8ff0ea', 44], arcs: '#39d5d0', bg: ['#122640', '#060a12'] },
  mol_chamas: { ramp: ['#3a0a2e', '#6a1250', '#a81e7a', '#e040a8', '#ff9ad8'], inner: '#ff7138', plasma: true, bg: ['#2a1022', '#0a0408'] },
  mol_66: { ramp: ['#4a300a', '#7a5214', '#b07e26', '#deac44', '#fbe08a'], inner: '#fff0d6', stars: true, arcs: '#ffb45e', bg: ['#2a2210', '#0a0804'] },
};

/** Retrato redondo (rosto e ombros) com a moldura equipada. Canvas de P×P pixels. */
export const P = 84;
export function drawPortrait(ctx: CanvasRenderingContext2D, img: Uint8ClampedArray, frameId: string | undefined) {
  const f = FRAMES[frameId ?? 'mol_bronze'] ?? FRAMES.mol_bronze, ramp = f.ramp.map(hex);
  const R = 34, cx = 41.5, cy = 41.5, u = 1.6, TAU = Math.PI * 2;
  const im = ctx.createImageData(P, P), d = im.data;
  const bg1 = hex(f.bg[0]), bg2 = hex(f.bg[1]);
  const set = (x: number, y: number, c: number[]) => { if (x >= 0 && x < P && y >= 0 && y < P) { const k = (y * P + x) * 4; d[k] = c[0]; d[k + 1] = c[1]; d[k + 2] = c[2]; d[k + 3] = 255; } };
  const ringOuter = f.double ? R + 3.6 * u : R + 3.2 * u;
  for (let y = 0; y < P; y++) for (let x = 0; x < P; x++) {
    const dx = x - cx, dy = y - cy, r = Math.hypot(dx, dy), ang = (Math.atan2(dy, dx) + TAU) % TAU;
    if (r <= R) {
      // recorte do rosto e do peito: região 68×68 a partir de x=62, y=2 da arte de 192
      const sx = Math.round(62 + (x - (cx - R))), sy = Math.round(2 + (y - (cy - R)));
      const j = (sy * W + sx) * 4, t = Math.min(1, r / R);
      if (sx >= 0 && sx < W && sy >= 0 && sy < W && img[j + 3]) set(x, y, [img[j], img[j + 1], img[j + 2]]);
      else set(x, y, bg1.map((v, i) => v * (1 - t) + bg2[i] * t));
      if (f.inner && r > R - 0.9) set(x, y, hex(f.inner));
      continue;
    }
    const inRing = f.double ? (r <= R + 1.4 * u) || (r > R + 2.4 * u && r <= R + 3.6 * u) : r <= R + 3.2 * u;
    const gap = f.gaps && ((ang + Math.PI / f.gaps) % (TAU / f.gaps)) < 0.07 && r > R + 0.6 * u;
    if (inRing && gap) { set(x, y, hex(f.inner ?? '#39d5d0')); continue; }
    if (inRing) {
      const lit = -(dx * 0.6 + dy * 0.7) / Math.max(r, 1);
      let lv = Math.max(0, Math.min(4, Math.round(2 + lit * 1.8 + ((x + y) % 2 ? 0.2 : -0.2))));
      if (!f.double && Math.abs(r - (R + 1.6 * u)) < 0.5) lv = Math.max(0, lv - 1);
      set(x, y, ramp[lv]);
    } else if (r <= ringOuter + 1.2) set(x, y, ramp[0].map((v) => v * 0.4));
    if (f.arcs && r > R + 4.6 * u && r <= R + 5.2 * u) {
      const a = ang / TAU;
      if ((a > 0.58 && a < 0.8) || (a > 0.08 && a < 0.3)) set(x, y, hex(f.arcs));
    }
  }
  const at = (a: number, rr: number) => [Math.round(cx + Math.cos(a) * rr), Math.round(cy + Math.sin(a) * rr)];
  const dot = (x: number, y: number, c: number[]) => { set(x, y, c); set(x + 1, y, c); set(x, y + 1, c); set(x + 1, y + 1, c); };
  if (f.bolts) for (let i = 0; i < 4; i++) { const [x, y] = at(Math.PI / 4 + i * Math.PI / 2, R + 1.6 * u); dot(x, y, ramp[4]); set(x + 1, y + 1, hex(f.bolts)); }
  if (f.ticks) { const [col, n] = f.ticks; for (let i = 0; i < n; i++) { const [x, y] = at(i * TAU / n, R + 4.6 * u); set(x, y, hex(i % 3 ? col : '#e6fffd')); } }
  if (f.plasma) for (let i = 0; i < 24; i++) { const a = i * TAU / 24; const n = 1 + (i * 7 % 3); for (let s = 0; s < n; s++) { const [x, y] = at(a, R + 3.6 * u + s * 1.2); set(x, y, hex(s === 0 ? '#ff7138' : s === 1 ? '#e040a8' : '#ff9ad8')); } }
  if (f.stars) for (let i = 0; i < 6; i++) { const [x, y] = at(-Math.PI / 2 + i * Math.PI / 3, R + 1.6 * u); dot(x, y, hex('#fff0d6')); set(x - 1, y, hex('#ff7138')); set(x + 2, y, hex('#ff7138')); set(x, y - 1, hex('#ffb45e')); set(x, y + 2, hex('#ffb45e')); }
  ctx.putImageData(im, 0, 0);
}

/** Corpo inteiro (recorte 104×192 centrado), fundo transparente. */
export const FULL = { x: 44, w: 104, h: 192 };
export function drawFull(ctx: CanvasRenderingContext2D, img: Uint8ClampedArray) {
  const im = ctx.createImageData(FULL.w, FULL.h);
  for (let y = 0; y < FULL.h; y++) im.data.set(img.subarray((y * W + FULL.x) * 4, (y * W + FULL.x + FULL.w) * 4), y * FULL.w * 4);
  ctx.putImageData(im, 0, 0);
}
