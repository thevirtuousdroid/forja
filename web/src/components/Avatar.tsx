import { useId } from 'react';
import type { AvatarConfig, Slot } from '../lib/types';
import { HAIR_COLORS, OUTFIT_COLORS, SKIN_TONES } from '../lib/rpg';

/** Mistura uma cor hex com preto (amt > 0) ou branco (amt < 0). */
export function shade(hex: string, amt: number): string {
  const n = parseInt(hex.slice(1), 16);
  const target = amt > 0 ? 0 : 255;
  const a = Math.abs(amt);
  const ch = (v: number) => Math.round(v + (target - v) * a);
  const r = ch((n >> 16) & 255), g = ch((n >> 8) & 255), b = ch(n & 255);
  return `#${((1 << 24) | (r << 16) | (g << 8) | b).toString(16).slice(1)}`;
}

const FRAMES: Record<string, { ring: string; ring2: string; bg1: string; bg2: string }> = {
  mol_bronze: { ring: '#B07A44', ring2: '#5E3E1F', bg1: '#2E231A', bg2: '#110D0A' },
  mol_ferro: { ring: '#8D96A6', ring2: '#4A515E', bg1: '#232A36', bg2: '#0E1117' },
  mol_aco: { ring: '#CDD5E1', ring2: '#6F7887', bg1: '#1F2A3B', bg2: '#0C111A' },
  mol_runas: { ring: '#6AA8FF', ring2: '#2D4C80', bg1: '#172642', bg2: '#0A0F1C' },
  mol_chamas: { ring: '#FF8A3D', ring2: '#8A2A0E', bg1: '#36170B', bg2: '#130805' },
  mol_66: { ring: '#E9C46A', ring2: '#8A6A1F', bg1: '#302612', bg2: '#110D05' },
};

const TORSO = 'M14 200 C18 160 50 138 100 136 C150 138 182 160 186 200 Z';
const DRAPE_L = 'M12 200 C14 166 36 146 71 139 C64 156 60 178 62 200 Z';
const DRAPE_R = 'M188 200 C186 166 164 146 129 139 C136 156 140 178 138 200 Z';

interface Props {
  config: AvatarConfig;
  size?: number;
  /** Mostra este item no lugar do equipado (prévia no inventário). null tira o item do espaço. */
  preview?: { slot: Slot; item: string | null };
  locked?: boolean;
  className?: string;
  label?: string;
}

