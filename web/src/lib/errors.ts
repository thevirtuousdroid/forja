/** Converte códigos de erro do servidor em mensagens para a pessoa. */
const MESSAGES: Record<string, string> = {
  nao_autenticado: 'Sua sessão expirou. Entre novamente.',
  missao_nao_encontrada: 'Essa missão não foi encontrada.',
  fora_do_prazo: 'Essa missão já passou do prazo e não pode mais ser concluída.',
  so_no_mesmo_dia: 'Só dá para desfazer no mesmo dia em que a missão foi concluída.',
  resposta_invalida: 'Alguma resposta ficou faltando. Revise o questionário.',
  conclua_a_avaliacao: 'Conclua a avaliação inicial primeiro.',
  dimensao_invalida: 'Escolha uma área para a missão.',
  dificuldade_invalida: 'Missões personalizadas vão da dificuldade 1 a 3.',
  duracao_invalida: 'A duração precisa ficar entre 1 e 120 minutos.',
  nome_invalido: 'Dê um nome de até 60 caracteres.',
  limite_gratuito_personalizadas: 'No plano gratuito, você pode ter até 2 hábitos personalizados recorrentes. Pause um para criar outro.',
  limite_habitos: 'Você atingiu o limite de hábitos personalizados.',
  limite_diario_personalizadas: 'Você já criou 5 missões avulsas hoje.',
  habito_nao_encontrado: 'Hábito não encontrado.',
  meta_fora_do_intervalo: 'A meta precisa ficar entre o valor inicial e o teto do hábito.',
  modo_extremo_bloqueia_ajustes: 'No modo Extremo, as metas e a meta diária não podem ser alteradas.',
  modo_extremo_bloqueia_habitos: 'No modo Extremo, o plano é fixo: dá para criar missões avulsas, mas não hábitos novos.',
  fuso_invalido: 'Fuso horário inválido.',
  meta_invalida: 'A meta diária precisa ficar entre 1 e 10 missões.',
  aparencia_invalida: 'Alguma escolha de aparência não é válida. Tente de novo.',
  item_nao_disponivel: 'Esse item ainda não foi desbloqueado.',
  titulo_nao_disponivel: 'Esse título ainda não foi desbloqueado.',
  chefe_nao_encontrado: 'Esse chefe não foi encontrado.',
  chefe_ja_ativo: 'Você já está enfrentando um chefe. Termine ou desista dessa batalha antes.',
  chefe_bloqueado_dia: 'Esse chefe ainda não apareceu no seu programa.',
  chefe_bloqueado_vitorias: 'Vença outros chefes antes de enfrentar este.',
  chefe_bloqueado_habito: 'Você precisa de um hábito ativo nessa área para enfrentar este chefe.',
  aceite_as_regras: 'Confirme que leu as regras antes de ativar o modo.',
  modo_invalido: 'Modo inválido.',
  modo_bloqueado_dia: 'Esse modo ainda não está liberado no seu programa.',
  modo_bloqueado_sequencia: 'O modo Extremo pede uma sequência de pelo menos 7 dias antes.',
  modo_em_espera: 'Você saiu do modo Extremo há pouco. Ele volta a ficar disponível depois de 7 dias.',
};

export function friendlyError(err: unknown): string {
  const raw = err instanceof Error ? err.message : typeof err === 'object' && err && 'message' in err ? String((err as { message: unknown }).message) : String(err);
  const code = Object.keys(MESSAGES).find((k) => raw.includes(k));
  if (code) return MESSAGES[code];
  if (/Could not find the (function|table)|schema cache/i.test(raw)) {
    return 'O banco de dados ainda não recebeu a atualização mais recente do app. Peça para aplicar a última migração.';
  }
  if (/fetch|network|Failed to fetch/i.test(raw)) return 'Sem conexão com o servidor. Verifique a internet e tente de novo.';
  if (/Invalid login credentials/i.test(raw)) return 'E-mail ou senha incorretos.';
  if (/User already registered/i.test(raw)) return 'Já existe uma conta com esse e-mail.';
  if (/Password should be/i.test(raw)) return 'A senha precisa ter pelo menos 6 caracteres.';
  if (/Email not confirmed/i.test(raw)) return 'Confirme seu e-mail pelo link que enviamos antes de entrar.';
  return 'Algo deu errado. Tente de novo em instantes.';
}
