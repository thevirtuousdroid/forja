import { useId } from 'react';
import type { AvatarConfig, Slot } from '../lib/types';
import { HAIR_COLORS, OUTFIT_COLORS, SKIN_TONES } from '../lib/rpg';

// Personagem · estilo Cyberforge Industrial.
// Desenho vetorial em camadas (fundo → arma → cabelo de trás → corpo → capa → pescoço → amuleto → rosto → cabelo → cabeça → moldura).
// Mesmo AvatarConfig, mesmos espaços e mesmos ids de item de sempre: só o traço mudou.

/** Mistura uma cor hex com preto (amt > 0) ou branco (amt < 0). */
export function shade(hex: string, amt: number): string {
  const n = parseInt(hex.slice(1), 16);
  const target = amt > 0 ? 0 : 255;
  const a = Math.abs(amt);
  const ch = (v: number) => Math.round(v + (target - v) * a);
  const r = ch((n >> 16) & 255), g = ch((n >> 8) & 255), b = ch(n & 255);
  return `#${((1 << 24) | (r << 16) | (g << 8) | b).toString(16).slice(1)}`;
}

const TECH = '#39D5D0';
const ACCENT = '#FF7138';

const FRAMES: Record<string, { ring: string; ring2: string; bg1: string; bg2: string; glow: string }> = {
  mol_bronze: { ring: '#B98454', ring2: '#4E3420', bg1: '#1F2A33', bg2: '#080C10', glow: '#FF9A5C' },
  mol_ferro: { ring: '#8D9AA8', ring2: '#3A4652', bg1: '#1E2A35', bg2: '#080C10', glow: '#B7C4D2' },
  mol_aco: { ring: '#D5DEE8', ring2: '#5E6B7A', bg1: '#1C2B3A', bg2: '#070B10', glow: '#E8F1FA' },
  mol_runas: { ring: '#5FB4FF', ring2: '#24476E', bg1: '#132640', bg2: '#060A12', glow: '#8FCBFF' },
  mol_chamas: { ring: '#FF7138', ring2: '#7A2A0E', bg1: '#2E1609', bg2: '#0A0604', glow: '#FFB45E' },
  mol_66: { ring: '#EBC56A', ring2: '#7E5F1C', bg1: '#2A2210', bg2: '#0A0804', glow: '#FFE6A3' },
};

