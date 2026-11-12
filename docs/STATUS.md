# Status do desenvolvimento

_Atualizado em 12/11/2026._

## Etapa 1 · Planejamento ✅

`docs/PLANEJAMENTO.md`: arquitetura, banco, identidade visual, navegação, regras de negócio (fórmula de XP, curva de níveis, atributos, progressão, sequências e escudos, programa de 66 dias) e modelo gratuito/premium adaptado para uso entre amigos.

## Etapa 2 · MVP ✅ (pronto para uso)

### Implementado

| Área | O que funciona |
|---|---|
| Conta | Cadastro, login, confirmação por e-mail (opcional), recuperação de senha, sair. |
| Onboarding | 3 telas de boas-vindas; questionário em 8 etapas curtas, com rascunho salvo no aparelho. |
| Avaliação | Pontuação por dimensão, perfil de referência (sem diagnóstico), 3 prioridades, atributos iniciais. |
| Plano de 66 dias | Gerado no servidor a partir das prioridades e do tempo disponível (60% no início); hábitos novos entram nos dias 8, 22 e 34; água e sono entram quando as respostas indicam. |
| Missões | Diárias (dos hábitos), semanais (revisão da semana), especiais (fase 3+), surpresa (fase 2+, opcionais), personalizadas (avulsas ou recorrentes). Todas com os campos do item 5 do briefing. |
| Progressão | Meta sobe um passo quando o hábito é cumprido em 5 dos 7 dias anteriores; nunca passa do teto; redução só pelo usuário. |
| XP e níveis | Calculados e concedidos **somente no servidor**; histórico imutável (`xp_ledger`); proteção contra conclusão duplicada; retorno decrescente para missões personalizadas e excesso diário; desfazer no mesmo dia. |
| Atributos | Disciplina, Foco, Vitalidade, Conhecimento e Determinação, com níveis próprios. |
| Sequências | Dias completos/parciais/em branco/protegidos, sequência atual e melhor, consistência, escudos, marcos (7 a 132), bônus de meta diária e de retorno. Perder a sequência não apaga nada. |
| Telas | Splash, login/cadastro, boas-vindas, questionário, resultado, início, missões, detalhe (com ajuste de meta e pausa), nova missão, jornada (calendário + fases), personagem (emblema que evolui, atributos, histórico), perfil (nome, meta diária, fuso, cor de destaque, hábitos pausados, instalação no iPhone). |
| PWA | Ícone, manifesto, service worker, instalável no iPhone e Android, layout com áreas seguras do iPhone. |
| Premium | Campo `plan` no servidor; limite gratuito de hábitos personalizados aplicado nas funções; `admin_set_plan` para liberar. |

### Testado

- **Banco (Postgres local):** 8 grupos de testes, todos passando, incluindo uma simulação de 30 dias (nível 7, 90% de consistência, escudo protegendo um dia, sequência zerando quando os escudos acabam, metas subindo com teto, missões vencidas expirando).
- **App:** 12 testes unitários (curva de níveis igual à do banco, questionário cobre tudo o que o servidor exige, mensagens de erro, componente de missão); verificação de tipos; build de produção.
- **Ponta a ponta:** o app rodou num navegador (tamanho de iPhone) contra o banco de verdade, com as permissões reais: boas-vindas → questionário → resultado → início → concluir missões (XP, bônus) → detalhe → jornada → personagem → perfil.

### Limitações conhecidas

- A autenticação real (e-mail e senha) depende do Supabase e não foi exercitada localmente; a sessão foi simulada no teste ponta a ponta.
- Notificações e lembretes ainda não existem (Etapa 4).
- A reavaliação do dia 66 está prevista, mas a tela ainda não oferece refazer o questionário.

## Versão individual ✅ (publicada)

Para começar sem Supabase nem Vercel, o app ganhou uma versão individual:

- **Sem login.** Abre direto no questionário (agora pede o nome na primeira etapa).
- **Regras do jogo no próprio app** (`web/src/engine/`), traduzidas do banco. Os testes comparam as duas versões: 3.250 combinações de XP, a curva de níveis e a mesma simulação de 30 dias dão exatamente os mesmos números (3.125 XP, nível 7, sequência 18, consistência 90%).
- **Dados no espaço privado da página no claude.ai**, divididos em um documento de perfil e um por mês. Só o que mudou é gravado. Fora do claude.ai, usa o navegador.
- **Backup:** exportar e restaurar em Perfil → Seus dados.
- **Publicada** como página no claude.ai, em arquivo único (`npm run build:pagina`).

Testado: 24 testes do app (motor, armazenamento, questionário, componentes), testes do banco, e o fluxo completo no navegador em tamanho de iPhone, incluindo recarregar a página e encontrar os dados.
Não testado ao vivo: a gravação no espaço privado do claude.ai (só roda dentro da página publicada); o caminho com armazenamento do navegador, que usa o mesmo código de gravação, foi testado.

A versão com servidor continua no projeto, pronta para quando for usar com amigos. Um backup exportado da versão individual pode servir de base para migrar.

## Próximas etapas

| Etapa | Escopo |
|---|---|
| 3 · Gamificação | Avatar personalizável com equipamentos, inventário, conquistas, títulos, chefes ligados a missões reais, modos Desafio e Extremo. |
| 4 · Sistemas avançados | Amigos, grupos, ranking e temporadas entre amigos, ferramentas (foco, água, sono, leitura, meditação, diário), assistente de IA, relatório semanal, notificações. |
| 5 · Premium | Tela de planos e gestão de quem é premium. |
| 6 · Lançamento | Teste com amigos, ajustes de usabilidade e desempenho. |