export function Avatar({ config, size = 160, preview, locked, className, label }: Props) {
  const uid = useId().replace(/:/g, '');
  const id = (k: string) => `${uid}-${k}`;
  const url = (k: string) => `url(#${id(k)})`;

  const equip = { ...config.equip };
  if (preview) {
    if (preview.item) equip[preview.slot] = preview.item;
    else delete equip[preview.slot];
  }
  const skin = SKIN_TONES[config.pele] ?? SKIN_TONES[2];
  const skinShade = shade(skin, 0.22);
  const hair = HAIR_COLORS[config.corCabelo]?.color ?? HAIR_COLORS[1].color;
  const outfit = OUTFIT_COLORS[config.corRoupa]?.color ?? OUTFIT_COLORS[0].color;
  const lip = shade(skin, 0.38);
  const frame = FRAMES[equip.moldura ?? 'mol_bronze'] ?? FRAMES.mol_bronze;
  const style = config.cabelo;

  return (
    <svg width={size} height={size} viewBox="-8 -8 216 216" role="img" className={className}
         aria-label={label ?? 'Personagem'} style={locked ? { filter: 'grayscale(1) brightness(.72)', opacity: 0.8 } : undefined}>
      <defs>
        <radialGradient id={id('bg')} cx="0.5" cy="0.36" r="0.7">
          <stop offset="0" stopColor={frame.bg1} />
          <stop offset="1" stopColor={frame.bg2} />
        </radialGradient>
        <clipPath id={id('clip')}><circle cx="100" cy="100" r="88" /></clipPath>
        <clipPath id={id('face')}><ellipse cx="100" cy="86" rx="27" ry="31" /></clipPath>
        <linearGradient id={id('steel')} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#D2D9E3" /><stop offset="1" stopColor="#6B7484" />
        </linearGradient>
        <linearGradient id={id('stone')} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#86A194" /><stop offset="1" stopColor="#36493F" />
        </linearGradient>
        <linearGradient id={id('blue')} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#8FB3E6" /><stop offset="1" stopColor="#3B5C93" />
        </linearGradient>
        <linearGradient id={id('gold')} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#F4D58A" /><stop offset="1" stopColor="#B8862E" />
        </linearGradient>
        <linearGradient id={id('ember')} x1="0" y1="1" x2="0" y2="0">
          <stop offset="0" stopColor="#FF5A1F" /><stop offset="1" stopColor="#FFC56B" />
        </linearGradient>
        <radialGradient id={id('orb')} cx="0.4" cy="0.35" r="0.65">
          <stop offset="0" stopColor="#E6F2FF" /><stop offset="1" stopColor="#4F86D6" />
        </radialGradient>
        <pattern id={id('chain')} width="6" height="6" patternUnits="userSpaceOnUse">
          <rect width="6" height="6" fill="#4C5360" />
          <circle cx="3" cy="3" r="2.2" fill="none" stroke="#A3ACBA" strokeWidth="0.8" />
        </pattern>
      </defs>

      <circle cx="100" cy="100" r="88" fill={url('bg')} />

      <g clipPath={url('clip')}>
        <ellipse cx="100" cy="206" rx="80" ry="22" fill={frame.ring} opacity="0.16" />
        <g transform="translate(100 112) scale(1.12) translate(-100 -112)">

        {/* Ferramenta, atrás do corpo */}
        <Weapon item={equip.arma} url={url} />

        {/* Cabelo de trás */}
        {style === 4 && <path d="M68 84 C62 120 66 150 58 172 L142 172 C134 150 138 120 132 84 C132 60 118 46 100 46 C82 46 68 60 68 84 Z" fill={hair} />}
        {style === 6 && <path d="M55 92 C49 50 74 29 100 29 C126 29 151 50 145 92 C143 108 135 117 128 119 L72 119 C65 117 57 108 55 92 Z" fill={hair} />}
        {style === 3 && (
          <g fill={hair}><circle cx="69" cy="96" r="9" /><circle cx="131" cy="96" r="9" /><circle cx="72" cy="108" r="7" /><circle cx="128" cy="108" r="7" /></g>
        )}

        {/* Corpo */}
        <path d={TORSO} fill={outfit} />
        <path d="M100 136 C150 138 182 160 186 200 L100 200 Z" fill="#000" opacity="0.14" />
        <path d="M87 137 L100 157 L113 137 Z" fill={shade(outfit, 0.35)} />
        <Body item={equip.corpo} outfit={outfit} url={url} />

        {/* Capa: gola alta fica atrás do pescoço */}
        {equip.capa === 'cap_constante' && <path d="M79 135 C77 120 86 110 100 110 C114 110 123 120 121 135 Z" fill="#3A2266" />}
        <Cape item={equip.capa} outfit={outfit} />
        <Pauldrons item={equip.corpo} url={url} />

        {/* Pescoço */}
        <path d="M87 106 L87 138 Q100 146 113 138 L113 106 Z" fill={skin} />
        <path d="M87 114 Q100 128 113 114 L113 106 L87 106 Z" fill={skinShade} opacity="0.55" />
        {equip.capa === 'cap_mestre' && (
          <g fill="#8E939D">
            {[72, 80, 88, 96, 104, 112, 120, 128].map((x, i) => <circle key={x} cx={x} cy={137 + (i % 2) * 2} r="7" />)}
            {[76, 92, 108, 124].map((x) => <circle key={x} cx={x} cy="134" r="3" fill="#B7BCC6" />)}
          </g>
        )}
        <Amulet item={equip.amuleto} url={url} />

        {/* Cabeça */}
        <ellipse cx="73" cy="90" rx="5" ry="8" fill={skinShade} />
        <ellipse cx="127" cy="90" rx="5" ry="8" fill={skinShade} />
        <ellipse cx="100" cy="86" rx="27" ry="31" fill={skin} />
        <ellipse cx="123" cy="92" rx="15" ry="36" fill={skinShade} opacity="0.3" clipPath={url('face')} />

        {config.barba === 1 && (
          <g fill={hair} opacity="0.32">
            <path d="M75 94 C76 114 88 124 100 124 C112 124 124 114 125 94 C121 108 112 115 100 115 C88 115 79 108 75 94 Z" />
            <ellipse cx="100" cy="104" rx="9" ry="2.6" />
          </g>
        )}
        {config.barba === 2 && (
          <g fill={hair}>
            <path d="M73 90 C72 120 86 132 100 132 C114 132 128 120 127 90 C124 100 118 106 112 107 C108 103 92 103 88 107 C82 106 76 100 73 90 Z" />
            <path d="M88 104.5 C94 100.5 106 100.5 112 104.5 C108 107.5 92 107.5 88 104.5 Z" />
          </g>
        )}

        <ellipse cx="90" cy="90" rx="3.2" ry="3.8" fill="#1D1A22" />
        <ellipse cx="110" cy="90" rx="3.2" ry="3.8" fill="#1D1A22" />
        <circle cx="91.2" cy="88.6" r="1.1" fill="#fff" />
        <circle cx="111.2" cy="88.6" r="1.1" fill="#fff" />
        <g stroke={style === 7 ? shade(skin, 0.5) : hair} strokeWidth="2.6" strokeLinecap="round" fill="none">
          <path d="M84 82.5 Q89.5 79.5 95 81.5" />
          <path d="M105 81.5 Q110.5 79.5 116 82.5" />
        </g>
        <path d="M100 92 Q97.5 99 100.5 101" stroke={skinShade} strokeWidth="1.8" fill="none" strokeLinecap="round" />
        <path d="M94.5 108 Q100 111.5 105.5 108" stroke={config.barba === 2 ? shade(skin, 0.1) : lip} strokeWidth="2.2" fill="none" strokeLinecap="round" />

        <HairFront style={style} color={hair} />
        <Head item={equip.cabeca} url={url} />
        </g>
      </g>

      <Frame item={equip.moldura} colors={frame} url={url} />
    </svg>
  );
}

