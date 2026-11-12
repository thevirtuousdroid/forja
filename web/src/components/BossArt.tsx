import { useId } from 'react';

/**
 * Arte dos chefes. Cada um tem silhueta e cor próprias.
 * `damage` (0 a 1) abre rachaduras conforme a barra cai; `defeated` apaga o chefe.
 */
interface Props {
  id: string;
  size?: number;
  damage?: number;
  defeated?: boolean;
  locked?: boolean;
  className?: string;
}

export const BOSS_COLORS: Record<string, string> = {
  tempestade: '#5FD3D0',
  adiador: '#E0A23C',
  hidra: '#5AA9FF',
  nevoa: '#B9B3D9',
  sentinela: '#7FC9A8',
  errante: '#B48CFF',
  juiz: '#FF7A3D',
};

export function BossArt({ id, size = 140, damage = 0, defeated, locked, className }: Props) {
  const uid = useId().replace(/:/g, '');
  const g = (k: string) => `${uid}-${k}`;
  const color = BOSS_COLORS[id] ?? '#999';
  const crack = (n: number) => damage >= n;
  const filter = locked ? 'grayscale(1) brightness(.35)' : defeated ? 'grayscale(.85) brightness(.6)' : undefined;

  return (
    <svg width={size} height={size} viewBox="0 0 160 160" role="img" aria-hidden className={className} style={filter ? { filter } : undefined}>
      <defs>
        <radialGradient id={g('glow')} cx="0.5" cy="0.45" r="0.55">
          <stop offset="0" stopColor={color} stopOpacity="0.32" />
          <stop offset="1" stopColor={color} stopOpacity="0" />
        </radialGradient>
        <linearGradient id={g('stone')} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#8DA79A" /><stop offset="1" stopColor="#3B5046" />
        </linearGradient>
        <linearGradient id={g('iron')} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#5B6270" /><stop offset="1" stopColor="#22252C" />
        </linearGradient>
        <radialGradient id={g('core')} cx="0.5" cy="0.5" r="0.5">
          <stop offset="0" stopColor="#FFE2A8" /><stop offset="0.5" stopColor="#FF7A3D" /><stop offset="1" stopColor="#B8321E" />
        </radialGradient>
        <linearGradient id={g('mist')} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#D9D4F2" /><stop offset="1" stopColor="#8E86B8" stopOpacity="0.2" />
        </linearGradient>
      </defs>
      <circle cx="80" cy="76" r="76" fill={`url(#${g('glow')})`} />
      <ellipse cx="80" cy="146" rx="46" ry="7" fill="#000" opacity="0.35" />

      {id === 'tempestade' && (
        <g>
          <g stroke="#5FD3D0" strokeWidth="2" fill="none" opacity="0.5" strokeLinecap="round">
            <path d="M18 60 C30 44 46 40 58 46" /><path d="M142 92 C132 108 116 112 104 106" /><path d="M24 106 C34 116 46 118 56 112" />
          </g>
          <g fill="#2E3B6E">
            <circle cx="50" cy="72" r="22" /><circle cx="80" cy="58" r="29" /><circle cx="111" cy="68" r="24" />
            <circle cx="64" cy="90" r="22" /><circle cx="98" cy="91" r="24" /><circle cx="125" cy="86" r="17" />
          </g>
          <g fill="#4F67A6" opacity="0.8">
            <path d="M58 48 C66 34 92 28 104 40 C92 36 74 38 58 48 Z" /><path d="M30 66 C32 56 40 50 48 50 C40 54 34 60 30 66 Z" />
          </g>
          <path d="M60 78 Q70 72 80 77 Q70 81 60 78 Z" fill="#8FF0E8" />
          <path d="M88 77 Q98 72 108 78 Q98 81 88 77 Z" fill="#8FF0E8" />
          <path d="M72 96 C78 92 90 92 96 97" stroke="#8FF0E8" strokeWidth="2" fill="none" opacity="0.7" />
          <path d="M84 108 L74 126 L85 126 L76 146 L100 117 L89 117 L97 108 Z" fill="#FFE38A" />
          <g stroke="#7FA8E8" strokeWidth="1.6" strokeLinecap="round" opacity="0.7">
            <path d="M52 112 L48 122" /><path d="M118 108 L114 118" /><path d="M110 122 L106 132" /><path d="M60 126 L56 136" />
          </g>
        </g>
      )}

      {id === 'adiador' && (
        <g>
          <path d="M26 92 C18 96 16 108 22 114 L32 110 C30 104 32 98 38 96 Z" fill="#7A5A3A" />
          <path d="M134 92 C142 96 144 108 138 114 L128 110 C130 104 128 98 122 96 Z" fill="#7A5A3A" />
          <rect x="38" y="22" width="84" height="12" rx="5" fill="#6B4A2B" />
          <rect x="38" y="128" width="84" height="12" rx="5" fill="#6B4A2B" />
          <rect x="42" y="34" width="6" height="94" fill="#56391F" /><rect x="112" y="34" width="6" height="94" fill="#56391F" />
          <path d="M52 34 L108 34 L84 79 L76 79 Z" fill="#F5E6C8" opacity="0.18" stroke="#F5E6C8" strokeOpacity="0.5" />
          <path d="M76 81 L84 81 L108 128 L52 128 Z" fill="#F5E6C8" opacity="0.12" stroke="#F5E6C8" strokeOpacity="0.5" />
          <path d="M57 44 L103 44 L84 78 L76 78 Z" fill="#D9A441" />
          <path d="M57 44 L103 44 L99 51 L61 51 Z" fill="#F0C46A" />
          <path d="M66 58 Q72 54 77 58 Q72 61 66 58 Z" fill="#3A2410" /><path d="M83 58 Q88 54 94 58 Q88 61 83 58 Z" fill="#3A2410" />
          <path d="M64 53 L76 56 M96 53 L84 56" stroke="#3A2410" strokeWidth="2" strokeLinecap="round" />
          <circle cx="80" cy="80" r="1.6" fill="#D9A441" />
          <path d="M68 120 Q80 114 92 120 L96 127 L64 127 Z" fill="#D9A441" opacity="0.35" />
        </g>
      )}

      {id === 'hidra' && (
        <g>
          <path d="M38 142 C38 112 58 98 80 98 C102 98 122 112 122 142 Z" fill="#1E3C72" />
          <g stroke="#2A5298" strokeWidth="11" fill="none" strokeLinecap="round">
            <path d="M68 104 C58 88 44 78 42 58" /><path d="M80 100 C80 82 80 66 80 46" /><path d="M92 104 C102 88 116 80 118 60" />
          </g>
          {[[42, 48, -14], [80, 34, 0], [118, 50, 14]].map(([x, y, r]) => (
            <g key={x} transform={`translate(${x} ${y}) rotate(${r})`}>
              <rect x="-13" y="-18" width="26" height="36" rx="6" fill="#0F1B33" stroke="#6AA8FF" strokeWidth="2" />
              <rect x="-9" y="-13" width="18" height="24" rx="2" fill="#22406E" />
              <rect x="-6" y="-6" width="4" height="5" rx="1" fill="#BFE0FF" /><rect x="2" y="-6" width="4" height="5" rx="1" fill="#BFE0FF" />
              <path d="M-5 4 L5 4" stroke="#BFE0FF" strokeWidth="1.6" />
              <circle cx="12" cy="-17" r="5" fill="#FF4D5E" /><circle cx="12" cy="-17" r="1.6" fill="#fff" />
            </g>
          ))}
          <path d="M58 124 C66 118 94 118 102 124" stroke="#6AA8FF" strokeWidth="2" fill="none" opacity="0.5" />
        </g>
      )}

      {id === 'nevoa' && (
        <g>
          <path d="M18 120 C40 110 60 126 82 116 C104 106 124 122 146 112 L146 136 L18 136 Z" fill="#8E86B8" opacity="0.22" />
          <path d="M80 26 C110 26 124 54 122 84 C121 102 128 118 136 132 C120 128 112 136 100 130 C92 140 80 136 72 130 C62 136 50 130 40 134 C48 118 52 102 50 84 C48 54 52 26 80 26 Z" fill={`url(#${g('mist')})`} />
          <path d="M60 44 C66 36 76 34 84 36 C74 38 66 42 60 44 Z" fill="#fff" opacity="0.35" />
          <ellipse cx="70" cy="72" rx="7" ry="10" fill="#2A2440" /><ellipse cx="94" cy="72" rx="7" ry="10" fill="#2A2440" />
          <ellipse cx="82" cy="98" rx="6" ry="4" fill="#2A2440" opacity="0.7" />
          {[[30, 60, -18, 0.9], [128, 48, 14, 0.75], [124, 98, -8, 0.5], [34, 96, 22, 0.55]].map(([x, y, r, o]) => (
            <g key={x} transform={`translate(${x} ${y}) rotate(${r})`} opacity={o}>
              <rect x="-8" y="-10" width="16" height="20" rx="1.5" fill="#EEEAF8" />
              <path d="M-5 -5 L5 -5 M-5 -1 L5 -1 M-5 3 L3 3" stroke="#8E86B8" strokeWidth="1" />
            </g>
          ))}
        </g>
      )}

      {id === 'sentinela' && (
        <g>
          <path d="M34 56 L58 50 L60 92 L36 96 Z" fill={`url(#${g('stone')})`} stroke="#2A3832" />
          <path d="M126 56 L102 50 L100 92 L124 96 Z" fill={`url(#${g('stone')})`} stroke="#2A3832" />
          <path d="M52 142 L57 48 L80 28 L103 48 L108 142 Z" fill={`url(#${g('stone')})`} stroke="#2A3832" strokeWidth="1.5" />
          <rect x="66" y="56" width="28" height="6" rx="2" fill="#7FE3C4" />
          <rect x="62" y="52" width="36" height="14" rx="4" fill="#7FE3C4" opacity="0.18" />
          <path d="M56 84 L104 84 L104 108 C104 124 94 134 80 141 C66 134 56 124 56 108 Z" fill="#4E6B5F" stroke="#2A3832" strokeWidth="1.5" />
          <path d="M80 88 L80 136 M60 104 L100 104" stroke="#7FE3C4" strokeWidth="2" opacity="0.6" />
          <circle cx="45" cy="70" r="3" fill="#5E8F64" opacity="0.8" /><circle cx="90" cy="40" r="2.5" fill="#5E8F64" opacity="0.8" />
        </g>
      )}

      {id === 'errante' && (
        <g>
          <path d="M44 142 C46 112 52 92 80 86 C108 92 114 112 116 142 L106 134 L98 142 L90 134 L80 142 L70 134 L62 142 L54 134 Z" fill="#3B2266" />
          <ellipse cx="86" cy="64" rx="31" ry="38" fill="none" stroke="#B48CFF" strokeWidth="1.5" strokeDasharray="3 5" opacity="0.7" />
          <path d="M51 46 C54 30 66 24 80 24 C94 24 106 30 109 46 Z" fill="#E8DDFF" transform="translate(-5 0)" />
          <path d="M50 48 L110 48 L111 66 L49 66 Z" fill="#E8DDFF" transform="translate(6 0)" />
          <path d="M49 68 L111 68 C110 86 98 100 80 102 C62 100 50 86 49 68 Z" fill="#E8DDFF" transform="translate(-3 0)" />
          <path d="M60 56 Q68 51 75 56 Q68 60 60 56 Z" fill="#3B2266" transform="translate(6 0)" />
          <path d="M85 56 Q92 51 100 56 Q92 60 85 56 Z" fill="#3B2266" transform="translate(6 0)" />
          <path d="M70 84 C76 88 84 88 90 84" stroke="#3B2266" strokeWidth="2.4" fill="none" transform="translate(-3 0)" />
          <rect x="112" y="52" width="10" height="3" fill="#B48CFF" /><rect x="34" y="70" width="12" height="3" fill="#B48CFF" />
          <rect x="116" y="76" width="6" height="3" fill="#B48CFF" opacity="0.6" />
        </g>
      )}

      {id === 'juiz' && (
        <g>
          <path d="M30 70 C22 82 22 104 30 118 L42 114 C38 100 38 86 44 76 Z" fill={`url(#${g('iron')})`} />
          <path d="M130 70 C138 82 138 104 130 118 L118 114 C122 100 122 86 116 76 Z" fill={`url(#${g('iron')})`} />
          <path d="M42 144 L46 78 C54 68 106 68 114 78 L118 144 Z" fill={`url(#${g('iron')})`} stroke="#15171B" strokeWidth="1.5" />
          <circle cx="80" cy="104" r="22" fill="#FF7A3D" opacity="0.25" />
          <circle cx="80" cy="104" r="13" fill={`url(#${g('core')})`} />
          <path d="M60 128 L100 128" stroke="#15171B" strokeWidth="2" /><path d="M56 88 L104 88" stroke="#15171B" strokeWidth="2" />
          <path d="M40 30 L118 30 C118 36 112 40 104 41 L100 52 L106 62 L54 62 L60 52 L56 41 C48 40 40 36 40 30 Z M40 30 C30 30 22 34 18 38 C28 38 36 37 40 35 Z" fill="#2E3138" stroke="#15171B" strokeWidth="1.5" />
          <rect x="62" y="44" width="10" height="4" rx="1.5" fill="#FFB36B" /><rect x="88" y="44" width="10" height="4" rx="1.5" fill="#FFB36B" />
          <path d="M44 33 L114 33" stroke="#6F7887" strokeWidth="2" />
        </g>
      )}

      {/* Rachaduras conforme o dano */}
      <g stroke="#FFF7E6" strokeWidth="1.8" fill="none" strokeLinecap="round" strokeLinejoin="round" opacity={defeated ? 0.9 : 0.75}>
        {crack(0.25) && <path d="M62 60 L70 70 L66 78 L74 86" />}
        {crack(0.5) && <path d="M100 52 L94 64 L102 72 L96 84" />}
        {crack(0.75) && <path d="M78 98 L86 108 L80 118 L90 128" />}
        {defeated && <path d="M48 40 L64 62 L58 76 L80 92 L76 110 L98 128 L110 146" strokeWidth="2.6" />}
      </g>
    </svg>
  );
}