// Silhuetas base
const TORSO = 'M14 200 C18 160 50 138 100 136 C150 138 182 160 186 200 Z';
const DRAPE_L = 'M12 200 C14 166 36 146 71 139 C64 156 60 178 62 200 Z';
const DRAPE_R = 'M188 200 C186 166 164 146 129 139 C136 156 140 178 138 200 Z';
const FACE = 'M73 84 C73 63 85 55 100 55 C115 55 127 63 127 84 C127 99 123 109 114 115.5 C109 119 104.5 120.5 100 120.5 C95.5 120.5 91 119 86 115.5 C77 109 73 99 73 84 Z';

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
  const skinShade = shade(skin, 0.24);
  const skinDeep = shade(skin, 0.4);
  const skinLight = shade(skin, -0.16);
  const hair = HAIR_COLORS[config.corCabelo]?.color ?? HAIR_COLORS[1].color;
  const outfit = OUTFIT_COLORS[config.corRoupa]?.color ?? OUTFIT_COLORS[0].color;
  const lip = shade(skin, 0.34);
  const frame = FRAMES[equip.moldura ?? 'mol_bronze'] ?? FRAMES.mol_bronze;
  const style = config.cabelo;
  const ctx: Ctx = { url, outfit, hair, skin };

  return (
    <svg width={size} height={size} viewBox="-8 -8 216 216" role="img" className={className}
         aria-label={label ?? 'Personagem'} style={locked ? { filter: 'grayscale(1) brightness(.72)', opacity: 0.8 } : undefined}>
      <defs>
        <radialGradient id={id('bg')} cx="0.5" cy="0.34" r="0.72">
          <stop offset="0" stopColor={frame.bg1} />
          <stop offset="1" stopColor={frame.bg2} />
        </radialGradient>
        <clipPath id={id('clip')}><circle cx="100" cy="100" r="88" /></clipPath>
        <clipPath id={id('face')}><path d={FACE} /></clipPath>
        <pattern id={id('grid')} width="12" height="12" patternUnits="userSpaceOnUse">
          <path d="M12 0 L0 0 L0 12" fill="none" stroke="#8FB7C9" strokeWidth="0.4" />
        </pattern>
        <radialGradient id={id('skin')} cx="0.4" cy="0.36" r="0.7">
          <stop offset="0" stopColor={skinLight} />
          <stop offset="0.55" stopColor={skin} />
          <stop offset="1" stopColor={skinShade} />
        </radialGradient>
        <linearGradient id={id('cloth')} x1="0" y1="0" x2="1" y2="0.4">
          <stop offset="0" stopColor={shade(outfit, -0.14)} />
          <stop offset="0.55" stopColor={outfit} />
          <stop offset="1" stopColor={shade(outfit, 0.38)} />
        </linearGradient>
        <linearGradient id={id('hair')} x1="0" y1="0" x2="0.6" y2="1">
          <stop offset="0" stopColor={shade(hair, -0.22)} />
          <stop offset="0.5" stopColor={hair} />
          <stop offset="1" stopColor={shade(hair, 0.3)} />
        </linearGradient>
        <linearGradient id={id('steel')} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#DCE3EC" /><stop offset="0.5" stopColor="#8E99A8" /><stop offset="1" stopColor="#3F4955" />
        </linearGradient>
        <linearGradient id={id('gun')} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#5C6774" /><stop offset="1" stopColor="#1E252D" />
        </linearGradient>
        <linearGradient id={id('stone')} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#7FA597" /><stop offset="1" stopColor="#24382F" />
        </linearGradient>
        <linearGradient id={id('blue')} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#7FB0EE" /><stop offset="1" stopColor="#24406E" />
        </linearGradient>
        <linearGradient id={id('gold')} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#F6DA92" /><stop offset="1" stopColor="#A87A26" />
        </linearGradient>
        <linearGradient id={id('ember')} x1="0" y1="1" x2="0" y2="0">
          <stop offset="0" stopColor="#FF4E1A" /><stop offset="1" stopColor="#FFD27A" />
        </linearGradient>
        <radialGradient id={id('orb')} cx="0.4" cy="0.35" r="0.65">
          <stop offset="0" stopColor="#F0FFFE" /><stop offset="0.5" stopColor="#7CEAE5" /><stop offset="1" stopColor="#1D8F8B" />
        </radialGradient>
        <pattern id={id('mesh')} width="7" height="6" patternUnits="userSpaceOnUse">
          <rect width="7" height="6" fill="#2A323C" />
          <path d="M0 3 L1.75 0 L5.25 0 L7 3 L5.25 6 L1.75 6 Z" fill="none" stroke="#8C98A6" strokeWidth="0.7" />
        </pattern>
      </defs>

      {/* Fundo: placa escura com grade técnica e luz da forja */}
      <circle cx="100" cy="100" r="88" fill={url('bg')} />

      <g clipPath={url('clip')}>
        <rect x="0" y="0" width="200" height="200" fill={url('grid')} opacity="0.07" />
        <ellipse cx="100" cy="210" rx="92" ry="34" fill={frame.glow} opacity="0.13" />
        <g transform="translate(100 112) scale(1.12) translate(-100 -112)">

        {/* Ferramenta, atrás do corpo */}
        <Weapon item={equip.arma} url={url} />

        {/* Cabelo de trás */}
        {style === 4 && <path d="M68 84 C62 120 66 150 58 172 L142 172 C134 150 138 120 132 84 C132 60 118 46 100 46 C82 46 68 60 68 84 Z" fill={url('hair')} />}
        {style === 6 && <path d="M55 92 C49 50 74 29 100 29 C126 29 151 50 145 92 C143 108 135 117 128 119 L72 119 C65 117 57 108 55 92 Z" fill={url('hair')} />}
        {style === 3 && (
          <g fill={shade(hair, 0.12)}><circle cx="69" cy="96" r="9" /><circle cx="131" cy="96" r="9" /><circle cx="72" cy="108" r="7" /><circle cx="128" cy="108" r="7" /></g>
        )}

        {/* Corpo: jaqueta técnica de gola alta */}
        <path d={TORSO} fill={url('cloth')} />
        <path d="M100 136 C150 138 182 160 186 200 L100 200 Z" fill="#000" opacity="0.16" />
        <path d="M14 200 C18 160 50 138 100 136" stroke={shade(outfit, -0.35)} strokeWidth="1.2" fill="none" opacity="0.5" />
        <path d="M87 137 L100 157 L113 137 Z" fill={shade(outfit, 0.45)} />
        <Body item={equip.corpo} ctx={ctx} />

        {/* Capa: gola alta fica atrás do pescoço */}
        {equip.capa === 'cap_constante' && <path d="M79 135 C77 120 86 110 100 110 C114 110 123 120 121 135 Z" fill="#33205C" />}
        <Cape item={equip.capa} outfit={outfit} />
        <Pauldrons item={equip.corpo} url={url} />

        {/* Pescoço */}
        <path d="M87 106 L87 138 Q100 146 113 138 L113 106 Z" fill={skin} />
        <path d="M87 112 Q100 130 113 112 L113 106 L87 106 Z" fill={skinDeep} opacity="0.55" />
        <path d="M108 118 L112 136" stroke={skinShade} strokeWidth="1.4" opacity="0.5" strokeLinecap="round" />
        {equip.capa === 'cap_mestre' && (
          <g>
            {[72, 80, 88, 96, 104, 112, 120, 128].map((x, i) => <circle key={x} cx={x} cy={137 + (i % 2) * 2} r="7" fill={i % 2 ? '#5D6470' : '#7C8592'} />)}
            {[76, 92, 108, 124].map((x) => <circle key={x} cx={x} cy="134" r="2.4" fill={ACCENT} />)}
          </g>
        )}
        <Amulet item={equip.amuleto} url={url} />

        {/* Orelhas, com um implante discreto na direita */}
        <ellipse cx="73.5" cy="90" rx="5" ry="8" fill={skinShade} />
        <ellipse cx="126.5" cy="90" rx="5" ry="8" fill={skinShade} />
        <path d="M72.5 85.5 Q70.5 90 72.5 94.5" stroke={skinDeep} strokeWidth="1.3" fill="none" />
        <path d="M127.5 85.5 Q129.5 90 127.5 94.5" stroke={skinDeep} strokeWidth="1.3" fill="none" />
        <rect x="128.6" y="86.5" width="3.4" height="7" rx="1.4" fill="#2A333D" />
        <circle cx="130.3" cy="88.7" r="1" fill={TECH} />

        {/* Rosto */}
        <path d={FACE} fill={url('skin')} />
        <g clipPath={url('face')}>
          <path d="M116 56 C130 70 130 104 112 122 L132 122 L132 56 Z" fill={skinDeep} opacity="0.32" />
          <path d="M125.6 74 C127 86 126 100 120 109" stroke={TECH} strokeWidth="1.6" fill="none" opacity="0.4" strokeLinecap="round" />
          <ellipse cx="85" cy="100" rx="6" ry="3.4" fill={shade(skin, 0.1)} opacity="0.2" />
          <ellipse cx="115" cy="100" rx="6" ry="3.4" fill={shade(skin, 0.14)} opacity="0.2" />
          <path d="M80 112 C88 122 112 122 120 112 L120 124 L80 124 Z" fill={skinDeep} opacity="0.2" />
        </g>

        {config.barba === 1 && (
          <g fill={hair} opacity="0.3">
            <path d="M75 94 C76 112 88 121 100 121 C112 121 124 112 125 94 C121 107 112 114 100 114 C88 114 79 107 75 94 Z" />
            <ellipse cx="100" cy="104" rx="9" ry="2.6" />
          </g>
        )}
        {config.barba === 2 && (
          <g>
            <path d="M73 90 C72 120 86 132 100 132 C114 132 128 120 127 90 C124 100 118 106 112 107 C108 103 92 103 88 107 C82 106 76 100 73 90 Z" fill={url('hair')} />
            <path d="M88 104.5 C94 100.5 106 100.5 112 104.5 C108 107.5 92 107.5 88 104.5 Z" fill={hair} />
            <g stroke={shade(hair, -0.25)} strokeWidth="0.8" opacity="0.45" fill="none" strokeLinecap="round">
              <path d="M84 112 L86 120" /><path d="M93 116 L94 126" /><path d="M107 116 L106 126" /><path d="M116 112 L114 120" />
            </g>
          </g>
        )}

        {/* Olhos */}
        <g>
          <path d="M84 90.5 Q90 85.5 96 90.5 Q90 94 84 90.5 Z" fill="#EFE9E2" />
          <path d="M104 90.5 Q110 85.5 116 90.5 Q110 94 104 90.5 Z" fill="#EFE9E2" />
          <circle cx="90.2" cy="90" r="3" fill="#3A2A20" />
          <circle cx="110.2" cy="90" r="3" fill="#3A2A20" />
          <circle cx="90.2" cy="90" r="1.5" fill="#0D0B0E" />
          <circle cx="110.2" cy="90" r="1.5" fill="#0D0B0E" />
          <circle cx="91.2" cy="88.9" r="0.9" fill="#fff" />
          <circle cx="111.2" cy="88.9" r="0.9" fill="#fff" />
          <g stroke="#1D1A22" strokeWidth="1.5" fill="none" strokeLinecap="round">
            <path d="M83.6 90.6 Q90 84.8 96.4 90.2" />
            <path d="M103.6 90.2 Q110 84.8 116.4 90.6" />
          </g>
        </g>
        {/* Sobrancelhas */}
        <g fill={style === 7 ? shade(skin, 0.5) : shade(hair, 0.05)}>
          <path d="M83 82.5 Q89 78 96 80 L95.6 82.3 Q89 81 83.6 84 Z" />
          <path d="M104 80 Q111 78 117 82.5 L116.4 84 Q111 81 104.4 82.3 Z" />
        </g>
        {/* Nariz e boca */}
        <path d="M100 91 Q98 98 97 100.5 Q99.5 102.4 103 101" stroke={skinDeep} strokeWidth="1.5" fill="none" strokeLinecap="round" strokeLinejoin="round" />
        <path d="M101.5 92 Q102.8 97 102.5 99" stroke={skinLight} strokeWidth="1" fill="none" opacity="0.7" strokeLinecap="round" />
        <path d="M93.8 107.6 Q100 110.6 106.2 107.6" stroke={config.barba === 2 ? shade(skin, 0.15) : lip} strokeWidth="2" fill="none" strokeLinecap="round" />
        <path d="M96 111.4 Q100 112.6 104 111.4" stroke={skinDeep} strokeWidth="1" fill="none" opacity="0.4" strokeLinecap="round" />

        <HairFront style={style} color={hair} url={url} />
        <Head item={equip.cabeca} url={url} />
        </g>
      </g>

      <Frame item={equip.moldura} colors={frame} url={url} />
    </svg>
  );
}