// ── Camadas ─────────────────────────────────────────────────────────────────

type UrlFn = (k: string) => string;

function HairFront({ style, color }: { style: number; color: string }) {
  switch (style) {
    case 0: return <path d="M73 86 C71 62 84 51 100 51 C116 51 129 62 127 86 C125 74 116 64 100 64 C84 64 75 74 73 86 Z" fill={color} opacity="0.9" />;
    case 1: return <path d="M70 88 C66 60 80 46 100 46 C121 46 134 60 130 88 C128 80 125 74 121 71 C113 75 104 74 98 70 C91 74 82 75 78 72 C74 76 71 82 70 88 Z" fill={color} />;
    case 2: return <path d="M70 90 C65 58 82 44 102 44 C124 44 136 60 130 90 C127 76 122 68 114 66 C104 70 92 78 82 84 C78 82 74 86 70 90 Z" fill={color} />;
    case 3:
      return (
        <g fill={color}>
          {[[76, 74, 10], [83, 61, 11], [96, 53, 12], [110, 53, 12], [122, 61, 11], [127, 74, 10], [72, 86, 7], [129, 86, 7]].map(([x, y, r]) => (
            <circle key={`${x}-${y}`} cx={x} cy={y} r={r} />
          ))}
        </g>
      );
    case 4:
      return (
        <g fill={color}>
          <path d="M70 92 C66 62 80 46 100 46 C120 46 134 62 130 92 C126 74 116 62 101 60 C99 66 92 70 84 72 C78 76 73 84 70 92 Z" />
          <path d="M70 86 C67 104 69 118 65 132 L74 130 C76 116 76 102 75 90 Z" />
          <path d="M130 86 C133 104 131 118 135 132 L126 130 C124 116 124 102 125 90 Z" />
        </g>
      );
    case 5:
      return (
        <g fill={color}>
          <path d="M71 86 C68 60 82 48 100 48 C118 48 132 60 129 86 C126 72 114 64 100 64 C86 64 74 72 71 86 Z" />
          <circle cx="100" cy="40" r="12" />
          <rect x="90" y="48" width="20" height="4" rx="2" fill={shade(color, 0.35)} />
        </g>
      );
    case 6: return <path d="M73 80 C74 64 86 58 100 58 C114 58 126 64 127 80 C120 70 110 66 100 66 C90 66 80 70 73 80 Z" fill={color} />;
    default: return <ellipse cx="110" cy="64" rx="8" ry="4" fill="#fff" opacity="0.08" />;
  }
}

