# Status do desenvolvimento

_Atualizado em 12/11/2026._

| Etapa | Situação |
|---|---|
| 1 · Planejamento | ✅ `docs/PLANEJAMENTO.md` |
| 2 · MVP | ✅ no ar em forja-kappa-wheat.vercel.app |
| 3 · Gamificação | ✅ pronta e testada; entra no ar depois que o banco receber a migração `0004_rpg.sql` |
| 4 · Sistemas avançados | próxima |
| 5 · Premium | |
| 6 · Testes com amigos e lançamento | |

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

### Pendente

- Notificações e lembretes (Etapa 4).
- Reavaliação no dia 66 (a tela ainda não oferece refazer o questionário).

## Próximas etapas

| Etapa | Escopo |
|---|---|
| 4 · Sistemas avançados | Amigos, grupos, ranking e temporadas entre amigos, ferramentas (foco, água, sono, leitura, meditação, diário), assistente de IA, relatório semanal, notificações. |
| 5 · Premium | Tabela de recursos pagos no servidor, tela de planos e gestão de quem é premium. |
| 6 · Lançamento | Teste com amigos, ajustes de usabilidade e desempenho. |