// ── Camadas ─────────────────────────────────────────────────────────────────

type UrlFn = (k: string) => string;
interface Ctx { url: UrlFn; outfit: string; hair: string; skin: string }

function HairFront({ style, color, url }: { style: number; color: string; url: UrlFn }) {
  const fill = url('hair');
  const strand = shade(color, -0.3);
  const shine = (d: string) => <path d={d} stroke={strand} strokeWidth="1.2" fill="none" opacity="0.55" strokeLinecap="round" />;
  switch (style) {
    case 0:
      return (
        <g>
          <path d="M73 86 C71 62 84 51 100 51 C116 51 129 62 127 86 C125 74 116 64 100 64 C84 64 75 74 73 86 Z" fill={fill} opacity="0.85" />
          <path d="M80 70 C86 62 96 59 104 59" stroke={strand} strokeWidth="0.8" fill="none" opacity="0.4" strokeDasharray="1.5 2" />
        </g>
      );
    case 1:
      return (
        <g>
          <path d="M70 88 C66 60 80 46 100 46 C121 46 134 60 130 88 C128 80 125 74 121 71 C113 75 104 74 98 70 C91 74 82 75 78 72 C74 76 71 82 70 88 Z" fill={fill} />
          {shine('M86 54 C94 50 106 50 114 54')}
          {shine('M98 70 C99 62 103 56 108 52')}
        </g>
      );
    case 2:
      return (
        <g>
          <path d="M70 90 C65 58 82 44 102 44 C124 44 136 60 130 90 C127 76 122 68 114 66 C104 70 92 78 82 84 C78 82 74 86 70 90 Z" fill={fill} />
          {shine('M84 80 C94 72 106 66 116 58')}
          {shine('M92 52 C102 48 114 50 122 56')}
        </g>
      );
    case 3:
      return (
        <g fill={fill}>
          {[[76, 74, 10], [83, 61, 11], [96, 53, 12], [110, 53, 12], [122, 61, 11], [127, 74, 10], [72, 86, 7], [129, 86, 7]].map(([x, y, r]) => (
            <g key={`${x}-${y}`}>
              <circle cx={x} cy={y} r={r} />
              <path d={`M${x - r * 0.5} ${y - r * 0.2} q${r * 0.5} ${-r * 0.6} ${r} 0`} stroke={shade(color, -0.32)} strokeWidth="1" fill="none" opacity="0.6" />
            </g>
          ))}
        </g>
      );
    case 4:
      return (
        <g>
          <g fill={fill}>
            <path d="M70 92 C66 62 80 46 100 46 C120 46 134 62 130 92 C126 74 116 62 101 60 C99 66 92 70 84 72 C78 76 73 84 70 92 Z" />
            <path d="M70 86 C67 104 69 118 65 132 L74 130 C76 116 76 102 75 90 Z" />
            <path d="M130 86 C133 104 131 118 135 132 L126 130 C124 116 124 102 125 90 Z" />
          </g>
          {shine('M101 60 C108 54 116 52 122 56')}
          {shine('M70 98 C70 110 69 120 67 128')}
        </g>
      );
    case 5:
      return (
        <g>
          <g fill={fill}>
            <path d="M71 86 C68 60 82 48 100 48 C118 48 132 60 129 86 C126 72 114 64 100 64 C86 64 74 72 71 86 Z" />
            <circle cx="100" cy="40" r="12" />
          </g>
          <rect x="89" y="47" width="22" height="4.5" rx="1" fill="#2A333D" />
          <rect x="97" y="48" width="6" height="2.5" rx="0.6" fill={TECH} opacity="0.85" />
          {shine('M92 34 C96 30 104 30 108 34')}
        </g>
      );
    case 6:
      return (
        <g>
          <path d="M73 80 C74 64 86 58 100 58 C114 58 126 64 127 80 C120 70 110 66 100 66 C90 66 80 70 73 80 Z" fill={fill} />
          {shine('M64 60 C74 44 90 36 104 36')}
          {shine('M118 40 C130 46 138 58 140 70')}
        </g>
      );
    default:
      return <ellipse cx="111" cy="64" rx="9" ry="4" fill="#fff" opacity="0.1" />;
  }
}