function Body({ item, outfit, url }: { item?: string; outfit: string; url: UrlFn }) {
  switch (item) {
    case 'cor_gibao':
      return (
        <g>
          <path d="M30 200 C34 166 56 146 86 140 L100 160 L114 140 C144 146 166 166 170 200 Z" fill="#6E4527" />
          <path d="M100 160 C150 160 166 172 170 200 L100 200 Z" fill="#000" opacity="0.12" />
          <path d="M86 140 L100 160 L114 140" stroke="#9A6A3E" strokeWidth="2" fill="none" />
          <path d="M95 166 L105 172 M105 166 L95 172 M95 177 L105 183 M105 177 L95 183 M95 188 L105 194 M105 188 L95 194" stroke="#3A2414" strokeWidth="1.6" />
          <g stroke="#9A6A3E" strokeWidth="1.4" strokeDasharray="3 3" fill="none">
            <path d="M44 166 C56 158 68 153 82 151" /><path d="M156 166 C144 158 132 153 118 151" />
          </g>
        </g>
      );
    case 'cor_malha':
      return (
        <g>
          <path d="M22 200 C26 164 54 142 100 140 C146 142 174 164 178 200 Z" fill={url('chain')} />
          <path d="M100 140 C146 142 174 164 178 200 L100 200 Z" fill="#000" opacity="0.18" />
          <path d="M86 146 L114 146 L118 200 L82 200 Z" fill={outfit} stroke={shade(outfit, 0.4)} strokeWidth="1.5" />
          <path d="M100 162 L106 170 L100 178 L94 170 Z" fill={shade(outfit, -0.35)} />
        </g>
      );
    case 'cor_placas':
      return (
        <g>
          <path d="M54 200 C54 170 70 148 100 145 C130 148 146 170 146 200 Z" fill={url('steel')} />
          <path d="M100 147 L100 200" stroke="#EEF2F7" strokeWidth="1.5" opacity="0.7" />
          <path d="M60 176 C80 168 120 168 140 176 M58 190 C80 182 120 182 142 190" stroke="#566070" strokeWidth="1.2" fill="none" />
          <path d="M83 133 Q100 143 117 133 L119 142 Q100 154 81 142 Z" fill="#9AA3B1" />
        </g>
      );
    case 'cor_sentinela':
      return (
        <g>
          <path d="M52 200 C52 170 68 148 100 144 C132 148 148 170 148 200 Z" fill={url('stone')} />
          <path d="M100 151 L100 197" stroke="#7FE3C4" strokeWidth="2" opacity="0.9" />
          <path d="M94 160 L100 166 L106 160 M94 176 L100 182 L106 176" stroke="#7FE3C4" strokeWidth="1.6" fill="none" opacity="0.9" />
          <path d="M70 168 L78 174 L74 184" stroke="#2A3832" strokeWidth="1.2" fill="none" />
          <path d="M83 133 Q100 142 117 133 L119 141 Q100 152 81 141 Z" fill="#5E7A6E" />
        </g>
      );
    default:
      return <path d="M86 137 L100 158 L114 137" stroke={shade(outfit, -0.25)} strokeWidth="2" fill="none" />;
  }
}

function Pauldrons({ item, url }: { item?: string; url: UrlFn }) {
  if (item === 'cor_placas') {
    return (
      <g>
        <path d="M16 178 C16 157 35 142 60 144 C71 146 75 157 70 167 C58 162 40 166 26 181 Z" fill={url('steel')} />
        <path d="M184 178 C184 157 165 142 140 144 C129 146 125 157 130 167 C142 162 160 166 174 181 Z" fill={url('steel')} />
        <path d="M24 170 C36 158 52 154 66 156 M176 170 C164 158 148 154 134 156" stroke="#566070" strokeWidth="1.2" fill="none" />
      </g>
    );
  }
  if (item === 'cor_sentinela') {
    return (
      <g fill={url('stone')} stroke="#2A3832" strokeWidth="1">
        <path d="M14 180 L21 152 L62 143 L71 164 L28 184 Z" />
        <path d="M186 180 L179 152 L138 143 L129 164 L172 184 Z" />
      </g>
    );
  }
  return null;
}

