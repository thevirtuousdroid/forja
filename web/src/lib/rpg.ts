// Conteúdo e ajudantes do RPG (aparência, raridade, espaços de equipamento, modos, chefes).
// As regras valem no servidor; aqui ficam só textos e apresentação.
import type { AchievementCategory, AvatarConfig, CatalogItem, Mode, Profile, Rarity, Slot } from './types';
import type { Catalogs } from './api';

export const RARITY: Record<Rarity, { label: string; color: string }> = {
  comum: { label: 'Comum', color: 'var(--r-comum)' },
  raro: { label: 'Raro', color: 'var(--r-raro)' },
  epico: { label: 'Épico', color: 'var(--r-epico)' },
  lendario: { label: 'Lendário', color: 'var(--r-lendario)' },
};

export const SLOTS: { id: Slot; label: string; optional: boolean }[] = [
  { id: 'cabeca', label: 'Cabeça', optional: true },
  { id: 'corpo', label: 'Armadura', optional: false },
  { id: 'capa', label: 'Capa', optional: true },
  { id: 'arma', label: 'Ferramenta', optional: true },
  { id: 'amuleto', label: 'Amuleto', optional: true },
  { id: 'moldura', label: 'Moldura', optional: false },
];

// ── Aparência ───────────────────────────────────────────────────────────────

export const SKIN_TONES = ['#F3D2B8', '#E3B08A', '#C68A5F', '#A3683F', '#7A4A2B', '#4F311F'];
export const HAIR_COLORS = [
  { color: '#1F1B19', label: 'Preto' },
  { color: '#4A2E1F', label: 'Castanho-escuro' },
  { color: '#7B4B2A', label: 'Castanho' },
  { color: '#B07A3E', label: 'Mel' },
  { color: '#D9B26A', label: 'Loiro' },
  { color: '#A3401F', label: 'Ruivo' },
  { color: '#C9CCD3', label: 'Grisalho' },
  { color: '#3E5C8A', label: 'Azul' },
];
export const HAIR_STYLES = ['Raspado', 'Curto', 'Franja', 'Cacheado', 'Longo', 'Coque', 'Volumoso', 'Sem cabelo'];
export const BEARDS = ['Sem barba', 'Por fazer', 'Cheia'];
export const OUTFIT_COLORS = [
  { color: '#3B4A6B', label: 'Azul-aço' },
  { color: '#5A3E36', label: 'Couro' },
  { color: '#2F5D50', label: 'Musgo' },
  { color: '#6B2E3A', label: 'Vinho' },
  { color: '#44464F', label: 'Grafite' },
  { color: '#7A5C2E', label: 'Ocre' },
];

export const DEFAULT_AVATAR: AvatarConfig = {
  pele: 2, cabelo: 1, corCabelo: 1, barba: 0, corRoupa: 0, personalizado: false,
  equip: { corpo: 'cor_tunica', moldura: 'mol_bronze' },
};

export function avatarOf(profile: Pick<Profile, 'avatar'> | null | undefined): AvatarConfig {
  const a = profile?.avatar as Partial<AvatarConfig> | undefined;
  if (!a || typeof a.pele !== 'number') return DEFAULT_AVATAR;
  return { ...DEFAULT_AVATAR, ...a, equip: { ...DEFAULT_AVATAR.equip, ...(a.equip ?? {}) } };
}

// ── Nomes de chefes no meio da frase ────────────────────────────────────────

/** "O Adiador" → "o Adiador" (para usar no meio da frase). */
export function midName(name: string): string {
  return name.replace(/^(O|A|Os|As) /, (m) => m.toLowerCase());
}

/** "O Adiador" → "no Adiador"; "A Hidra" → "na Hidra". */
export function inName(name: string): string {
  const m = name.match(/^(O|A|Os|As) (.*)$/);
  if (!m) return `em ${name}`;
  return `${{ O: 'no', A: 'na', Os: 'nos', As: 'nas' }[m[1] as 'O' | 'A' | 'Os' | 'As']} ${m[2]}`;
}

// ── Itens e títulos ─────────────────────────────────────────────────────────

