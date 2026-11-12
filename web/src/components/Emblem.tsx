import { emblemTier } from '../lib/game';

/**
 * Emblema do personagem. Ganha camadas conforme a faixa de nível:
 * 0 núcleo de brasa · 1 hexágono forjado · 2 runas e anel duplo · 3 lâminas · 4 coroa de chamas.
 */
export function Emblem({ level, size = 120, showLevel = true }: { level: number; size?: number; showLevel?: boolean }) {
  const tier = emblemTier(level);
  const id = `em-${size}`;
  return (
    <svg width={size} height={size} viewBox="0 0 120 120" role="img" aria-label={`Emblema do personagem, nível ${level}`}>
      <defs>
        <radialGradient id={`${id}-core`} cx="0.5" cy="0.45" r="0.55">
          <stop offset="0" stopColor="var(--accent-2)" />
          <stop offset="1" stopColor="var(--accent)" />
        </radialGradient>
        <radialGradient id={`${id}-glow`} cx="0.5" cy="0.5" r="0.5">
          <stop offset="0" stopColor="var(--accent)" stopOpacity={0.18 + tier * 0.06} />
          <stop offset="1" stopColor="var(--accent)" stopOpacity="0" />
        </radialGradient>
      </defs>

      <circle cx="60" cy="60" r="58" fill={`url(#${id}-glow)`} />

      {tier >= 4 && (
        <g fill="var(--accent)" opacity="0.9">
          {[0, 45, 90, 135, 180, 225, 270, 315].map((a) => (
            <path key={a} d="M60 4c3 6 6 9 6 14a6 6 0 0 1-12 0c0-5 3-8 6-14z" transform={`rotate(${a} 60 60)`} />
          ))}
        </g>
      )}

      {tier >= 3 && (
        <g fill="var(--surface-3)" stroke="var(--accent-2)" strokeWidth="1.5">
          {[30, 150, 270].map((a) => (
            <path key={a} d="M60 10 66 30 60 26 54 30z" transform={`rotate(${a} 60 60)`} />
          ))}
        </g>
      )}

      <circle cx="60" cy="60" r="40" fill="var(--surface-2)" stroke="var(--line)" strokeWidth="2" />
      <circle cx="60" cy="60" r="40" fill="none" stroke="var(--accent)" strokeWidth="2.5" strokeOpacity={0.5 + tier * 0.12} />

      {tier >= 2 && (
        <>
          <circle cx="60" cy="60" r="46" fill="none" stroke="var(--accent-2)" strokeWidth="1" strokeDasharray="2 6" />
          {[0, 90, 180, 270].map((a) => (
            <rect key={a} x="58.5" y="12" width="3" height="8" rx="1.5" fill="var(--accent-2)" transform={`rotate(${a} 60 60)`} />
          ))}
        </>
      )}

      {tier >= 1 && (
        <polygon points="60,30 86,45 86,75 60,90 34,75 34,45" fill="none" stroke="var(--accent-2)" strokeWidth="1.5" strokeOpacity="0.7" />
      )}

      <circle cx="60" cy="60" r={showLevel ? 20 : 16} fill={`url(#${id}-core)`} />
      {showLevel ? (
        <text x="60" y="61" textAnchor="middle" dominantBaseline="central" fontFamily="Sora, sans-serif" fontWeight="700"
              fontSize={level >= 100 ? 14 : 18} fill="var(--accent-ink)">
          {level}
        </text>
      ) : null}
    </svg>
  );
}