function Cape({ item, outfit }: { item?: string; outfit: string }) {
  if (!item) return null;
  const color = item === 'cap_curta' ? shade(outfit, 0.38)
    : item === 'cap_constante' ? '#4B2E83'
    : item === 'cap_fenix' ? '#B8321E' : '#1B1E26';
  const edge = item === 'cap_constante' ? '#D9B26A' : item === 'cap_mestre' ? '#FF7A3D' : item === 'cap_fenix' ? '#FF9A4D' : shade(outfit, -0.1);
  return (
    <g>
      <path d={DRAPE_L} fill={color} />
      <path d={DRAPE_R} fill={color} />
      <path d={DRAPE_R} fill="#000" opacity="0.15" />
      <g stroke={edge} strokeWidth={item === 'cap_curta' ? 1.6 : 2.6} fill="none">
        <path d="M71 139 C64 156 60 178 62 200" />
        <path d="M129 139 C136 156 140 178 138 200" />
      </g>
      {item === 'cap_fenix' && (
        <g fill="#FF7A3D">
          {[[30, 156, -40], [42, 148, -30], [55, 143, -20], [145, 143, 20], [158, 148, 30], [170, 156, 40]].map(([x, y, r]) => (
            <path key={`${x}`} d="M0 0 C-4 -6 -3 -12 0 -16 C3 -12 4 -6 0 0 Z" transform={`translate(${x} ${y}) rotate(${r})`} />
          ))}
        </g>
      )}
      {item !== 'cap_mestre' && (
        <g>
          <path d="M80 142 Q100 151 120 142" stroke="#D9B26A" strokeWidth="1.2" fill="none" />
          <circle cx="80" cy="142" r="3.6" fill="#D9B26A" />
          <circle cx="120" cy="142" r="3.6" fill="#D9B26A" />
        </g>
      )}
    </g>
  );
}

function Amulet({ item, url }: { item?: string; url: UrlFn }) {
  if (!item) return null;
  return (
    <g>
      <path d="M87 127 C86 146 92 158 100 163 C108 158 114 146 113 127" stroke="#C9A66B" strokeWidth="1.4" fill="none" />
      {item === 'amu_ampulheta' && (
        <g>
          <path d="M93 162 L107 162 L102 170 L107 178 L93 178 L98 170 Z" fill="#E2C27A" stroke="#8A6A2A" strokeWidth="1" />
          <path d="M101.5 164.5 L99 169 L102 172.5" stroke="#5A3E1A" strokeWidth="1" fill="none" />
        </g>
      )}
      {item === 'amu_calma' && (
        <g>
          <path d="M100 161 C106.5 167 108.5 175 100 179.5 C91.5 175 93.5 167 100 161 Z" fill="#3FB8A5" />
          <ellipse cx="97.4" cy="170" rx="1.8" ry="3.2" fill="#fff" opacity="0.5" />
        </g>
      )}
      {item === 'amu_equilibrio' && (
        <g>
          <circle cx="100" cy="170" r="8" fill={url('gold')} stroke="#8A6A2A" strokeWidth="1" />
          {[0, 1, 2, 3, 4].map((k) => {
            const a = (-90 + k * 72) * (Math.PI / 180);
            return <circle key={k} cx={100 + Math.cos(a) * 4.4} cy={170 + Math.sin(a) * 4.4} r="1.3" fill="#3A2A10" />;
          })}
        </g>
      )}
    </g>
  );
}

