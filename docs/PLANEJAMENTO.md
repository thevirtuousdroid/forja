# Forja — Planejamento (Etapa 1)

> Forja é um web app de evolução pessoal gamificada. Cada hábito cumprido na vida real é uma missão concluída; o personagem evolui junto com o usuário.
> Uso inicial: pessoal e entre amigos, principalmente em iPhone (web app instalável na tela inicial).

---

## 1. Decisões de produto para este contexto

| Tema | Decisão | Motivo |
|---|---|---|
| Plataforma | Web app instalável (PWA) | Funciona no iPhone sem conta de desenvolvedor Apple, sem App Store e com uma única base de código. |
| Monetização | Estrutura gratuito/premium controlada no servidor, **sem pagamento real** | Assinatura pela App Store exige app publicado; para amigos, o administrador libera o premium manualmente. A estrutura fica pronta para virar produto. |
| Tempo de tela | Registro manual | O iOS não libera a leitura do tempo de tela para web apps. |
| Ranking | Entre amigos e grupos | Ranking global perde sentido num grupo fechado. |
| Notificações | Web Push (iOS 16.4+ com o app instalado na tela inicial) | Entra na Etapa 4. |

O programa de 66 dias é uma **estrutura de acompanhamento**, não uma promessa de que os hábitos estarão automatizados ao final. O app nunca apresenta resultados como diagnóstico médico ou psicológico.

---

## 2. Arquitetura

```
┌──────────────────────────┐        HTTPS         ┌──────────────────────────────────┐
│  Web app (PWA)           │  ───────────────────▶ │  Supabase                         │
│  React + TypeScript      │   supabase-js         │  • Auth (e-mail e senha)          │
│  Vite, React Router      │   (chave pública)     │  • PostgreSQL + RLS               │
│  Service worker (offline │                       │  • Funções RPC (regras de jogo)   │
│  do shell, cache)        │ ◀───────────────────  │  • Edge Functions (IA, Etapa 4)   │
└──────────────────────────┘                       └──────────────────────────────────┘
```

**Princípio central: o servidor é a autoridade do jogo.** O app nunca grava XP, nível, atributos ou status de missão diretamente. Ele chama funções RPC no banco (`complete_mission`, `ensure_today`, `submit_assessment`…), que validam, calculam e registram tudo numa transação. As políticas de RLS só permitem que cada usuário **leia** os próprios dados; escrita direta nas tabelas de progresso é negada.

Isso resolve de uma vez:
- **Manipulação de XP:** o valor de XP é calculado no servidor no momento em que a missão é criada e concedido só por `complete_mission`.
- **Conclusão duplicada:** `xp_ledger.mission_id` é único, e a função trava a linha da missão (`FOR UPDATE`) antes de concluir.
- **Permissões premium:** verificadas dentro das funções, nunca por variável local.
- **Histórico de transações:** toda concessão de XP fica no `xp_ledger`, com origem e distribuição por atributo.

### Pastas

```
forja/
├── docs/                 Planejamento e decisões
├── supabase/
│   ├── migrations/       SQL do banco (tabelas, RLS, funções, catálogo de missões)
│   └── tests/            Testes do banco (rodam num Postgres local)
└── web/                  Web app React
    └── src/
        ├── lib/          Cliente Supabase, API tipada, utilidades
        ├── content/      Questionário e textos
        ├── components/   Componentes visuais
        └── screens/      Telas
```

---

## 3. Banco de dados

| Tabela | Conteúdo |
|---|---|
| `profiles` | Nome, fuso horário, data de início do programa, meta mínima diária, modo de dificuldade, plano (free/premium). Criada por gatilho no cadastro. |
| `assessments` | Respostas do questionário, pontuação por dimensão, prioridades. Histórico (permite reavaliação no dia 66). |
| `character_stats` | XP total, nível e XP de cada atributo. |
| `mission_templates` | Catálogo de hábitos: dimensão, atributos, duração inicial, passo de progressão, teto, dificuldade, horário recomendado, fase mínima. |
| `user_habits` | O plano do usuário: quais hábitos, a partir de qual dia, meta atual. |
| `missions` | Instâncias diárias, semanais, especiais, personalizadas e surpresa, com XP fixado na criação. Única por hábito e dia. |
| `xp_ledger` | Histórico imutável de XP concedido. |
| `progression_events` | Registro de cada aumento de meta (para estatísticas e transparência). |

