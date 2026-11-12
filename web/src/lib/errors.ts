// Mensagens de erro compartilhadas pelas duas versões (servidor e individual).
/** Converte códigos de erro do servidor em mensagens para o usuário. */
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
  modo_extremo_bloqueia_ajustes: 'No modo Extremo, as metas não podem ser alteradas.',
  fuso_invalido: 'Fuso horário inválido.',
  meta_invalida: 'A meta diária precisa ficar entre 1 e 10 missões.',
  sem_conexao_dados: 'Não foi possível carregar seus dados agora. Verifique a internet e tente de novo.',
  falha_ao_salvar: 'Não foi possível salvar agora. Seu progresso fica guardado nesta tela e será salvo na próxima ação.',
  backup_invalido: 'Esse arquivo não é um backup válido do Forja.',
};

export function friendlyError(err: unknown): string {
  const raw = err instanceof Error ? err.message : typeof err === 'object' && err && 'message' in err ? String((err as { message: unknown }).message) : String(err);
  const code = Object.keys(MESSAGES).find((k) => raw.includes(k));
  if (code) return MESSAGES[code];
  if (/fetch|network|Failed to fetch/i.test(raw)) return 'Sem conexão com o servidor. Verifique a internet e tente de novo.';
  if (/Invalid login credentials/i.test(raw)) return 'E-mail ou senha incorretos.';
  if (/User already registered/i.test(raw)) return 'Já existe uma conta com esse e-mail.';
  if (/Password should be/i.test(raw)) return 'A senha precisa ter pelo menos 6 caracteres.';
  if (/Email not confirmed/i.test(raw)) return 'Confirme seu e-mail pelo link que enviamos antes de entrar.';
  return 'Algo deu errado. Tente de novo em instantes.';
}