function Weapon({ item, url }: { item?: string; url: UrlFn }) {
  switch (item) {
    case 'arm_martelo':
      return (
        <g>
          <path d="M128 200 L160 100" stroke="#8A5A33" strokeWidth="6" strokeLinecap="round" />
          <g transform="translate(162 94) rotate(-18)">
            <rect x="-15" y="-8" width="30" height="16" rx="3" fill="#7C8594" />
            <rect x="-15" y="-8" width="30" height="5" rx="2" fill="#AAB3C1" />
          </g>
        </g>
      );
    case 'arm_cajado':
      return (
        <g>
          <path d="M72 200 L40 72" stroke="#5A3E2B" strokeWidth="5" strokeLinecap="round" />
          <path d="M30 70 C30 56 46 52 48 64 M50 70 C50 56 34 52 32 64" stroke="#B8862E" strokeWidth="2" fill="none" />
          <circle cx="39" cy="62" r="16" fill="#6AA8FF" opacity="0.22" />
          <circle cx="39" cy="62" r="8.5" fill={url('orb')} />
        </g>
      );
    case 'arm_lamina':
      return (
        <g>
          <path d="M156 96 L118 200" stroke="#C9D1DD" strokeWidth="7" strokeLinecap="round" />
          <path d="M154 102 L158.8 88.8" stroke="#3A2A20" strokeWidth="6" strokeLinecap="round" />
          <path d="M142.7 97.9 L165.3 106.1" stroke="#D9B26A" strokeWidth="5" strokeLinecap="round" />
          <circle cx="160.6" cy="84.4" r="4.6" fill="#D9B26A" />
        </g>
      );
    case 'arm_martelo_juiz':
      return (
        <g>
          <path d="M124 200 L160 92" stroke="#2E3138" strokeWidth="7" strokeLinecap="round" />
          <circle cx="163" cy="86" r="26" fill="#FF7A3D" opacity="0.14" />
          <g transform="translate(163 86) rotate(-18)">
            <rect x="-24" y="-13" width="48" height="26" rx="4" fill="#3A3F4A" />
            <rect x="-24" y="-13" width="48" height="7" rx="3" fill="#5B6270" />
            <path d="M-15 2 L-7 -4 L1 2 L9 -4 L16 2" stroke="#FF7A3D" strokeWidth="2.4" fill="none" strokeLinejoin="round" />
          </g>
        </g>
      );
    default:
      return null;
  }
}

function Head({ item, url }: { item?: string; url: UrlFn }) {
  switch (item) {
    case 'cab_faixa':
      return (
        <g>
          <path d="M71 72 C86 66 114 66 129 72 L129 79 C114 73 86 73 71 79 Z" fill="#C8562B" />
          <path d="M127 74 L139 70 L137 78 Z M127 77 L138 85 L132 87 Z" fill="#A8441F" />
        </g>
      );
    case 'cab_capuz':
      return (
        <g>
          <path fillRule="evenodd" fill="#4A4F5C"
                d="M58 104 C54 62 74 38 100 38 C126 38 146 62 142 104 C140 124 128 140 112 144 L88 144 C72 140 60 124 58 104 Z M100 54 C84 54 73 66 73 86 C73 108 86 121 100 121 C114 121 127 108 127 86 C127 66 116 54 100 54 Z" />
          <path d="M100 54 C84 54 73 66 73 86 C73 108 86 121 100 121 C114 121 127 108 127 86 C127 66 116 54 100 54 Z" stroke="#2A2D35" strokeWidth="3" fill="none" opacity="0.6" />
          <path d="M120 44 C134 54 142 76 141 100 L130 90 C130 70 126 56 120 44 Z" fill="#000" opacity="0.15" />
        </g>
      );
    case 'cab_elmo_silencio':
      return (
        <g>
          <path d="M70 90 C68 60 82 44 100 44 C118 44 132 60 130 90 L124 90 C122 72 112 62 100 62 C88 62 78 72 76 90 Z" fill={url('blue')} />
          <rect x="63" y="77" width="15" height="29" rx="6" fill={url('blue')} />
          <rect x="122" y="77" width="15" height="29" rx="6" fill={url('blue')} />
          <path d="M100 44 L100 62" stroke="#C6DAFF" strokeWidth="3" />
          <circle cx="70.5" cy="91" r="2" fill="#C6DAFF" /><circle cx="129.5" cy="91" r="2" fill="#C6DAFF" />
        </g>
      );
    case 'cab_elmo_ferro':
      return (
        <g>
          <path d="M69 84 C67 56 82 42 100 42 C118 42 133 56 131 84 Z" fill={url('steel')} />
          <rect x="66" y="79" width="68" height="9" rx="4" fill="#8A93A3" />
          <path d="M96 86 L104 86 L102.5 104 L97.5 104 Z" fill="#8A93A3" />
          {[74, 86, 114, 126].map((x) => <circle key={x} cx={x} cy="83.5" r="1.4" fill="#566070" />)}
        </g>
      );
    case 'cab_coroa':
      return (
        <g>
          {[[84, 67, 0.7], [100, 63, 1], [116, 67, 0.7]].map(([x, y, s]) => (
            <path key={x} d="M0 0 C-4 -6 -3 -12 0 -18 C3 -12 4 -6 0 0 Z" fill={url('ember')} transform={`translate(${x} ${y}) scale(${s})`} />
          ))}
          <path d="M73 70 C86 64 114 64 127 70 L127 77 C114 71 86 71 73 77 Z" fill={url('gold')} />
          {[86, 100, 114].map((x, i) => <circle key={x} cx={x} cy={i === 1 ? 68.6 : 70.4} r="2" fill="#FF5A1F" />)}
        </g>
      );
    default:
      return null;
  }
}

