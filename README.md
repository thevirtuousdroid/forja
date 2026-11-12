# Forja

Web app de evolução pessoal gamificada: hábitos reais viram missões, geram XP, fortalecem atributos e fazem o personagem subir de nível, num programa de 66 dias que continua depois.

Funciona no navegador e pode ser **instalado na tela inicial do iPhone** (e do Android) como um app.

- `docs/PLANEJAMENTO.md`: decisões de produto, arquitetura, regras e fórmulas (Etapa 1)
- `docs/STATUS.md`: o que está pronto, o que foi testado e o que falta
- `supabase/`: banco de dados e regras do jogo (rodam no servidor)
- `web/`: o app

O app tem duas versões, escolhidas no build:

| Versão | Para quem | Onde ficam os dados | Como gerar |
|---|---|---|---|
| **Individual** | Só você | Espaço privado da página no claude.ai (ou o navegador, fora dele) | `npm run build:pagina` → `web/dist-pagina/forja.html` |
| **Com servidor** (padrão) | Você e amigos | Supabase | `npm run build` + passos abaixo |

As regras do jogo são as mesmas nas duas: na individual rodam no app (`web/src/engine/`), na com servidor rodam no banco (`supabase/migrations/`). Os testes conferem que as duas dão os mesmos números.

## Versão individual

Já está publicada como página no claude.ai: é só abrir o link, com a sua conta, no computador ou no iPhone (no Safari, **Compartilhar → Adicionar à Tela de Início** cria o atalho). Os dados ficam no seu espaço privado da página e aparecem em qualquer aparelho em que você abrir com a sua conta. Em **Perfil → Seus dados** dá para exportar e restaurar um backup.

Para testar no PC sem publicar: `cd web`, `npm install`, `npm run dev` (os dados ficam no navegador).

---

## Versão com servidor (para usar com amigos)

### Colocar no ar (passo a passo)

Você vai precisar de: [Node.js LTS](https://nodejs.org) instalado no PC, uma conta gratuita no [Supabase](https://supabase.com) e uma conta gratuita na [Vercel](https://vercel.com) ou na [Netlify](https://netlify.com).

#### 1. Banco de dados (Supabase)

1. No Supabase, crie um projeto novo (região São Paulo, se disponível).
2. Abra **SQL Editor → New query**, cole todo o conteúdo de `supabase/forja_completo.sql` e clique em **Run**. (Ele junta os três arquivos de `supabase/migrations/`, na ordem.)
3. Em **Authentication → Sign In / Providers → Email**, decida se quer exigir confirmação de e-mail. Para um grupo de amigos, desligar **Confirm email** deixa o cadastro mais simples.
4. Em **Project Settings → API**, copie a **Project URL** e a chave **anon public**.

> Não use os arquivos de `supabase/tests/` no Supabase: eles simulam o Supabase só para os testes locais.

#### 2. Rodar no seu PC

No PowerShell, dentro da pasta do projeto:

```powershell
cd web
copy .env.example .env
notepad .env          # cole a Project URL e a chave anon
npm install
npm run dev
```

Abra o endereço que aparecer (normalmente `http://localhost:5173`).

#### 3. Publicar para usar no iPhone

A instalação na tela inicial do iPhone exige um endereço com HTTPS, então publique o app:

**Vercel:** *Add New → Project* → importe a pasta (pelo GitHub ou pela CLI `npx vercel` dentro de `web/`).
- Root directory: `web`
- Build command: `npm run build` · Output: `dist`
- Environment variables: `VITE_SUPABASE_URL` e `VITE_SUPABASE_ANON_KEY`

**Netlify** funciona do mesmo jeito (base `web`, build `npm run build`, publish `web/dist`).

Depois de publicar, no Supabase em **Authentication → URL Configuration**, coloque o endereço do app em **Site URL** (para os links de confirmação e de senha funcionarem).

#### 4. Instalar no iPhone

1. Abra o endereço do app no **Safari**.
2. Toque em **Compartilhar** → **Adicionar à Tela de Início**.

Mande o mesmo endereço para os amigos; cada um cria a própria conta.

#### 5. Liberar o Premium para alguém

Não há pagamento: o administrador libera. No **SQL Editor** do Supabase:

```sql
select admin_set_plan('email@da.pessoa', 'premium');
```

---

## Testes

```bash
cd web && npm test          # testes do app: motor individual (igual ao do banco), armazenamento, questionário, componentes
supabase/tests/run.sh       # testes do banco: precisa do PostgreSQL instalado (Linux, macOS ou WSL)
```

O teste do banco sobe um Postgres temporário, aplica as migrações e verifica fórmulas, avaliação, plano de 66 dias, bloqueio de escrita direta, conclusão duplicada, bônus, desfazer, limites, isolamento entre usuários e uma simulação de 30 dias com progressão, escudos e sequência.