function Body({ item, ctx }: { item?: string; ctx: Ctx }) {
  const { url, outfit } = ctx;
  switch (item) {
    case 'cor_gibao':
      return (
        <g>
          <path d="M30 200 C34 166 56 146 86 140 L100 160 L114 140 C144 146 166 166 170 200 Z" fill="#4A2F1E" />
          <path d="M100 160 C150 160 166 172 170 200 L100 200 Z" fill="#000" opacity="0.18" />
          <g stroke="#2C1B10" strokeWidth="1.2" fill="none" opacity="0.8">
            <path d="M40 176 C60 166 76 162 92 162" /><path d="M36 190 C58 180 76 176 94 176" />
            <path d="M160 176 C140 166 124 162 108 162" /><path d="M164 190 C142 180 124 176 106 176" />
          </g>
          <path d="M86 140 L100 160 L114 140" stroke="#8A5C36" strokeWidth="2" fill="none" />
          <path d="M100 160 L100 200" stroke="#1E130B" strokeWidth="2" />
          {[166, 178, 190].map((y) => <rect key={y} x="97.5" y={y} width="5" height="3" rx="0.8" fill={ACCENT} />)}
          <g stroke={ACCENT} strokeWidth="1" strokeDasharray="2.4 2.4" fill="none" opacity="0.75">
            <path d="M44 166 C56 158 68 153 82 151" /><path d="M156 166 C144 158 132 153 118 151" />
          </g>
        </g>
      );
    case 'cor_malha':
      return (
        <g>
          <path d="M22 200 C26 164 54 142 100 140 C146 142 174 164 178 200 Z" fill={url('mesh')} />
          <path d="M100 140 C146 142 174 164 178 200 L100 200 Z" fill="#000" opacity="0.22" />
          <path d="M84 146 L116 146 L120 200 L80 200 Z" fill={outfit} stroke={shade(outfit, 0.45)} strokeWidth="1.5" />
          <path d="M84 150 L116 150" stroke={TECH} strokeWidth="1" opacity="0.7" />
          <path d="M100 160 L107 169 L100 178 L93 169 Z" fill="#1A2129" stroke={TECH} strokeWidth="1.3" />
          <circle cx="100" cy="169" r="2" fill={TECH} />
        </g>
      );
    case 'cor_placas':
      return (
        <g>
          <path d="M54 200 C54 170 70 148 100 145 C130 148 146 170 146 200 Z" fill={url('steel')} />
          <path d="M100 147 L100 200" stroke="#F2F6FA" strokeWidth="1.5" opacity="0.6" />
          <path d="M60 176 C80 168 120 168 140 176 M58 190 C80 182 120 182 142 190" stroke="#3F4955" strokeWidth="1.4" fill="none" />
          <g fill={ACCENT}>
            <rect x="72" y="158" width="10" height="2" rx="1" /><rect x="118" y="158" width="10" height="2" rx="1" />
            <rect x="74" y="162.5" width="8" height="2" rx="1" opacity="0.7" /><rect x="118" y="162.5" width="8" height="2" rx="1" opacity="0.7" />
          </g>
          <path d="M83 133 Q100 143 117 133 L119 142 Q100 154 81 142 Z" fill="#8995A4" stroke="#3F4955" strokeWidth="1" />
          {[86, 114].map((x) => <circle key={x} cx={x} cy="141" r="1.3" fill="#3F4955" />)}
        </g>
      );
    case 'cor_sentinela':
      return (
        <g>
          <path d="M52 200 C52 170 68 148 100 144 C132 148 148 170 148 200 Z" fill={url('stone')} />
          <g stroke={TECH} strokeWidth="1.6" fill="none" strokeLinecap="round" strokeLinejoin="round">
            <path d="M100 151 L100 197" opacity="0.9" />
            <path d="M94 160 L100 166 L106 160 M94 176 L100 182 L106 176" opacity="0.9" />
            <path d="M100 188 L86 188 L80 194 M100 172 L118 172 L124 166" strokeWidth="1" opacity="0.6" />
          </g>
          <circle cx="80" cy="194" r="1.6" fill={TECH} /><circle cx="124" cy="166" r="1.6" fill={TECH} />
          <path d="M66 168 L76 174 L72 186" stroke="#1C2B25" strokeWidth="1.2" fill="none" />
          <path d="M83 133 Q100 142 117 133 L119 141 Q100 152 81 141 Z" fill="#4E6B60" stroke="#1C2B25" strokeWidth="1" />
        </g>
      );
    default:
      // Túnica / jaqueta da forja: gola técnica, costuras e faixa de luz
      return (
        <g>
          <path d="M86 137 L100 158 L114 137" stroke={shade(outfit, -0.3)} strokeWidth="2" fill="none" />
          <path d="M100 158 L100 200" stroke={shade(outfit, 0.45)} strokeWidth="1.6" />
          <g stroke={shade(outfit, 0.4)} strokeWidth="1.1" fill="none" opacity="0.8">
            <path d="M58 148 C62 162 64 180 62 200" /><path d="M142 148 C138 162 136 180 138 200" />
          </g>
          <path d="M70 168 L88 168" stroke={ACCENT} strokeWidth="2" strokeLinecap="round" />
          <circle cx="66" cy="168" r="1.6" fill={ACCENT} />
          <rect x="112" y="164" width="16" height="9" rx="1.5" fill={shade(outfit, 0.3)} stroke={shade(outfit, -0.2)} strokeWidth="0.8" />
        </g>
      );
  }
}