---

## 4. Regras de negócio

### 4.1 Dimensões e atributos

Seis dimensões: Saúde física, Saúde mental, Intelectual, Disciplina e produtividade, Saúde digital, Autocuidado e rotina.

Cinco atributos: **Disciplina, Foco, Vitalidade, Conhecimento, Determinação.** Cada modelo de missão tem um atributo principal (recebe 70% do XP) e um secundário (30%).

| Dimensão | Atributo principal | Secundário típico |
|---|---|---|
| Saúde física | Vitalidade | Determinação |
| Saúde mental | Foco | Vitalidade |
| Intelectual | Conhecimento | Foco |
| Produtividade | Disciplina | Foco |
| Saúde digital | Foco | Disciplina |
| Autocuidado | Disciplina | Vitalidade |

**Determinação** cresce de três jeitos: missões difíceis (dificuldade 4–5) a levam como secundário, o **bônus de retorno** (concluir a meta do dia logo após um dia em branco) e marcos de sequência.

### 4.2 Fórmula de XP

```
XP = round( 10 × D[dificuldade] × T(minutos) × K[tipo] )

D = { 1: 1.0, 2: 1.5, 3: 2.2, 4: 3.0, 5: 4.0 }
T = clamp( √(minutos / 10), 0.6, 2.5 )     ← tempo pesa, mas com retorno decrescente
K = { diária: 1.0, semanal: 2.5, especial: 3.0, surpresa: 1.2, personalizada: 0.8 }
```

Exemplos: caminhada leve de 10 min (dif. 1) = 10 XP; treino de 30 min (dif. 3) = 38 XP; leitura de 20 min (dif. 2) = 21 XP.

**Proteções contra repetição trivial:**
- Missões personalizadas: dificuldade máxima 3, no máximo 3 por dia rendem XP integral; a partir da 4ª rendem 25%.
- Acima de 12 missões concluídas no dia, o XP cai para 50%.
- A missão só pode ser concluída na própria data (ou até o fim da semana, no caso das semanais).

**Bônus diários** (registrados no ledger, únicos por dia):
- Meta mínima do dia atingida: +15 XP em Disciplina.
- Retorno após um dia em branco: +20 XP em Determinação.

### 4.3 Níveis

XP acumulado necessário para o nível L:

```
XP(L) = round( 100 × (L − 1)^1.8 )
```

| Nível | XP total | Aprox. |
|---|---|---|
| 2 | 100 | dia 1–2 |
| 5 | 1.213 | 2ª semana |
| 10 | 5.220 | ~dia 45 com boa consistência |
| 12 | 7.490 | ~dia 66 com alta consistência |
| 30 | 42.886 | muitos meses de prática |

A curva cresce mais rápido que o XP diário possível, então níveis altos exigem tempo e consistência, não repetição.

Nível de atributo: `floor( √(XP_do_atributo / 30) ) + 1`.

Conquistas e vitórias sobre chefes somam XP extra. Como cada uma vale uma vez só, elas adiantam esses marcos em alguns dias sem abrir caminho para repetição.

### 4.4 Programa de 66 dias

| Fase | Dias | O que acontece |
|---|---|---|
| 1 · Adaptação | 1–7 | 2–3 hábitos simples nas áreas prioritárias, metas mínimas. |
| 2 · Construção | 8–21 | Entram novos hábitos; metas sobem se a semana anterior foi consistente; missões surpresa. |
| 3 · Consolidação | 22–33 | Missões especiais; análise de progresso. |
| 4 · Evolução | 34–45 | Metas mais longas; desafios maiores. |
| 5 · Domínio | 46–60 | Foco em longo prazo; menos lembretes. |
| 6 · Conclusão | 61–66 | Reavaliação e relatório comparando com a avaliação inicial. |

Depois do dia 66 o app entra em **evolução contínua**: o plano permanece, a progressão continua e novas temporadas e desafios assumem o papel das fases.

### 4.5 Geração do plano a partir da avaliação

1. Cada dimensão recebe uma pontuação de 0 a 100 a partir das respostas (maior = melhor).
2. Prioridades: as 3 dimensões mais fracas. A dimensão escolhida pelo usuário como objetivo principal sempre entra.
3. O orçamento de tempo diário vem da resposta "quanto tempo por dia você consegue dedicar". O plano inicial nunca ultrapassa 60% desse tempo, deixando margem para a progressão.
4. Para cada prioridade entra um hábito inicial (dia 1). Hábitos adicionais são agendados para os dias 8, 22 e 34, sempre dentro do orçamento.
5. Água e sono entram como hábitos de autocuidado quando as respostas indicam necessidade.

