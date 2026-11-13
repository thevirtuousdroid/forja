import { useId } from 'react';
import hidra from '../assets/bosses/hidra.webp';
import tempestade from '../assets/bosses/tempestade.webp';
import adiador from '../assets/bosses/adiador.webp';
import nevoa from '../assets/bosses/nevoa.webp';
import sentinela from '../assets/bosses/sentinela.webp';
import errante from '../assets/bosses/errante.webp';
import juiz from '../assets/bosses/juiz.webp';

/**
 * Arte dos chefes: uma pintura por chefe, com o estado do combate desenhado por cima.
 * `damage` (0 a 1) abre rachaduras incandescentes nos marcos de 25%, 50% e 75%;
 * `defeated` apaga o chefe e o parte ao meio; `locked` mostra só a silhueta.
 */
interface Props {
  id: string;
  size?: number;
  damage?: number;
  defeated?: boolean;
  locked?: boolean;
  className?: string;
}

/** Cor de identificação de cada chefe (brilho de fundo, textos e detalhes). */
export const BOSS_COLORS: Record<string, string> = {
  tempestade: '#6FA8FF',
  adiador: '#E0A23C',
  hidra: '#39D5D0',
  nevoa: '#B9A8F0',
  sentinela: '#4FD1B0',
  errante: '#A18AFF',
  juiz: '#FF7138',
};

const ART: Record<string, string> = { hidra, tempestade, adiador, nevoa, sentinela, errante, juiz };

// Rachaduras em três estágios, pensadas para o centro de massa das pinturas
const CRACKS = [
  'M58 52 L67 66 L61 77 L72 90 L68 99',
  'M104 44 L96 60 L105 71 L97 86 L103 96',
  'M76 92 L87 105 L79 117 L91 131 L86 140',
];
const BREAK = 'M44 30 L62 56 L55 72 L80 90 L74 110 L98 128 L112 150';

export function BossArt({ id, size = 140, damage = 0, defeated, locked, className }: Props) {
  const uid = useId().replace(/:/g, '');
  const g = (k: string) => `${uid}-${k}`;
  const color = BOSS_COLORS[id] ?? '#999';
  const art = ART[id];
  const stage = defeated ? 3 : damage >= 0.75 ? 3 : damage >= 0.5 ? 2 : damage >= 0.25 ? 1 : 0;
  const filter = locked ? 'grayscale(1) brightness(.22) contrast(1.4)'
    : defeated ? 'grayscale(.9) brightness(.55)'
    : stage > 0 ? `saturate(${1 - stage * 0.12}) brightness(${1 - stage * 0.05})` : undefined;

  return (
    <svg width={size} height={size} viewBox="0 0 160 160" role="img" aria-hidden className={className} data-boss={id} data-stage={stage}>
      <defs>
        <radialGradient id={g('glow')} cx="0.5" cy="0.5" r="0.5">
          <stop offset="0" stopColor={color} stopOpacity={locked ? 0 : 0.28} />
          <stop offset="1" stopColor={color} stopOpacity="0" />
        </radialGradient>
        {/* A pintura some nas bordas, para assentar em qualquer cartão */}
        <radialGradient id={g('fade')} cx="0.5" cy="0.5" r="0.5">
          <stop offset="0.72" stopColor="#fff" /><stop offset="1" stopColor="#fff" stopOpacity="0" />
        </radialGradient>
        <mask id={g('mask')}><rect width="160" height="160" fill={`url(#${g('fade')})`} /></mask>
      </defs>
      <circle cx="80" cy="80" r="80" fill={`url(#${g('glow')})`} />
      {art && (
        <image href={art} x="0" y="0" width="160" height="160" preserveAspectRatio="xMidYMid slice"
               mask={`url(#${g('mask')})`} style={filter ? { filter } : undefined} />
      )}

      {/* Rachaduras conforme o dano: o brilho por baixo é a energia que escapa */}
      {!locked && (
        <>
          <g stroke={defeated ? '#8A929C' : '#FF7138'} strokeWidth="3.6" fill="none" strokeLinecap="round" strokeLinejoin="round" opacity={defeated ? 0.25 : 0.5}>
            {CRACKS.slice(0, stage).map((d) => <path key={d} d={d} />)}
            {defeated && <path d={BREAK} strokeWidth="7" />}
          </g>
          <g stroke="#FFF7E6" strokeWidth="1.2" fill="none" strokeLinecap="round" strokeLinejoin="round" opacity={defeated ? 0.85 : 0.9}>
            {CRACKS.slice(0, stage).map((d) => <path key={d} d={d} />)}
            {defeated && <path d={BREAK} strokeWidth="2.6" />}
          </g>
        </>
      )}
    </svg>
  );
}