function Pauldrons({ item, url }: { item?: string; url: UrlFn }) {
  if (item === 'cor_placas') {
    return (
      <g>
        <path d="M16 178 C16 157 35 142 60 144 C71 146 75 157 70 167 C58 162 40 166 26 181 Z" fill={url('steel')} stroke="#3F4955" strokeWidth="1" />
        <path d="M184 178 C184 157 165 142 140 144 C129 146 125 157 130 167 C142 162 160 166 174 181 Z" fill={url('steel')} stroke="#3F4955" strokeWidth="1" />
        <path d="M24 170 C36 158 52 154 66 156 M176 170 C164 158 148 154 134 156" stroke="#3F4955" strokeWidth="1.2" fill="none" />
        <path d="M30 164 L46 157 M170 164 L154 157" stroke={ACCENT} strokeWidth="1.6" strokeLinecap="round" />
      </g>
    );
  }
  if (item === 'cor_sentinela') {
    return (
      <g>
        <g fill={url('stone')} stroke="#1C2B25" strokeWidth="1">
          <path d="M14 180 L21 152 L62 143 L71 164 L28 184 Z" />
          <path d="M186 180 L179 152 L138 143 L129 164 L172 184 Z" />
        </g>
        <path d="M28 160 L56 152 M172 160 L144 152" stroke={TECH} strokeWidth="1.3" opacity="0.8" strokeLinecap="round" />
      </g>
    );
  }
  return null;
}