export function unlockText(item: CatalogItem, catalogs: Catalogs | null): string {
  switch (item.unlock_type) {
    case 'inicial': return 'Item inicial';
    case 'nivel': return `Alcance o nível ${item.unlock_level}`;
    case 'chefe': {
      const b = catalogs?.bosses.find((x) => x.id === item.unlock_ref);
      return b ? `Vença ${midName(b.name)}` : 'Vença um chefe';
    }
    case 'conquista': {
      const a = catalogs?.achievements.find((x) => x.id === item.unlock_ref);
      return a ? `Conquista "${a.name}"` : 'Desbloqueie uma conquista';
    }
  }
}

/** Título mostrado: o escolhido, ou o maior título de nível já alcançado. */
export function titleName(profile: Pick<Profile, 'active_title'> | null, level: number, items: CatalogItem[] | undefined): string {
  const list = items ?? [];
  if (profile?.active_title) {
    const t = list.find((i) => i.id === profile.active_title);
    if (t) return t.name;
  }
  const byLevel = list
    .filter((i) => i.kind === 'titulo' && (i.unlock_type === 'inicial' || (i.unlock_type === 'nivel' && (i.unlock_level ?? 0) <= level)))
    .sort((a, b) => (b.unlock_level ?? 0) - (a.unlock_level ?? 0));
  return byLevel[0]?.name ?? 'Aprendiz da Forja';
}

// ── Conquistas ──────────────────────────────────────────────────────────────

export const ACHIEVEMENT_CATEGORIES: { id: AchievementCategory; label: string }[] = [
  { id: 'missoes', label: 'Missões' },
  { id: 'sequencia', label: 'Sequência' },
  { id: 'programa', label: 'Programa' },
  { id: 'habitos', label: 'Hábitos' },
  { id: 'atributos', label: 'Atributos' },
  { id: 'nivel', label: 'Nível' },
  { id: 'chefes', label: 'Chefes' },
  { id: 'modos', label: 'Modos' },
];

// ── Modos ───────────────────────────────────────────────────────────────────

export interface ModeDef {
  id: Mode;
  name: string;
  tagline: string;
  multiplier: number;
  shields: number;
  rules: string[];
  consequences: string[];
}

export const MODES: ModeDef[] = [
  {
    id: 'normal',
    name: 'Normal',
    tagline: 'Flexível, para construir o hábito sem pressão.',
    multiplier: 1,
    shields: 2,
    rules: [
      'Meta do dia: o mínimo que você escolheu no Perfil.',
      'Você pode ajustar metas e pausar hábitos quando precisar.',
      'Até 2 escudos protegem a sequência num dia em branco.',
      'Se o prazo de um chefe acabar, ele só recua: tente de novo quando quiser.',
    ],
    consequences: [],
  },
  {
    id: 'desafio',
    name: 'Desafio',
    tagline: 'Metas mais exigentes e menos margem para dias vazios.',
    multiplier: 1.2,
    shields: 1,
    rules: [
      'Meta do dia: pelo menos 60% das suas missões diárias (ou o seu mínimo, o que for maior).',
      'Missões rendem 20% mais XP.',
      'Só 1 escudo de sequência.',
      'Você continua podendo ajustar metas e pausar hábitos.',
    ],
    consequences: [
      'Cada dia sem nenhuma missão devolve 1 golpe ao chefe que você estiver enfrentando.',
    ],
  },
  {
    id: 'extremo',
    name: 'Extremo',
    tagline: 'Programa fixo e regras rígidas, para quem já tem ritmo.',
    multiplier: 1.4,
    shields: 0,
    rules: [
      'Meta do dia: todas as missões diárias do plano.',
      'Missões rendem 40% mais XP.',
      'Sem escudos de sequência.',
      'O plano fica travado: sem ajustar metas, pausar hábitos, criar hábitos novos ou mudar a meta diária. Missões avulsas continuam liberadas.',
    ],
    consequences: [
      'Cada dia abaixo da meta devolve 1 golpe ao chefe que você estiver enfrentando.',
      '3 dias abaixo da meta em 7 dias levam você de volta ao modo Desafio.',
      'Depois de sair do Extremo, ele só volta a ficar disponível em 7 dias.',
    ],
  },
];

export const modeDef = (m: Mode) => MODES.find((x) => x.id === m) ?? MODES[0];

/** Os modos mexem só com a progressão virtual. Essa frase aparece sempre que um modo é ativado. */
export const MODE_SAFETY =
  'Os modos mudam só pontos, escudos e chefes. Nenhum modo pede menos sono, menos comida ou mais exercício: as metas físicas têm teto fixo e descansar continua sendo parte do plano.';
