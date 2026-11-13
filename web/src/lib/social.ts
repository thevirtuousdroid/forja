// Textos e ajudantes do social, temporadas e desafios. As regras valem no servidor.
import type {
  ChallengeKind, ChallengeMetric, CheerKind, Dimension, FeedPost, LeagueId, Privacy, RankingCategory, SocialNotification,
} from './types';
import { DIMENSIONS } from './game';
import { midName } from './rpg';

export const LEAGUE_COLORS: Record<LeagueId, [string, string]> = {
  bronze: ['#E2A577', '#8A5130'],
  prata: ['#E3E8EF', '#7C8594'],
  ouro: ['#FFE08A', '#C98A1E'],
  platina: ['#A9F0E6', '#3F9C93'],
  diamante: ['#B9D3FF', '#4E73D6'],
  mestre: ['#FFB36B', '#E0482A'],
};

export const CHEERS: Record<CheerKind, { emoji: string; label: string }> = {
  parabens: { emoji: '👏', label: 'Parabéns' },
  forca: { emoji: '💪', label: 'Força' },
  brasa: { emoji: '🔥', label: 'Mandou bem' },
  foco: { emoji: '🎯', label: 'Foco' },
  volta: { emoji: '🤝', label: 'Bora voltar' },
};
/** Reações a uma publicação do feed. */
export const REACTIONS: CheerKind[] = ['parabens', 'forca', 'brasa', 'foco'];
/** Incentivos diretos para um amigo (um por dia). */
export const DIRECT_CHEERS: CheerKind[] = ['forca', 'foco', 'volta'];

export const METRICS: Record<ChallengeMetric, { label: string; desc: string; unit: [string, string] }> = {
  meta_diaria: { label: 'Meta do dia', desc: 'Conta os dias em que cada um cumpre a própria meta diária.', unit: ['dia', 'dias'] },
  missoes: { label: 'Missões do plano', desc: 'Conta as missões do plano concluídas (até 12 por dia; avulsas não contam).', unit: ['missão', 'missões'] },
  area: { label: 'Uma área', desc: 'Conta os dias com pelo menos uma missão concluída na área escolhida.', unit: ['dia', 'dias'] },
};

export const CHALLENGE_KINDS: Record<ChallengeKind, { label: string; desc: string }> = {
  competitivo: { label: 'Competitivo', desc: 'Quem fizer mais no período vence e ganha 40 XP.' },
  coletivo: { label: 'Coletivo', desc: 'Todos somam para uma meta em comum. Batendo a meta, cada participante ganha 30 XP.' },
};

export function metricUnit(metric: ChallengeMetric, n: number) {
  const [one, many] = METRICS[metric].unit;
  return n === 1 ? one : many;
}

/** Quanto falta para a meta coletiva, somando todo mundo. */
export function collectiveLeft(metric: ChallengeMetric, n: number) {
  if (metric === 'missoes') return `Faltam ${plural(n, 'missão', 'missões')}, somando todo mundo.`;
  if (metric === 'area') return `Faltam ${plural(n, 'dia', 'dias')} com missão na área, somando todo mundo.`;
  return `Faltam ${plural(n, 'dia', 'dias')} de meta cumprida, somando todo mundo.`;
}

export function metricLabel(metric: ChallengeMetric, dimension: Dimension | null) {
  return metric === 'area' && dimension ? `Dias de ${DIMENSIONS[dimension].short}` : METRICS[metric].label;
}

export const RANKING_CATEGORIES: { id: RankingCategory; label: string; unit: [string, string] }[] = [
  { id: 'pontos', label: 'Pontos', unit: ['ponto', 'pontos'] },
  { id: 'constancia', label: 'Constância', unit: ['dia', 'dias'] },
  { id: 'xp', label: 'XP', unit: ['XP', 'XP'] },
  { id: 'chefes', label: 'Chefes', unit: ['vitória', 'vitórias'] },
];