function Cape({ item, outfit }: { item?: string; outfit: string }) {
  if (!item) return null;
  const color = item === 'cap_curta' ? shade(outfit, 0.42)
    : item === 'cap_constante' ? '#432A78'
    : item === 'cap_fenix' ? '#A82C1A' : '#161B22';
  const edge = item === 'cap_constante' ? '#E2BC72' : item === 'cap_mestre' ? ACCENT : item === 'cap_fenix' ? '#FFB45E' : shade(outfit, -0.12);
  return (
    <g>
      <path d={DRAPE_L} fill={color} />
      <path d={DRAPE_R} fill={color} />
      <path d={DRAPE_R} fill="#000" opacity="0.2" />
      <path d="M30 200 C32 176 44 158 64 148" stroke={shade(color, -0.2)} strokeWidth="1" fill="none" opacity="0.5" />
      <path d="M170 200 C168 176 156 158 136 148" stroke={shade(color, 0.35)} strokeWidth="1" fill="none" opacity="0.6" />
      <g stroke={edge} strokeWidth={item === 'cap_curta' ? 1.6 : 2.6} fill="none">
        <path d="M71 139 C64 156 60 178 62 200" />
        <path d="M129 139 C136 156 140 178 138 200" />
      </g>
      {item === 'cap_mestre' && (
        <g stroke={ACCENT} strokeWidth="1" opacity="0.5" fill="none">
          <path d="M66 150 C62 166 60 184 61 200" /><path d="M134 150 C138 166 140 184 139 200" />
        </g>
      )}
      {item === 'cap_fenix' && (
        <g fill="#FF7138">
          {[[30, 156, -40], [42, 148, -30], [55, 143, -20], [145, 143, 20], [158, 148, 30], [170, 156, 40]].map(([x, y, r]) => (
            <path key={`${x}`} d="M0 0 C-4 -6 -3 -12 0 -16 C3 -12 4 -6 0 0 Z" transform={`translate(${x} ${y}) rotate(${r})`} />
          ))}
        </g>
      )}
      {item !== 'cap_mestre' && (
        <g>
          <path d="M80 142 Q100 151 120 142" stroke="#C9A66B" strokeWidth="1.2" fill="none" />
          <rect x="76.5" y="138.5" width="7" height="7" rx="1.2" fill="#2A333D" stroke="#C9A66B" strokeWidth="1" />
          <rect x="116.5" y="138.5" width="7" height="7" rx="1.2" fill="#2A333D" stroke="#C9A66B" strokeWidth="1" />
          <circle cx="80" cy="142" r="1.4" fill={item === 'cap_constante' ? '#E2BC72' : ACCENT} />
          <circle cx="120" cy="142" r="1.4" fill={item === 'cap_constante' ? '#E2BC72' : ACCENT} />
        </g>
      )}
    </g>
  );
}

