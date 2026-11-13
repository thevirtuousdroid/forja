import { useId } from 'react';
import type { AchievementCategory, Rarity } from '../lib/types';

const RARITY_FILL: Record<Rarity, [string, string]> = {
  comum: ['#C9D0DB', '#6B7382'],
  raro: ['#9CCBFF', '#2F6FC4'],
  epico: ['#D8C0FF', '#7A4FD6'],
  lendario: ['#FFDD95', '#E0662A'],
};

const OUTER = 'M32 3 L57 17.5 L57 46.5 L32 61 L7 46.5 L7 17.5 Z';
const INNER = 'M32 9.5 L51.5 20.8 L51.5 43.2 L32 54.5 L12.5 43.2 L12.5 20.8 Z';

function star(cx: number, cy: number, r1: number, r2: number) {
  const pts: string[] = [];
  for (let i = 0; i < 10; i++) {
    const a = (-90 + i * 36) * (Math.PI / 180);
    const r = i % 2 ? r2 : r1;
    pts.push(`${(cx + Math.cos(a) * r).toFixed(2)} ${(cy + Math.sin(a) * r).toFixed(2)}`);
  }
  return `M${pts.join(' L')} Z`;
}

function pentagon(cx: number, cy: number, radii: number[]) {
  return 'M' + radii.map((r, k) => {
    const a = (-90 + k * 72) * (Math.PI / 180);
    return `${(cx + Math.cos(a) * r).toFixed(2)} ${(cy + Math.sin(a) * r).toFixed(2)}`;
  }).join(' L') + ' Z';
}

function Glyph({ category, c }: { category: AchievementCategory | 'oculta'; c: string }) {
  const stroke = { stroke: c, strokeWidth: 2.7, fill: 'none', strokeLinecap: 'round' as const, strokeLinejoin: 'round' as const };
  switch (category) {
    case 'missoes': return <g><circle cx="32" cy="32" r="10.5" {...stroke} /><path d="M26.8 32.4 L30.8 36.4 L38 28.4" {...stroke} /></g>;
    case 'sequencia': return <path d="M32 19.5 C36.5 25.5 41.5 29 41.5 35.5 C41.5 40.8 37.3 44.5 32 44.5 C26.7 44.5 22.5 40.8 22.5 35.5 C22.5 31.4 25 29.1 27.8 26.8 C28.3 29.9 29.8 31.5 31.7 32 C30.4 27.4 30.9 23.3 32 19.5 Z" fill={c} />;
    case 'programa': return <g><path d="M25 44 L25 21" {...stroke} /><path d="M25 21.5 L40.5 26 L25 31 Z" fill={c} /><path d="M30.5 41.5 h2.2 M35.5 39.5 h2.2 M40.5 37.5 h1.6" {...stroke} strokeWidth={2.2} /></g>;
    case 'nivel': return <path d={star(32, 33, 12, 5.2)} fill={c} />;
    case 'atributos': return <g><path d={pentagon(32, 33, [12, 12, 12, 12, 12])} {...stroke} strokeWidth={1.6} /><path d={pentagon(32, 33, [9, 6, 10, 5, 8])} fill={c} opacity="0.9" /></g>;
    case 'habitos': return <g><path d="M22.5 41 L30.5 33 L34.5 37 L41.5 29.5" {...stroke} /><path d="M35.5 28.5 L42.5 28.5 L42.5 35.5" {...stroke} /></g>;
    case 'chefes': return <g><path d="M21.5 40.5 L23.5 25.5 L29 32 L32 22.5 L35 32 L40.5 25.5 L42.5 40.5 Z" fill={c} /><rect x="21.5" y="42" width="21" height="3.2" rx="1.2" fill={c} /></g>;
    case 'modos': return <path d="M34.5 19.5 L24.5 34.5 L31 34.5 L28.8 45 L39.5 29 L33 29 Z" fill={c} />;
    case 'social': return <g><circle cx="26.5" cy="27.5" r="4.6" fill={c} /><circle cx="38" cy="27.5" r="4.6" fill={c} opacity="0.75" /><path d="M18.5 42.5 C19.5 36.5 22.5 34 26.5 34 C30.5 34 33.5 36.5 34.5 42.5 Z" fill={c} /><path d="M31.5 35.2 C33.2 34.4 35.4 34 38 34 C42 34 44.8 36.5 45.6 42.5 L36.4 42.5" fill={c} opacity="0.75" /></g>;
    case 'temporadas': return <g><path d="M24 21 H40 V27.5 C40 32.5 36.5 35.5 32 35.5 C27.5 35.5 24 32.5 24 27.5 Z" fill={c} /><path d="M24 23.5 H20.5 C20.5 28 22 30 24.8 30.5 M40 23.5 H43.5 C43.5 28 42 30 39.2 30.5" {...stroke} strokeWidth={2.2} /><path d="M32 35.5 V40 M26.5 43.5 H37.5" {...stroke} /></g>;
    case 'ferramentas': return <g><path d="M36.5 20.5 A6.5 6.5 0 0 0 30 29 L21.5 37.5 A2.6 2.6 0 0 0 25.2 41.2 L33.7 32.7 A6.5 6.5 0 0 0 42.2 26.2 L38.3 30.1 L35 29.4 L34.3 26.1 Z" fill={c} /></g>;
    default: return <text x="32" y="39.5" textAnchor="middle" fontSize="20" fontWeight="700" fill={c} fontFamily="Sora, sans-serif">?</text>;
  }
}

export function Badge({ category, rarity, locked, hidden, size = 56 }: {
  category: AchievementCategory; rarity: Rarity; locked?: boolean; hidden?: boolean; size?: number;
}) {
  const uid = useId().replace(/:/g, '');
  const [light, dark] = locked ? ['#454B58', '#2A2E37'] : RARITY_FILL[rarity];
  const glyphColor = locked ? '#6C7383' : light;
  return (
    <svg width={size} height={size} viewBox="0 0 64 64" aria-hidden>
      <defs>
        <linearGradient id={`${uid}-g`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor={light} /><stop offset="1" stopColor={dark} />
        </linearGradient>
      </defs>
      {!locked && <path d={OUTER} fill={light} opacity="0.18" transform="translate(32 32) scale(1.08) translate(-32 -32)" />}
      <path d={OUTER} fill={`url(#${uid}-g)`} />
      <path d={INNER} fill="#151821" />
      <Glyph category={locked && hidden ? 'oculta' : category} c={glyphColor} />
    </svg>
  );
}
