-- Forja · 0001 · Tabelas, índices e segurança (RLS)
-- Regra geral: o usuário LÊ os próprios dados; toda escrita de progresso passa por funções no servidor.

create table public.profiles (
  id                 uuid primary key references auth.users(id) on delete cascade,
  display_name       text not null default '' check (char_length(display_name) <= 40),
  timezone           text not null default 'America/Sao_Paulo',
  program_start      date,
  onboarding_done    boolean not null default false,
  min_daily_missions smallint not null default 2 check (min_daily_missions between 1 and 10),
  mode               text not null default 'normal' check (mode in ('normal','desafio','extremo')),
  plan               text not null default 'free' check (plan in ('free','premium')),
  created_at         timestamptz not null default now()
);

create table public.assessments (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  answers     jsonb not null,
  scores      jsonb not null,           -- { fisica: 0..100, mental: ..., ... }
  priorities  text[] not null,
  created_at  timestamptz not null default now()
);
create index on public.assessments (user_id, created_at desc);

create table public.character_stats (
  user_id        uuid primary key references public.profiles(id) on delete cascade,
  total_xp       integer not null default 0,
  level          integer not null default 1,
  -- XP de base vindo da avaliação inicial
  base_disciplina   integer not null default 0,
  base_foco         integer not null default 0,
  base_vitalidade   integer not null default 0,
  base_conhecimento integer not null default 0,
  base_determinacao integer not null default 0,
  -- XP total por atributo (base + ledger)
  disciplina     integer not null default 0,
  foco           integer not null default 0,
  vitalidade     integer not null default 0,
  conhecimento   integer not null default 0,
  determinacao   integer not null default 0,
  updated_at     timestamptz not null default now()
);

create table public.mission_templates (
  id              text primary key,
  dimension       text not null check (dimension in ('fisica','mental','intelectual','produtividade','digital','autocuidado')),
  name            text not null,
  description     text not null,
  attr_primary    text not null check (attr_primary in ('disciplina','foco','vitalidade','conhecimento','determinacao')),
  attr_secondary  text not null check (attr_secondary in ('disciplina','foco','vitalidade','conhecimento','determinacao')),
  difficulty      smallint not null check (difficulty between 1 and 5),
  unit            text not null check (unit in ('min','copos','paginas','vez')),
  base_value      integer not null check (base_value > 0),
  step            integer not null default 0 check (step >= 0),
  max_value       integer not null,
  est_minutes     integer not null,       -- tempo estimado quando a unidade não é minutos
  passive         boolean not null default false, -- não ocupa tempo extra na agenda (ex.: manhã sem celular)
  period          text not null default 'qualquer' check (period in ('manha','tarde','noite','qualquer')),
  tier            smallint not null default 1,   -- 1 = hábito inicial, 2 = hábito de continuação, 9 = surpresa
  sort            smallint not null default 0,
  check (max_value >= base_value)
);

create table public.user_habits (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  template_id     text references public.mission_templates(id),
  name            text not null check (char_length(name) between 1 and 60),
  description     text not null default '' check (char_length(description) <= 280),
  dimension       text not null,
  attr_primary    text not null,
  attr_secondary  text not null,
  difficulty      smallint not null check (difficulty between 1 and 5),
  unit            text not null,
  base_value      integer not null,
  step            integer not null default 0,
  max_value       integer not null,
  est_minutes     integer not null,
  current_target  integer not null,
  start_day       integer not null default 1 check (start_day >= 1),
  period          text not null default 'qualquer',
  is_custom       boolean not null default false,
  active          boolean not null default true,
  created_at      timestamptz not null default now(),
  check (current_target between base_value and max_value)
);
create index on public.user_habits (user_id);

create table public.missions (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references public.profiles(id) on delete cascade,
  habit_id         uuid references public.user_habits(id) on delete set null,
  dedupe_key       text not null,
  kind             text not null check (kind in ('diaria','semanal','especial','personalizada','surpresa')),
  name             text not null,
  description      text not null default '',
  dimension        text not null,
  attr_primary     text not null,
  attr_secondary   text not null,
  difficulty       smallint not null,
  estimated_minutes integer not null,
  target_value     integer not null,
  unit             text not null,
  period           text not null default 'qualquer',
  frequency        text not null default 'unica' check (frequency in ('diaria','semanal','unica')),
  xp_reward        integer not null check (xp_reward > 0),
  mission_date     date not null,          -- data de início
  due_date         date not null,          -- último dia em que pode ser concluída
  status           text not null default 'pendente' check (status in ('pendente','concluida','expirada')),
  completed_at     timestamptz,
  created_at       timestamptz not null default now(),
  unique (user_id, dedupe_key),
  check (due_date >= mission_date)
);
create index on public.missions (user_id, mission_date);
create index on public.missions (user_id, status, due_date);

create table public.xp_ledger (
  id            bigint generated always as identity primary key,
  user_id       uuid not null references public.profiles(id) on delete cascade,
  mission_id    uuid unique references public.missions(id) on delete set null,
  source        text not null check (source in ('missao','meta_diaria','retorno','marco')),
  day           date not null,
  amount        integer not null,
  disciplina    integer not null default 0,
  foco          integer not null default 0,
  vitalidade    integer not null default 0,
  conhecimento  integer not null default 0,
  determinacao  integer not null default 0,
  created_at    timestamptz not null default now(),
  check (amount = disciplina + foco + vitalidade + conhecimento + determinacao)
);
-- Um bônus de cada tipo por dia
create unique index xp_ledger_bonus_once on public.xp_ledger (user_id, source, day) where source <> 'missao';
create index on public.xp_ledger (user_id, day);

create table public.progression_events (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  habit_id    uuid not null references public.user_habits(id) on delete cascade,
  week        integer not null,
  old_target  integer not null,
  new_target  integer not null,
  completed_days integer not null,
  created_at  timestamptz not null default now()
);

create table public.progression_checks (
  user_id  uuid not null references public.profiles(id) on delete cascade,
  week     integer not null,
  primary key (user_id, week)
);

-- ── RLS ──────────────────────────────────────────────────────────────────────
alter table public.profiles            enable row level security;
alter table public.assessments         enable row level security;
alter table public.character_stats     enable row level security;
alter table public.mission_templates   enable row level security;
alter table public.user_habits         enable row level security;
alter table public.missions            enable row level security;
alter table public.xp_ledger           enable row level security;
alter table public.progression_events  enable row level security;
alter table public.progression_checks  enable row level security;

create policy "ler o próprio perfil"     on public.profiles           for select using (id = auth.uid());
create policy "ler as próprias avaliações" on public.assessments      for select using (user_id = auth.uid());
create policy "ler os próprios atributos" on public.character_stats   for select using (user_id = auth.uid());
create policy "catálogo é público"        on public.mission_templates for select using (auth.uid() is not null);
create policy "ler os próprios hábitos"  on public.user_habits        for select using (user_id = auth.uid());
create policy "ler as próprias missões"  on public.missions           for select using (user_id = auth.uid());
create policy "ler o próprio histórico"  on public.xp_ledger          for select using (user_id = auth.uid());
create policy "ler a própria progressão" on public.progression_events for select using (user_id = auth.uid());

-- Sem políticas de insert/update/delete: escrita só pelas funções SECURITY DEFINER.
revoke insert, update, delete on all tables in schema public from anon, authenticated;
grant select on all tables in schema public to authenticated;
