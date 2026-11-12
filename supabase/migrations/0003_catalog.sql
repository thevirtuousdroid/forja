-- Forja · 0003 · Catálogo de hábitos e missões surpresa
-- Tetos fixos impedem que a progressão leve a metas físicas excessivas.

insert into public.mission_templates
  (id, dimension, name, description, attr_primary, attr_secondary, difficulty, unit, base_value, step, max_value, est_minutes, period, tier, sort, passive)
values
  -- Saúde física
  ('fis_caminhada',   'fisica', 'Caminhada', 'Caminhe em ritmo confortável. Vale na rua, na esteira ou indo a algum compromisso.', 'vitalidade', 'determinacao', 1, 'min', 10, 5, 45, 0, 'qualquer', 1, 1, false),
  ('fis_alongamento', 'fisica', 'Alongamento', 'Alongue pescoço, ombros, costas e pernas, sem forçar além do confortável.', 'vitalidade', 'foco', 1, 'min', 5, 2, 15, 0, 'manha', 2, 2, false),
  ('fis_treino',      'fisica', 'Treino', 'Treino de força ou cardio no seu nível atual. Se sentir dor, pare: descanso também conta como cuidado.', 'vitalidade', 'determinacao', 3, 'min', 15, 5, 45, 0, 'qualquer', 2, 3, false),
  ('fis_sono',        'fisica', 'Dormir no horário', 'Deite no horário que você definiu para si, sem telas nos 30 minutos anteriores.', 'vitalidade', 'disciplina', 2, 'vez', 1, 0, 1, 5, 'noite', 3, 4, true),

  -- Saúde mental
  ('men_respiracao',  'mental', 'Respiração consciente', 'Sente-se confortavelmente e respire devagar, contando 4 tempos ao inspirar e 6 ao expirar.', 'foco', 'vitalidade', 1, 'min', 3, 2, 10, 0, 'qualquer', 1, 1, false),
  ('men_reflexao',    'mental', 'Reflexão do dia', 'Escreva três linhas: algo que deu certo, algo que pesou e algo pelo que você é grato.', 'foco', 'disciplina', 1, 'min', 5, 2, 15, 0, 'noite', 2, 2, false),
  ('men_meditacao',   'mental', 'Meditação', 'Foque na respiração. Quando a mente se distrair, volte sem se cobrar.', 'foco', 'determinacao', 2, 'min', 5, 3, 20, 0, 'qualquer', 2, 3, false),
  ('men_pausa',       'mental', 'Pausa sem estímulos', 'Alguns minutos sem tela, música ou conversa. Só descanso.', 'vitalidade', 'foco', 1, 'min', 10, 5, 20, 0, 'tarde', 2, 4, false),

  -- Desenvolvimento intelectual
  ('int_leitura',     'intelectual', 'Leitura', 'Leia um livro ou texto longo, de preferência longe do celular.', 'conhecimento', 'foco', 2, 'min', 10, 5, 40, 0, 'noite', 1, 1, false),
  ('int_estudo',      'intelectual', 'Estudo focado', 'Uma sessão de estudo de um tema que você escolheu, com o celular longe.', 'conhecimento', 'determinacao', 3, 'min', 20, 5, 60, 0, 'qualquer', 2, 2, false),
  ('int_idioma',      'intelectual', 'Prática de idioma', 'Pratique um idioma: aula, app, leitura ou conversa.', 'conhecimento', 'disciplina', 2, 'min', 10, 5, 30, 0, 'qualquer', 2, 3, false),

  -- Disciplina e produtividade
  ('pro_planejar',    'produtividade', 'Planejar o dia', 'Escolha as três prioridades do dia antes de abrir mensagens.', 'disciplina', 'foco', 1, 'min', 5, 0, 5, 0, 'manha', 1, 1, false),
  ('pro_tarefa',      'produtividade', 'Tarefa mais difícil primeiro', 'Comece pela tarefa que você mais adiaria, num bloco de tempo sem interrupções.', 'disciplina', 'determinacao', 3, 'min', 25, 5, 50, 0, 'manha', 2, 2, false),
  ('pro_revisao',     'produtividade', 'Revisão do dia', 'Confira o que ficou pendente e anote o primeiro passo de amanhã.', 'disciplina', 'conhecimento', 1, 'min', 5, 0, 5, 0, 'noite', 2, 3, false),

  -- Saúde digital
  ('dig_manha',       'digital', 'Manhã sem celular', 'Depois de acordar, fique um tempo sem abrir o celular.', 'foco', 'disciplina', 2, 'min', 15, 15, 60, 0, 'manha', 1, 1, true),
  ('dig_bloco',       'digital', 'Bloco sem distrações', 'Notificações desligadas e celular fora de alcance durante uma atividade importante.', 'foco', 'determinacao', 2, 'min', 20, 10, 60, 0, 'qualquer', 2, 2, true),
  ('dig_redes',       'digital', 'Redes no limite', 'Ao fim do dia, marque se o seu uso de redes sociais ficou dentro do limite que você definiu.', 'foco', 'disciplina', 2, 'vez', 1, 0, 1, 5, 'noite', 2, 3, true),

  -- Autocuidado e rotina
  ('auto_manha',      'autocuidado', 'Rotina matinal', 'Arrume a cama, faça a higiene e beba um copo de água logo ao acordar.', 'disciplina', 'vitalidade', 1, 'min', 10, 5, 20, 0, 'manha', 1, 1, false),
  ('auto_agua',       'autocuidado', 'Água', 'Beba copos de água ao longo do dia. Marque quando chegar à meta.', 'vitalidade', 'disciplina', 1, 'copos', 4, 1, 8, 2, 'qualquer', 3, 2, true),
  ('auto_noite',      'autocuidado', 'Rotina noturna', 'Prepare o dia seguinte e desacelere: higiene, roupa separada, ambiente pronto.', 'disciplina', 'vitalidade', 1, 'min', 10, 5, 20, 0, 'noite', 2, 3, false),
  ('auto_ambiente',   'autocuidado', 'Organizar o ambiente', 'Organize um espaço: mesa, quarto, uma gaveta.', 'disciplina', 'foco', 1, 'min', 10, 5, 20, 0, 'tarde', 2, 4, false),

  -- Missões surpresa (opcionais)
  ('sur_gratidao',    'mental', 'Mensagem de gratidão', 'Mande uma mensagem sincera de agradecimento a alguém.', 'determinacao', 'foco', 1, 'min', 5, 0, 5, 0, 'qualquer', 9, 1, false),
  ('sur_escadas',     'fisica', 'Escadas', 'Hoje, troque o elevador pelas escadas pelo menos uma vez.', 'vitalidade', 'determinacao', 2, 'min', 5, 0, 5, 0, 'qualquer', 9, 2, false),
  ('sur_aprender',    'intelectual', 'Algo novo em 10 minutos', 'Aprenda algo que você não sabia: um conceito, uma palavra, um fato.', 'conhecimento', 'foco', 1, 'min', 10, 0, 10, 0, 'qualquer', 9, 3, false),
  ('sur_notificacao', 'digital', 'Silenciar um app', 'Desligue as notificações de um app que interrompe você sem necessidade.', 'foco', 'disciplina', 1, 'min', 3, 0, 3, 0, 'qualquer', 9, 4, false),
  ('sur_ar_livre',    'autocuidado', 'Ar livre', 'Passe 10 minutos ao ar livre, de preferência com luz natural.', 'vitalidade', 'foco', 1, 'min', 10, 0, 10, 0, 'qualquer', 9, 5, false);
