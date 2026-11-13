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
  // Etapa 4
  recurso_premium: 'Esse recurso faz parte do Premium.',
  codigo_invalido: 'Não encontramos ninguém com esse código. Confira as letras e os números.',
  codigo_proprio: 'Esse é o seu próprio código.',
  ja_sao_amigos: 'Vocês já são amigos.',
  pedido_ja_enviado: 'Você já mandou um pedido para essa pessoa.',
  pedido_recusado_recente: 'Essa pessoa recusou um pedido seu há pouco. Espere alguns dias para tentar de novo.',
  pedidos_desativados: 'Essa pessoa não está recebendo pedidos de amizade agora.',
  limite_amigos: 'O limite é de 50 amizades por pessoa.',
  limite_pedidos: 'Você tem muitos pedidos esperando resposta. Aguarde alguns serem respondidos.',
  pedido_nao_encontrado: 'Esse pedido não está mais disponível.',
  perfil_indisponivel: 'Esse perfil não está disponível para você.',
  privacidade_invalida: 'Não foi possível salvar essa opção de privacidade.',
  publicacao_invalida: 'Não dá para compartilhar isso.',
  publicacao_nao_encontrada: 'Essa publicação não está mais disponível.',
  incentivo_invalido: 'Esse incentivo não está disponível aqui.',
  incentivo_proprio: 'Você não pode mandar incentivo para si mesmo.',
  incentivo_ja_enviado_hoje: 'Você já mandou um incentivo direto para essa pessoa hoje.',
  limite_incentivos: 'Você chegou ao limite de incentivos de hoje.',
  amigo_nao_encontrado: 'Só dá para fazer isso com amigos.',
  nome_grupo_invalido: 'Dê ao grupo um nome de 2 a 40 caracteres.',
  limite_grupos_criados: 'Você já criou 5 grupos.',
  limite_grupos: 'Você já participa de 10 grupos.',
  grupo_nao_encontrado: 'Grupo não encontrado. Confira o código.',
  grupo_cheio: 'Esse grupo já tem 30 pessoas.',
  so_o_dono: 'Só quem criou o grupo pode fazer isso.',
  duracao_desafio_invalida: 'Um desafio dura de 3 a 30 dias.',
  desafio_invalido: 'Revise as opções do desafio.',
  desafio_sem_participantes: 'Convide pelo menos uma pessoa para o desafio.',
  desafio_muitos_participantes: 'Um desafio pode ter até 30 pessoas.',
  meta_coletiva_invalida: 'A meta coletiva precisa ser possível de alcançar com essas pessoas e dias.',
  limite_desafios_criados: 'Você já tem 3 desafios criados em andamento.',
  limite_desafios: 'Você já participa de 5 desafios ao mesmo tempo.',
  convite_nao_encontrado: 'Esse convite não está mais disponível.',
  desafio_encerrado: 'Esse desafio já terminou.',
  desafio_nao_encontrado: 'Desafio não encontrado.',
  ranking_invalido: 'Ranking indisponível.',
  ferramenta_invalida: 'Ferramenta não encontrada.',
  registro_invalido: 'Confira os valores e tente de novo.',
  limite_registro: 'Esse registro passou do limite do dia.',
  registro_nao_encontrado: 'Esse registro não existe mais.',
  ajuste_invalido: 'Esse valor não é aceito.',
  livro_invalido: 'Confira o título e o número de páginas.',
  livro_nao_encontrado: 'Livro não encontrado.',
  limite_livros: 'Você chegou ao limite de livros cadastrados.',
  sugestao_nao_encontrada: 'Essa sugestão não está mais disponível.',
  relatorio_nao_encontrado: 'Ainda não há relatório semanal. Ele fica pronto na segunda-feira.',
};

// Códigos mais longos primeiro: "limite_grupos_criados" não pode cair em "limite_grupos"
const CODES = Object.keys(MESSAGES).sort((a, b) => b.length - a.length);

export function isPremiumError(err: unknown): boolean {
  const raw = err instanceof Error ? err.message : String((err as { message?: unknown })?.message ?? err);
  return raw.includes('recurso_premium');
}

export function friendlyError(err: unknown): string {
  const raw = err instanceof Error ? err.message : typeof err === 'object' && err && 'message' in err ? String((err as { message: unknown }).message) : String(err);
  const code = CODES.find((k) => raw.includes(k));
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
