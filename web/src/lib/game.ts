import type { Attribute, Dimension, MissionKind, Period, Unit } from './types';

/** Espelha public.xp_for_level do banco (somente para exibição; o servidor é a autoridade). */
export function xpForLevel(level: number): number {
  return Math.round(100 * Math.pow(Math.max(level - 1, 0), 1.8));
}

export function levelForXp(xp: number): number {
  let l = 1;
  while (xpForLevel(l + 1) <= xp) l++;
  return l;
}

export function levelProgress(totalXp: number, level: number) {
  const floor = xpForLevel(level);
  const next = xpForLevel(level + 1);
  return { current: totalXp - floor, needed: next - floor, ratio: Math.min(1, Math.max(0, (totalXp - floor) / (next - floor))) };
}

export function attributeLevel(xp: number): number {
  return Math.floor(Math.sqrt(Math.max(xp, 0) / 30)) + 1;
}

export function attributeProgress(xp: number) {
  const lvl = attributeLevel(xp);
  const floor = 30 * (lvl - 1) ** 2;
  const next = 30 * lvl ** 2;
  return { level: lvl, ratio: (xp - floor) / (next - floor) };
}

export const PHASES = [
  { n: 1, name: 'Adaptação', days: [1, 7], goal: 'Criar familiaridade com as missões, sem pressa.' },
  { n: 2, name: 'Construção', days: [8, 21], goal: 'Estabelecer regularidade. Novos hábitos entram e as metas sobem aos poucos.' },
  { n: 3, name: 'Consolidação', days: [22, 33], goal: 'Ganhar consistência. Missões especiais aparecem toda semana.' },
  { n: 4, name: 'Evolução', days: [34, 45], goal: 'Aumentar a capacidade de execução com metas mais longas.' },
  { n: 5, name: 'Domínio', days: [46, 60], goal: 'Depender menos de lembretes e pensar no longo prazo.' },
  { n: 6, name: 'Conclusão', days: [61, 66], goal: 'Avaliar os resultados e planejar o próximo capítulo.' },
  { n: 7, name: 'Evolução contínua', days: [67, Infinity], goal: 'O programa terminou; a progressão continua.' },
] as const;

export const phaseInfo = (n: number) => PHASES[Math.min(Math.max(n, 1), 7) - 1];

export const DIMENSIONS: Record<Dimension, { label: string; short: string }> = {
  fisica: { label: 'Saúde física', short: 'Física' },
  mental: { label: 'Saúde mental', short: 'Mental' },
  intelectual: { label: 'Desenvolvimento intelectual', short: 'Intelectual' },
  produtividade: { label: 'Disciplina e produtividade', short: 'Produtividade' },
  digital: { label: 'Saúde digital', short: 'Digital' },
  autocuidado: { label: 'Autocuidado e rotina', short: 'Autocuidado' },
};
export const DIMENSION_KEYS = Object.keys(DIMENSIONS) as Dimension[];

export const ATTRIBUTES: Record<Attribute, { label: string; hint: string; color: string }> = {
  disciplina: { label: 'Disciplina', hint: 'Consistência na execução dos compromissos', color: 'var(--attr-disciplina)' },
  foco: { label: 'Foco', hint: 'Concentração e controle de distrações', color: 'var(--attr-foco)' },
  vitalidade: { label: 'Vitalidade', hint: 'Cuidado com o corpo e recuperação', color: 'var(--attr-vitalidade)' },
  conhecimento: { label: 'Conhecimento', hint: 'Investimento em aprendizado', color: 'var(--attr-conhecimento)' },
  determinacao: { label: 'Determinação', hint: 'Persistência diante das dificuldades', color: 'var(--attr-determinacao)' },
};
export const ATTRIBUTE_KEYS = Object.keys(ATTRIBUTES) as Attribute[];

export const KIND_LABEL: Record<MissionKind, string> = {
  diaria: 'Diária', semanal: 'Semanal', especial: 'Especial', personalizada: 'Personalizada', surpresa: 'Surpresa',
};

export const PERIOD_LABEL: Record<Period, string> = {
  manha: 'Manhã', tarde: 'Tarde', noite: 'Noite', qualquer: 'Qualquer hora',
};
export const PERIOD_ORDER: Period[] = ['manha', 'tarde', 'noite', 'qualquer'];

export function formatTarget(value: number, unit: Unit): string {
  switch (unit) {
    case 'min': return `${value} min`;
    case 'copos': return `${value} ${value === 1 ? 'copo' : 'copos'}`;
    case 'paginas': return `${value} ${value === 1 ? 'página' : 'páginas'}`;
    case 'vez': return value === 1 ? '1 vez' : `${value} vezes`;
  }
}

export const MILESTONES = [7, 14, 21, 33, 45, 66, 90, 132];

/** Faixa visual do emblema do personagem por nível. */
export function emblemTier(level: number): 0 | 1 | 2 | 3 | 4 {
  if (level >= 25) return 4;
  if (level >= 15) return 3;
  if (level >= 8) return 2;
  if (level >= 4) return 1;
  return 0;
}


/** Perfil de referência (não é diagnóstico): arquétipo pela dimensão mais forte. */
const ARCHETYPES: Record<Dimension, string> = {
  fisica: 'Guardião', mental: 'Sereno', intelectual: 'Erudito', produtividade: 'Estrategista', digital: 'Atento', autocuidado: 'Cultivador',
};

export function referenceProfile(scores: Record<Dimension, number>) {
  const sorted = [...DIMENSION_KEYS].sort((a, b) => scores[b] - scores[a]);
  const strongest = sorted[0];
  const weakest = sorted[sorted.length - 1];
  return {
    archetype: ARCHETYPES[strongest],
    strongest,
    weakest,
    summary: `Seu ponto de apoio hoje é ${DIMENSIONS[strongest].label.toLowerCase()}. A maior oportunidade de evolução está em ${DIMENSIONS[weakest].label.toLowerCase()}.`,
  };
}

/** Espelha public._phase_for_day. */
export function phaseForDay(day: number): number {
  if (day <= 7) return 1;
  if (day <= 21) return 2;
  if (day <= 33) return 3;
  if (day <= 45) return 4;
  if (day <= 60) return 5;
  if (day <= 66) return 6;
  return 7;
}