### 4.6 Progressão de dificuldade

No início de cada semana do programa, para cada hábito ativo:
- Concluiu ≥ 5 dos últimos 7 dias → meta sobe um passo (ex.: caminhada 10 → 15 min), até o teto do hábito.
- Menos que isso → meta mantida. A redução é sempre decisão do usuário (botão "ajustar meta"), nunca automática.
- No **modo Normal**, o usuário pode reduzir a meta a qualquer momento até o valor inicial.

### 4.7 Sequências e consistência

Classificação de cada dia: **completo** (meta mínima atingida), **parcial** (≥ 1 missão, abaixo da meta), **em branco** (nenhuma), **protegido** (em branco, mas salvo por um escudo).

**Escudos de consistência:** a cada 7 dias seguidos, o usuário ganha um escudo (máx. 2 no Normal, 1 no Desafio, 0 no Extremo). Um dia em branco consome um escudo em vez de zerar a sequência. Perder a sequência **nunca** apaga histórico, XP ou nível.

Marcos: 7, 14, 21, 33, 45, 66, 90 e 132 dias.

### 4.8 Modos de dificuldade

| | Normal | Desafio | Extremo |
|---|---|---|---|
| Meta do dia | mínimo escolhido | maior entre o mínimo e 60% das missões diárias | todas as missões diárias (missão avulsa não substitui diária) |
| XP das missões | ×1 | ×1,2 | ×1,4 |
| Escudos | até 2 | até 1 | nenhum |
| Ajustes no plano | livres | livres | travados (sem ajustar, pausar, criar hábito ou mudar a meta diária) |
| Chefe ativo | prazo acaba → recua | dia sem missão devolve 1 golpe | dia abaixo da meta devolve 1 golpe |
| Liberação | sempre | dia 8 | dia 22 + sequência de 7 dias |

- No Extremo, 3 dias abaixo da meta em 7 levam de volta ao Desafio. Depois de sair do Extremo, ele fica 7 dias indisponível.
- Ativar Desafio ou Extremo exige confirmar a leitura das regras (no app e no servidor).
- **Histórico de regras:** cada mudança de modo ou de meta mínima vale a partir do dia em que é feita. Os dias anteriores continuam julgados pelas regras que valiam neles, então ninguém reescreve o passado baixando a meta.
- As penalidades mexem só com o que é virtual. O app nunca propõe menos sono, menos comida ou mais exercício: as metas físicas têm teto fixo.

### 4.9 Personagem, equipamentos e títulos (Etapa 3)

- **Avatar** desenhado em SVG próprio: pele (6 tons), cabelo (8 estilos, 8 cores), barba (3), cor da roupa (6). A aparência inicial é sorteada por pessoa; a pessoa personaliza quando quiser.
- **Seis espaços de equipamento:** cabeça, armadura, capa, ferramenta, amuleto e moldura. São 27 equipamentos, liberados por nível, conquista ou vitória sobre um chefe. Equipamentos são só visuais: mostram a trajetória e **não dão XP**, para a progressão continuar justa.
- **Moldura evolui sozinha** com o nível (bronze, ferro, aço, rúnica, chamas). A pessoa pode trocar no inventário.
- **19 títulos**, em linguagem neutra (ex.: "Faísca Constante", "Aço Temperado"). O título escolhido aparece sob o nome; sem escolha, vale o do nível.

### 4.10 Conquistas

44 conquistas em 8 categorias (missões, sequência, programa, hábitos, atributos, nível, chefes e modos). Cada uma tem raridade, um alvo medido no servidor e, quase sempre, um pouco de XP para um atributo.
- Conquistas de **nível não dão XP**, para não alimentarem a si mesmas.
- Uma conquista é **oculta**: "Ajuste consciente", por reduzir uma meta que estava pesada. Ajustar também é evoluir.
- Conquistas e vitórias são **permanentes**: desfazer uma missão depois não tira o que já foi conquistado.

### 4.11 Chefes

Sete chefes, cada um com arte, história, dificuldade e recompensas próprias. **Golpe = um dia** em que a pessoa fez o que o chefe exige (no máximo um golpe por dia), então só a constância vence.