export const PRIVACY_OPTIONS: { id: keyof Privacy; label: string; desc: string }[] = [
  { id: 'mostrar_nivel', label: 'Nível e título', desc: 'Amigos e colegas de grupo veem seu nível e título.' },
  { id: 'mostrar_sequencia', label: 'Sequência e semana', desc: 'Mostra sua sequência e como foram os últimos dias.' },
  { id: 'mostrar_conquistas', label: 'Conquistas e chefes', desc: 'Mostra suas conquistas recentes e chefes vencidos.' },
  { id: 'mostrar_atributos', label: 'Atributos', desc: 'Permite comparar atributos com você.' },
  { id: 'mostrar_habitos', label: 'Áreas que você treina', desc: 'Mostra as áreas dos seus hábitos (nunca os detalhes).' },
  { id: 'publicar_automatico', label: 'Publicar no feed automaticamente', desc: 'Conquistas, vitórias, níveis múltiplos de 5 e temporadas aparecem para seus amigos.' },
  { id: 'participar_ranking', label: 'Aparecer no ranking', desc: 'Desligado, você ainda vê o ranking, mas os outros não veem você.' },
  { id: 'aceitar_pedidos', label: 'Receber pedidos de amizade', desc: 'Desligado, ninguém consegue mandar pedido pelo seu código.' },
];

export function postText(p: FeedPost): string {
  switch (p.kind) {
    case 'conquista': return `desbloqueou a conquista "${p.data.name}"`;
    case 'chefe': return p.data.rematch ? `venceu ${midName(p.data.name)} de novo` : `venceu ${midName(p.data.name)}`;
    case 'nivel': return `chegou ao nível ${p.data.level}`;
    case 'temporada': return `terminou a ${p.data.name.replace('Temporada', 'temporada')} na liga ${p.data.league_name}`;
  }
}

export function notificationText(n: SocialNotification): string {
  switch (n.kind) {
    case 'pedido_amizade': return n.data.status === 'aceita' ? 'Vocês agora são amigos.' : 'quer ser seu amigo na Forja.';
    case 'amizade_aceita': return 'aceitou seu pedido de amizade.';
    case 'incentivo': return n.data.post
      ? `reagiu com ${CHEERS[n.data.cheer].emoji} à sua publicação.`
      : `mandou ${CHEERS[n.data.cheer].emoji} ${CHEERS[n.data.cheer].label.toLowerCase()} para você.`;
    case 'desafio_convite': return `convidou você para o desafio "${n.data.challenge.title}".`;
    case 'grupo_entrada': return `entrou no grupo ${n.data.group.name}.`;
  }
}

/** "agora", "há 5 min", "há 3 h", "ontem", "12 nov". */
export function relativeTime(iso: string, now = Date.now()): string {
  const t = new Date(iso).getTime();
  const s = Math.max(0, Math.round((now - t) / 1000));
  if (s < 60) return 'agora';
  if (s < 3600) return `há ${Math.floor(s / 60)} min`;
  if (s < 86400) return `há ${Math.floor(s / 3600)} h`;
  if (s < 2 * 86400) return 'ontem';
  return new Date(iso).toLocaleDateString('pt-BR', { day: 'numeric', month: 'short' }).replace('.', '');
}

export const friendLink = (code: string) => `${window.location.origin}/amigo/${code}`;
export const groupLink = (code: string) => `${window.location.origin}/grupo/${code}`;

/** Código com hífen no meio para ler e ditar melhor: ABC-DEF. */
export function prettyCode(code: string) {
  return code.length > 4 ? `${code.slice(0, 3)}-${code.slice(3)}` : code;
}

/** Compartilha pelo menu do celular; sem ele, copia. Devolve o que aconteceu. */
export async function shareOrCopy(text: string, url: string): Promise<'shared' | 'copied' | 'failed'> {
  const nav = navigator as Navigator & { share?: (d: ShareData) => Promise<void> };
  if (nav.share) {
    try { await nav.share({ text, url }); return 'shared'; } catch (e) {
      if ((e as Error)?.name === 'AbortError') return 'failed';
    }
  }
  try { await navigator.clipboard.writeText(`${text} ${url}`); return 'copied'; } catch { return 'failed'; }
}

export async function copyText(text: string): Promise<boolean> {
  try { await navigator.clipboard.writeText(text); return true; } catch { return false; }
}

export const plural = (n: number, one: string, many: string) => `${n.toLocaleString('pt-BR')} ${n === 1 ? one : many}`;