function Amulet({ item, url }: { item?: string; url: UrlFn }) {
  if (!item) return null;
  return (
    <g>
      <path d="M87 127 C86 146 92 158 100 163" stroke="#A7B2BF" strokeWidth="1.4" fill="none" strokeDasharray="2 1" />
      <path d="M113 127 C114 146 108 158 100 163" stroke="#A7B2BF" strokeWidth="1.4" fill="none" strokeDasharray="2 1" />
      {item === 'amu_ampulheta' && (
        <g>
          <circle cx="100" cy="170" r="11" fill="#FFB45E" opacity="0.18" />
          <path d="M93 162 L107 162 L102 170 L107 178 L93 178 L98 170 Z" fill="#E2C27A" stroke="#6E5220" strokeWidth="1" />
          <path d="M96 175.5 L104 175.5 L100 171 Z" fill="#FF7138" />
          <path d="M91.5 161.5 L108.5 161.5 M91.5 178.5 L108.5 178.5" stroke="#3A2A10" strokeWidth="1.6" strokeLinecap="round" />
        </g>
      )}
      {item === 'amu_calma' && (
        <g>
          <circle cx="100" cy="170" r="11" fill={TECH} opacity="0.2" />
          <path d="M100 161 C106.5 167 108.5 175 100 179.5 C91.5 175 93.5 167 100 161 Z" fill={TECH} stroke="#1D6F6C" strokeWidth="1" />
          <ellipse cx="97.4" cy="170" rx="1.8" ry="3.2" fill="#fff" opacity="0.6" />
        </g>
      )}
      {item === 'amu_equilibrio' && (
        <g>
          <circle cx="100" cy="170" r="11" fill="#F6DA92" opacity="0.18" />
          <circle cx="100" cy="170" r="8" fill={url('gold')} stroke="#6E5220" strokeWidth="1" />
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
          <path d="M128 200 L160 100" stroke="#2A333D" strokeWidth="6.5" strokeLinecap="round" />
          <path d="M136 176 L140 164 M142 157 L146 145" stroke="#5C6774" strokeWidth="7" />
          <g transform="translate(162 94) rotate(-18)">
            <rect x="-16" y="-9" width="32" height="18" rx="2" fill={url('gun')} />
            <rect x="-16" y="-9" width="32" height="5" rx="1.5" fill="#8C98A6" />
            <rect x="-11" y="1" width="22" height="3" rx="1" fill={ACCENT} />
          </g>
        </g>
      );
    case 'arm_cajado':
      return (
        <g>
          <path d="M72 200 L40 72" stroke="#2A333D" strokeWidth="5" strokeLinecap="round" />
          <path d="M60 152 L56 136 M52 120 L49 108" stroke={TECH} strokeWidth="1.4" opacity="0.8" />
          <path d="M30 70 C30 56 46 52 48 64 M50 70 C50 56 34 52 32 64" stroke="#8C98A6" strokeWidth="2.2" fill="none" />
          <circle cx="39" cy="62" r="17" fill={TECH} opacity="0.2" />
          <circle cx="39" cy="62" r="8.5" fill={url('orb')} />
        </g>
      );
    case 'arm_lamina':
      return (
        <g>
          <path d="M156 96 L118 200" stroke="#D6DEE8" strokeWidth="7" strokeLinecap="round" />
          <path d="M153 104 L120 194" stroke={TECH} strokeWidth="1.4" opacity="0.85" />
          <path d="M154 102 L158.8 88.8" stroke="#1E252D" strokeWidth="6" strokeLinecap="round" />
          <path d="M142.7 97.9 L165.3 106.1" stroke="#5C6774" strokeWidth="5" strokeLinecap="round" />
          <circle cx="160.6" cy="84.4" r="4.4" fill="#2A333D" stroke={TECH} strokeWidth="1.2" />
        </g>
      );
    case 'arm_martelo_juiz':
      return (
        <g>
          <path d="M124 200 L160 92" stroke="#1E252D" strokeWidth="7" strokeLinecap="round" />
          <circle cx="163" cy="86" r="28" fill={ACCENT} opacity="0.16" />
          <g transform="translate(163 86) rotate(-18)">
            <rect x="-25" y="-14" width="50" height="28" rx="3" fill="#2A2F38" stroke="#596270" strokeWidth="1" />
            <rect x="-25" y="-14" width="50" height="7" rx="2" fill="#4B5361" />
            <path d="M-15 3 L-7 -3 L1 3 L9 -3 L16 3" stroke={ACCENT} strokeWidth="2.4" fill="none" strokeLinejoin="round" />
            <path d="M-15 3 L-7 -3 L1 3 L9 -3 L16 3" stroke="#FFE2B8" strokeWidth="0.8" fill="none" strokeLinejoin="round" />
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
          <path d="M71 72 C86 66 114 66 129 72 L129 79 C114 73 86 73 71 79 Z" fill="#C24E24" />
          <path d="M71 74.5 C86 68.5 114 68.5 129 74.5" stroke="#FF9A5C" strokeWidth="0.8" fill="none" opacity="0.8" />
          <path d="M127 74 L140 69 L137 78 Z M127 77 L139 85 L132 87 Z" fill="#8E3818" />
          <rect x="95" y="68.3" width="10" height="4" rx="1" fill="#1E252D" />
          <rect x="97" y="69.3" width="6" height="2" rx="0.6" fill={TECH} />
        </g>
      );
    case 'cab_capuz':
      return (
        <g>
          <path fillRule="evenodd" fill="#373D48"
                d="M58 104 C54 62 74 38 100 38 C126 38 146 62 142 104 C140 124 128 140 112 144 L88 144 C72 140 60 124 58 104 Z M100 54 C84 54 73 66 73 86 C73 108 86 121 100 121 C114 121 127 108 127 86 C127 66 116 54 100 54 Z" />
          <path d="M100 54 C84 54 73 66 73 86 C73 108 86 121 100 121 C114 121 127 108 127 86 C127 66 116 54 100 54 Z" stroke={TECH} strokeWidth="1.4" fill="none" opacity="0.65" />
          <path d="M100 38 L100 54" stroke="#252A33" strokeWidth="1.4" />
          <path d="M120 44 C134 54 142 76 141 100 L130 90 C130 70 126 56 120 44 Z" fill="#000" opacity="0.2" />
          <path d="M66 70 C70 58 80 48 92 43" stroke="#5A6270" strokeWidth="1" fill="none" opacity="0.7" />
        </g>
      );
    case 'cab_elmo_silencio':
      return (
        <g>
          <path d="M70 90 C68 60 82 44 100 44 C118 44 132 60 130 90 L124 90 C122 72 112 62 100 62 C88 62 78 72 76 90 Z" fill={url('blue')} />
          <rect x="62" y="76" width="16" height="31" rx="6" fill={url('blue')} stroke="#18304F" strokeWidth="1" />
          <rect x="122" y="76" width="16" height="31" rx="6" fill={url('blue')} stroke="#18304F" strokeWidth="1" />
          <circle cx="70" cy="91.5" r="4.4" fill="#132640" stroke={TECH} strokeWidth="1.2" />
          <circle cx="130" cy="91.5" r="4.4" fill="#132640" stroke={TECH} strokeWidth="1.2" />
          <path d="M100 44 L100 62" stroke="#C6DAFF" strokeWidth="3" />
          <path d="M84 52 C90 48 96 46 100 46" stroke="#E6F0FF" strokeWidth="1" fill="none" opacity="0.6" />
        </g>
      );
    case 'cab_elmo_ferro':
      return (
        <g>
          <path d="M69 84 C67 56 82 42 100 42 C118 42 133 56 131 84 Z" fill={url('steel')} />
          <path d="M100 42 L100 79" stroke="#5E6B7A" strokeWidth="2" />
          <rect x="66" y="79" width="68" height="9" rx="2" fill="#6E7A88" stroke="#3F4955" strokeWidth="1" />
          <rect x="74" y="82" width="52" height="2.4" rx="1" fill={ACCENT} opacity="0.85" />
          <path d="M96 86 L104 86 L102.5 104 L97.5 104 Z" fill="#6E7A88" stroke="#3F4955" strokeWidth="0.8" />
          {[70, 130].map((x) => <circle key={x} cx={x} cy="83.5" r="1.5" fill="#2A333D" />)}
          <path d="M80 52 C86 47 93 45 98 45" stroke="#F2F6FA" strokeWidth="1.2" fill="none" opacity="0.7" />
        </g>
      );
    case 'cab_coroa':
      return (
        <g>
          {[[84, 67, 0.7], [100, 63, 1], [116, 67, 0.7]].map(([x, y, s]) => (
            <g key={x}>
              <path d="M0 0 C-4 -6 -3 -12 0 -18 C3 -12 4 -6 0 0 Z" fill={url('ember')} transform={`translate(${x} ${y}) scale(${s})`} />
              <path d="M0 0 C-1.6 -4 -1.2 -8 0 -11 C1.2 -8 1.6 -4 0 0 Z" fill="#FFF1C2" transform={`translate(${x} ${y}) scale(${s})`} />
            </g>
          ))}
          <path d="M73 70 C86 64 114 64 127 70 L127 77 C114 71 86 71 73 77 Z" fill={url('gold')} stroke="#6E5220" strokeWidth="0.8" />
          {[86, 100, 114].map((x, i) => <rect key={x} x={x - 2} y={(i === 1 ? 68.6 : 70.4) - 2} width="4" height="4" transform={`rotate(45 ${x} ${i === 1 ? 68.6 : 70.4})`} fill="#FF4E1A" />)}
        </g>
      );
    default:
      return null;
  }
}

function Frame({ item, colors, url }: { item?: string; colors: (typeof FRAMES)[string]; url: UrlFn }) {
  // Anel industrial: aro largo, aro fino interno e marcas de engate
  const ring = (
    <>
      <circle cx="100" cy="100" r="91" fill="none" stroke={colors.ring2} strokeWidth="6" />
      <circle cx="100" cy="100" r="91" fill="none" stroke={colors.ring} strokeWidth="3.4" strokeDasharray="44 4" />
      <circle cx="100" cy="100" r="87.6" fill="none" stroke={colors.glow} strokeWidth="0.8" opacity="0.55" />
    </>
  );
  const around = (n: number, render: (deg: number, i: number) => JSX.Element) =>
    Array.from({ length: n }, (_, i) => render((360 / n) * i, i));
  const notch = (a: number) => <rect key={`n${a}`} x="96" y="5.5" width="8" height="5" rx="1" fill={colors.ring2} stroke={colors.ring} strokeWidth="1" transform={`rotate(${a} 100 100)`} />;

  switch (item) {
    case 'mol_ferro':
      return (
        <g>
          {ring}
          {around(4, (a) => notch(a + 45))}
          {around(4, (a) => <circle key={a} cx="100" cy="8" r="1.4" fill={colors.ring} transform={`rotate(${a + 45} 100 100)`} />)}
        </g>
      );
    case 'mol_aco':
      return (
        <g>
          {ring}
          <circle cx="100" cy="100" r="96.5" fill="none" stroke={colors.ring} strokeWidth="1.2" />
          {around(24, (a, i) => <path key={a} d={i % 2 ? 'M100 3.6 L100 5.6' : 'M100 2.8 L100 6.6'} stroke={colors.ring} strokeWidth="1.4" transform={`rotate(${a} 100 100)`} />)}
        </g>
      );
    case 'mol_runas':
      return (
        <g>
          {ring}
          {around(8, (a, i) => (
            <path key={a} d={i % 2 ? 'M97 7.5 L100 11.5 L103 7.5' : 'M98 6.5 L102 9.5 L98 12.5'} stroke="#C6E4FF" strokeWidth="1.3" fill="none"
                  transform={`rotate(${a + 22.5} 100 100)`} />
          ))}
          <circle cx="100" cy="6" r="10" fill={colors.ring} opacity="0.25" />
          <path d="M100 -1 L106 6 L100 13 L94 6 Z" fill={colors.ring} stroke="#E6F4FF" strokeWidth="1" />
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
      return <g>{ring}{around(3, (a) => notch(a + 60))}</g>;
  }
}
