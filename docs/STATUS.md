# Status do desenvolvimento

_Atualizado em 12/11/2026._

| Etapa | Situação |
|---|---|
| 1 · Planejamento | ✅ `docs/PLANEJAMENTO.md` |
| 2 · MVP | ✅ no ar |
| 3 · Gamificação | ✅ no ar (banco com `0004_rpg.sql`) |
| 4 · Sistemas avançados | ✅ no ar em forja-kappa-wheat.vercel.app (banco atualizado com `0005_etapa4.sql`); faltam as notificações |
| 5 · Premium | estrutura pronta (Premium liberado para todos por tempo limitado) |
| 6 · Testes com amigos e lançamento | |

## Etapa 4 · Sistemas avançados

### Implementado

| Área | O que funciona |
|---|---|
| Premium aberto | Premium liberado para todos, com data de fim definida pelo administrador (`admin_set_premium_aberto`). Tabela de recursos pagos no servidor (`admin_set_feature`), conferida na entrada de cada recurso. Tela "Seu plano". Quando a liberação acabar, nada é apagado: só deixa de dar para começar coisas premium. |
| Amigos | Código de 6 caracteres (sem letras que se confundem) e link de convite. Pedido, aceite, recusa (quem pediu espera 7 dias), pedidos cruzados viram amizade na hora, desfazer amizade. Até 50 amigos. |
| Privacidade | 8 escolhas: nível, sequência, conquistas, atributos, áreas dos hábitos, publicar no feed, receber pedidos, aparecer no ranking. O servidor aplica as escolhas em tudo que outra pessoa vê. Diário e detalhes dos hábitos nunca aparecem. |
| Perfil do amigo | Avatar, título, nível, sequência, últimos 7 dias, liga, conquistas recentes e comparação de atributos lado a lado. |
| Feed e incentivos | Conquistas, primeiras vitórias, níveis múltiplos de 5 e temporadas são publicados sozinhos (ou à mão, se a pessoa preferir). Quatro reações e incentivo direto (um por dia para cada amigo). Sininho com os avisos sociais. |
| Grupos | Até 30 pessoas, código de convite, dono que edita, remove e gera código novo; se o dono sai, o membro mais antigo assume. |
| Desafios | Competitivos ou coletivos, de 3 a 30 dias, contando meta do dia, missões do plano (até 12 por dia) ou dias numa área. Vencer rende 40 XP; meta coletiva, 30 XP para quem contribuiu; no máximo 2 recompensas por semana. Resultado aparece no primeiro acesso depois do fim. |
| Temporadas | Uma por mês, com pontos vindos só de missões do plano confirmadas no servidor (no máximo 25 por dia), chefes, desafios e 3 objetivos. Ligas Bronze → Mestre, com XP no fim do mês, posição entre amigos e histórico. |
| Ranking | Entre amigos ou num grupo, por pontos, constância, XP ou chefes. Quem não quer aparecer fica de fora. |
| Ferramentas | Foco (timer que continua com o app fechado, ligado a uma missão), água, sono, alimentação (calorias opcionais, com aviso de que não é orientação nutricional), leitura (livros, páginas e minutos), meditação (respiração guiada), tempo de tela (registro manual), diário (humor, texto e gratidão) e rastreador de hábitos de 4 semanas. Quando um registro cumpre uma missão, ela aparece pronta: quem conclui é a pessoa. |
| Mentor | Só com consentimento. Análises (constância, tendência, horário, áreas, dias da semana, sono, água, humor nos dias com meditação), sugestões que só mudam algo com aceite (baixar meta, pausar hábito, mudar a meta diária, modo Desafio, chefe disponível, descanso), relatório semanal toda segunda e "esta semana até agora". Sem diagnósticos; do diário usa só o número do humor. |
| Conquistas e títulos | 14 conquistas novas (social, temporadas, ferramentas), total de 58, e 4 títulos novos. |
| Navegação | Abas Início · Missões · Social · Jornada · Personagem; Perfil pela engrenagem. Atalhos de água, foco e diário no Início; Mentor e temporada na Jornada. |
| Conta de teste | `supabase/admin/conta_de_teste.sql` cria uma conta veterana com tudo liberado, bots, grupo, desafios, temporadas, ferramentas e Mentor. |

### Testado

- **Banco:** suítes do MVP, da Etapa 3, do social e temporadas (Premium aberto e fechado, pedidos, privacidade, feed, grupos, desafios no tempo, temporadas e ranking), das ferramentas e do Mentor, e do script da conta de teste. Todas passando.
- **Atualização:** a migração foi aplicada num banco com pessoas usando o app, duas vezes seguidas, sem erro e sem publicar nada retroativo.
- **App:** 41 testes, verificação de tipos e build.
- **Ponta a ponta:** no navegador, em tamanho de iPhone, contra o banco local com as permissões reais: 33 telas sem nenhum erro e 11 ações completas (aceitar pedido, aceitar convite de desafio, reagir, mandar incentivo, água até concluir a missão, diário, aceitar sugestão do Mentor, criar desafio, criar grupo, golpe final num chefe, sessão de foco), mais as telas de resultado de desafio, fim de temporada e relatório.