| Chefe | Representa | Golpe | Golpes / prazo | Aparece |
|---|---|---|---|---|
| A Tempestade Interna | sobrecarga | missão de Saúde mental | 5 / 7 dias | dia 2 |
| O Adiador | procrastinação | missão de Produtividade | 5 / 7 dias | dia 2 |
| A Hidra das Notificações | distrações | missão de Saúde digital | 7 / 10 dias | dia 8 |
| A Névoa do Esquecimento | esquecimento | missão Intelectual | 7 / 10 dias | dia 8 |
| A Sentinela de Pedra | desconforto | missão de Saúde física | 10 / 14 dias | dia 15 |
| O Errante | inconsistência | meta do dia cumprida | 12 / 16 dias | dia 22 |
| O Juiz da Bigorna | disciplina | todas as missões diárias | 14 / 20 dias | dia 34, após 3 vitórias |

- Um chefe por vez. Chefes de uma área pedem um hábito ativo nessa área.
- O progresso é **recalculado a partir das missões**, então desfazer uma conclusão tira o golpe do dia.
- Prazo esgotado: o chefe **recua**, sem custo, e pode ser desafiado de novo. Revanche contra um chefe já vencido rende metade do XP e não repete itens.

### 4.12 Avisos

Nível, conquista, item novo, vitória, recuo e rebaixamento de modo viram **avisos guardados no servidor**. O app mostra cada um uma vez, com animação, e marca como visto. Assim nada se perde, mesmo que algo aconteça enquanto o app está fechado.

---

## 5. Identidade visual

- **Nome:** Forja. A metáfora é forjar a si mesmo: calor, metal, brasa, aprimoramento gradual.
- **Base:** escura, quase preta com tom azulado frio (`#0B0D12`), superfícies em camadas (`#12151C`, `#1A1E27`).
- **Destaque padrão:** brasa (`#FF7A3D`), com alternativas configuráveis: aço azul, jade e ametista.
- **Atributos** com cores próprias, sempre acompanhadas de rótulo, nunca só cor.
- **Tipografia:** Sora para títulos e números; fonte do sistema para textos, priorizando legibilidade.
- **Ícone e emblema:** uma bigorna estilizada com uma chama, desenhada em SVG próprio.
- **Personagem:** emblema que evolui por faixa de nível (anel, gemas, chama). Na Etapa 3 vira avatar personalizável com equipamentos.
- **Movimento:** animações curtas (150–300 ms), respeitando "reduzir movimento" do sistema.

---

## 6. Navegação

```
Splash → Login/Cadastro → Boas-vindas (3 telas) → Questionário (7 etapas) → Resultado da avaliação → Início
                                                                                                      │
Abas inferiores:  Início · Missões · Jornada (calendário + plano) · Personagem · Perfil
```

---

## 7. Gratuito × Premium

| Gratuito (para sempre) | Premium |
|---|---|
| Avaliação, plano de 66 dias completo, 2 hábitos personalizados recorrentes, até 5 missões avulsas por dia, XP, níveis, sequências, estatísticas essenciais | Hábitos e missões ilimitados, modos Desafio/Extremo, chefes, temporadas, ferramentas auxiliares completas, assistente de IA, relatórios, temas |

> Na Etapa 3, personagem, chefes e modos ficaram liberados para todos. A divisão entre gratuito e premium é aplicada na Etapa 5, com uma tabela no servidor onde o administrador escolhe o que é pago.

O plano fica em `profiles.plan` e só muda por função administrativa (`admin_set_plan`) ou, no futuro, por validação de pagamento no servidor. Preços não são definidos aqui: haverá uma tabela de configuração quando o pagamento existir.

---

## 8. Roteiro

| Etapa | Escopo | Status |
|---|---|---|
| 1 | Planejamento | ✅ este documento |
| 2 | MVP: cadastro, onboarding, avaliação, programa de 66 dias, missões, XP, níveis, atributos, sequências, dashboard | ✅ |
| 3 | Personagem visual, inventário, conquistas, chefes, modos de dificuldade | ✅ |
| 4 | Amigos, grupos, ranking, temporadas, ferramentas (foco, água, sono, leitura, diário), assistente de IA, notificações | |
| 5 | Premium: decidir quais recursos são pagos (estrutura administrativa no servidor); pagamentos só se virar produto | |
| 6 | Testes de usabilidade com amigos, ajustes, publicação | |
