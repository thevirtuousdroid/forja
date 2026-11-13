// Ferramentas: textos e ajudantes. Os registros e a ligação com as missões ficam no servidor.
import type { ToolId, ToolSummaries } from './types';

export interface ToolDef { id: ToolId | 'habitos'; path: string; name: string; desc: string; premium: boolean }

export const TOOLS: ToolDef[] = [
  { id: 'foco', path: '/ferramentas/foco', name: 'Foco', desc: 'Timer de concentração', premium: false },
  { id: 'agua', path: '/ferramentas/agua', name: 'Água', desc: 'Copos do dia', premium: false },
  { id: 'diario', path: '/ferramentas/diario', name: 'Diário', desc: 'Humor e reflexão', premium: false },
  { id: 'habitos', path: '/ferramentas/habitos', name: 'Hábitos', desc: 'Últimas 4 semanas', premium: false },
  { id: 'sono', path: '/ferramentas/sono', name: 'Sono', desc: 'Horários e qualidade', premium: true },
  { id: 'leitura', path: '/ferramentas/leitura', name: 'Leitura', desc: 'Páginas e livros', premium: true },
  { id: 'meditacao', path: '/ferramentas/meditacao', name: 'Meditação', desc: 'Respiração guiada', premium: true },
  { id: 'tela', path: '/ferramentas/tela', name: 'Tempo de tela', desc: 'Registro do dia', premium: true },
  { id: 'alimentacao', path: '/ferramentas/alimentacao', name: 'Alimentação', desc: 'Refeições do dia', premium: true },
];

/** 470 → "7h50"; 45 → "45 min"; 120 → "2h". */
export function fmtMinutes(min: number | null | undefined): string {
  if (min === null || min === undefined) return '–';
  const m = Math.round(min);
  if (m < 60) return `${m} min`;
  const h = Math.floor(m / 60);
  const r = m % 60;
  return r === 0 ? `${h}h` : `${h}h${String(r).padStart(2, '0')}`;
}

/** "07:30" ↔ minutos desde a meia-noite. */
export const timeToMin = (t: string) => { const [h, m] = t.split(':').map(Number); return h * 60 + m; };
export const minToTime = (m: number) => `${String(Math.floor(m / 60) % 24).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`;
export const sleepMinutes = (bed: string, wake: string) => (timeToMin(wake) - timeToMin(bed) + 1440) % 1440;

export const MOODS: { value: number; emoji: string; label: string }[] = [
  { value: 1, emoji: '😣', label: 'Muito mal' },
  { value: 2, emoji: '😕', label: 'Mal' },
  { value: 3, emoji: '😐', label: 'Neutro' },
  { value: 4, emoji: '🙂', label: 'Bem' },
  { value: 5, emoji: '😄', label: 'Muito bem' },
];
export const moodOf = (v: number | null | undefined) => MOODS.find((m) => m.value === v);

export const SLEEP_QUALITY = ['Péssima', 'Ruim', 'Ok', 'Boa', 'Ótima'];

export const MEALS: { id: 'cafe' | 'almoco' | 'jantar' | 'lanche'; label: string }[] = [
  { id: 'cafe', label: 'Café da manhã' },
  { id: 'almoco', label: 'Almoço' },
  { id: 'lanche', label: 'Lanche' },
  { id: 'jantar', label: 'Jantar' },
];

export const MEDITATION_KINDS: { id: 'respiracao' | 'meditacao' | 'relaxamento'; label: string; desc: string }[] = [
  { id: 'respiracao', label: 'Respiração', desc: 'Inspire contando 4, expire contando 6. Siga o círculo.' },
  { id: 'meditacao', label: 'Meditação', desc: 'Foque na respiração. Quando a mente se distrair, volte sem se cobrar.' },
  { id: 'relaxamento', label: 'Relaxamento', desc: 'Solte o corpo de cima para baixo: rosto, ombros, braços, barriga, pernas.' },
];

/** Resumo curto de cada ferramenta para a tela inicial das ferramentas. */
export function toolLine(id: ToolDef['id'], s: ToolSummaries | undefined): string {
  if (!s || id === 'habitos') return '';
  switch (id) {
    case 'foco': return s.foco.minutes > 0 ? `${fmtMinutes(s.foco.minutes)} hoje` : 'Nenhuma sessão hoje';
    case 'agua': return `${s.agua.cups} de ${s.agua.goal} copos`;
    case 'diario': return s.diario.written ? 'Escrito hoje' : 'Ainda não escrito';
    case 'sono': return s.sono.logged ? `${fmtMinutes(s.sono.minutes)} esta noite` : 'Registre a noite';
    case 'leitura': return s.leitura.pages > 0 ? `${s.leitura.pages} páginas hoje` : s.leitura.book ? s.leitura.book.title : 'Nenhum livro';
    case 'meditacao': return s.meditacao.minutes > 0 ? `${fmtMinutes(s.meditacao.minutes)} hoje` : 'Nenhuma sessão hoje';
    case 'tela': return s.tela.logged ? `${fmtMinutes(s.tela.minutes)} de ${fmtMinutes(s.tela.limit)}` : 'Registre o dia';
    case 'alimentacao': return s.alimentacao.meals > 0 ? `${s.alimentacao.meals} ${s.alimentacao.meals === 1 ? 'refeição' : 'refeições'}` : 'Nenhuma refeição';
  }
}

/** Ferramenta que ajuda numa missão do plano (pelo modelo do hábito). */
export function toolForTemplate(templateId: string | null | undefined, unit: string): ToolDef['id'] | null {
  switch (templateId) {
    case 'auto_agua': return 'agua';
    case 'int_leitura': return 'leitura';
    case 'men_meditacao': case 'men_respiracao': return 'meditacao';
    case 'dig_redes': return 'tela';
    case 'men_reflexao': return 'diario';
  }
  return unit === 'min' ? 'foco' : null;
}

export const FOOD_DISCLAIMER =
  'Calorias são estimativas para você acompanhar a sua rotina. Este registro não é orientação nutricional: para metas de alimentação, procure um nutricionista.';
export const SLEEP_DISCLAIMER =
  'O registro de sono ajuda a enxergar a sua rotina e não substitui avaliação profissional. Se dormir mal for frequente, vale procurar um profissional de saúde.';