### Decisões

- **Premium liberado para todos por tempo limitado**, com a data de fim definida depois pelo administrador.
- **Ranking só entre amigos e grupos**, sem ranking geral.
- **Anti-fraude:** temporadas e desafios contam só missões do plano confirmadas no servidor, com limite por dia; missões avulsas não pontuam.
- **Mentor por regras no servidor**, sem IA generativa por enquanto (precisaria de uma chave de API paga).
- **As ferramentas registram, a pessoa conclui:** nenhuma missão é concluída sozinha.
- **Temporadas contam a partir do mês em que a atualização é instalada.**

### Pendente

- Notificações e lembretes (precisam de chaves configuradas na Vercel).
- Decidir se o Mentor ganha uma camada de IA generativa (tem custo por uso).
- Reavaliação no dia 66 (a tela ainda não oferece refazer o questionário).

## Etapa 3 · Gamificação

### Implementado

| Área | O que funciona |
|---|---|
| Personagem | Avatar em SVG próprio, com pele, cabelo, barba e roupa personalizáveis (editor com prévia). Aparência inicial sorteada para cada pessoa. |
| Equipamentos | 27 itens em 6 espaços (cabeça, armadura, capa, ferramenta, amuleto, moldura), desenhados no avatar. Liberados por nível, conquista ou chefe. Só visuais, sem XP extra. A moldura evolui sozinha com o nível. |
| Inventário | Todos os itens com prévia no próprio avatar, raridade e como desbloquear. Equipar e tirar. |
| Títulos | 19 títulos em linguagem neutra; escolha manual ou automática pelo nível. |
| Atributos | Gráfico em pentágono, nível e progresso de cada atributo, XP dos últimos 14 dias e quais hábitos alimentam cada um. |
| Conquistas | 44 conquistas em 8 categorias, com raridade, progresso, XP e recompensas; uma oculta. |
| Chefes | 7 chefes com arte, história e dificuldade próprias. Batalha com barra de vida, rachaduras que aparecem conforme o dano, linha do tempo dos golpes e missões que contam hoje (dá para concluir direto da tela do chefe). Vitória, revanche, recuo e desistência. |
| Modos | Normal, Desafio e Extremo, com regras escritas, requisitos, aceite obrigatório, XP maior, escudos e metas diferentes, cura do chefe, travas do Extremo, rebaixamento automático e espera de 7 dias. |
| Avisos | Nível, conquista, item, vitória, recuo e rebaixamento aparecem uma vez, com animação; itens podem ser equipados direto do aviso. |
| Integração | Início com avatar, título, modo e chefe ativo; missões mostram o XP do modo e quais dão golpe no chefe; jornada com atalhos e dias marcados por modo; perfil com modo e aparência. |
| Histórico de regras | Mudar o modo ou a meta mínima vale a partir de hoje; o passado não é reescrito. |

### Testado

- **Banco:** 8 grupos de testes novos (itens e avatar, conquistas e avisos, ajuste consciente, itens por nível, chefes, leitura protegida, modos, travas do Extremo) e os 8 do MVP, todos passando.
- **Atualização:** a migração foi aplicada num banco com uma pessoa já usando o app; ela ganhou na hora a conquista que já tinha alcançado e os itens iniciais. A migração também foi rodada duas vezes seguidas sem erro.
- **App:** 27 testes (todos os equipamentos desenham algo diferente, ids não colidem entre avatares, cada chefe tem arte própria, rachaduras por dano, fila de avisos, textos de bloqueio, artigos no meio da frase), verificação de tipos e build.
- **Ponta a ponta:** no navegador, em tamanho de iPhone, contra o banco local com as permissões reais: questionário → aparência salva → primeira conquista → inventário, títulos, atributos e conquistas → chefes bloqueados e liberados → batalha contra a Névoa → golpe pela tela do chefe → vitória com 6 avisos em sequência → modo Desafio ativado.

### Decisões

- **Versão individual retirada do código.** Manter dois motores de regras dobraria o trabalho de cada etapa. A página publicada continua como estava, e o código fica no histórico do Git (commit `49bf4ba`).
- **Tudo da Etapa 3 liberado para todos por enquanto.** A divisão gratuito × premium entra na Etapa 5, com uma tabela no servidor para o administrador escolher o que é pago.
- **Linguagem neutra** nos títulos e em perguntas do questionário que tinham adjetivos no masculino.

## Próximas etapas

| Etapa | Escopo |
|---|---|
| 4 · Complementos | Notificações e lembretes; decisão sobre IA generativa no Mentor. |
| 5 · Premium | Definir a data de fim da liberação e o que fica pago; tela de planos. |
| 6 · Lançamento | Teste com amigos, ajustes de usabilidade e desempenho. |
