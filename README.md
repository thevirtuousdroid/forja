# Forja

Web app de evolução pessoal gamificada: hábitos reais viram missões, geram XP, fortalecem atributos e fazem o personagem subir de nível, num programa de 66 dias que continua depois.

Funciona no navegador e pode ser **instalado na tela inicial do iPhone** (e do Android) como um app.

- `docs/PLANEJAMENTO.md`: decisões de produto, arquitetura, regras e fórmulas (atualizado até a Etapa 4)
- `docs/STATUS.md`: o que está pronto, o que foi testado e o que falta
- `supabase/`: banco de dados e regras do jogo (rodam no servidor)
- `web/`: o app

---

## Colocar no ar


Você vai precisar de: [Node.js LTS](https://nodejs.org) instalado no PC, uma conta gratuita no [Supabase](https://supabase.com) e uma conta gratuita na [Vercel](https://vercel.com) ou na [Netlify](https://netlify.com).

### 1. Banco de dados (Supabase)

1. No Supabase, crie um projeto novo (região São Paulo, se disponível).
2. Abra **SQL Editor → New query**, cole todo o conteúdo de `supabase/forja_completo.sql` e clique em **Run**. (Ele junta todos os arquivos de `supabase/migrations/`, na ordem.)
3. Em **Authentication → Sign In / Providers → Email**, decida se quer exigir confirmação de e-mail. Para um grupo de amigos, desligar **Confirm email** deixa o cadastro mais simples.
4. Em **Project Settings → API**, copie a **Project URL** e a chave **anon public**.

> Não use os arquivos de `supabase/tests/` no Supabase: eles simulam o Supabase só para os testes locais.

### 2. Rodar no seu PC

No PowerShell, dentro da pasta do projeto:

```powershell
cd web
copy .env.example .env
notepad .env          # cole a Project URL e a chave anon
npm install
npm run dev
```

Abra o endereço que aparecer (normalmente `http://localhost:5173`).

### 3. Publicar para usar no iPhone

A instalação na tela inicial do iPhone exige um endereço com HTTPS, então publique o app:

**Vercel:** *Add New → Project* → importe a pasta (pelo GitHub ou pela CLI `npx vercel` dentro de `web/`).
- Root directory: `web`
- Build command: `npm run build` · Output: `dist`
- Environment variables: `VITE_SUPABASE_URL` e `VITE_SUPABASE_ANON_KEY`

**Netlify** funciona do mesmo jeito (base `web`, build `npm run build`, publish `web/dist`).

Depois de publicar, no Supabase em **Authentication → URL Configuration**, coloque o endereço do app em **Site URL** (para os links de confirmação e de senha funcionarem).

### 4. Instalar no iPhone

1. Abra o endereço do app no **Safari**.
2. Toque em **Compartilhar** → **Adicionar à Tela de Início**.

Mande o mesmo endereço para os amigos; cada um cria a própria conta.

### 5. Premium

Não há pagamento: o administrador libera. Os comandos abaixo são rodados no **SQL Editor** do Supabase.

**Liberado para todos por tempo limitado.** Depois da Etapa 4, o Premium começa liberado para todos, ainda sem data de fim. Quando decidir a data:

```sql
select admin_set_premium_aberto(true, '2027-01-31');  -- liberado até 31/01/2027 (inclusive)
select admin_set_premium_aberto(false);               -- encerra a liberação agora
select admin_set_premium_aberto(true);                -- libera de novo, sem data de fim
```

Quando a liberação acaba, ninguém perde nada do que já conquistou. Só deixa de dar para começar algo premium, como um chefe novo, o modo Extremo ou uma ferramenta extra.

**Para uma pessoa específica**, mesmo depois que a liberação acabar:

```sql
select admin_set_plan('email@da.pessoa', 'premium');
select admin_set_plan('email@da.pessoa', 'free');     -- volta para o gratuito
```

**O que é premium.** São 7 recursos: `habitos_ilimitados`, `modos`, `chefes`, `temporadas`, `ferramentas_extras`, `mentor` e `relatorios`. Para tornar um deles gratuito para todos (ou premium de novo):

```sql
select admin_set_feature('chefes', false);   -- chefes passam a ser gratuitos
select admin_set_feature('chefes', true);    -- chefes voltam a ser premium
select * from premium_features order by sort; -- lista o que é premium hoje
```

### 6. Atualizar um banco que já está em uso

Quando sai uma etapa nova, o banco recebe uma migração nova em `supabase/migrations/` (a da Etapa 4 é `0005_etapa4.sql`).
Rode **só a migração nova** no **SQL Editor**, do mesmo jeito do passo 1. As migrações podem ser rodadas de novo sem estragar nada,
e o progresso de quem já usa o app é mantido. Não rode o `forja_completo.sql` num banco que já está em uso: ele é para projetos novos.

### 7. Conta de teste com tudo liberado

Para testar o app inteiro sem esperar semanas, `supabase/admin/conta_de_teste.sql` transforma uma conta numa conta veterana:
70 dias de histórico, programa de 66 dias concluído, todos os modos liberados, chefes vencidos e uma revanche em andamento,
todas as conquistas, equipamentos e títulos, e Premium. Com a Etapa 4 instalada, também cria amigos de teste (bots), grupo,
desafios, temporadas passadas, registros nas ferramentas e o Mentor com relatórios.

1. **Authentication → Users → Add user → Create new user**: um e-mail só para testes, com **Auto Confirm User** marcado.
2. No **SQL Editor**, cole o arquivo, troque o e-mail na linha indicada e clique **Run**. Leva poucos segundos.
3. Entre no app com esse e-mail e senha.

O script apaga e refaz o progresso da conta indicada (rodar de novo "reseta" a conta) e recusa contas que já têm progresso de verdade.
No fim do arquivo há as linhas para apagar a conta de teste e os bots.

---

## Testes

```bash
cd web && npm test          # testes do app: fórmulas, questionário, avatar, chefes, insígnias e componentes
supabase/tests/run.sh       # testes do banco: precisa do PostgreSQL instalado (Linux, macOS ou WSL)
```

O teste do banco sobe um Postgres temporário, aplica as migrações e verifica:
- **MVP:** fórmulas, avaliação, plano de 66 dias, bloqueio de escrita direta, conclusão duplicada, bônus, desfazer, limites, isolamento entre usuários e uma simulação de 30 dias.
- **Etapa 3:** itens e avatar, títulos, conquistas e avisos, chefes (bloqueios, golpes, desfazer, vitória, revanche, recuo e cura), modos de dificuldade (requisitos, meta, escudos, XP, histórico de regras e rebaixamento) e as travas do modo Extremo.
- **Etapa 4:** Premium liberado e encerrado, amigos e privacidade, feed e incentivos, grupos, desafios competitivos e coletivos, temporadas e ligas, ranking, as 9 ferramentas, o Mentor e o relatório semanal, além do script da conta de teste.