function Frame({ item, colors, url }: { item?: string; colors: (typeof FRAMES)[string]; url: UrlFn }) {
  const ring = (
    <>
      <circle cx="100" cy="100" r="91" fill="none" stroke={colors.ring} strokeWidth="5" />
      <circle cx="100" cy="100" r="88" fill="none" stroke={colors.ring2} strokeWidth="1.5" />
    </>
  );
  const around = (n: number, render: (deg: number, i: number) => JSX.Element) =>
    Array.from({ length: n }, (_, i) => render((360 / n) * i, i));

  switch (item) {
    case 'mol_ferro':
      return (
        <g>
          {ring}
          {around(4, (a) => <circle key={a} cx="100" cy="9" r="3.4" fill={colors.ring2} stroke={colors.ring} strokeWidth="1.5" transform={`rotate(${a} 100 100)`} />)}
        </g>
      );
    case 'mol_aco':
      return (
        <g>
          {ring}
          <circle cx="100" cy="100" r="96.5" fill="none" stroke={colors.ring} strokeWidth="1.2" />
          {around(12, (a) => <path key={a} d="M100 3.5 L100 6.8" stroke={colors.ring} strokeWidth="1.6" transform={`rotate(${a} 100 100)`} />)}
        </g>
      );
    case 'mol_runas':
      return (
        <g>
          {ring}
          {around(8, (a, i) => (
            <path key={a} d={i % 2 ? 'M97 7.5 L100 11.5 L103 7.5' : 'M98 6.5 L102 9.5 L98 12.5'} stroke="#C6DAFF" strokeWidth="1.3" fill="none"
                  transform={`rotate(${a + 22.5} 100 100)`} />
          ))}
          <circle cx="100" cy="6" r="9" fill={colors.ring} opacity="0.25" />
          <path d="M100 -1 L106 6 L100 13 L94 6 Z" fill={colors.ring} stroke="#E6F0FF" strokeWidth="1" />
        </g>
      );
    case 'mol_chamas':
      return (
        <g>
          {around(16, (a, i) => (
            <path key={a} d="M-4.5 0 C-4.5 -5 -1.5 -8 0 -13 C1.5 -8 4.5 -5 4.5 0 Z" fill={url('ember')}
                  transform={`rotate(${a} 100 100) translate(100 ${i % 2 ? 9 : 8}) scale(${i % 2 ? 0.75 : 1})`} />
          ))}
          {ring}
        </g>
      );
    case 'mol_66':
      return (
        <g>
          {ring}
          <circle cx="100" cy="100" r="96.5" fill="none" stroke={colors.ring} strokeWidth="1.5" />
          {around(6, (a) => (
            <path key={a} d="M100 -2 L102 3 L107 5 L102 7 L100 12 L98 7 L93 5 L98 3 Z" fill="#FFF1C2" transform={`rotate(${a} 100 100)`} />
          ))}
        </g>
      );
    default:
      return <g>{ring}</g>;
  }
}
