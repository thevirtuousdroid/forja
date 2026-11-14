import { useId } from 'react';
import { emblemTier } from '../lib/game';

/**
 * Emblema do personagem: um reator da forja que ganha peças conforme a faixa de nível.
 * 0 núcleo aceso · 1 chassi hexagonal · 2 anel segmentado com travas · 3 aletas de resfriamento · 4 coroa de energia.
 */
export function Emblem({ level, size = 120, showLevel = true }: { level: number; size?: number; showLevel?: boolean }) {
  const tier = emblemTier(level);
  const id = `em-${useId().replace(/:/g, '')}`;
  const around = (n: number, off = 0) => Array.from({ length: n }, (_, i) => off + (360 / n) * i);
  return (
    <svg width={size} height={size} viewBox="0 0 120 120" role="img" aria-label={`Emblema do personagem, nível ${level}`}>
      <defs>
        <radialGradient id={`${id}-core`} cx="0.5" cy="0.42" r="0.6">
          <stop offset="0" stopColor="#FFE2B8" />
          <stop offset="0.45" stopColor="var(--accent-2)" />
          <stop offset="1" stopColor="var(--accent)" />
        </radialGradient>
        <radialGradient id={`${id}-glow`} cx="0.5" cy="0.5" r="0.5">
          <stop offset="0" stopColor="var(--accent)" stopOpacity={0.2 + tier * 0.07} />
          <stop offset="1" stopColor="var(--accent)" stopOpacity="0" />
        </radialGradient>
        <linearGradient id={`${id}-metal`} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#5C6B79" /><stop offset="0.5" stopColor="#2A3642" /><stop offset="1" stopColor="#4A5866" />
        </linearGradient>
      </defs>

      <circle cx="60" cy="60" r="58" fill={`url(#${id}-glow)`} />

      {/* 4 · coroa de energia */}
      {tier >= 4 && (
        <g fill="var(--accent)">
          {around(6, 30).map((a) => (
            <path key={a} d="M60 1 L64.5 14 L55.5 14 Z" transform={`rotate(${a} 60 60)`} />
          ))}
        </g>
      )}

      {/* 3 · aletas de resfriamento */}
      {tier >= 3 && (
        <g fill={`url(#${id}-metal)`} stroke="var(--accent-2)" strokeWidth="1">
          {around(6, 0).map((a) => (
            <path key={a} d="M54.5 5 L65.5 5 L63.5 16 L56.5 16 Z" transform={`rotate(${a} 60 60)`} />
          ))}
        </g>
      )}

      {/* 2 · anel segmentado com travas */}
      {tier >= 2 && (
        <>
          <circle cx="60" cy="60" r="45" fill="none" stroke="var(--line-hi)" strokeWidth="4" strokeDasharray="20 3.6" />
          <circle cx="60" cy="60" r="45" fill="none" stroke="var(--tech)" strokeWidth="1" strokeDasharray="2 8" opacity="0.8" />
          {around(4, 45).map((a) => (
            <rect key={a} x="56" y="12.5" width="8" height="5" fill="#0A0F14" stroke="var(--accent-2)" strokeWidth="1" transform={`rotate(${a} 60 60)`} />
          ))}
        </>
      )}

      {/* Base: placa octogonal */}
      <path d="M44 22 L76 22 L98 44 L98 76 L76 98 L44 98 L22 76 L22 44 Z" fill="var(--surface-2)" stroke="var(--line)" strokeWidth="2" />
      <path d="M44 22 L76 22 L98 44 L98 76 L76 98 L44 98 L22 76 L22 44 Z" fill="none" stroke="var(--accent)" strokeWidth="1.6"
            strokeOpacity={0.45 + tier * 0.13} transform="translate(60 60) scale(0.9) translate(-60 -60)" />

      {/* 1 · chassi hexagonal */}
      {tier >= 1 && (
        <>
          <polygon points="60,31 85,45.5 85,74.5 60,89 35,74.5 35,45.5" fill="none" stroke="var(--accent-2)" strokeWidth="1.6" strokeOpacity="0.8" />
          {[[60, 31], [85, 45.5], [85, 74.5], [60, 89], [35, 74.5], [35, 45.5]].map(([x, y]) => (
            <circle key={`${x}-${y}`} cx={x} cy={y} r="1.8" fill="var(--accent-2)" />
          ))}
        </>
      )}

      {/* Núcleo */}
      <circle cx="60" cy="60" r={showLevel ? 22 : 17} fill="#0A0F14" stroke="var(--accent)" strokeWidth="1.5" />
      <circle cx="60" cy="60" r={showLevel ? 18.5 : 13.5} fill={`url(#${id}-core)`} />
      {showLevel ? (
        <text x="60" y="61" textAnchor="middle" dominantBaseline="central" fontFamily="'Space Grotesk', sans-serif" fontWeight="700"
              fontSize={level >= 100 ? 13 : 17} fill="#1A0D05">
          {level}
        </text>
      ) : null}
    </svg>
  );
}
