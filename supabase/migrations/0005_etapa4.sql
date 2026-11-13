-- Forja · 0005 · Etapa 4: Premium aberto, amigos, privacidade, feed, incentivos, grupos, desafios entre amigos,
--                         temporadas e ranking, ferramentas (foco, água, sono, alimentação, leitura, meditação,
--                         tempo de tela, diário, hábitos) e Mentor (análises, sugestões com autorização e relatório semanal)
--
-- Pode ser aplicada num banco que já tem 0001–0004 e usuários com dados, e rodada de novo sem estragar nada.
-- Regra geral continua a mesma: o app só LÊ os próprios dados. Tudo que envolve outra pessoa passa por
-- funções do servidor, que aplicam as escolhas de privacidade de cada um.

-- ════════════════════════════════════════════════════════════════════════════
-- 1. Tabelas
-- ════════════════════════════════════════════════════════════════════════════

-- Configuração geral (uma linha só)
create table if not exists public.app_config (
  id                  boolean primary key default true check (id),
  premium_aberto      boolean not null default true,   -- Premium liberado para todos?
  premium_aberto_ate  date,                            -- último dia liberado (inclusive); vazio = sem data definida
  seasons_since       date not null default current_date, -- primeira temporada que conta
  updated_at          timestamptz not null default now()
);
insert into public.app_config (id) values (true) on conflict do nothing;

-- O que é Premium. O administrador escolhe com admin_set_feature (o valor de "premium" nunca é sobrescrito aqui).
create table if not exists public.premium_features (
  id           text primary key,
  name         text not null,
  description  text not null,
  premium      boolean not null default true,
  sort         smallint not null default 0
);

-- Código de amizade e privacidade
alter table public.profiles add column if not exists friend_code text;
alter table public.profiles add column if not exists privacy jsonb not null default '{}'::jsonb;
create unique index if not exists profiles_friend_code_key on public.profiles (friend_code);

create table if not exists public.friendships (
  id            uuid primary key default gen_random_uuid(),
  requester     uuid not null references public.profiles(id) on delete cascade,
  addressee     uuid not null references public.profiles(id) on delete cascade,
  status        text not null default 'pendente' check (status in ('pendente','aceita','recusada')),
  created_at    timestamptz not null default now(),
  responded_at  timestamptz,
  check (requester <> addressee)
);
create unique index if not exists friendships_pair on public.friendships
  (least(requester, addressee), greatest(requester, addressee));
create index if not exists friendships_addressee_idx on public.friendships (addressee, status);
create index if not exists friendships_requester_idx on public.friendships (requester, status);

-- Feed: retratos de conquistas, vitórias, níveis e temporadas (o texto fica guardado como estava no dia)
create table if not exists public.feed_posts (
  id          bigint generated always as identity primary key,
  author      uuid not null references public.profiles(id) on delete cascade,
  kind        text not null check (kind in ('conquista','chefe','nivel','temporada')),
  ref         text not null,
  data        jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now(),
  unique (author, kind, ref)
);
create index if not exists feed_posts_author_idx on public.feed_posts (author, id desc);

-- Incentivos: reação a uma publicação ou mensagem direta para um amigo
create table if not exists public.cheers (
  id          bigint generated always as identity primary key,
  post_id     bigint references public.feed_posts(id) on delete cascade,
  sender      uuid not null references public.profiles(id) on delete cascade,
  receiver    uuid not null references public.profiles(id) on delete cascade,
  kind        text not null check (kind in ('parabens','forca','brasa','foco','volta')),
  created_at  timestamptz not null default now(),
  check (sender <> receiver)
);
create unique index if not exists cheers_once_per_post on public.cheers (post_id, sender) where post_id is not null;
create index if not exists cheers_sender_idx on public.cheers (sender, created_at);
create index if not exists cheers_receiver_idx on public.cheers (receiver, created_at);

-- Grupos
create table if not exists public.social_groups (
  id           uuid primary key default gen_random_uuid(),
  name         text not null check (char_length(name) between 2 and 40),
  description  text not null default '' check (char_length(description) <= 140),
  owner        uuid not null references public.profiles(id) on delete cascade,
  invite_code  text not null unique,
  created_at   timestamptz not null default now()
);

create table if not exists public.group_members (
  group_id   uuid not null references public.social_groups(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  role       text not null default 'membro' check (role in ('dono','membro')),
  joined_at  timestamptz not null default now(),
  primary key (group_id, user_id)
);
create index if not exists group_members_user_idx on public.group_members (user_id);

-- Desafios entre amigos (competitivos ou coletivos)
create table if not exists public.challenges (
  id           uuid primary key default gen_random_uuid(),
  creator      uuid not null references public.profiles(id) on delete cascade,
  group_id     uuid references public.social_groups(id) on delete set null,
  kind         text not null check (kind in ('competitivo','coletivo')),
  metric       text not null check (metric in ('meta_diaria','missoes','area')),
  dimension    text check (dimension in ('fisica','mental','intelectual','produtividade','digital','autocuidado')),
  title        text not null check (char_length(title) between 2 and 50),
  target       integer check (target > 0),
  starts_on    date not null,
  ends_on      date not null,
  status       text not null default 'ativo' check (status in ('ativo','encerrado','cancelado')),
  created_at   timestamptz not null default now(),
  finished_at  timestamptz,
  check ((metric = 'area') = (dimension is not null)),
  check ((kind = 'coletivo') = (target is not null)),
  check (ends_on >= starts_on)
);
create index if not exists challenges_creator_idx on public.challenges (creator, status);

create table if not exists public.challenge_participants (
  challenge_id  uuid not null references public.challenges(id) on delete cascade,
  user_id       uuid not null references public.profiles(id) on delete cascade,
  status        text not null default 'convidado' check (status in ('convidado','aceito','recusado','saiu')),
  score         integer not null default 0,
  rank          integer,
  result        text check (result in ('venceu','meta_coletiva','participou')),
  xp            integer not null default 0,
  responded_at  timestamptz,
  primary key (challenge_id, user_id)
);
create index if not exists challenge_participants_user_idx on public.challenge_participants (user_id, status);

-- Temporadas (uma por mês) e ligas
create table if not exists public.league_catalog (
  id          text primary key,
  name        text not null,
  min_points  integer not null,
  xp_reward   integer not null,
  sort        smallint not null
);

create table if not exists public.season_results (
  user_id     uuid not null references public.profiles(id) on delete cascade,
  season      integer not null,               -- aaaamm
  points      integer not null,
  league      text not null references public.league_catalog(id),
  xp          integer not null default 0,
  data        jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now(),
  primary key (user_id, season)
);

-- Ferramentas: cada registro é do dia local da pessoa
alter table public.profiles add column if not exists tool_settings jsonb not null default '{}'::jsonb;

create table if not exists public.tool_logs (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  tool        text not null check (tool in ('foco','agua','sono','alimentacao','leitura','meditacao','tela','diario')),
  day         date not null,
  data        jsonb not null default '{}'::jsonb,
  mission_id  uuid references public.missions(id) on delete set null,
  created_at  timestamptz not null default now()
);
create index if not exists tool_logs_user_idx on public.tool_logs (user_id, tool, day);

create table if not exists public.books (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles(id) on delete cascade,
  title         text not null check (char_length(title) between 1 and 120),
  author        text not null default '' check (char_length(author) <= 80),
  total_pages   integer check (total_pages between 1 and 5000),
  current_page  integer not null default 0 check (current_page >= 0),
  status        text not null default 'lendo' check (status in ('lendo','concluido','pausado')),
  started_on    date not null,
  finished_on   date,
  created_at    timestamptz not null default now()
);
create index if not exists books_user_idx on public.books (user_id, status);

-- Mentor: só funciona com o consentimento da pessoa; sugestões só mudam algo quando ela aceita
alter table public.profiles add column if not exists mentor_enabled boolean not null default false;
alter table public.profiles add column if not exists mentor_checked_on date;

create table if not exists public.mentor_suggestions (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles(id) on delete cascade,
  kind          text not null check (kind in ('reduzir_meta','pausar_habito','reduzir_minimo','aumentar_minimo',
                                              'experimentar_desafio','enfrentar_chefe','descansar')),
  ref           text not null default '',
  data          jsonb not null default '{}'::jsonb,
  status        text not null default 'aberta' check (status in ('aberta','aceita','recusada','expirada')),
  created_on    date not null,
  responded_at  timestamptz
);
create unique index if not exists mentor_suggestions_open on public.mentor_suggestions (user_id, kind, ref) where status = 'aberta';
create index if not exists mentor_suggestions_user_idx on public.mentor_suggestions (user_id, status);

create table if not exists public.mentor_reports (
  user_id     uuid not null references public.profiles(id) on delete cascade,
  week_start  date not null,                -- segunda-feira
  data        jsonb not null,
  created_at  timestamptz not null default now(),
  primary key (user_id, week_start)
);

-- Novas origens de XP e novos avisos
alter table public.xp_ledger drop constraint if exists xp_ledger_source_check;
alter table public.xp_ledger add constraint xp_ledger_source_check
  check (source in ('missao','meta_diaria','retorno','marco','conquista','chefe','desafio','temporada'));

alter table public.user_events drop constraint if exists user_events_kind_check;
alter table public.user_events add constraint user_events_kind_check check (kind in (
  'nivel','conquista','item','chefe_vencido','chefe_recuou','modo_rebaixado','temporada','desafio_fim','relatorio',
  'pedido_amizade','amizade_aceita','incentivo','desafio_convite','grupo_entrada'));

alter table public.achievement_catalog drop constraint if exists achievement_catalog_category_check;
alter table public.achievement_catalog add constraint achievement_catalog_category_check check (category in (
  'missoes','sequencia','programa','nivel','atributos','habitos','chefes','modos','social','temporadas','ferramentas'));

-- ── Segurança das novas tabelas (leitura só do que é da pessoa; o resto vem pelas funções) ──
alter table public.app_config             enable row level security;
alter table public.premium_features       enable row level security;
alter table public.friendships            enable row level security;
alter table public.feed_posts             enable row level security;
alter table public.cheers                 enable row level security;
alter table public.social_groups          enable row level security;
alter table public.group_members          enable row level security;
alter table public.challenges             enable row level security;
alter table public.challenge_participants enable row level security;
alter table public.league_catalog         enable row level security;
alter table public.season_results         enable row level security;
alter table public.tool_logs              enable row level security;
alter table public.books                  enable row level security;
alter table public.mentor_suggestions     enable row level security;
alter table public.mentor_reports         enable row level security;

drop policy if exists "configuração" on public.app_config;
create policy "configuração" on public.app_config for select using (auth.uid() is not null);
drop policy if exists "recursos premium" on public.premium_features;
create policy "recursos premium" on public.premium_features for select using (auth.uid() is not null);
drop policy if exists "ligas" on public.league_catalog;
create policy "ligas" on public.league_catalog for select using (auth.uid() is not null);
drop policy if exists "as próprias amizades" on public.friendships;
create policy "as próprias amizades" on public.friendships for select using (auth.uid() in (requester, addressee));
drop policy if exists "as próprias publicações" on public.feed_posts;
create policy "as próprias publicações" on public.feed_posts for select using (author = auth.uid());
drop policy if exists "os próprios incentivos" on public.cheers;
create policy "os próprios incentivos" on public.cheers for select using (auth.uid() in (sender, receiver));
drop policy if exists "os próprios grupos" on public.social_groups;
create policy "os próprios grupos" on public.social_groups for select using (
  exists (select 1 from public.group_members m where m.group_id = social_groups.id and m.user_id = auth.uid()));
drop policy if exists "as próprias participações em grupos" on public.group_members;
create policy "as próprias participações em grupos" on public.group_members for select using (user_id = auth.uid());
drop policy if exists "os próprios desafios" on public.challenges;
create policy "os próprios desafios" on public.challenges for select using (
  creator = auth.uid() or exists (select 1 from public.challenge_participants cp
                                   where cp.challenge_id = challenges.id and cp.user_id = auth.uid()));
drop policy if exists "as próprias participações em desafios" on public.challenge_participants;
create policy "as próprias participações em desafios" on public.challenge_participants for select using (user_id = auth.uid());
drop policy if exists "os próprios resultados de temporada" on public.season_results;
create policy "os próprios resultados de temporada" on public.season_results for select using (user_id = auth.uid());
drop policy if exists "os próprios registros" on public.tool_logs;
create policy "os próprios registros" on public.tool_logs for select using (user_id = auth.uid());
drop policy if exists "os próprios livros" on public.books;
create policy "os próprios livros" on public.books for select using (user_id = auth.uid());
drop policy if exists "as próprias sugestões" on public.mentor_suggestions;
create policy "as próprias sugestões" on public.mentor_suggestions for select using (user_id = auth.uid());
drop policy if exists "os próprios relatórios" on public.mentor_reports;
create policy "os próprios relatórios" on public.mentor_reports for select using (user_id = auth.uid());

-- ════════════════════════════════════════════════════════════════════════════
-- 2. Catálogos
-- ════════════════════════════════════════════════════════════════════════════

insert into public.premium_features (id, name, description, sort) values
  ('habitos_ilimitados', 'Hábitos personalizados ilimitados', 'Mais de 2 hábitos personalizados recorrentes (até 12).', 1),
  ('modos',              'Modos Desafio e Extremo',          'Regras mais exigentes, com mais XP.', 2),
  ('chefes',             'Chefes',                           'Batalhas contra chefes, com itens e títulos exclusivos.', 3),
  ('temporadas',         'Temporadas e ranking',             'Ligas mensais, objetivos da temporada e ranking entre amigos.', 4),
  ('ferramentas_extras', 'Ferramentas completas',            'Sono, alimentação, leitura, meditação e tempo de tela, além de foco, água e diário.', 5),
  ('mentor',             'Mentor',                           'Análise do seu progresso e sugestões de ajuste do plano.', 6),
  ('relatorios',         'Relatórios',                       'Relatório semanal com tendências e comparações.', 7)
on conflict (id) do update set name = excluded.name, description = excluded.description, sort = excluded.sort;

insert into public.league_catalog (id, name, min_points, xp_reward, sort) values
  ('bronze',   'Bronze',   0,   0,   1),
  ('prata',    'Prata',    120, 25,  2),
  ('ouro',     'Ouro',     260, 50,  3),
  ('platina',  'Platina',  400, 80,  4),
  ('diamante', 'Diamante', 540, 120, 5),
  ('mestre',   'Mestre',   680, 160, 6)
on conflict (id) do update set name = excluded.name, min_points = excluded.min_points,
  xp_reward = excluded.xp_reward, sort = excluded.sort;

insert into public.achievement_catalog (id, category, name, description, rarity, metric, threshold, xp, attr, hidden, sort) values
  ('so_amigo',     'social',     'Em boa companhia',    'Faça sua primeira amizade na Forja.',               'comum',    'amigos',     1, 20,  'determinacao', false, 80),
  ('so_amigos5',   'social',     'Círculo da forja',    'Tenha 5 amizades na Forja.',                        'raro',     'amigos',     5, 50,  'determinacao', false, 81),
  ('so_incentivo', 'social',     'Palavra que levanta', 'Mande 10 incentivos para amigos.',                  'comum',    'incentivos', 10, 30, 'determinacao', false, 82),
  ('so_desafio',   'social',     'Duelo amistoso',      'Vença um desafio ou cumpra uma meta coletiva.',     'raro',     'desafios',   1, 50,  'disciplina',   false, 83),
  ('so_desafio5',  'social',     'Rival respeitado',    'Vença 5 desafios ou metas coletivas.',              'epico',    'desafios',   5, 120, 'disciplina',   false, 84),
  ('tp_1',         'temporadas', 'Primeira temporada',  'Termine uma temporada na liga Prata ou acima.',     'comum',    'temporadas', 1, 30,  'determinacao', false, 90),
  ('tp_ouro',      'temporadas', 'Liga de Ouro',        'Termine uma temporada na liga Ouro ou acima.',      'raro',     'liga_max',   3, 60,  'determinacao', false, 91),
  ('tp_diamante',  'temporadas', 'Brilho de diamante',  'Termine uma temporada na liga Diamante ou acima.',  'epico',    'liga_max',   5, 120, 'determinacao', false, 92),
  ('tp_mestre',    'temporadas', 'Mestre da temporada', 'Termine uma temporada na liga Mestre.',             'lendario', 'liga_max',   6, 200, 'determinacao', false, 93),
  ('fe_agua',      'ferramentas', 'Bem hidratado',      'Bata a sua meta de água em 7 dias.',                'comum',    'dias_agua',      7,   30, 'vitalidade',   false, 100),
  ('fe_foco',      'ferramentas', 'Foco profundo',      'Complete 10 sessões de foco de pelo menos 20 minutos.', 'raro', 'sessoes_foco',   10,  50, 'foco',         false, 101),
  ('fe_livro',     'ferramentas', 'Última página',      'Termine um livro registrado na Forja.',             'raro',     'livros',         1,   60, 'conhecimento', false, 102),
  ('fe_diario',    'ferramentas', 'Páginas do diário',  'Escreva no diário em 7 dias.',                      'comum',    'dias_diario',    7,   30, 'foco',         false, 103),
  ('fe_meditacao', 'ferramentas', 'Mente quieta',       'Medite por 100 minutos no total.',                  'raro',     'min_meditacao',  100, 50, 'foco',         false, 104)
on conflict (id) do update set
  category = excluded.category, name = excluded.name, description = excluded.description, rarity = excluded.rarity,
  metric = excluded.metric, threshold = excluded.threshold, xp = excluded.xp, attr = excluded.attr,
  hidden = excluded.hidden, sort = excluded.sort;

insert into public.item_catalog (id, kind, slot, name, description, rarity, unlock_type, unlock_level, unlock_ref, sort) values
  ('tit_aliado',    'titulo', null, 'Aliado da Forja',      'Conquista "Círculo da forja".',    'raro',     'conquista', null, 'so_amigos5',  127),
  ('tit_rival',     'titulo', null, 'Rival Respeitado',     'Conquista "Rival respeitado".',    'epico',    'conquista', null, 'so_desafio5', 128),
  ('tit_temporada', 'titulo', null, 'Mestre de Temporada',  'Conquista "Mestre da temporada".', 'lendario', 'conquista', null, 'tp_mestre',   129),
  ('tit_leitor',    'titulo', null, 'Guardião das Páginas', 'Conquista "Última página".',       'raro',     'conquista', null, 'fe_livro',    130)
on conflict (id) do update set
  kind = excluded.kind, slot = excluded.slot, name = excluded.name, description = excluded.description,
  rarity = excluded.rarity, unlock_type = excluded.unlock_type, unlock_level = excluded.unlock_level,
  unlock_ref = excluded.unlock_ref, sort = excluded.sort;

-- ════════════════════════════════════════════════════════════════════════════
-- 3. Premium: liberado para todos por tempo limitado + o que é pago
-- ════════════════════════════════════════════════════════════════════════════

create or replace function public._has_premium(p_uid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select p.plan = 'premium' from profiles p where p.id = p_uid), false)
      or coalesce((select c.premium_aberto and (c.premium_aberto_ate is null or _local_today(p_uid) <= c.premium_aberto_ate)
                     from app_config c where c.id), false)
$$;

create or replace function public._feature_allowed(p_uid uuid, p_feature text)
returns boolean language sql stable security definer set search_path = public as $$
  select not coalesce((select f.premium from premium_features f where f.id = p_feature), false) or _has_premium(p_uid)
$$;

create or replace function public._require_feature(p_uid uuid, p_feature text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not _feature_allowed(p_uid, p_feature) then
    raise exception 'recurso_premium' using detail = p_feature;
  end if;
end $$;

create or replace function public.get_plan_info()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_plan text;
  v_cfg app_config;
  v_open boolean;
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  select plan into v_plan from profiles where id = v_uid;
  select * into v_cfg from app_config where id;
  v_open := coalesce(v_cfg.premium_aberto, false)
            and (v_cfg.premium_aberto_ate is null or _local_today(v_uid) <= v_cfg.premium_aberto_ate);
  return jsonb_build_object(
    'plan', v_plan,
    'premium', v_plan = 'premium' or v_open,
    'via', case when v_plan = 'premium' then 'plano' when v_open then 'liberado' end,
    'open_until', case when v_open then v_cfg.premium_aberto_ate end,
    'features', (select coalesce(jsonb_agg(jsonb_build_object(
                   'id', f.id, 'name', f.name, 'description', f.description, 'premium', f.premium,
                   'allowed', not f.premium or v_plan = 'premium' or v_open) order by f.sort), '[]'::jsonb)
                   from premium_features f));
end $$;

-- ── Administração (rodar no SQL Editor do Supabase; não fica exposta ao app) ──
-- Exemplos:
--   select admin_set_premium_aberto(true, '2027-01-31');  -- liberado para todos até 31/01/2027 (inclusive)
--   select admin_set_premium_aberto(true, null);          -- liberado, sem data de fim
--   select admin_set_premium_aberto(false);               -- encerra a liberação agora
create or replace function public.admin_set_premium_aberto(p_aberto boolean, p_ate date default null)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  update app_config set premium_aberto = coalesce(p_aberto, false), premium_aberto_ate = p_ate, updated_at = now() where id;
  return (select to_jsonb(c) from app_config c where c.id);
end $$;

--   select admin_set_feature('chefes', false);  -- chefes passam a ser gratuitos
create or replace function public.admin_set_feature(p_feature text, p_premium boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  update premium_features set premium = coalesce(p_premium, true) where id = p_feature;
  if not found then raise exception 'recurso_nao_encontrado'; end if;
  return (select to_jsonb(f) from premium_features f where f.id = p_feature);
end $$;

-- Hábitos personalizados: limite do plano gratuito vale só sem Premium
create or replace function public.create_custom_mission(
  p_name text, p_description text, p_dimension text, p_difficulty int, p_minutes int, p_recurring boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  prof profiles;
  a record;
  today date;
  day_n int;
  n int;
  hid uuid;
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  select * into prof from profiles where id = uid;
  if not prof.onboarding_done then raise exception 'conclua_a_avaliacao'; end if;
  if p_dimension not in ('fisica','mental','intelectual','produtividade','digital','autocuidado') then raise exception 'dimensao_invalida'; end if;
  if p_difficulty is null or p_difficulty not between 1 and 3 then raise exception 'dificuldade_invalida'; end if;
  if p_minutes is null or p_minutes not between 1 and 120 then raise exception 'duracao_invalida'; end if;
  if char_length(trim(coalesce(p_name, ''))) not between 1 and 60 then raise exception 'nome_invalido'; end if;

  select * into a from _attr_for_dimension(p_dimension);
  today := _local_today(uid);
  day_n := (today - prof.program_start) + 1;

  if p_recurring then
    if prof.mode = 'extremo' then raise exception 'modo_extremo_bloqueia_habitos'; end if;
    select count(*) into n from user_habits where user_id = uid and active and is_custom;
    if n >= 12 then raise exception 'limite_habitos'; end if;
    if n >= 2 and not _feature_allowed(uid, 'habitos_ilimitados') then raise exception 'limite_gratuito_personalizadas'; end if;

    insert into user_habits (user_id, name, description, dimension, attr_primary, attr_secondary, difficulty,
                             unit, base_value, step, max_value, est_minutes, current_target, start_day, is_custom)
    values (uid, trim(p_name), left(coalesce(p_description, ''), 280), p_dimension, a.primary_attr, a.secondary_attr,
            p_difficulty, 'min', p_minutes, 0, p_minutes, p_minutes, p_minutes, greatest(day_n, 1), true)
    returning id into hid;
    perform _ensure_day(uid, today);
    return jsonb_build_object('habit_id', hid);
  else
    select count(*) into n from missions where user_id = uid and kind = 'personalizada' and mission_date = today;
    if n >= 5 then raise exception 'limite_diario_personalizadas'; end if;
    perform _insert_mission(uid, null, 'c:' || gen_random_uuid(), 'personalizada', trim(p_name),
      left(coalesce(p_description, ''), 280), p_dimension, a.primary_attr, a.secondary_attr, p_difficulty,
      p_minutes, 'min', p_minutes, 'qualquer', 'unica', today, today);
    return jsonb_build_object('ok', true);
  end if;
end $$;

-- Chefes e modos exigentes: o Premium é conferido na entrada (batalhas e modos já ativos continuam)
create or replace function public.start_boss(p_boss text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  perform _require_feature(uid, 'chefes');
  return _start_boss(uid, p_boss, _local_today(uid), now());
end $$;

create or replace function public.set_mode(p_mode text, p_accept boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  if p_mode in ('desafio','extremo') then perform _require_feature(uid, 'modos'); end if;
  return _set_mode(uid, p_mode, p_accept, _local_today(uid));
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 4. Ajudantes do social
-- ════════════════════════════════════════════════════════════════════════════

-- Códigos sem caracteres que se confundem (sem 0, 1, I, L, O)
create or replace function public._new_code(p_len int)
returns text language plpgsql volatile as $$
declare
  alphabet constant text := '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  s text := '';
begin
  for i in 1 .. p_len loop
    s := s || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
  end loop;
  return s;
end $$;

create or replace function public._normalize_code(p_code text)
returns text language sql immutable as $$
  select upper(regexp_replace(coalesce(p_code, ''), '[^0-9A-Za-z]', '', 'g'))
$$;

create or replace function public._new_friend_code()
returns text language plpgsql volatile security definer set search_path = public as $$
declare c text;
begin
  loop
    c := _new_code(6);
    exit when not exists (select 1 from profiles where friend_code = c);
  end loop;
  return c;
end $$;

create or replace function public._new_group_code()
returns text language plpgsql volatile security definer set search_path = public as $$
declare c text;
begin
  loop
    c := _new_code(7);
    exit when not exists (select 1 from social_groups where invite_code = c);
  end loop;
  return c;
end $$;

create or replace function public._profiles_friend_code()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.friend_code is null then new.friend_code := _new_friend_code(); end if;
  return new;
end $$;

drop trigger if exists profiles_friend_code on public.profiles;
create trigger profiles_friend_code before insert on public.profiles
  for each row execute function public._profiles_friend_code();

-- Quem já tem conta ganha um código agora
do $$
declare r record;
begin
  for r in select id from public.profiles where friend_code is null loop
    update public.profiles set friend_code = public._new_friend_code() where id = r.id;
  end loop;
end $$;
alter table public.profiles alter column friend_code set not null;

-- Privacidade: o que vale quando a pessoa ainda não escolheu
create or replace function public._privacy(p_uid uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select '{"mostrar_nivel":true,"mostrar_sequencia":true,"mostrar_conquistas":true,"mostrar_atributos":true,
           "mostrar_habitos":false,"publicar_automatico":true,"aceitar_pedidos":true,"participar_ranking":true}'::jsonb
         || coalesce((select privacy from profiles where id = p_uid), '{}'::jsonb)
$$;

create or replace function public._is_friend(p_a uuid, p_b uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from friendships f
                  where f.status = 'aceita'
                    and least(f.requester, f.addressee) = least(p_a, p_b)
                    and greatest(f.requester, f.addressee) = greatest(p_a, p_b))
$$;

create or replace function public._friend_ids(p_uid uuid)
returns setof uuid language sql stable security definer set search_path = public as $$
  select case when f.requester = p_uid then f.addressee else f.requester end
    from friendships f
   where f.status = 'aceita' and p_uid in (f.requester, f.addressee)
$$;

create or replace function public._friend_count(p_uid uuid)
returns int language sql stable security definer set search_path = public as $$
  select count(*)::int from friendships f where f.status = 'aceita' and p_uid in (f.requester, f.addressee)
$$;

-- Pode ver o cartão da outra pessoa: ela mesma, amigos ou gente do mesmo grupo
create or replace function public._can_see(p_viewer uuid, p_target uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select p_viewer = p_target
      or _is_friend(p_viewer, p_target)
      or exists (select 1 from group_members a join group_members b on b.group_id = a.group_id
                  where a.user_id = p_viewer and b.user_id = p_target)
$$;

create or replace function public._title_name(p_uid uuid)
returns text language sql stable security definer set search_path = public as $$
  select coalesce(
    (select ic.name from profiles p join item_catalog ic on ic.id = p.active_title where p.id = p_uid),
    (select ic.name from item_catalog ic, character_stats cs
      where cs.user_id = p_uid and ic.kind = 'titulo'
        and (ic.unlock_type = 'inicial' or (ic.unlock_type = 'nivel' and ic.unlock_level <= cs.level))
      order by coalesce(ic.unlock_level, 0) desc limit 1),
    'Aprendiz da Forja')
$$;

-- Identificação mínima (nome e aparência)
create or replace function public._lite(p_uid uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', p.id, 'name', p.display_name, 'avatar', p.avatar)
    from profiles p where p.id = p_uid
$$;

-- Cartão de uma pessoa visto por outra, respeitando a privacidade de quem é visto
create or replace function public._card(p_viewer uuid, p_target uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_prof profiles;
  v_pv jsonb;
  v_self boolean := p_viewer = p_target;
  v_level int;
  v_j jsonb;
  v_today date;
  v_card jsonb;
begin
  select * into v_prof from profiles where id = p_target;
  if not found then return null; end if;
  v_pv := _privacy(p_target);
  v_card := jsonb_build_object('id', v_prof.id, 'name', v_prof.display_name, 'avatar', v_prof.avatar,
                               'onboarded', v_prof.onboarding_done);

  if v_self or (v_pv->>'mostrar_nivel')::boolean then
    select level into v_level from character_stats where user_id = p_target;
    v_card := v_card || jsonb_build_object('level', coalesce(v_level, 1), 'title', _title_name(p_target));
  end if;

  if (v_self or (v_pv->>'mostrar_sequencia')::boolean) and v_prof.program_start is not null then
    v_today := _local_today(p_target);
    v_j := _journey(p_target, v_today);
    v_card := v_card || jsonb_build_object(
      'streak', (v_j->>'current_streak')::int,
      'best_streak', (v_j->>'best_streak')::int,
      'today', (select jsonb_build_object('done', (e->>'done')::int, 'goal', (e->>'goal')::int, 'met', e->>'status' = 'completo')
                  from jsonb_array_elements(v_j->'days') e where (e->>'date')::date = v_today),
      'last_active', (select max((e->>'date')::date) from jsonb_array_elements(v_j->'days') e where (e->>'done')::int > 0));
  end if;

  if v_self or (v_pv->>'mostrar_conquistas')::boolean then
    v_card := v_card || jsonb_build_object('achievements', (select count(*) from user_achievements where user_id = p_target));
  end if;

  if v_self or (v_pv->>'mostrar_habitos')::boolean then
    v_card := v_card || jsonb_build_object('areas', (select coalesce(jsonb_agg(distinct h.dimension), '[]'::jsonb)
                                                       from user_habits h where h.user_id = p_target and h.active));
  end if;
  return v_card;
end $$;

create or replace function public._social_unseen(p_uid uuid)
returns int language sql stable security definer set search_path = public as $$
  select count(*)::int from user_events
   where user_id = p_uid and not seen
     and kind in ('pedido_amizade','amizade_aceita','incentivo','desafio_convite','grupo_entrada')
$$;

-- ════════════════════════════════════════════════════════════════════════════
-- 5. Amigos e privacidade
-- ════════════════════════════════════════════════════════════════════════════

create or replace function public.update_privacy(p_privacy jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  k text;
  v jsonb;
  v_clean jsonb := '{}'::jsonb;
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  if p_privacy is null or jsonb_typeof(p_privacy) <> 'object' then raise exception 'privacidade_invalida'; end if;
  for k, v in select * from jsonb_each(p_privacy) loop
    if k not in ('mostrar_nivel','mostrar_sequencia','mostrar_conquistas','mostrar_atributos','mostrar_habitos',
                 'publicar_automatico','aceitar_pedidos','participar_ranking')
       or jsonb_typeof(v) <> 'boolean' then
      raise exception 'privacidade_invalida';
    end if;
    v_clean := v_clean || jsonb_build_object(k, v);
  end loop;
  update profiles set privacy = privacy || v_clean where id = v_uid;
  return _privacy(v_uid);
end $$;

create or replace function public.reset_friend_code()
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); c text;
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  c := _new_friend_code();
  update profiles set friend_code = c where id = v_uid;
  return jsonb_build_object('friend_code', c);
end $$;

-- Mostra quem é o dono de um código antes de enviar o pedido
create or replace function public.lookup_friend_code(p_code text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_target profiles;
  f friendships;
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  select * into v_target from profiles where friend_code = _normalize_code(p_code);
  if not found then raise exception 'codigo_invalido'; end if;
  if v_target.id = v_uid then raise exception 'codigo_proprio'; end if;
  select * into f from friendships
   where least(requester, addressee) = least(v_uid, v_target.id) and greatest(requester, addressee) = greatest(v_uid, v_target.id);
  return jsonb_build_object(
    'name', v_target.display_name, 'avatar', v_target.avatar,
    'status', case when f.id is null or f.status = 'recusada' then 'nenhum'
                   when f.status = 'aceita' then 'amigos'
                   when f.requester = v_uid then 'pedido_enviado'
                   else 'pedido_recebido' end,
    'accepts', (_privacy(v_target.id)->>'aceitar_pedidos')::boolean);
end $$;

create or replace function public.send_friend_request(p_code text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_target profiles;
  f friendships;
  v_id uuid;
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  select * into v_target from profiles where friend_code = _normalize_code(p_code);
  if not found then raise exception 'codigo_invalido'; end if;
  if v_target.id = v_uid then raise exception 'codigo_proprio'; end if;

  select * into f from friendships
   where least(requester, addressee) = least(v_uid, v_target.id) and greatest(requester, addressee) = greatest(v_uid, v_target.id)
   for update;
  if found then
    if f.status = 'aceita' then raise exception 'ja_sao_amigos'; end if;
    if f.status = 'pendente' and f.requester = v_uid then raise exception 'pedido_ja_enviado'; end if;
    if f.status = 'pendente' then
      -- A outra pessoa já tinha pedido: vira amizade na hora
      if _friend_count(v_uid) >= 50 or _friend_count(v_target.id) >= 50 then raise exception 'limite_amigos'; end if;
      update friendships set status = 'aceita', responded_at = now() where id = f.id;
      update user_events set seen = true where user_id = v_uid and kind = 'pedido_amizade' and ref = f.id::text;
      insert into user_events (user_id, kind, ref) values (v_target.id, 'amizade_aceita', f.id::text) on conflict do nothing;
      perform _progress_rewards(v_uid, _local_today(v_uid));
      perform _progress_rewards(v_target.id, _local_today(v_target.id));
      return jsonb_build_object('status', 'aceita', 'name', v_target.display_name, 'avatar', v_target.avatar);
    end if;
    -- Recusado: quem pediu espera 7 dias para tentar de novo
    if f.requester = v_uid and f.responded_at > now() - interval '7 days' then raise exception 'pedido_recusado_recente'; end if;
    delete from friendships where id = f.id;
  end if;

  if not (_privacy(v_target.id)->>'aceitar_pedidos')::boolean then raise exception 'pedidos_desativados'; end if;
  if _friend_count(v_uid) >= 50 or _friend_count(v_target.id) >= 50 then raise exception 'limite_amigos'; end if;
  if (select count(*) from friendships where requester = v_uid and status = 'pendente') >= 20 then raise exception 'limite_pedidos'; end if;

  insert into friendships (requester, addressee) values (v_uid, v_target.id) returning id into v_id;
  insert into user_events (user_id, kind, ref) values (v_target.id, 'pedido_amizade', v_id::text) on conflict do nothing;
  return jsonb_build_object('status', 'pendente', 'name', v_target.display_name, 'avatar', v_target.avatar);
end $$;

create or replace function public.respond_friend_request(p_id uuid, p_accept boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  f friendships;
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  select * into f from friendships where id = p_id and addressee = v_uid and status = 'pendente' for update;
  if not found then raise exception 'pedido_nao_encontrado'; end if;
  update user_events set seen = true where user_id = v_uid and kind = 'pedido_amizade' and ref = f.id::text;

  if coalesce(p_accept, false) then
    if _friend_count(v_uid) >= 50 or _friend_count(f.requester) >= 50 then raise exception 'limite_amigos'; end if;
    update friendships set status = 'aceita', responded_at = now() where id = f.id;
    insert into user_events (user_id, kind, ref) values (f.requester, 'amizade_aceita', f.id::text) on conflict do nothing;
    perform _progress_rewards(v_uid, _local_today(v_uid));
    perform _progress_rewards(f.requester, _local_today(f.requester));
    return jsonb_build_object('status', 'aceita', 'user', _lite(f.requester));
  end if;
  update friendships set status = 'recusada', responded_at = now() where id = f.id;
  return jsonb_build_object('status', 'recusada');
end $$;

-- Desfaz amizade ou cancela um pedido (enviado ou recebido)
create or replace function public.remove_friend(p_user uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_n int;
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  delete from friendships
   where least(requester, addressee) = least(v_uid, p_user) and greatest(requester, addressee) = greatest(v_uid, p_user)
     and status in ('aceita','pendente');
  get diagnostics v_n = row_count;
  return jsonb_build_object('ok', v_n > 0);
end $$;

create or replace function public.get_social()
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_prof profiles;
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  select * into v_prof from profiles where id = v_uid;
  return jsonb_build_object(
    'me', jsonb_build_object('id', v_uid, 'friend_code', v_prof.friend_code, 'privacy', _privacy(v_uid)),
    'friends', (select coalesce(jsonb_agg(_card(v_uid, x.other) || jsonb_build_object('friendship_id', x.id, 'since', x.responded_at)
                                          order by lower(x.name), x.other), '[]'::jsonb)
                  from (select f.id, f.responded_at, o.id as other, o.display_name as name
                          from friendships f
                          join profiles o on o.id = case when f.requester = v_uid then f.addressee else f.requester end
                         where f.status = 'aceita' and v_uid in (f.requester, f.addressee)) x),
    'incoming', (select coalesce(jsonb_agg(jsonb_build_object('id', f.id, 'created_at', f.created_at, 'user', _lite(f.requester))
                                           order by f.created_at desc), '[]'::jsonb)
                   from friendships f where f.addressee = v_uid and f.status = 'pendente'),
    'outgoing', (select coalesce(jsonb_agg(jsonb_build_object('id', f.id, 'created_at', f.created_at, 'user', _lite(f.addressee))
                                           order by f.created_at desc), '[]'::jsonb)
                   from friendships f where f.requester = v_uid and f.status = 'pendente'),
    'limits', jsonb_build_object('friends', 50, 'pending', 20),
    'unseen', _social_unseen(v_uid));
end $$;

-- Perfil de um amigo (ou colega de grupo), com comparação lado a lado
create or replace function public.friend_profile(p_user uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_pv jsonb;
  v_res jsonb;
  v_today date;
  v_j jsonb;
  f friendships;
  st character_stats;
  me character_stats;
  v_season int;
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  if p_user is null or not _can_see(v_uid, p_user) then raise exception 'perfil_indisponivel'; end if;
  v_pv := _privacy(p_user);
  select * into f from friendships
   where least(requester, addressee) = least(v_uid, p_user) and greatest(requester, addressee) = greatest(v_uid, p_user)
     and status = 'aceita';
  select * into st from character_stats where user_id = p_user;
  select * into me from character_stats where user_id = v_uid;

  v_res := jsonb_build_object(
    'card', _card(v_uid, p_user),
    'me', _card(v_uid, v_uid),
    'relation', case when v_uid = p_user then 'eu' when f.id is not null then 'amigo' else 'grupo' end,
    'friendship_id', f.id,
    'since', f.responded_at,
    'groups_in_common', (select coalesce(jsonb_agg(jsonb_build_object('id', g.id, 'name', g.name) order by g.name), '[]'::jsonb)
                           from social_groups g
                          where exists (select 1 from group_members a where a.group_id = g.id and a.user_id = v_uid)
                            and exists (select 1 from group_members b where b.group_id = g.id and b.user_id = p_user)),
    'privacy', jsonb_build_object('nivel', (v_pv->>'mostrar_nivel')::boolean, 'sequencia', (v_pv->>'mostrar_sequencia')::boolean,
                                  'conquistas', (v_pv->>'mostrar_conquistas')::boolean, 'atributos', (v_pv->>'mostrar_atributos')::boolean));

  if v_uid = p_user or (v_pv->>'mostrar_atributos')::boolean then
    v_res := v_res || jsonb_build_object(
      'attributes', jsonb_build_object('disciplina', _attr_level(st.disciplina), 'foco', _attr_level(st.foco),
        'vitalidade', _attr_level(st.vitalidade), 'conhecimento', _attr_level(st.conhecimento), 'determinacao', _attr_level(st.determinacao)),
      'my_attributes', jsonb_build_object('disciplina', _attr_level(me.disciplina), 'foco', _attr_level(me.foco),
        'vitalidade', _attr_level(me.vitalidade), 'conhecimento', _attr_level(me.conhecimento), 'determinacao', _attr_level(me.determinacao)));
  end if;

  if v_uid = p_user or (v_pv->>'mostrar_conquistas')::boolean then
    v_res := v_res || jsonb_build_object(
      'achievements', (select coalesce(jsonb_agg(x), '[]'::jsonb) from (
                         select jsonb_build_object('id', ac.id, 'name', ac.name, 'rarity', ac.rarity, 'category', ac.category,
                                                   'unlocked_at', ua.unlocked_at) as x
                           from user_achievements ua join achievement_catalog ac on ac.id = ua.achievement_id
                          where ua.user_id = p_user and not ac.hidden
                          order by ua.unlocked_at desc, ac.sort desc limit 8) s),
      'bosses', (select count(distinct boss_id) from user_bosses where user_id = p_user and status = 'vencido'),
      'my_bosses', (select count(distinct boss_id) from user_bosses where user_id = v_uid and status = 'vencido'));
  end if;

  if v_uid = p_user or (v_pv->>'mostrar_sequencia')::boolean then
    v_today := _local_today(p_user);
    v_j := _journey(p_user, v_today);
    v_res := v_res || jsonb_build_object(
      'week', (select coalesce(jsonb_agg(jsonb_build_object('date', e->>'date', 'status', e->>'status') order by e->>'date'), '[]'::jsonb)
                 from jsonb_array_elements(v_j->'days') e where (e->>'date')::date > v_today - 7),
      'consistency', v_j->'consistency');
  end if;

  if (v_uid = p_user or (v_pv->>'participar_ranking')::boolean)
     and _feature_allowed(p_user, 'temporadas') and _feature_allowed(v_uid, 'temporadas') then
    v_season := _season_of(_local_today(v_uid));
    v_res := v_res || jsonb_build_object(
      'season', (select jsonb_build_object('points', (sp->>'points')::int, 'league', _league_for((sp->>'points')::int))
                   from (select _season_points(p_user, v_season, _local_today(p_user)) sp) s),
      'my_season', (select jsonb_build_object('points', (sp->>'points')::int, 'league', _league_for((sp->>'points')::int))
                      from (select _season_points(v_uid, v_season, _local_today(v_uid)) sp) s));
  end if;
  return v_res;
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 6. Feed e incentivos
-- ════════════════════════════════════════════════════════════════════════════

-- Retrato do que vai para o feed. Devolve vazio se a pessoa não tem aquilo (ou se não é publicável).
create or replace function public._post_data(p_uid uuid, p_kind text, p_ref text, p_manual boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v jsonb;
begin
  case p_kind
    when 'conquista' then
      select jsonb_build_object('id', ac.id, 'name', ac.name, 'description', ac.description,
                                'rarity', ac.rarity, 'category', ac.category)
        into v
        from achievement_catalog ac join user_achievements ua on ua.achievement_id = ac.id and ua.user_id = p_uid
       where ac.id = p_ref and (p_manual or not ac.hidden);
    when 'chefe' then
      select jsonb_build_object('boss_id', b.id, 'name', b.name, 'epithet', b.epithet, 'difficulty', b.difficulty,
                                'rematch', f.rematch,
                                'days', (f.finished_at at time zone p.timezone)::date - f.started_on + 1)
        into v
        from user_bosses f join boss_catalog b on b.id = f.boss_id join profiles p on p.id = f.user_id
       where f.id::text = p_ref and f.user_id = p_uid and f.status = 'vencido' and (p_manual or not f.rematch);
    when 'nivel' then
      if p_ref ~ '^[0-9]{1,4}$'
         and p_ref::int <= coalesce((select level from character_stats where user_id = p_uid), 1)
         and (p_manual or p_ref::int % 5 = 0) then
        v := jsonb_build_object('level', p_ref::int);
      end if;
    when 'temporada' then
      select jsonb_build_object('season', sr.season, 'name', _season_name(sr.season), 'league', sr.league,
                                'league_name', l.name, 'points', sr.points)
        into v
        from season_results sr join league_catalog l on l.id = sr.league
       where sr.user_id = p_uid and sr.season::text = p_ref and sr.points > 0 and (p_manual or sr.league <> 'bronze');
    else
      v := null;
  end case;
  return v;
end $$;

-- Publica sozinho conquistas, primeiras vitórias, níveis múltiplos de 5 e temporadas (se a pessoa deixar)
create or replace function public._autopost()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_kind text; v_data jsonb;
begin
  v_kind := case new.kind when 'conquista' then 'conquista' when 'chefe_vencido' then 'chefe'
                          when 'nivel' then 'nivel' when 'temporada' then 'temporada' end;
  if v_kind is null then return null; end if;
  if not coalesce((_privacy(new.user_id)->>'publicar_automatico')::boolean, true) then return null; end if;
  v_data := _post_data(new.user_id, v_kind, new.ref, false);
  if v_data is not null then
    insert into feed_posts (author, kind, ref, data) values (new.user_id, v_kind, new.ref, v_data) on conflict do nothing;
  end if;
  return null;
end $$;

drop trigger if exists user_events_autopost on public.user_events;
create trigger user_events_autopost after insert on public.user_events
  for each row execute function public._autopost();

create or replace function public.share_post(p_kind text, p_ref text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_data jsonb; v_id bigint;
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  if p_kind not in ('conquista','chefe','nivel','temporada') then raise exception 'publicacao_invalida'; end if;
  v_data := _post_data(v_uid, p_kind, p_ref, true);
  if v_data is null then raise exception 'publicacao_invalida'; end if;
  insert into feed_posts (author, kind, ref, data) values (v_uid, p_kind, p_ref, v_data)
    on conflict (author, kind, ref) do nothing returning id into v_id;
  if v_id is null then
    select id into v_id from feed_posts where author = v_uid and kind = p_kind and ref = p_ref;
    return jsonb_build_object('id', v_id, 'already', true);
  end if;
  return jsonb_build_object('id', v_id, 'already', false);
end $$;

create or replace function public.delete_post(p_id bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  delete from user_events e using cheers c
   where c.post_id = p_id and e.kind = 'incentivo' and e.ref = c.id::text
     and exists (select 1 from feed_posts fp where fp.id = p_id and fp.author = v_uid);
  delete from feed_posts where id = p_id and author = v_uid;
  return jsonb_build_object('ok', found);
end $$;

create or replace function public.friends_feed(p_before bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  return (
    with authors as (
      select v_uid as id
      union
      select x from _friend_ids(v_uid) x),
    posts as (
      select fp.* from feed_posts fp join authors a on a.id = fp.author
       where p_before is null or fp.id < p_before
       order by fp.id desc limit 30)
    select coalesce(jsonb_agg(jsonb_build_object(
      'id', p.id, 'kind', p.kind, 'ref', p.ref, 'data', p.data, 'created_at', p.created_at,
      'author', _lite(p.author), 'mine', p.author = v_uid,
      'cheers', (select coalesce(jsonb_object_agg(k, c), '{}'::jsonb)
                   from (select ch.kind as k, count(*) as c from cheers ch where ch.post_id = p.id group by ch.kind) s),
      'cheerers', (select coalesce(jsonb_agg(_lite(s.sender)), '[]'::jsonb)
                     from (select ch.sender from cheers ch where ch.post_id = p.id order by ch.id desc limit 5) s),
      'my_cheer', (select ch.kind from cheers ch where ch.post_id = p.id and ch.sender = v_uid)
    ) order by p.id desc), '[]'::jsonb)
    from posts p);
end $$;

-- Reagir a uma publicação (tocar de novo na mesma reação desfaz) ou mandar força direto para um amigo
create or replace function public.send_cheer(p_post bigint, p_user uuid, p_kind text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_tz text;
  v_since timestamptz;
  v_post feed_posts;
  v_old cheers;
  v_id bigint;
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  select timezone into v_tz from profiles where id = v_uid;
  v_since := (_local_today(v_uid)::timestamp at time zone v_tz);

  if p_post is not null then
    if p_kind not in ('parabens','forca','brasa','foco') then raise exception 'incentivo_invalido'; end if;
    select * into v_post from feed_posts where id = p_post;
    if not found then raise exception 'publicacao_nao_encontrada'; end if;
    if v_post.author = v_uid then raise exception 'incentivo_proprio'; end if;
    if not _is_friend(v_uid, v_post.author) then raise exception 'publicacao_nao_encontrada'; end if;

    select * into v_old from cheers where post_id = p_post and sender = v_uid for update;
    if found then
      if v_old.kind = p_kind then
        delete from user_events where user_id = v_post.author and kind = 'incentivo' and ref = v_old.id::text and not seen;
        delete from cheers where id = v_old.id;
        return jsonb_build_object('state', null);
      end if;
      update cheers set kind = p_kind where id = v_old.id;
      return jsonb_build_object('state', p_kind);
    end if;
    if (select count(*) from cheers where sender = v_uid and created_at >= v_since) >= 40 then raise exception 'limite_incentivos'; end if;
    insert into cheers (post_id, sender, receiver, kind) values (p_post, v_uid, v_post.author, p_kind) returning id into v_id;
    insert into user_events (user_id, kind, ref) values (v_post.author, 'incentivo', v_id::text) on conflict do nothing;
  else
    if p_kind not in ('forca','volta','foco') then raise exception 'incentivo_invalido'; end if;
    if p_user is null or not _is_friend(v_uid, p_user) then raise exception 'amigo_nao_encontrado'; end if;
    if exists (select 1 from cheers where sender = v_uid and receiver = p_user and post_id is null and created_at >= v_since) then
      raise exception 'incentivo_ja_enviado_hoje';
    end if;
    if (select count(*) from cheers where sender = v_uid and created_at >= v_since) >= 40 then raise exception 'limite_incentivos'; end if;
    insert into cheers (post_id, sender, receiver, kind) values (null, v_uid, p_user, p_kind) returning id into v_id;
    insert into user_events (user_id, kind, ref) values (p_user, 'incentivo', v_id::text) on conflict do nothing;
  end if;

  perform _progress_rewards(v_uid, _local_today(v_uid));
  return jsonb_build_object('state', p_kind);
end $$;

-- Avisos sociais (pedidos, amizades, incentivos, convites e entradas em grupo): não vão para a tela de recompensa
create or replace function public.get_notifications()
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  return jsonb_build_object(
    'unseen', _social_unseen(v_uid),
    'items', (
      select coalesce(jsonb_agg(x order by (x->>'id')::bigint desc), '[]'::jsonb) from (
        select jsonb_build_object('id', e.id, 'kind', e.kind, 'seen', e.seen, 'created_at', e.created_at,
          'data', case e.kind
            when 'pedido_amizade' then (
              select jsonb_build_object('request_id', f.id, 'status', f.status, 'user', _lite(f.requester))
                from friendships f where f.id::text = e.ref)
            when 'amizade_aceita' then (
              select jsonb_build_object('user', _lite(case when f.requester = v_uid then f.addressee else f.requester end))
                from friendships f where f.id::text = e.ref and f.status = 'aceita')
            when 'incentivo' then (
              select jsonb_build_object('cheer', c.kind, 'user', _lite(c.sender),
                       'post', (select jsonb_build_object('id', fp.id, 'kind', fp.kind, 'data', fp.data)
                                  from feed_posts fp where fp.id = c.post_id))
                from cheers c where c.id::text = e.ref)
            when 'desafio_convite' then (
              select jsonb_build_object('challenge', jsonb_build_object('id', c.id, 'title', c.title, 'kind', c.kind,
                                          'metric', c.metric, 'starts_on', c.starts_on, 'ends_on', c.ends_on, 'status', c.status),
                                        'my_status', cp.status, 'user', _lite(c.creator))
                from challenges c left join challenge_participants cp on cp.challenge_id = c.id and cp.user_id = v_uid
               where c.id::text = e.ref)
            when 'grupo_entrada' then (
              select jsonb_build_object('group', jsonb_build_object('id', g.id, 'name', g.name),
                                        'user', _lite(split_part(e.ref, ':', 2)::uuid))
                from social_groups g where g.id::text = split_part(e.ref, ':', 1))
          end) as x
          from user_events e
         where e.user_id = v_uid
           and e.kind in ('pedido_amizade','amizade_aceita','incentivo','desafio_convite','grupo_entrada')
           and (not e.seen or e.created_at > now() - interval '14 days')
         order by e.id desc limit 50) s
      where x->'data' is not null and x->'data' <> 'null'::jsonb));
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 7. Grupos
-- ════════════════════════════════════════════════════════════════════════════

create or replace function public.create_group(p_name text, p_description text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_id uuid; v_code text;
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  if char_length(trim(coalesce(p_name, ''))) not between 2 and 40 then raise exception 'nome_grupo_invalido'; end if;
  if (select count(*) from social_groups where owner = v_uid) >= 5 then raise exception 'limite_grupos_criados'; end if;
  if (select count(*) from group_members where user_id = v_uid) >= 10 then raise exception 'limite_grupos'; end if;
  v_code := _new_group_code();
  insert into social_groups (name, description, owner, invite_code)
    values (trim(p_name), left(trim(coalesce(p_description, '')), 140), v_uid, v_code)
    returning id into v_id;
  insert into group_members (group_id, user_id, role) values (v_id, v_uid, 'dono');
  return jsonb_build_object('id', v_id, 'invite_code', v_code);
end $$;

create or replace function public.join_group(p_code text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); g social_groups;
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  select * into g from social_groups where invite_code = _normalize_code(p_code) for update;
  if not found then raise exception 'grupo_nao_encontrado'; end if;
  if exists (select 1 from group_members where group_id = g.id and user_id = v_uid) then
    return jsonb_build_object('id', g.id, 'name', g.name, 'already', true);
  end if;
  if (select count(*) from group_members where group_id = g.id) >= 30 then raise exception 'grupo_cheio'; end if;
  if (select count(*) from group_members where user_id = v_uid) >= 10 then raise exception 'limite_grupos'; end if;
  insert into group_members (group_id, user_id) values (g.id, v_uid);
  insert into user_events (user_id, kind, ref) values (g.owner, 'grupo_entrada', g.id || ':' || v_uid) on conflict do nothing;
  return jsonb_build_object('id', g.id, 'name', g.name, 'already', false);
end $$;

-- Sair do grupo. Se o dono sai, o membro mais antigo assume; grupo vazio é apagado.
create or replace function public.leave_group(p_group uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_role text; v_next uuid;
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  perform 1 from social_groups where id = p_group for update;
  delete from group_members where group_id = p_group and user_id = v_uid returning role into v_role;
  if v_role is null then raise exception 'grupo_nao_encontrado'; end if;
  if v_role = 'dono' then
    select user_id into v_next from group_members where group_id = p_group order by joined_at, user_id limit 1;
    if v_next is null then
      delete from social_groups where id = p_group;
    else
      update group_members set role = 'dono' where group_id = p_group and user_id = v_next;
      update social_groups set owner = v_next where id = p_group;
    end if;
  end if;
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.remove_group_member(p_group uuid, p_user uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  if not exists (select 1 from social_groups where id = p_group and owner = v_uid) then raise exception 'so_o_dono'; end if;
  if p_user = v_uid then raise exception 'so_o_dono'; end if;
  delete from group_members where group_id = p_group and user_id = p_user;
  return jsonb_build_object('ok', found);
end $$;

create or replace function public.update_group(p_group uuid, p_name text, p_description text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  if not exists (select 1 from social_groups where id = p_group and owner = v_uid) then raise exception 'so_o_dono'; end if;
  if char_length(trim(coalesce(p_name, ''))) not between 2 and 40 then raise exception 'nome_grupo_invalido'; end if;
  update social_groups set name = trim(p_name), description = left(trim(coalesce(p_description, '')), 140) where id = p_group;
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.reset_group_code(p_group uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_code text;
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  if not exists (select 1 from social_groups where id = p_group and owner = v_uid) then raise exception 'so_o_dono'; end if;
  v_code := _new_group_code();
  update social_groups set invite_code = v_code where id = p_group;
  return jsonb_build_object('invite_code', v_code);
end $$;

create or replace function public.get_groups()
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  return (select coalesce(jsonb_agg(jsonb_build_object(
            'id', g.id, 'name', g.name, 'description', g.description, 'invite_code', g.invite_code,
            'role', m.role, 'owner', _lite(g.owner),
            'members', (select count(*) from group_members x where x.group_id = g.id),
            'preview', (select coalesce(jsonb_agg(_lite(y.user_id)), '[]'::jsonb)
                          from (select user_id from group_members x where x.group_id = g.id order by x.joined_at limit 5) y)
          ) order by lower(g.name)), '[]'::jsonb)
            from social_groups g join group_members m on m.group_id = g.id and m.user_id = v_uid);
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 8. Temporadas (um mês cada) e ligas
-- ════════════════════════════════════════════════════════════════════════════

create or replace function public._season_of(p_day date)
returns int language sql immutable as $$
  select (extract(year from p_day)::int * 100 + extract(month from p_day)::int)
$$;

create or replace function public._season_start(p_season int)
returns date language sql immutable as $$
  select make_date(p_season / 100, p_season % 100, 1)
$$;

create or replace function public._season_end(p_season int)
returns date language sql immutable as $$
  select (make_date(p_season / 100, p_season % 100, 1) + interval '1 month' - interval '1 day')::date
$$;

create or replace function public._season_next(p_season int)
returns int language sql immutable as $$
  select case when p_season % 100 = 12 then (p_season / 100 + 1) * 100 + 1 else p_season + 1 end
$$;

create or replace function public._season_name(p_season int)
returns text language sql immutable as $$
  select 'Temporada de ' || (array['janeiro','fevereiro','março','abril','maio','junho','julho','agosto',
                                   'setembro','outubro','novembro','dezembro'])[p_season % 100]
$$;

create or replace function public._league_for(p_points int)
returns jsonb language sql stable security definer set search_path = public as $$
  select to_jsonb(l) from league_catalog l where l.min_points <= greatest(coalesce(p_points, 0), 0)
   order by l.min_points desc limit 1
$$;

-- Missões do plano concluídas por dia (avulsas não contam para temporada e desafios)
create or replace function public._plan_done(p_uid uuid, p_from date, p_to date)
returns table(day date, cnt int) language sql stable security definer set search_path = public as $$
  select (m.completed_at at time zone p.timezone)::date, count(*)::int
    from missions m join profiles p on p.id = m.user_id
   where m.user_id = p_uid and m.status = 'concluida' and m.kind <> 'personalizada'
     and m.completed_at >= (p_from::timestamp at time zone p.timezone)
     and m.completed_at <  ((p_to + 1)::timestamp at time zone p.timezone)
   group by 1
$$;

-- Pontos de uma temporada, sempre recalculados das missões (anti-fraude: limite por dia, avulsas não contam)
--   por dia: meta cumprida +10 · missões do plano ×2 (até 5) · dia perfeito +5   → no máximo 25 por dia
--   chefe vencido +15 (revanche +5) · desafio vencido ou meta coletiva +10 (até 4)
--   objetivos: 15 dias com a meta +30 · 3 dias perfeitos +20 · vencer um chefe +20
create or replace function public._season_points(p_uid uuid, p_season int, p_until date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_prof profiles;
  v_start date := _season_start(p_season);
  v_end date := _season_end(p_season);
  v_from date;
  v_to date;
  r record;
  v_goal_days int := 0;
  v_perfect_days int := 0;
  v_plan_pts int := 0;
  v_first int := 0;
  v_rematch int := 0;
  v_chal int := 0;
  v_obj jsonb;
  v_obj_pts int;
  v_total int;
begin
  select * into v_prof from profiles where id = p_uid;
  v_from := greatest(v_start, coalesce(v_prof.program_start, v_end + 1));
  v_to := least(v_end, p_until);

  if v_to >= v_from then
    for r in
      select s.goal_met, s.daily_total, s.daily_done, coalesce(pd.cnt, 0) as plan_cnt
        from _day_stats(p_uid, v_from, v_to) s
        left join _plan_done(p_uid, v_from, v_to) pd on pd.day = s.day
    loop
      if r.goal_met then v_goal_days := v_goal_days + 1; end if;
      v_plan_pts := v_plan_pts + least(r.plan_cnt, 5) * 2;
      if r.daily_total > 0 and r.daily_done = r.daily_total then v_perfect_days := v_perfect_days + 1; end if;
    end loop;

    select count(*) filter (where not b.rematch), count(*) filter (where b.rematch)
      into v_first, v_rematch
      from user_bosses b
     where b.user_id = p_uid and b.status = 'vencido'
       and (b.finished_at at time zone v_prof.timezone)::date between v_from and v_to;

    select count(*) into v_chal
      from challenge_participants cp join challenges c on c.id = cp.challenge_id
     where cp.user_id = p_uid and cp.result in ('venceu','meta_coletiva') and c.ends_on between v_from and v_to;
  end if;

  v_obj := jsonb_build_array(
    jsonb_build_object('id', 'meta15', 'name', 'Cumpra a meta do dia em 15 dias', 'progress', least(v_goal_days, 15),
                       'target', 15, 'points', 30, 'done', v_goal_days >= 15),
    jsonb_build_object('id', 'perfeito3', 'name', 'Tenha 3 dias perfeitos (todas as missões diárias)', 'progress', least(v_perfect_days, 3),
                       'target', 3, 'points', 20, 'done', v_perfect_days >= 3),
    jsonb_build_object('id', 'chefe1', 'name', 'Vença um chefe', 'progress', least(v_first + v_rematch, 1),
                       'target', 1, 'points', 20, 'done', v_first + v_rematch >= 1));
  select coalesce(sum((o->>'points')::int) filter (where (o->>'done')::boolean), 0) into v_obj_pts from jsonb_array_elements(v_obj) o;

  v_total := v_goal_days * 10 + v_plan_pts + v_perfect_days * 5 + v_first * 15 + v_rematch * 5 + least(v_chal, 4) * 10 + v_obj_pts;
  return jsonb_build_object(
    'season', p_season, 'points', v_total,
    'goal_days', v_goal_days, 'perfect_days', v_perfect_days, 'boss_wins', v_first + v_rematch, 'challenges', v_chal,
    'breakdown', jsonb_build_object('meta', v_goal_days * 10, 'missoes', v_plan_pts, 'perfeitos', v_perfect_days * 5,
                                    'chefes', v_first * 15 + v_rematch * 5, 'desafios', least(v_chal, 4) * 10, 'objetivos', v_obj_pts),
    'objectives', v_obj);
end $$;

-- Fecha as temporadas que já acabaram (no primeiro acesso do mês seguinte): liga, XP, aviso e publicação
create or replace function public._finalize_seasons(p_uid uuid, p_today date)
returns int language plpgsql security definer set search_path = public as $$
declare
  v_prof profiles;
  v_since date;
  v_s int;
  v_cur int := _season_of(p_today);
  v_sp jsonb;
  v_pts int;
  v_lg league_catalog;
  v_xp int;
  v_rank int;
  v_of int;
  v_f uuid;
  v_n int := 0;
begin
  select * into v_prof from profiles where id = p_uid;
  if v_prof.program_start is null then return 0; end if;
  select seasons_since into v_since from app_config where id;
  v_s := _season_of(greatest(coalesce(v_since, p_today), v_prof.program_start));

  while v_s < v_cur loop
    if not exists (select 1 from season_results where user_id = p_uid and season = v_s) then
      v_sp := _season_points(p_uid, v_s, p_today);
      v_pts := (v_sp->>'points')::int;
      select * into v_lg from league_catalog where min_points <= v_pts order by min_points desc limit 1;
      v_xp := case when v_pts > 0 and _feature_allowed(p_uid, 'temporadas') then v_lg.xp_reward else 0 end;

      -- Posição entre os amigos que participam do ranking
      v_rank := 1; v_of := 1;
      if v_pts > 0 then
        for v_f in select x from _friend_ids(p_uid) x loop
          continue when not (_privacy(v_f)->>'participar_ranking')::boolean or not _feature_allowed(v_f, 'temporadas');
          v_of := v_of + 1;
          if (_season_points(v_f, v_s, _local_today(v_f))->>'points')::int > v_pts then v_rank := v_rank + 1; end if;
        end loop;
      end if;

      insert into season_results (user_id, season, points, league, xp, data)
      values (p_uid, v_s, v_pts, v_lg.id, v_xp, v_sp || jsonb_build_object('rank', v_rank, 'of', v_of))
      on conflict do nothing;
      if found then
        if v_xp > 0 then
          insert into xp_ledger (user_id, source, ref, day, amount, disciplina, determinacao)
          values (p_uid, 'temporada', v_s::text, p_today, v_xp, v_xp / 2, v_xp - v_xp / 2)
          on conflict do nothing;
        end if;
        if v_pts > 0 then
          insert into user_events (user_id, kind, ref) values (p_uid, 'temporada', v_s::text) on conflict do nothing;
        end if;
        v_n := v_n + 1;
      end if;
    end if;
    v_s := _season_next(v_s);
  end loop;
  return v_n;
end $$;

create or replace function public.get_season()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_today date;
  v_s int;
  v_sp jsonb;
  v_lg jsonb;
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  perform _require_feature(v_uid, 'temporadas');
  v_today := _local_today(v_uid);
  v_s := _season_of(v_today);
  v_sp := _season_points(v_uid, v_s, v_today);
  v_lg := _league_for((v_sp->>'points')::int);
  return jsonb_build_object(
    'id', v_s, 'name', _season_name(v_s), 'year', v_s / 100,
    'starts_on', _season_start(v_s), 'ends_on', _season_end(v_s), 'days_left', _season_end(v_s) - v_today + 1,
    'points', (v_sp->>'points')::int,
    'league', v_lg,
    'next', (select to_jsonb(l) from league_catalog l where l.min_points > (v_sp->>'points')::int order by l.min_points limit 1),
    'goal_days', v_sp->'goal_days', 'perfect_days', v_sp->'perfect_days', 'boss_wins', v_sp->'boss_wins', 'challenges', v_sp->'challenges',
    'breakdown', v_sp->'breakdown',
    'objectives', v_sp->'objectives',
    'leagues', (select jsonb_agg(to_jsonb(l) order by l.sort) from league_catalog l),
    'history', (select coalesce(jsonb_agg(jsonb_build_object('season', sr.season, 'name', _season_name(sr.season), 'year', sr.season / 100,
                                                             'points', sr.points, 'league', sr.league, 'xp', sr.xp,
                                                             'rank', sr.data->'rank', 'of', sr.data->'of')
                                          order by sr.season desc), '[]'::jsonb)
                  from season_results sr where sr.user_id = v_uid and sr.points > 0));
end $$;

-- Ranking da temporada atual entre amigos ou num grupo
create or replace function public.get_ranking(p_scope text, p_group uuid, p_category text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_today date;
  v_s int;
  v_members uuid[];
  v_m uuid;
  v_pv jsonb;
  v_sp jsonb;
  v_val int;
  v_rows jsonb := '[]'::jsonb;
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  perform _require_feature(v_uid, 'temporadas');
  if p_category not in ('pontos','constancia','xp','chefes') then raise exception 'ranking_invalido'; end if;
  v_today := _local_today(v_uid);
  v_s := _season_of(v_today);

  if p_scope = 'amigos' then
    select array_agg(x) into v_members from (select v_uid as x union select y from _friend_ids(v_uid) y) s;
  elsif p_scope = 'grupo' then
    if not exists (select 1 from group_members where group_id = p_group and user_id = v_uid) then raise exception 'grupo_nao_encontrado'; end if;
    select array_agg(user_id) into v_members from group_members where group_id = p_group;
  else
    raise exception 'ranking_invalido';
  end if;

  foreach v_m in array v_members loop
    v_pv := _privacy(v_m);
    continue when v_m <> v_uid and (not (v_pv->>'participar_ranking')::boolean or not _feature_allowed(v_m, 'temporadas'));
    v_sp := _season_points(v_m, v_s, _local_today(v_m));
    v_val := case p_category
      when 'pontos' then (v_sp->>'points')::int
      when 'constancia' then (v_sp->>'goal_days')::int
      when 'chefes' then (v_sp->>'boss_wins')::int
      else (select coalesce(sum(l.amount), 0)::int from xp_ledger l
             where l.user_id = v_m and l.day between _season_start(v_s) and _season_end(v_s)) end;
    v_rows := v_rows || jsonb_build_object(
      'user', _lite(v_m), 'value', v_val, 'points', (v_sp->>'points')::int,
      'league', _league_for((v_sp->>'points')::int)->>'id',
      'me', v_m = v_uid,
      'hidden', v_m = v_uid and not (v_pv->>'participar_ranking')::boolean,
      'level', case when v_m = v_uid or (v_pv->>'mostrar_nivel')::boolean
                    then (select level from character_stats where user_id = v_m) end);
  end loop;

  return jsonb_build_object(
    'scope', p_scope, 'category', p_category,
    'season', jsonb_build_object('id', v_s, 'name', _season_name(v_s), 'days_left', _season_end(v_s) - v_today + 1),
    'rows', (select coalesce(jsonb_agg(e || jsonb_build_object('rank', rk) order by rk, lower(e->'user'->>'name')), '[]'::jsonb)
               from (select e, rank() over (order by (e->>'value')::int desc) as rk
                       from jsonb_array_elements(v_rows) e) s));
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 9. Desafios entre amigos
-- ════════════════════════════════════════════════════════════════════════════

-- Placar de uma pessoa num desafio, recalculado das missões dela (no fuso e nas regras dela)
create or replace function public._challenge_score(p_uid uuid, p_ch challenges, p_until date)
returns int language plpgsql security definer set search_path = public as $$
declare v_to date := least(p_ch.ends_on, p_until); v_score int;
begin
  if v_to < p_ch.starts_on then return 0; end if;
  if p_ch.metric = 'meta_diaria' then
    select count(*) into v_score from _day_stats(p_uid, p_ch.starts_on, v_to) s where s.goal_met;
  elsif p_ch.metric = 'area' then
    select count(*) into v_score from _day_stats(p_uid, p_ch.starts_on, v_to) s where p_ch.dimension = any(s.dims);
  else
    select coalesce(sum(least(pd.cnt, 12)), 0) into v_score from _plan_done(p_uid, p_ch.starts_on, v_to) pd;
  end if;
  return v_score;
end $$;

create or replace function public.create_challenge(p_data jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_prof profiles;
  v_today date;
  v_kind text := p_data->>'kind';
  v_metric text := p_data->>'metric';
  v_dim text := nullif(p_data->>'dimension', '');
  v_days int;
  v_start date;
  v_title text := trim(coalesce(p_data->>'title', ''));
  v_group uuid := nullif(p_data->>'group_id', '')::uuid;
  v_target int;
  v_people uuid[];
  v_cap int;
  v_id uuid;
  v_p uuid;
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  select * into v_prof from profiles where id = v_uid;
  if not v_prof.onboarding_done then raise exception 'conclua_a_avaliacao'; end if;
  if p_data is null or jsonb_typeof(p_data) <> 'object' then raise exception 'desafio_invalido'; end if;
  if v_kind is null or v_kind not in ('competitivo','coletivo') then raise exception 'desafio_invalido'; end if;
  if v_metric is null or v_metric not in ('meta_diaria','missoes','area') then raise exception 'desafio_invalido'; end if;
  if v_metric = 'area' then
    if v_dim is null or v_dim not in ('fisica','mental','intelectual','produtividade','digital','autocuidado') then raise exception 'dimensao_invalida'; end if;
  else
    v_dim := null;
  end if;
  if not _int_in(p_data->'days', 3, 30) then raise exception 'duracao_desafio_invalida'; end if;
  v_days := (p_data->>'days')::int;
  v_today := _local_today(v_uid);
  v_start := case when coalesce((p_data->>'start_tomorrow')::boolean, false) then v_today + 1 else v_today end;
  if v_title = '' then v_title := 'Desafio de ' || v_days || ' dias'; end if;
  if char_length(v_title) not between 2 and 50 then raise exception 'nome_invalido'; end if;

  -- Quem participa: um grupo inteiro ou amigos escolhidos
  if v_group is not null then
    if not exists (select 1 from group_members where group_id = v_group and user_id = v_uid) then raise exception 'grupo_nao_encontrado'; end if;
    select array_agg(user_id order by joined_at) into v_people from group_members where group_id = v_group;
  else
    if jsonb_typeof(coalesce(p_data->'friends', '[]'::jsonb)) <> 'array' then raise exception 'desafio_invalido'; end if;
    select array_agg(distinct x::uuid) into v_people from jsonb_array_elements_text(coalesce(p_data->'friends', '[]'::jsonb)) x;
    v_people := array_remove(coalesce(v_people, '{}'), v_uid);
    foreach v_p in array v_people loop
      if not _is_friend(v_uid, v_p) then raise exception 'amigo_nao_encontrado'; end if;
    end loop;
    v_people := v_uid || v_people;
  end if;
  if coalesce(array_length(v_people, 1), 0) < 2 then raise exception 'desafio_sem_participantes'; end if;
  if array_length(v_people, 1) > 30 then raise exception 'desafio_muitos_participantes'; end if;

  if v_kind = 'coletivo' then
    v_cap := case when v_metric = 'missoes' then 12 else 1 end;
    if not _int_in(p_data->'target', 1, v_days * array_length(v_people, 1) * v_cap) then raise exception 'meta_coletiva_invalida'; end if;
    v_target := (p_data->>'target')::int;
  end if;

  if (select count(*) from challenges where creator = v_uid and status = 'ativo') >= 3 then raise exception 'limite_desafios_criados'; end if;
  if (select count(*) from challenge_participants cp join challenges c on c.id = cp.challenge_id
       where cp.user_id = v_uid and cp.status = 'aceito' and c.status = 'ativo') >= 5 then raise exception 'limite_desafios'; end if;

  insert into challenges (creator, group_id, kind, metric, dimension, title, target, starts_on, ends_on)
  values (v_uid, v_group, v_kind, v_metric, v_dim, v_title, v_target, v_start, v_start + v_days - 1)
  returning id into v_id;

  insert into challenge_participants (challenge_id, user_id, status, responded_at) values (v_id, v_uid, 'aceito', now());
  foreach v_p in array v_people loop
    continue when v_p = v_uid;
    insert into challenge_participants (challenge_id, user_id) values (v_id, v_p) on conflict do nothing;
    insert into user_events (user_id, kind, ref) values (v_p, 'desafio_convite', v_id::text) on conflict do nothing;
  end loop;
  return jsonb_build_object('id', v_id);
end $$;

create or replace function public.respond_challenge(p_id uuid, p_accept boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  c challenges;
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  select * into c from challenges where id = p_id;
  if not found or not exists (select 1 from challenge_participants where challenge_id = p_id and user_id = v_uid and status = 'convidado') then
    raise exception 'convite_nao_encontrado';
  end if;
  update user_events set seen = true where user_id = v_uid and kind = 'desafio_convite' and ref = p_id::text;
  if c.status <> 'ativo' or _local_today(v_uid) > c.ends_on then raise exception 'desafio_encerrado'; end if;

  if coalesce(p_accept, false) then
    if (select count(*) from challenge_participants cp join challenges x on x.id = cp.challenge_id
         where cp.user_id = v_uid and cp.status = 'aceito' and x.status = 'ativo') >= 5 then raise exception 'limite_desafios'; end if;
    update challenge_participants set status = 'aceito', responded_at = now() where challenge_id = p_id and user_id = v_uid;
    return jsonb_build_object('status', 'aceito');
  end if;
  update challenge_participants set status = 'recusado', responded_at = now() where challenge_id = p_id and user_id = v_uid;
  return jsonb_build_object('status', 'recusado');
end $$;

create or replace function public.leave_challenge(p_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  update challenge_participants cp set status = 'saiu', responded_at = now()
    from challenges c
   where c.id = cp.challenge_id and cp.challenge_id = p_id and cp.user_id = v_uid and cp.status = 'aceito' and c.status = 'ativo';
  if not found then raise exception 'desafio_nao_encontrado'; end if;
  -- Ninguém mais aceitou: o desafio é cancelado
  if not exists (select 1 from challenge_participants where challenge_id = p_id and status = 'aceito') then
    update challenges set status = 'cancelado', finished_at = now() where id = p_id;
  end if;
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.cancel_challenge(p_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  update challenges set status = 'cancelado', finished_at = now() where id = p_id and creator = v_uid and status = 'ativo';
  if not found then raise exception 'desafio_nao_encontrado'; end if;
  update user_events set seen = true where kind = 'desafio_convite' and ref = p_id::text;
  return jsonb_build_object('ok', true);
end $$;

-- Encerra um desafio: placar final, posições, XP (no máximo 2 recompensas de desafio por semana) e avisos
create or replace function public._finalize_challenge(p_id uuid, p_now timestamptz)
returns void language plpgsql security definer set search_path = public as $$
declare
  c challenges;
  r record;
  v_n int;
  v_total int;
  v_xp int;
  v_day date;
begin
  select * into c from challenges where id = p_id for update;
  if not found or c.status <> 'ativo' then return; end if;

  for r in select user_id from challenge_participants where challenge_id = c.id and status = 'aceito' loop
    update challenge_participants set score = _challenge_score(r.user_id, c, c.ends_on)
     where challenge_id = c.id and user_id = r.user_id;
  end loop;
  select count(*), coalesce(sum(score), 0) into v_n, v_total
    from challenge_participants where challenge_id = c.id and status = 'aceito';

  update challenge_participants cp set rank = x.rk
    from (select user_id, rank() over (order by score desc) as rk
            from challenge_participants where challenge_id = c.id and status = 'aceito') x
   where cp.challenge_id = c.id and cp.user_id = x.user_id;

  if c.kind = 'competitivo' then
    update challenge_participants set result = case when rank = 1 and score > 0 and v_n >= 2 then 'venceu' else 'participou' end
     where challenge_id = c.id and status = 'aceito';
  else
    update challenge_participants set result = case when v_total >= c.target and score > 0 then 'meta_coletiva' else 'participou' end
     where challenge_id = c.id and status = 'aceito';
  end if;

  for r in select user_id from challenge_participants
            where challenge_id = c.id and status = 'aceito' and result in ('venceu','meta_coletiva') loop
    v_day := _local_today(r.user_id);
    v_xp := case when c.kind = 'competitivo' then 40 else 30 end;
    if (select count(*) from xp_ledger where user_id = r.user_id and source = 'desafio' and day > v_day - 7) >= 2 then
      v_xp := 0;
    end if;
    if v_xp > 0 then
      insert into xp_ledger (user_id, source, ref, day, amount, disciplina, determinacao)
      values (r.user_id, 'desafio', c.id::text, v_day, v_xp, v_xp / 2, v_xp - v_xp / 2)
      on conflict do nothing;
      update challenge_participants set xp = v_xp where challenge_id = c.id and user_id = r.user_id;
      perform _recalc_stats(r.user_id);
    end if;
  end loop;

  update challenges set status = 'encerrado', finished_at = p_now where id = c.id;
  insert into user_events (user_id, kind, ref)
    select user_id, 'desafio_fim', c.id::text from challenge_participants where challenge_id = c.id and status = 'aceito'
  on conflict do nothing;
end $$;

create or replace function public._finalize_challenges(p_uid uuid, p_today date, p_now timestamptz)
returns int language plpgsql security definer set search_path = public as $$
declare r record; v_n int := 0;
begin
  for r in select c.id from challenges c
            where c.status = 'ativo' and c.ends_on < p_today
              and (c.creator = p_uid or exists (select 1 from challenge_participants cp
                                                 where cp.challenge_id = c.id and cp.user_id = p_uid))
            order by c.ends_on loop
    perform _finalize_challenge(r.id, p_now);
    v_n := v_n + 1;
  end loop;
  return v_n;
end $$;

create or replace function public._challenge_view(p_id uuid, p_viewer uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  c challenges;
  v_today date := _local_today(p_viewer);
  v_people jsonb;
  v_me challenge_participants;
begin
  select * into c from challenges where id = p_id;
  if not found then return null; end if;
  select * into v_me from challenge_participants where challenge_id = p_id and user_id = p_viewer;

  select coalesce(jsonb_agg(x order by (x->>'score')::int desc, lower(x->'user'->>'name')), '[]'::jsonb) into v_people
    from (select jsonb_build_object(
                   'user', _lite(cp.user_id), 'status', cp.status, 'me', cp.user_id = p_viewer,
                   'score', case when c.status = 'ativo' and cp.status = 'aceito'
                                 then _challenge_score(cp.user_id, c, _local_today(cp.user_id)) else cp.score end,
                   'rank', cp.rank, 'result', cp.result, 'xp', cp.xp) as x
            from challenge_participants cp
           where cp.challenge_id = p_id and cp.status in ('aceito','convidado')) s;

  return jsonb_build_object(
    'id', c.id, 'title', c.title, 'kind', c.kind, 'metric', c.metric, 'dimension', c.dimension, 'target', c.target,
    'starts_on', c.starts_on, 'ends_on', c.ends_on, 'status', c.status,
    'phase', case when c.status <> 'ativo' then c.status
                  when v_today < c.starts_on then 'agendado'
                  when v_today > c.ends_on then 'encerrando'
                  else 'em_andamento' end,
    'days', c.ends_on - c.starts_on + 1,
    'day_index', least(greatest(v_today - c.starts_on + 1, 0), c.ends_on - c.starts_on + 1),
    'creator', _lite(c.creator), 'is_creator', c.creator = p_viewer,
    'group', (select jsonb_build_object('id', g.id, 'name', g.name) from social_groups g where g.id = c.group_id),
    'my_status', v_me.status, 'my_result', v_me.result, 'my_xp', v_me.xp,
    'participants', v_people,
    'total', (select coalesce(sum((p->>'score')::int), 0) from jsonb_array_elements(v_people) p where p->>'status' = 'aceito'));
end $$;

create or replace function public.get_challenges()
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_today date;
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  v_today := _local_today(v_uid);
  perform _finalize_challenges(v_uid, v_today, now());
  return (select coalesce(jsonb_agg(_challenge_view(x.id, v_uid) order by x.active desc, x.ends_on desc), '[]'::jsonb)
            from (select c.id, c.ends_on, c.status = 'ativo' as active
                    from challenges c join challenge_participants cp on cp.challenge_id = c.id and cp.user_id = v_uid
                   where cp.status in ('aceito','convidado','saiu')
                     and (c.status = 'ativo' or c.finished_at > now() - interval '60 days')
                   order by c.status = 'ativo' desc, c.ends_on desc limit 30) x);
end $$;

create or replace function public.challenge_detail(p_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  if not exists (select 1 from challenge_participants where challenge_id = p_id and user_id = v_uid) then
    raise exception 'desafio_nao_encontrado';
  end if;
  perform _finalize_challenges(v_uid, _local_today(v_uid), now());
  return _challenge_view(p_id, v_uid);
end $$;

create or replace function public.group_detail(p_group uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); g social_groups; v_role text;
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  select role into v_role from group_members where group_id = p_group and user_id = v_uid;
  if v_role is null then raise exception 'grupo_nao_encontrado'; end if;
  select * into g from social_groups where id = p_group;
  perform _finalize_challenges(v_uid, _local_today(v_uid), now());
  return jsonb_build_object(
    'id', g.id, 'name', g.name, 'description', g.description, 'invite_code', g.invite_code,
    'role', v_role, 'owner', _lite(g.owner), 'created_at', g.created_at,
    'members', (select coalesce(jsonb_agg(_card(v_uid, m.user_id) || jsonb_build_object('role', m.role, 'joined_at', m.joined_at,
                                                                                          'friend', _is_friend(v_uid, m.user_id))
                                          order by m.role = 'dono' desc, m.joined_at), '[]'::jsonb)
                  from group_members m where m.group_id = p_group),
    'challenges', (select coalesce(jsonb_agg(_challenge_view(c.id, v_uid) order by c.status = 'ativo' desc, c.ends_on desc), '[]'::jsonb)
                     from (select * from challenges c where c.group_id = p_group
                             and (c.status = 'ativo' or c.finished_at > now() - interval '30 days')
                           order by c.status = 'ativo' desc, c.ends_on desc limit 10) c));
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 10. Ferramentas: foco, água, sono, alimentação, leitura, meditação, tempo de tela, diário e hábitos
-- ════════════════════════════════════════════════════════════════════════════
-- As ferramentas registram; quem conclui a missão é a pessoa (o app mostra "pronta para concluir").

create or replace function public._tool_settings(p_uid uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select '{"agua_meta":8,"agua_ml":250,"sono_meta":480,"sono_deitar":"23:00","tela_limite":120,"foco_min":25,"pausa_min":5}'::jsonb
         || coalesce((select tool_settings from profiles where id = p_uid), '{}'::jsonb)
$$;

create or replace function public.update_tool_settings(p_settings jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  k text;
  v jsonb;
  v_clean jsonb := '{}'::jsonb;
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  if p_settings is null or jsonb_typeof(p_settings) <> 'object' then raise exception 'ajuste_invalido'; end if;
  for k, v in select * from jsonb_each(p_settings) loop
    if not (case k
              when 'agua_meta'   then _int_in(v, 1, 20)
              when 'agua_ml'     then _int_in(v, 100, 1000)
              when 'sono_meta'   then _int_in(v, 240, 720)
              when 'tela_limite' then _int_in(v, 15, 1440)
              when 'foco_min'    then _int_in(v, 5, 120)
              when 'pausa_min'   then _int_in(v, 1, 30)
              when 'sono_deitar' then jsonb_typeof(v) = 'string' and (v #>> '{}') ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
              else false end) then
      raise exception 'ajuste_invalido';
    end if;
    v_clean := v_clean || jsonb_build_object(k, v);
  end loop;
  update profiles set tool_settings = tool_settings || v_clean where id = v_uid;
  return _tool_settings(v_uid);
end $$;

-- Meta de água do dia: a do hábito de água, se houver; senão a escolhida na ferramenta
create or replace function public._water_goal(p_uid uuid, p_day date)
returns int language sql stable security definer set search_path = public as $$
  select coalesce(
    (select m.target_value from missions m
      where m.user_id = p_uid and m.unit = 'copos' and m.kind = 'diaria' and m.mission_date = p_day
      order by m.created_at limit 1),
    (_tool_settings(p_uid)->>'agua_meta')::int)
$$;

create or replace function public._tool_summary(p_uid uuid, p_tool text, p_day date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_set jsonb := _tool_settings(p_uid);
  v jsonb;
  l tool_logs;
begin
  if p_tool = 'foco' then
    select jsonb_build_object('minutes', coalesce(sum((tl.data->>'minutes')::int), 0), 'sessions', count(*))
      into v from tool_logs tl where tl.user_id = p_uid and tl.tool = 'foco' and tl.day = p_day;
  elsif p_tool = 'agua' then
    select jsonb_build_object('cups', coalesce(sum((tl.data->>'cups')::int), 0), 'goal', _water_goal(p_uid, p_day),
                              'cup_ml', (v_set->>'agua_ml')::int)
      into v from tool_logs tl where tl.user_id = p_uid and tl.tool = 'agua' and tl.day = p_day;
  elsif p_tool = 'sono' then
    select * into l from tool_logs tl where tl.user_id = p_uid and tl.tool = 'sono' and tl.day = p_day order by tl.id desc limit 1;
    v := jsonb_build_object('logged', l.id is not null, 'minutes', (l.data->>'minutes')::int, 'bed', l.data->>'bed',
                            'wake', l.data->>'wake', 'quality', (l.data->>'quality')::int,
                            'goal', (v_set->>'sono_meta')::int, 'bedtime', v_set->>'sono_deitar');
  elsif p_tool = 'alimentacao' then
    select jsonb_build_object('kcal', coalesce(sum((tl.data->>'kcal')::int), 0), 'meals', count(*),
                              'with_kcal', count(*) filter (where tl.data ? 'kcal'))
      into v from tool_logs tl where tl.user_id = p_uid and tl.tool = 'alimentacao' and tl.day = p_day;
  elsif p_tool = 'leitura' then
    select jsonb_build_object('pages', coalesce(sum((tl.data->>'pages')::int), 0), 'minutes', coalesce(sum((tl.data->>'minutes')::int), 0))
      into v from tool_logs tl where tl.user_id = p_uid and tl.tool = 'leitura' and tl.day = p_day;
    v := v || jsonb_build_object('book', (select jsonb_build_object('id', b.id, 'title', b.title, 'current_page', b.current_page,
                                                                    'total_pages', b.total_pages)
                                            from books b where b.user_id = p_uid and b.status = 'lendo'
                                           order by b.created_at desc limit 1));
  elsif p_tool = 'meditacao' then
    select jsonb_build_object('minutes', coalesce(sum((tl.data->>'minutes')::int), 0), 'sessions', count(*))
      into v from tool_logs tl where tl.user_id = p_uid and tl.tool = 'meditacao' and tl.day = p_day;
  elsif p_tool = 'tela' then
    select * into l from tool_logs tl where tl.user_id = p_uid and tl.tool = 'tela' and tl.day = p_day order by tl.id desc limit 1;
    v := jsonb_build_object('logged', l.id is not null, 'minutes', (l.data->>'minutes')::int, 'limit', (v_set->>'tela_limite')::int);
  elsif p_tool = 'diario' then
    select * into l from tool_logs tl where tl.user_id = p_uid and tl.tool = 'diario' and tl.day = p_day order by tl.id desc limit 1;
    v := jsonb_build_object('written', l.id is not null, 'mood', (l.data->>'mood')::int);
  end if;
  return v;
end $$;

-- Missões do dia que a ferramenta ajuda a cumprir, com o progresso medido pelos registros
create or replace function public._tool_missions(p_uid uuid, p_tool text, p_day date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_limit int := (_tool_settings(p_uid)->>'tela_limite')::int;
  v_res jsonb;
begin
  with ms as (
    select m.id, m.name, m.unit, m.target_value, m.status, h.template_id
      from missions m left join user_habits h on h.id = m.habit_id
     where m.user_id = p_uid and p_day between m.mission_date and m.due_date
       and m.status in ('pendente','concluida')),
  lg as (select tl.tool, tl.data, tl.mission_id from tool_logs tl where tl.user_id = p_uid and tl.day = p_day),
  pr as (
    select ms.id, ms.name, ms.unit, ms.status,
      case
        when p_tool = 'agua' and ms.unit = 'copos' then
          (select coalesce(sum((lg.data->>'cups')::int), 0) from lg where lg.tool = 'agua')
        when p_tool = 'leitura' and ms.template_id = 'int_leitura' then
          (select coalesce(sum((lg.data->>'minutes')::int), 0) from lg where lg.tool = 'leitura')
          + (select coalesce(sum((lg.data->>'minutes')::int), 0) from lg where lg.tool = 'foco' and lg.mission_id = ms.id)
        when p_tool = 'meditacao' and ms.template_id in ('men_meditacao','men_respiracao') then
          (select coalesce(sum((lg.data->>'minutes')::int), 0) from lg where lg.tool = 'meditacao')
          + (select coalesce(sum((lg.data->>'minutes')::int), 0) from lg where lg.tool = 'foco' and lg.mission_id = ms.id)
        when p_tool = 'tela' and ms.template_id = 'dig_redes' then
          (select case when count(*) > 0 and min((lg.data->>'minutes')::int) <= v_limit then 1 else 0 end from lg where lg.tool = 'tela')
        when p_tool = 'diario' and ms.template_id = 'men_reflexao' then
          (select least(count(*), 1)::int from lg where lg.tool = 'diario')
        when p_tool = 'foco' and ms.unit = 'min' then
          (select sum((lg.data->>'minutes')::int)::int from lg where lg.tool = 'foco' and lg.mission_id = ms.id)
      end as progress,
      case when p_tool in ('tela','diario') then 1 else ms.target_value end as goal
      from ms)
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', pr.id, 'name', pr.name, 'unit', pr.unit, 'target', pr.goal, 'progress', pr.progress, 'status', pr.status,
           'ready', pr.status = 'pendente' and pr.progress >= pr.goal) order by pr.status desc, pr.name), '[]'::jsonb)
    into v_res
    from pr where pr.progress is not null;
  return v_res;
end $$;

create or replace function public._tool_day(p_uid uuid, p_tool text, p_day date)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  return jsonb_build_object(
    'tool', p_tool, 'day', p_day,
    'summary', _tool_summary(p_uid, p_tool, p_day),
    'entries', (select coalesce(jsonb_agg(jsonb_build_object('id', l.id, 'data', l.data, 'mission_id', l.mission_id,
                                                             'created_at', l.created_at) order by l.id desc), '[]'::jsonb)
                  from tool_logs l where l.user_id = p_uid and l.tool = p_tool and l.day = p_day),
    'missions', _tool_missions(p_uid, p_tool, p_day),
    'focusable', case when p_tool = 'foco' then
      (select coalesce(jsonb_agg(jsonb_build_object('id', m.id, 'name', m.name, 'target', m.target_value) order by m.name), '[]'::jsonb)
         from missions m where m.user_id = p_uid and m.unit = 'min' and m.status = 'pendente'
          and p_day between m.mission_date and m.due_date) end,
    'settings', _tool_settings(p_uid));
end $$;

create or replace function public._check_tool(p_uid uuid, p_tool text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_tool is null or p_tool not in ('foco','agua','sono','alimentacao','leitura','meditacao','tela','diario') then
    raise exception 'ferramenta_invalida';
  end if;
  if p_tool in ('sono','alimentacao','leitura','meditacao','tela') then
    perform _require_feature(p_uid, 'ferramentas_extras');
  end if;
end $$;

create or replace function public.get_tool(p_tool text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  perform _check_tool(v_uid, p_tool);
  return _tool_day(v_uid, p_tool, _local_today(v_uid));
end $$;

create or replace function public.log_tool(p_tool text, p_data jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_today date;
  v_d jsonb;
  v_mid uuid;
  v_total int;
  v_text text;
  v_bed int;
  v_wake int;
  v_min int;
  b books;
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  perform _check_tool(v_uid, p_tool);
  if p_data is null or jsonb_typeof(p_data) <> 'object' then raise exception 'registro_invalido'; end if;
  v_today := _local_today(v_uid);

  if p_tool = 'foco' then
    if not _int_in(p_data->'minutes', 1, 180) then raise exception 'registro_invalido'; end if;
    if p_data ? 'mission_id' and nullif(p_data->>'mission_id', '') is not null then
      v_mid := (p_data->>'mission_id')::uuid;
      if not exists (select 1 from missions where id = v_mid and user_id = v_uid and v_today between mission_date and due_date) then
        raise exception 'missao_nao_encontrada';
      end if;
    end if;
    select coalesce(sum((data->>'minutes')::int), 0) into v_total from tool_logs where user_id = v_uid and tool = 'foco' and day = v_today;
    if v_total + (p_data->>'minutes')::int > 960 then raise exception 'limite_registro'; end if;
    v_d := jsonb_build_object('minutes', (p_data->>'minutes')::int)
           || case when char_length(trim(coalesce(p_data->>'label', ''))) between 1 and 60
                   then jsonb_build_object('label', trim(p_data->>'label')) else '{}'::jsonb end;

  elsif p_tool = 'agua' then
    if not _int_in(p_data->'cups', -4, 4) or (p_data->>'cups')::int = 0 then raise exception 'registro_invalido'; end if;
    select coalesce(sum((data->>'cups')::int), 0) into v_total from tool_logs where user_id = v_uid and tool = 'agua' and day = v_today;
    if v_total + (p_data->>'cups')::int < 0 then raise exception 'registro_invalido'; end if;
    if v_total + (p_data->>'cups')::int > 30 then raise exception 'limite_registro'; end if;
    v_d := jsonb_build_object('cups', (p_data->>'cups')::int);

  elsif p_tool = 'sono' then
    if coalesce(p_data->>'bed', '') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
       or coalesce(p_data->>'wake', '') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then
      raise exception 'registro_invalido';
    end if;
    if p_data ? 'quality' and jsonb_typeof(p_data->'quality') <> 'null' and not _int_in(p_data->'quality', 1, 5) then
      raise exception 'registro_invalido';
    end if;
    v_bed := split_part(p_data->>'bed', ':', 1)::int * 60 + split_part(p_data->>'bed', ':', 2)::int;
    v_wake := split_part(p_data->>'wake', ':', 1)::int * 60 + split_part(p_data->>'wake', ':', 2)::int;
    v_min := (v_wake - v_bed + 1440) % 1440;
    if v_min not between 60 and 960 then raise exception 'registro_invalido'; end if;
    v_d := jsonb_build_object('bed', p_data->>'bed', 'wake', p_data->>'wake', 'minutes', v_min)
           || case when jsonb_typeof(p_data->'quality') = 'number' then jsonb_build_object('quality', (p_data->>'quality')::int) else '{}'::jsonb end;
    delete from tool_logs where user_id = v_uid and tool = 'sono' and day = v_today;

  elsif p_tool = 'alimentacao' then
    if coalesce(p_data->>'meal', '') not in ('cafe','almoco','jantar','lanche') then raise exception 'registro_invalido'; end if;
    if char_length(trim(coalesce(p_data->>'name', ''))) not between 1 and 60 then raise exception 'registro_invalido'; end if;
    if p_data ? 'kcal' and jsonb_typeof(p_data->'kcal') <> 'null' and not _int_in(p_data->'kcal', 0, 5000) then
      raise exception 'registro_invalido';
    end if;
    if (select count(*) from tool_logs where user_id = v_uid and tool = 'alimentacao' and day = v_today) >= 20 then
      raise exception 'limite_registro';
    end if;
    v_d := jsonb_build_object('meal', p_data->>'meal', 'name', trim(p_data->>'name'))
           || case when jsonb_typeof(p_data->'kcal') = 'number' then jsonb_build_object('kcal', (p_data->>'kcal')::int) else '{}'::jsonb end;

  elsif p_tool = 'leitura' then
    if not ((not p_data ? 'pages' or _int_in(p_data->'pages', 0, 1000)) and (not p_data ? 'minutes' or _int_in(p_data->'minutes', 0, 600))) then
      raise exception 'registro_invalido';
    end if;
    if coalesce((p_data->>'pages')::int, 0) + coalesce((p_data->>'minutes')::int, 0) = 0 then raise exception 'registro_invalido'; end if;
    v_d := jsonb_build_object('pages', coalesce((p_data->>'pages')::int, 0), 'minutes', coalesce((p_data->>'minutes')::int, 0));
    if nullif(p_data->>'book_id', '') is not null then
      select * into b from books where id = (p_data->>'book_id')::uuid and user_id = v_uid for update;
      if not found then raise exception 'livro_nao_encontrado'; end if;
      -- Páginas que de fato entraram no livro (o total do livro é o teto), para desfazer certo depois
      v_total := case when b.total_pages is null then (v_d->>'pages')::int
                      else least(b.current_page + (v_d->>'pages')::int, b.total_pages) - b.current_page end;
      update books set
        current_page = current_page + v_total,
        status = case when total_pages is not null and current_page + v_total >= total_pages then 'concluido' else 'lendo' end,
        finished_on = case when total_pages is not null and current_page + v_total >= total_pages then v_today end
      where id = b.id;
      v_d := v_d || jsonb_build_object('book_id', b.id, 'book_title', b.title, 'book_pages', v_total);
    end if;

  elsif p_tool = 'meditacao' then
    if not _int_in(p_data->'minutes', 1, 120) then raise exception 'registro_invalido'; end if;
    if p_data ? 'kind' and coalesce(p_data->>'kind', '') not in ('respiracao','meditacao','relaxamento') then
      raise exception 'registro_invalido';
    end if;
    v_d := jsonb_build_object('minutes', (p_data->>'minutes')::int, 'kind', coalesce(p_data->>'kind', 'meditacao'));

  elsif p_tool = 'tela' then
    if not _int_in(p_data->'minutes', 0, 1440) then raise exception 'registro_invalido'; end if;
    v_d := jsonb_build_object('minutes', (p_data->>'minutes')::int);
    delete from tool_logs where user_id = v_uid and tool = 'tela' and day = v_today;

  elsif p_tool = 'diario' then
    v_text := trim(coalesce(p_data->>'text', ''));
    if char_length(v_text) not between 1 and 2000 then raise exception 'registro_invalido'; end if;
    if p_data ? 'mood' and jsonb_typeof(p_data->'mood') <> 'null' and not _int_in(p_data->'mood', 1, 5) then
      raise exception 'registro_invalido';
    end if;
    v_d := jsonb_build_object('text', v_text)
           || case when jsonb_typeof(p_data->'mood') = 'number' then jsonb_build_object('mood', (p_data->>'mood')::int) else '{}'::jsonb end
           || case when char_length(trim(coalesce(p_data->>'gratitude', ''))) between 1 and 280
                   then jsonb_build_object('gratitude', trim(p_data->>'gratitude')) else '{}'::jsonb end;
    delete from tool_logs where user_id = v_uid and tool = 'diario' and day = v_today;
  end if;

  insert into tool_logs (user_id, tool, day, data, mission_id) values (v_uid, p_tool, v_today, v_d, v_mid);
  perform _progress_rewards(v_uid, v_today);
  return _tool_day(v_uid, p_tool, v_today);
end $$;

create or replace function public.delete_tool_log(p_id bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); l tool_logs;
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  select * into l from tool_logs where id = p_id and user_id = v_uid;
  if not found then raise exception 'registro_nao_encontrado'; end if;
  if l.tool = 'leitura' and l.data ? 'book_id' then
    update books set current_page = greatest(current_page - coalesce((l.data->>'book_pages')::int, (l.data->>'pages')::int), 0),
                     status = case when status = 'concluido' then 'lendo' else status end,
                     finished_on = case when status = 'concluido' then null else finished_on end
     where id = (l.data->>'book_id')::uuid and user_id = v_uid;
  end if;
  delete from tool_logs where id = l.id;
  return _tool_day(v_uid, l.tool, l.day);
end $$;

create or replace function public.tools_overview()
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_today date;
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  v_today := _local_today(v_uid);
  return jsonb_build_object(
    'day', v_today,
    'extras', _feature_allowed(v_uid, 'ferramentas_extras'),
    'settings', _tool_settings(v_uid),
    'summary', (select jsonb_object_agg(t, _tool_summary(v_uid, t, v_today))
                  from unnest(array['foco','agua','sono','alimentacao','leitura','meditacao','tela','diario']) t),
    'ready', (select count(*) from unnest(array['agua','leitura','meditacao','tela','diario','foco']) t,
                     jsonb_array_elements(_tool_missions(v_uid, t, v_today)) m
               where (m->>'ready')::boolean));
end $$;

create or replace function public.tool_history(p_tool text, p_days int)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_today date; v_n int; v_days jsonb;
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  perform _check_tool(v_uid, p_tool);
  v_today := _local_today(v_uid);
  v_n := least(greatest(coalesce(p_days, 7), 7), 90);
  select jsonb_agg(jsonb_build_object('date', d.day, 'value', x.value, 'extra', x.extra) order by d.day) into v_days
    from (select g::date as day from generate_series((v_today - v_n + 1)::timestamp, v_today::timestamp, interval '1 day') g) d
    left join lateral (
      select case p_tool
               when 'foco'        then sum((l.data->>'minutes')::int)
               when 'agua'        then sum((l.data->>'cups')::int)
               when 'sono'        then max((l.data->>'minutes')::int)
               when 'alimentacao' then sum((l.data->>'kcal')::int)
               when 'leitura'     then sum((l.data->>'pages')::int)
               when 'meditacao'   then sum((l.data->>'minutes')::int)
               when 'tela'        then max((l.data->>'minutes')::int)
               else max((l.data->>'mood')::int) end as value,
             case p_tool when 'sono' then max((l.data->>'quality')::int)
                         when 'leitura' then sum((l.data->>'minutes')::int)
                         when 'agua' then _water_goal(v_uid, d.day) end as extra
        from tool_logs l
       where l.user_id = v_uid and l.tool = p_tool and l.day = d.day
      having count(*) > 0) x on true;
  return jsonb_build_object('tool', p_tool, 'days', v_days, 'settings', _tool_settings(v_uid));
end $$;

create or replace function public.get_diary(p_limit int)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  return (select coalesce(jsonb_agg(jsonb_build_object('id', l.id, 'day', l.day, 'text', l.data->>'text',
                                                       'mood', (l.data->>'mood')::int, 'gratitude', l.data->>'gratitude')
                                    order by l.day desc, l.id desc), '[]'::jsonb)
            from (select * from tool_logs where user_id = v_uid and tool = 'diario'
                   order by day desc, id desc limit least(greatest(coalesce(p_limit, 30), 1), 120)) l);
end $$;

create or replace function public.get_books()
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  perform _require_feature(v_uid, 'ferramentas_extras');
  return (select coalesce(jsonb_agg(to_jsonb(b) - 'user_id' order by b.status = 'lendo' desc, b.created_at desc), '[]'::jsonb)
            from books b where b.user_id = v_uid);
end $$;

create or replace function public.save_book(p_id uuid, p_title text, p_author text, p_total_pages int)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); b books;
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  perform _require_feature(v_uid, 'ferramentas_extras');
  if char_length(trim(coalesce(p_title, ''))) not between 1 and 120 then raise exception 'livro_invalido'; end if;
  if char_length(trim(coalesce(p_author, ''))) > 80 then raise exception 'livro_invalido'; end if;
  if p_total_pages is not null and p_total_pages not between 1 and 5000 then raise exception 'livro_invalido'; end if;
  if p_id is null then
    if (select count(*) from books where user_id = v_uid) >= 100 then raise exception 'limite_livros'; end if;
    insert into books (user_id, title, author, total_pages, started_on)
      values (v_uid, trim(p_title), trim(coalesce(p_author, '')), p_total_pages, _local_today(v_uid))
      returning * into b;
  else
    update books set title = trim(p_title), author = trim(coalesce(p_author, '')), total_pages = p_total_pages,
                     current_page = case when p_total_pages is null then current_page else least(current_page, p_total_pages) end
     where id = p_id and user_id = v_uid returning * into b;
    if not found then raise exception 'livro_nao_encontrado'; end if;
  end if;
  return to_jsonb(b) - 'user_id';
end $$;

create or replace function public.set_book_status(p_id uuid, p_status text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); b books;
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  if p_status not in ('lendo','concluido','pausado') then raise exception 'livro_invalido'; end if;
  update books set status = p_status,
                   finished_on = case when p_status = 'concluido' then _local_today(v_uid) end,
                   current_page = case when p_status = 'concluido' and total_pages is not null then total_pages else current_page end
   where id = p_id and user_id = v_uid returning * into b;
  if not found then raise exception 'livro_nao_encontrado'; end if;
  perform _progress_rewards(v_uid, _local_today(v_uid));
  return to_jsonb(b) - 'user_id';
end $$;

-- Rastreador de hábitos: últimas 4 semanas de cada hábito
create or replace function public.habit_tracker()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_prof profiles;
  v_today date;
  v_res jsonb := '[]'::jsonb;
  h user_habits;
  v_days jsonb;
  v_done int;
  v_streak int;
  r record;
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  select * into v_prof from profiles where id = v_uid;
  if v_prof.program_start is null then return v_res; end if;
  v_today := _local_today(v_uid);
  for h in select * from user_habits where user_id = v_uid order by active desc, start_day, created_at loop
    select jsonb_agg(jsonb_build_object('date', d.day, 'status',
             case when m.id is not null then
                    case when m.status = 'concluida' then 'feito' when d.day < v_today then 'perdido' else 'pendente' end
                  when d.day < v_prof.program_start + h.start_day - 1 or not h.active then 'sem'
                  when d.day < v_today then 'perdido'
                  else 'pendente' end) order by d.day),
           count(*) filter (where m.status = 'concluida')
      into v_days, v_done
      from (select g::date as day from generate_series((v_today - 27)::timestamp, v_today::timestamp, interval '1 day') g) d
      left join missions m on m.habit_id = h.id and m.mission_date = d.day and m.kind = 'diaria';
    v_streak := 0;
    for r in select e->>'status' as st from jsonb_array_elements(v_days) e order by (e->>'date')::date desc loop
      if r.st = 'feito' then v_streak := v_streak + 1;
      elsif r.st = 'pendente' then continue;
      else exit;
      end if;
    end loop;
    v_res := v_res || jsonb_build_object(
      'habit', jsonb_build_object('id', h.id, 'name', h.name, 'dimension', h.dimension, 'unit', h.unit,
                                  'current_target', h.current_target, 'active', h.active, 'is_custom', h.is_custom, 'period', h.period),
      'days', v_days, 'done', v_done, 'streak', v_streak);
  end loop;
  return v_res;
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 11. Mentor: análises, sugestões (só mudam algo quando a pessoa aceita) e relatório semanal
-- ════════════════════════════════════════════════════════════════════════════
-- O Mentor é um conjunto de regras que roda no servidor, sobre os dados da própria pessoa.
-- Não faz diagnóstico, não lê o texto do diário (só o número do humor) e nunca muda metas sozinho.

create or replace function public._dim_label(p_dim text)
returns text language sql immutable as $$
  select case p_dim when 'fisica' then 'Saúde física' when 'mental' then 'Saúde mental'
                    when 'intelectual' then 'Desenvolvimento intelectual' when 'produtividade' then 'Disciplina e produtividade'
                    when 'digital' then 'Saúde digital' else 'Autocuidado e rotina' end
$$;

create or replace function public._weekday_name(p_isodow int)
returns text language sql immutable as $$
  select (array['segunda-feira','terça-feira','quarta-feira','quinta-feira','sexta-feira','sábado','domingo'])[p_isodow]
$$;

create or replace function public._unit_label(p_unit text, p_n int)
returns text language sql immutable as $$
  select case p_unit when 'min' then 'min'
                     when 'copos' then case when p_n = 1 then 'copo' else 'copos' end
                     when 'paginas' then case when p_n = 1 then 'página' else 'páginas' end
                     else case when p_n = 1 then 'vez' else 'vezes' end end
$$;

create or replace function public._fmt_minutes(p_min int)
returns text language sql immutable as $$
  select case when p_min < 60 then p_min || ' min'
              when p_min % 60 = 0 then (p_min / 60) || 'h'
              else (p_min / 60) || 'h' || lpad((p_min % 60)::text, 2, '0') end
$$;

create or replace function public._fmt_decimal(p numeric)
returns text language sql immutable as $$
  select replace(to_char(round(p, 1), 'FM990.0'), '.', ',')
$$;

-- "O Adiador" → "o Adiador" (no meio da frase)
create or replace function public._mid_name(p_name text)
returns text language sql immutable as $$
  select case when p_name ~ '^(O|A|Os|As) ' then lower(split_part(p_name, ' ', 1)) || substr(p_name, length(split_part(p_name, ' ', 1)) + 1)
              else p_name end
$$;

-- Ajuste de meta ou pausa (o mesmo caminho para o botão "ajustar meta" e para uma sugestão aceita)
create or replace function public._adjust_habit(p_uid uuid, p_habit uuid, p_target int, p_active boolean)
returns void language plpgsql security definer set search_path = public as $$
declare
  h user_habits;
  today date;
begin
  select * into h from user_habits where id = p_habit and user_id = p_uid for update;
  if not found then raise exception 'habito_nao_encontrado'; end if;
  if (select mode from profiles where id = p_uid) = 'extremo' then raise exception 'modo_extremo_bloqueia_ajustes'; end if;
  if p_target is null or p_target not between h.base_value and h.max_value then raise exception 'meta_fora_do_intervalo'; end if;

  if p_target <> h.current_target or coalesce(p_active, h.active) <> h.active then
    insert into habit_adjustments (user_id, habit_id, old_target, new_target, paused)
      values (p_uid, h.id, h.current_target, p_target, coalesce(p_active, h.active) = false);
  end if;
  update user_habits set current_target = p_target, active = coalesce(p_active, active) where id = h.id;

  today := _local_today(p_uid);
  update missions m set
    target_value = p_target,
    estimated_minutes = _est_minutes(h.unit, p_target, h.est_minutes),
    xp_reward = _xp_for(m.difficulty, _est_minutes(h.unit, p_target, h.est_minutes), m.kind)
  where m.habit_id = h.id and m.kind = 'diaria' and m.mission_date = today and m.status = 'pendente';

  if p_active = false then
    delete from missions where habit_id = h.id and mission_date = today and status = 'pendente' and kind = 'diaria';
  end if;

  perform _sync_boss(p_uid, today, now());
  perform _progress_rewards(p_uid, today);
end $$;

create or replace function public.adjust_habit(p_habit uuid, p_target int, p_active boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  perform _adjust_habit(uid, p_habit, p_target, p_active);
  return jsonb_build_object('ok', true);
end $$;

create or replace function public._mentor_insights(p_uid uuid, p_today date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_prof profiles;
  v_set jsonb := _tool_settings(p_uid);
  v_res jsonb := '[]'::jsonb;
  v_tot int; v_m int; v_t int; v_n int; v_pct int; v_best text;
  v_days int; v_met int;
  v_cur int; v_prev int;
  v_strong text; v_weak text; v_cnt int;
  v_wd_best int; v_wd_worst int; v_rate_best numeric; v_rate_worst numeric;
  v_avg numeric; v_avg2 numeric; v_cnt2 int;
begin
  select * into v_prof from profiles where id = p_uid;
  if v_prof.program_start is null then return v_res; end if;

  -- 1. Constância das últimas 2 semanas
  select count(*), count(*) filter (where s.goal_met) into v_days, v_met
    from _day_stats(p_uid, greatest(v_prof.program_start, p_today - 14), p_today - 1) s;
  if v_days >= 7 then
    if v_met * 1.0 / v_days >= 0.8 then
      v_res := v_res || jsonb_build_object('id', 'constancia', 'tone', 'positivo', 'title', 'Ritmo firme',
        'text', format('Você cumpriu a meta em %s dos últimos %s dias. É assim que esforço vira hábito.', v_met, v_days));
    elsif v_met * 1.0 / v_days < 0.4 then
      v_res := v_res || jsonb_build_object('id', 'constancia', 'tone', 'atencao', 'title', 'A meta está pesada?',
        'text', format('A meta foi cumprida em %s dos últimos %s dias. Se ela está pesada para este momento, ajustar faz parte do processo.', v_met, v_days));
    else
      v_res := v_res || jsonb_build_object('id', 'constancia', 'tone', 'neutro', 'title', 'Constância',
        'text', format('Você cumpriu a meta em %s dos últimos %s dias.', v_met, v_days));
    end if;
  end if;

  -- 2. Tendência: últimos 7 dias contra os 7 anteriores
  select count(*) filter (where x.d >= p_today - 6), count(*) filter (where x.d < p_today - 6) into v_cur, v_prev
    from (select (m.completed_at at time zone v_prof.timezone)::date as d from missions m
           where m.user_id = p_uid and m.status = 'concluida'
             and m.completed_at >= ((p_today - 13)::timestamp at time zone v_prof.timezone)) x;
  if p_today - v_prof.program_start >= 13 and v_cur + v_prev >= 4 then
    if v_cur > v_prev then
      v_res := v_res || jsonb_build_object('id', 'tendencia', 'tone', 'positivo', 'title', 'Em alta',
        'text', format('%s missões nos últimos 7 dias, %s a mais que nos 7 anteriores.', v_cur, v_cur - v_prev));
    elsif v_cur < v_prev then
      v_res := v_res || jsonb_build_object('id', 'tendencia', 'tone', 'atencao', 'title', 'Ritmo mais lento',
        'text', format('%s missões nos últimos 7 dias, contra %s nos 7 anteriores. Quedas acontecem: recomeçar pela missão mais fácil do dia ajuda.', v_cur, v_prev));
    end if;
  end if;

  -- 3. Horário em que você mais conclui (últimas 4 semanas)
  select count(*), count(*) filter (where x.h between 5 and 11), count(*) filter (where x.h between 12 and 17),
         count(*) filter (where x.h >= 18 or x.h < 5)
    into v_tot, v_m, v_t, v_n
    from (select extract(hour from m.completed_at at time zone v_prof.timezone)::int as h
            from missions m where m.user_id = p_uid and m.status = 'concluida'
             and m.completed_at >= ((p_today - 27)::timestamp at time zone v_prof.timezone)) x;
  if v_tot >= 10 then
    if v_m >= v_t and v_m >= v_n then v_best := 'de manhã'; v_pct := round(v_m * 100.0 / v_tot);
    elsif v_t >= v_n then v_best := 'à tarde'; v_pct := round(v_t * 100.0 / v_tot);
    else v_best := 'à noite'; v_pct := round(v_n * 100.0 / v_tot);
    end if;
    if v_pct >= 45 then
      v_res := v_res || jsonb_build_object('id', 'periodo', 'tone', 'neutro', 'title', 'Seu melhor horário',
        'text', format('%s%% das suas missões das últimas 4 semanas foram concluídas %s. Vale reservar esse horário para as missões mais difíceis.', v_pct, v_best));
    end if;
  end if;

  -- 4. Áreas do plano: a mais forte e a que pede atenção (últimas 2 semanas)
  select (array_agg(x.dim order by x.n desc, x.dim))[1], (array_agg(x.dim order by x.n asc, x.dim))[1], count(*), coalesce(sum(x.n), 0)
    into v_strong, v_weak, v_cnt, v_tot
    from (select h.dimension as dim,
                 (select count(*) from missions m where m.user_id = p_uid and m.status = 'concluida' and m.dimension = h.dimension
                     and m.completed_at >= ((p_today - 13)::timestamp at time zone v_prof.timezone))::int as n
            from (select distinct dimension from user_habits where user_id = p_uid and active) h) x;
  if v_cnt >= 2 and v_tot >= 6 and v_strong <> v_weak then
    v_res := v_res || jsonb_build_object('id', 'areas', 'tone', 'neutro', 'title', 'Equilíbrio entre áreas',
      'text', format('Nas últimas 2 semanas, sua área mais forte foi %s. A que mais pede atenção é %s.', _dim_label(v_strong), _dim_label(v_weak)));
  end if;

  -- 5. Dias da semana (últimas 4 semanas)
  select (array_agg(x.wd order by x.rate desc, x.wd))[1], (array_agg(x.wd order by x.rate asc, x.wd))[1],
         max(x.rate), min(x.rate), coalesce(sum(x.n), 0)
    into v_wd_best, v_wd_worst, v_rate_best, v_rate_worst, v_cnt
    from (select extract(isodow from s.day)::int as wd, avg(case when s.goal_met then 1 else 0 end) as rate, count(*) as n
            from _day_stats(p_uid, greatest(v_prof.program_start, p_today - 28), p_today - 1) s group by 1) x;
  if v_cnt >= 14 and v_rate_best - v_rate_worst >= 0.3 then
    v_res := v_res || jsonb_build_object('id', 'dia_semana', 'tone', 'neutro', 'title', 'Dias da semana',
      'text', format('Seu dia mais forte é %s (meta em %s%% das vezes). O mais difícil é %s (%s%%). Uma missão mais leve nesse dia pode ajudar.',
                     _weekday_name(v_wd_best), round(v_rate_best * 100), _weekday_name(v_wd_worst), round(v_rate_worst * 100)));
  end if;

  -- 6. Sono (registros dos últimos 7 dias)
  select avg((l.data->>'minutes')::int), count(*) into v_avg, v_cnt
    from tool_logs l where l.user_id = p_uid and l.tool = 'sono' and l.day > p_today - 7;
  if v_cnt >= 3 then
    if v_avg < (v_set->>'sono_meta')::int - 30 then
      v_res := v_res || jsonb_build_object('id', 'sono', 'tone', 'atencao', 'title', 'Sono abaixo da sua meta',
        'text', format('Média de %s por noite nos registros dos últimos 7 dias, abaixo da sua meta de %s. Se dormir bem estiver difícil com frequência, vale conversar com um profissional de saúde.',
                       _fmt_minutes(round(v_avg)::int), _fmt_minutes((v_set->>'sono_meta')::int)));
    else
      v_res := v_res || jsonb_build_object('id', 'sono', 'tone', 'positivo', 'title', 'Sono em dia',
        'text', format('Média de %s por noite nos registros dos últimos 7 dias, perto da sua meta.', _fmt_minutes(round(v_avg)::int)));
    end if;
  end if;

  -- 7. Água (dias registrados na última semana, sem contar hoje)
  select count(*) filter (where x.cups >= _water_goal(p_uid, x.day)), count(*) into v_met, v_cnt
    from (select l.day, sum((l.data->>'cups')::int) as cups from tool_logs l
           where l.user_id = p_uid and l.tool = 'agua' and l.day > p_today - 8 and l.day < p_today group by l.day) x;
  if v_cnt >= 3 then
    v_res := v_res || jsonb_build_object('id', 'agua', 'tone', case when v_met * 2 >= v_cnt then 'positivo' else 'neutro' end,
      'title', 'Água', 'text', format('Você bateu a meta de água em %s dos %s dias registrados na última semana.', v_met, v_cnt));
  end if;

  -- 8. Humor do diário nos dias com e sem meditação (só o número do humor, nunca o texto)
  select avg(x.mood) filter (where x.med), count(*) filter (where x.med), avg(x.mood) filter (where not x.med), count(*) filter (where not x.med)
    into v_avg, v_cnt, v_avg2, v_cnt2
    from (select (d.data->>'mood')::int as mood,
                 exists (select 1 from tool_logs m where m.user_id = p_uid and m.tool = 'meditacao' and m.day = d.day) as med
            from tool_logs d where d.user_id = p_uid and d.tool = 'diario' and d.data ? 'mood' and d.day > p_today - 28) x;
  if v_cnt >= 3 and v_cnt2 >= 3 and v_avg - v_avg2 >= 0.5 then
    v_res := v_res || jsonb_build_object('id', 'humor', 'tone', 'positivo', 'title', 'Meditação e humor',
      'text', format('Nos dias em que você meditou, o humor registrado no diário foi em média %s de 5. Nos outros dias, %s.',
                     _fmt_decimal(v_avg), _fmt_decimal(v_avg2)));
  end if;

  return v_res;
end $$;

-- Cria uma sugestão, sem insistir: recusada há menos de 14 dias ou aceita há menos de 7 não volta
create or replace function public._suggest(p_uid uuid, p_today date, p_kind text, p_ref text, p_data jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from mentor_suggestions
              where user_id = p_uid and kind = p_kind and ref = p_ref
                and ((status = 'recusada' and responded_at > now() - interval '14 days')
                  or (status = 'aceita' and responded_at > now() - interval '7 days'))) then
    return;
  end if;
  insert into mentor_suggestions (user_id, kind, ref, data, created_on)
    values (p_uid, p_kind, p_ref, p_data, p_today) on conflict do nothing;
end $$;

-- Sugestões que deixaram de fazer sentido expiram (meta já mudou, hábito pausado, chefe já em batalha…)
create or replace function public._mentor_cleanup(p_uid uuid, p_today date)
returns void language plpgsql security definer set search_path = public as $$
declare v_prof profiles;
begin
  select * into v_prof from profiles where id = p_uid;
  update mentor_suggestions s set status = 'expirada'
   where s.user_id = p_uid and s.status = 'aberta'
     and ((s.kind in ('reduzir_meta','pausar_habito','reduzir_minimo','aumentar_minimo') and v_prof.mode = 'extremo')
          or (s.kind = 'reduzir_meta' and not exists (select 1 from user_habits h where h.id::text = s.ref and h.active
                                                         and h.current_target > (s.data->>'to')::int))
          or (s.kind = 'pausar_habito' and not exists (select 1 from user_habits h where h.id::text = s.ref and h.active))
          or (s.kind in ('reduzir_minimo','aumentar_minimo') and (s.data->>'from')::int <> v_prof.min_daily_missions)
          or (s.kind = 'experimentar_desafio' and v_prof.mode <> 'normal')
          or (s.kind = 'enfrentar_chefe' and exists (select 1 from user_bosses b where b.user_id = p_uid and b.status = 'ativo')));
end $$;

-- Reavalia as sugestões uma vez por dia (só com o Mentor ligado). As que não valem mais para os dados de hoje expiram.
create or replace function public._mentor_refresh(p_uid uuid, p_today date)
returns int language plpgsql security definer set search_path = public as $$
declare
  v_keep text[] := '{}';
  v_prof profiles;
  v_day int;
  h user_habits;
  b boss_catalog;
  v_done int;
  v_last date;
  v_to int;
  v_days int;
  v_met int;
  v_avg numeric;
  v_busy int;
begin
  select * into v_prof from profiles where id = p_uid;
  if not v_prof.mentor_enabled or not v_prof.onboarding_done or v_prof.program_start is null then return 0; end if;
  if not _feature_allowed(p_uid, 'mentor') then return 0; end if;
  perform _mentor_cleanup(p_uid, p_today);
  if v_prof.mentor_checked_on is not null and v_prof.mentor_checked_on >= p_today then return 0; end if;
  v_day := (p_today - v_prof.program_start) + 1;

  -- Hábitos: meta pesada ou hábito esquecido
  if v_prof.mode <> 'extremo' then
    for h in select * from user_habits where user_id = p_uid and active and start_day <= v_day - 7 order by start_day, created_at loop
      select count(*) into v_done from missions
       where habit_id = h.id and status = 'concluida' and mission_date between p_today - 7 and p_today - 1;
      select max(mission_date) into v_last from missions where habit_id = h.id and status = 'concluida';
      if v_done <= 2 and h.current_target > h.base_value then
        v_to := greatest(h.base_value, h.current_target - greatest(h.step, 1));
        v_keep := v_keep || ('reduzir_meta:' || h.id);
        perform _suggest(p_uid, p_today, 'reduzir_meta', h.id::text, jsonb_build_object(
          'habit_id', h.id, 'name', h.name, 'unit', h.unit, 'from', h.current_target, 'to', v_to, 'done', v_done,
          'title', format('Ajustar a meta de %s', h.name),
          'text', format('Você concluiu %s em %s dos últimos 7 dias. Baixar de %s para %s %s pode ajudar a retomar o ritmo. Ajustar também é evoluir.',
                         h.name, v_done, h.current_target, v_to, _unit_label(h.unit, v_to)),
          'action', format('Ajustar para %s %s', v_to, _unit_label(h.unit, v_to))));
      elsif v_done = 0 and (v_last is null or v_last < p_today - 10) and h.current_target = h.base_value and h.start_day <= v_day - 10 then
        v_keep := v_keep || ('pausar_habito:' || h.id);
        perform _suggest(p_uid, p_today, 'pausar_habito', h.id::text, jsonb_build_object(
          'habit_id', h.id, 'name', h.name,
          'title', format('Pausar %s?', h.name),
          'text', format('%s ficou sem conclusões nos últimos 10 dias. Pausar por um tempo deixa o plano mais leve, e dá para retomar quando quiser.', h.name),
          'action', 'Pausar hábito'));
      end if;
    end loop;
  end if;

  -- Meta diária e modo (últimas 2 semanas)
  select count(*), count(*) filter (where s.goal_met), avg(s.daily_total) into v_days, v_met, v_avg
    from _day_stats(p_uid, greatest(v_prof.program_start, p_today - 14), p_today - 1) s;
  if v_prof.mode = 'normal' and v_days >= 14 then
    if v_met * 1.0 / v_days < 0.4 and v_prof.min_daily_missions > 1 then
      v_keep := v_keep || 'reduzir_minimo:'::text;
      perform _suggest(p_uid, p_today, 'reduzir_minimo', '', jsonb_build_object(
        'from', v_prof.min_daily_missions, 'to', v_prof.min_daily_missions - 1, 'met', v_met, 'days', v_days,
        'title', 'Meta diária mais leve',
        'text', format('Você cumpriu a meta em %s dos últimos %s dias. Baixar a meta diária de %s para %s missões pode tornar a sequência possível de novo.',
                       v_met, v_days, v_prof.min_daily_missions, v_prof.min_daily_missions - 1),
        'action', format('Mudar para %s', v_prof.min_daily_missions - 1)));
    elsif v_met = v_days and v_prof.min_daily_missions < 10 and v_prof.min_daily_missions + 1 <= floor(v_avg) then
      v_keep := v_keep || 'aumentar_minimo:'::text;
      perform _suggest(p_uid, p_today, 'aumentar_minimo', '', jsonb_build_object(
        'from', v_prof.min_daily_missions, 'to', v_prof.min_daily_missions + 1,
        'title', 'Subir a meta diária?',
        'text', format('Você cumpriu a meta em todos os últimos %s dias. Se couber na sua rotina, a meta diária pode passar de %s para %s missões.',
                       v_days, v_prof.min_daily_missions, v_prof.min_daily_missions + 1),
        'action', format('Mudar para %s', v_prof.min_daily_missions + 1)));
    end if;
    if v_met * 1.0 / v_days >= 0.85 and v_day >= 8 and _feature_allowed(p_uid, 'modos') then
      v_keep := v_keep || 'experimentar_desafio:'::text;
      perform _suggest(p_uid, p_today, 'experimentar_desafio', '', jsonb_build_object(
        'rate', round(v_met * 100.0 / v_days),
        'title', 'Pronto para o modo Desafio?',
        'text', format('Sua constância nas últimas 2 semanas foi de %s%%. O modo Desafio dá 20%% mais XP, com regras mais exigentes. Só vale se fizer sentido para você.',
                       round(v_met * 100.0 / v_days)),
        'action', 'Ver o modo Desafio', 'link', '/jornada/modos'));
    end if;
  end if;

  -- Um chefe disponível
  if not exists (select 1 from user_bosses where user_id = p_uid and status = 'ativo') and _feature_allowed(p_uid, 'chefes') then
    for b in select bc.* from boss_catalog bc
              where not exists (select 1 from user_bosses ub where ub.user_id = p_uid and ub.boss_id = bc.id and ub.status = 'vencido')
              order by bc.sort loop
      if _boss_lock(p_uid, b, v_day) is null then
        v_keep := v_keep || ('enfrentar_chefe:' || b.id);
        perform _suggest(p_uid, p_today, 'enfrentar_chefe', b.id, jsonb_build_object(
          'boss_id', b.id, 'name', b.name,
          'title', 'Um chefe está esperando',
          'text', format('Você já pode enfrentar %s. Cada dia em que fizer o que esse chefe exige vale um golpe.', _mid_name(b.name)),
          'action', 'Ver o chefe', 'link', '/jornada/chefes/' || b.id));
        exit;
      end if;
    end loop;
  end if;

  -- Volume alto demais: lembrar de descansar
  select count(*) into v_busy from _day_stats(p_uid, greatest(v_prof.program_start, p_today - 7), p_today - 1) s where s.done > 12;
  if v_busy >= 3 then
    v_keep := v_keep || 'descansar:'::text;
    perform _suggest(p_uid, p_today, 'descansar', '', jsonb_build_object(
      'days', v_busy, 'title', 'Lembre de descansar',
      'text', format('Você concluiu mais de 12 missões por dia em %s dos últimos 7 dias. Constância vale mais que volume, e descanso também faz parte do plano.', v_busy),
      'action', 'Entendi'));
  end if;

  update mentor_suggestions set status = 'expirada'
   where user_id = p_uid and status = 'aberta' and not ((kind || ':' || ref) = any(v_keep));
  update profiles set mentor_checked_on = p_today where id = p_uid;
  return (select count(*) from mentor_suggestions where user_id = p_uid and status = 'aberta');
end $$;

-- Relatório de uma semana (segunda a domingo). p_until corta a semana em andamento no dia de hoje.
create or replace function public._weekly_report(p_uid uuid, p_week date, p_until date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_prof profiles;
  v_end date := least(p_week + 6, p_until);
  v_from date;
  v_done int; v_prev int;
  v_days int; v_goal int; v_perfect int;
  v_xp int; v_xp_prev int;
  v_areas jsonb; v_strong text; v_weak text;
  v_best jsonb; v_ach jsonb; v_boss jsonb; v_tools jsonb;
  v_streak int;
  v_highlight text; v_focus text;
begin
  select * into v_prof from profiles where id = p_uid;
  v_from := greatest(p_week, coalesce(v_prof.program_start, p_week));

  select count(*) filter (where x.d between p_week and v_end), count(*) filter (where x.d between p_week - 7 and p_week - 1)
    into v_done, v_prev
    from (select (m.completed_at at time zone v_prof.timezone)::date as d from missions m
           where m.user_id = p_uid and m.status = 'concluida'
             and m.completed_at >= ((p_week - 7)::timestamp at time zone v_prof.timezone)
             and m.completed_at < ((v_end + 1)::timestamp at time zone v_prof.timezone)) x;

  select count(*), count(*) filter (where s.goal_met), count(*) filter (where s.daily_total > 0 and s.daily_done = s.daily_total)
    into v_days, v_goal, v_perfect from _day_stats(p_uid, v_from, v_end) s;

  select coalesce(sum(l.amount) filter (where l.day between p_week and v_end), 0),
         coalesce(sum(l.amount) filter (where l.day between p_week - 7 and p_week - 1), 0)
    into v_xp, v_xp_prev from xp_ledger l where l.user_id = p_uid and l.day between p_week - 7 and v_end;

  select coalesce(jsonb_object_agg(x.dim, x.n), '{}'::jsonb), (array_agg(x.dim order by x.n desc, x.dim))[1]
    into v_areas, v_strong
    from (select m.dimension as dim, count(*) as n from missions m
           where m.user_id = p_uid and m.status = 'concluida'
             and (m.completed_at at time zone v_prof.timezone)::date between p_week and v_end group by m.dimension) x;
  select (array_agg(h.dimension order by coalesce((v_areas->>h.dimension)::int, 0), h.dimension))[1] into v_weak
    from (select distinct dimension from user_habits where user_id = p_uid and active) h;

  select jsonb_build_object('date', s.day, 'done', s.done) into v_best
    from _day_stats(p_uid, v_from, v_end) s where s.done > 0 order by s.done desc, s.day limit 1;

  select coalesce(jsonb_agg(jsonb_build_object('id', ac.id, 'name', ac.name, 'rarity', ac.rarity) order by ua.unlocked_at), '[]'::jsonb)
    into v_ach
    from user_achievements ua join achievement_catalog ac on ac.id = ua.achievement_id
   where ua.user_id = p_uid and (ua.unlocked_at at time zone v_prof.timezone)::date between p_week and v_end;

  select coalesce(jsonb_agg(b.name order by f.finished_at), '[]'::jsonb) into v_boss
    from user_bosses f join boss_catalog b on b.id = f.boss_id
   where f.user_id = p_uid and f.status = 'vencido' and (f.finished_at at time zone v_prof.timezone)::date between p_week and v_end;

  select jsonb_build_object(
      'foco_min', coalesce(sum((l.data->>'minutes')::int) filter (where l.tool = 'foco'), 0),
      'meditacao_min', coalesce(sum((l.data->>'minutes')::int) filter (where l.tool = 'meditacao'), 0),
      'paginas', coalesce(sum((l.data->>'pages')::int) filter (where l.tool = 'leitura'), 0),
      'diario_dias', count(distinct l.day) filter (where l.tool = 'diario'),
      'humor_medio', round(avg((l.data->>'mood')::int) filter (where l.tool = 'diario'), 1),
      'sono_medio', round(avg((l.data->>'minutes')::int) filter (where l.tool = 'sono')),
      'agua_dias', (select count(*) from (select w.day, sum((w.data->>'cups')::int) as c from tool_logs w
                                            where w.user_id = p_uid and w.tool = 'agua' and w.day between p_week and v_end
                                            group by w.day) y where y.c >= _water_goal(p_uid, y.day)))
    into v_tools
    from tool_logs l where l.user_id = p_uid and l.day between p_week and v_end;

  v_streak := coalesce((_journey(p_uid, v_end)->>'current_streak')::int, 0);
  v_highlight := case
    when v_days > 0 and v_goal = v_days then 'Semana completa: meta cumprida em todos os dias.'
    when v_done > v_prev and v_prev > 0 then format('Você concluiu %s missões a mais que na semana anterior.', v_done - v_prev)
    when v_goal >= 4 then format('Boa constância: meta cumprida em %s dias.', v_goal)
    when v_done > 0 then 'Toda missão conta. Na próxima semana, tente cumprir a meta em um dia a mais.'
    else 'Toda semana é um recomeço. O importante é voltar.' end;
  v_focus := case when v_weak is not null and v_weak is distinct from v_strong
                  then format('Na próxima semana, dê um pouco mais de atenção a %s.', _dim_label(v_weak)) end;

  return jsonb_build_object(
    'week_start', p_week, 'week_end', p_week + 6, 'until', v_end, 'complete', v_end = p_week + 6,
    'missions', v_done, 'missions_prev', v_prev, 'days', v_days, 'goal_days', v_goal, 'perfect_days', v_perfect,
    'xp', v_xp, 'xp_prev', v_xp_prev, 'areas', v_areas, 'strongest', v_strong, 'weakest', v_weak, 'best_day', v_best,
    'achievements', v_ach, 'bosses', v_boss, 'tools', v_tools, 'streak', v_streak,
    'highlight', v_highlight, 'focus', v_focus);
end $$;

-- Fecha o relatório da semana anterior (na primeira abertura a partir de segunda-feira)
create or replace function public._finalize_reports(p_uid uuid, p_today date)
returns int language plpgsql security definer set search_path = public as $$
declare
  v_prof profiles;
  v_week date := (date_trunc('week', p_today::timestamp))::date - 7;
  v_r jsonb;
begin
  select * into v_prof from profiles where id = p_uid;
  if v_prof.program_start is null or v_prof.program_start > v_week + 6 then return 0; end if;
  if exists (select 1 from mentor_reports where user_id = p_uid and week_start = v_week) then return 0; end if;
  if not _feature_allowed(p_uid, 'relatorios') then return 0; end if;
  v_r := _weekly_report(p_uid, v_week, v_week + 6);
  if (v_r->>'missions')::int = 0 then return 0; end if;
  insert into mentor_reports (user_id, week_start, data) values (p_uid, v_week, v_r) on conflict do nothing;
  insert into user_events (user_id, kind, ref) values (p_uid, 'relatorio', v_week::text) on conflict do nothing;
  return 1;
end $$;

create or replace function public.set_mentor(p_enabled boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  if coalesce(p_enabled, false) then perform _require_feature(v_uid, 'mentor'); end if;
  update profiles set mentor_enabled = coalesce(p_enabled, false), mentor_checked_on = null where id = v_uid;
  if not coalesce(p_enabled, false) then
    update mentor_suggestions set status = 'expirada' where user_id = v_uid and status = 'aberta';
  end if;
  return jsonb_build_object('enabled', coalesce(p_enabled, false));
end $$;

create or replace function public.get_mentor()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_today date;
  v_prof profiles;
  v_reports boolean;
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  select * into v_prof from profiles where id = v_uid;
  v_today := _local_today(v_uid);
  v_reports := _feature_allowed(v_uid, 'relatorios');
  if not v_prof.mentor_enabled then
    return jsonb_build_object('enabled', false, 'allowed', _feature_allowed(v_uid, 'mentor'), 'reports_allowed', v_reports);
  end if;
  perform _require_feature(v_uid, 'mentor');
  perform _mentor_refresh(v_uid, v_today);
  perform _mentor_cleanup(v_uid, v_today);
  return jsonb_build_object(
    'enabled', true, 'allowed', true, 'reports_allowed', v_reports,
    'mode', v_prof.mode,
    'insights', _mentor_insights(v_uid, v_today),
    'suggestions', (select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'kind', s.kind, 'data', s.data, 'created_on', s.created_on)
                                              order by s.created_on desc, s.kind), '[]'::jsonb)
                      from mentor_suggestions s where s.user_id = v_uid and s.status = 'aberta'),
    'this_week', case when v_reports and v_prof.program_start is not null
                      then _weekly_report(v_uid, (date_trunc('week', v_today::timestamp))::date, v_today) end,
    'reports', case when v_reports then
                 (select coalesce(jsonb_agg(jsonb_build_object('week_start', r.week_start, 'missions', r.data->'missions',
                                                               'goal_days', r.data->'goal_days') order by r.week_start desc), '[]'::jsonb)
                    from (select * from mentor_reports where user_id = v_uid order by week_start desc limit 12) r)
               else '[]'::jsonb end);
end $$;

create or replace function public.respond_suggestion(p_id uuid, p_accept boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  s mentor_suggestions;
  v_prof profiles;
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  select * into s from mentor_suggestions where id = p_id and user_id = v_uid and status = 'aberta' for update;
  if not found then raise exception 'sugestao_nao_encontrada'; end if;
  if not coalesce(p_accept, false) then
    update mentor_suggestions set status = 'recusada', responded_at = now() where id = s.id;
    return jsonb_build_object('status', 'recusada', 'kind', s.kind);
  end if;

  select * into v_prof from profiles where id = v_uid;
  if s.kind = 'reduzir_meta' then
    perform _adjust_habit(v_uid, (s.data->>'habit_id')::uuid, (s.data->>'to')::int, true);
  elsif s.kind = 'pausar_habito' then
    perform _adjust_habit(v_uid, (s.data->>'habit_id')::uuid,
                          (select current_target from user_habits where id = (s.data->>'habit_id')::uuid and user_id = v_uid), false);
  elsif s.kind in ('reduzir_minimo','aumentar_minimo') then
    if v_prof.mode = 'extremo' then raise exception 'modo_extremo_bloqueia_ajustes'; end if;
    perform _record_rules(v_uid, _local_today(v_uid), v_prof.mode, (s.data->>'to')::int, 'escolha');
  end if;
  update mentor_suggestions set status = 'aceita', responded_at = now() where id = s.id;
  return jsonb_build_object('status', 'aceita', 'kind', s.kind, 'link', s.data->>'link');
end $$;

create or replace function public.get_report(p_week date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v jsonb;
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  perform _require_feature(v_uid, 'relatorios');
  select r.data into v from mentor_reports r
   where r.user_id = v_uid and (p_week is null or r.week_start = p_week)
   order by r.week_start desc limit 1;
  if v is null then raise exception 'relatorio_nao_encontrado'; end if;
  return v;
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 12. Conquistas, manutenção do dia e avisos (substituem as versões da 0004)
-- ════════════════════════════════════════════════════════════════════════════

create or replace function public._achievement_metrics(p_uid uuid, p_today date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  j jsonb := _journey(p_uid, p_today);
  st character_stats;
  res jsonb;
begin
  select * into st from character_stats where user_id = p_uid;
  select jsonb_build_object(
    'missoes',          (select count(*) from missions where user_id = p_uid and status = 'concluida'),
    'melhor_sequencia', coalesce((j->>'best_streak')::int, 0),
    'dias_ativos',      (select count(*) from jsonb_array_elements(j->'days') e where (e->>'done')::int > 0),
    'dias_perfeitos',   (select count(*) from jsonb_array_elements(j->'days') e where (e->>'perfect')::boolean),
    'dias_desafio',     (select count(*) from jsonb_array_elements(j->'days') e where e->>'status' = 'completo' and e->>'mode' = 'desafio'),
    'dias_extremo',     (select count(*) from jsonb_array_elements(j->'days') e where e->>'status' = 'completo' and e->>'mode' = 'extremo'),
    'nivel',            coalesce(st.level, 1),
    'attr_disciplina',  _attr_level(st.disciplina),
    'attr_foco',        _attr_level(st.foco),
    'attr_vitalidade',  _attr_level(st.vitalidade),
    'attr_conhecimento',_attr_level(st.conhecimento),
    'attr_determinacao',_attr_level(st.determinacao),
    'attr_min',         least(_attr_level(st.disciplina), _attr_level(st.foco), _attr_level(st.vitalidade),
                              _attr_level(st.conhecimento), _attr_level(st.determinacao)),
    'areas',            (select count(distinct dimension) from missions where user_id = p_uid and status = 'concluida'),
    'revisoes',         (select count(*) from missions where user_id = p_uid and status = 'concluida' and kind = 'semanal'),
    'especiais',        (select count(*) from missions where user_id = p_uid and status = 'concluida' and kind = 'especial'),
    'surpresas',        (select count(*) from missions where user_id = p_uid and status = 'concluida' and kind = 'surpresa'),
    'metas_subiram',    (select count(*) from progression_events where user_id = p_uid),
    'ajustes_baixo',    (select count(*) from habit_adjustments where user_id = p_uid and new_target < old_target),
    'retornos',         (select count(*) from xp_ledger where user_id = p_uid and source = 'retorno'),
    'chefes',           (select count(distinct boss_id) from user_bosses where user_id = p_uid and status = 'vencido'),
    'amigos',           _friend_count(p_uid),
    'incentivos',       (select count(*) from cheers where sender = p_uid),
    'desafios',         (select count(*) from challenge_participants where user_id = p_uid and result in ('venceu','meta_coletiva')),
    'temporadas',       (select count(*) from season_results sr join league_catalog l on l.id = sr.league
                          where sr.user_id = p_uid and l.sort >= 2),
    'liga_max',         (select coalesce(max(l.sort), 0) from season_results sr join league_catalog l on l.id = sr.league
                          where sr.user_id = p_uid),
    'dias_agua',        (select count(*) from (select t.day, sum((t.data->>'cups')::int) as c from tool_logs t
                                                 where t.user_id = p_uid and t.tool = 'agua' group by t.day) w
                          where w.c >= _water_goal(p_uid, w.day)),
    'sessoes_foco',     (select count(*) from tool_logs t where t.user_id = p_uid and t.tool = 'foco' and (t.data->>'minutes')::int >= 20),
    'livros',           (select count(*) from books b where b.user_id = p_uid and b.status = 'concluido'
                            and exists (select 1 from tool_logs t where t.user_id = p_uid and t.tool = 'leitura'
                                          and t.data->>'book_id' = b.id::text)),
    'dias_diario',      (select count(distinct t.day) from tool_logs t where t.user_id = p_uid and t.tool = 'diario'),
    'min_meditacao',    (select coalesce(sum((t.data->>'minutes')::int), 0) from tool_logs t where t.user_id = p_uid and t.tool = 'meditacao')
  ) into res;
  return res;
end $$;

create or replace function public._daily_maintenance(p_uid uuid, p_today date, p_now timestamptz)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform _check_demotion(p_uid, p_today);
  perform _sync_boss(p_uid, p_today, p_now);
  perform _finalize_challenges(p_uid, p_today, p_now);
  perform _finalize_seasons(p_uid, p_today);
  perform _finalize_reports(p_uid, p_today);
  perform _progress_rewards(p_uid, p_today);
  perform _mentor_refresh(p_uid, p_today);
end $$;

create or replace function public.ensure_today()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  today date;
  r jsonb;
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  today := _local_today(uid);
  r := _ensure_day(uid, today);
  if coalesce((r->>'onboarding_done')::boolean, false) then
    perform _daily_maintenance(uid, today, now());
    r := r || jsonb_build_object('mode', (select mode from profiles where id = uid),
                                 'boss', _active_boss_summary(uid, today));
  end if;
  return r || jsonb_build_object(
    'social_unseen', _social_unseen(uid),
    'premium', _has_premium(uid),
    'mentor_open', (select count(*) from mentor_suggestions s join profiles p on p.id = s.user_id
                     where s.user_id = uid and s.status = 'aberta' and p.mentor_enabled));
end $$;

-- Avisos de recompensa (a tela de recompensa mostra uma vez). Os sociais ficam em get_notifications.
create or replace function public.pending_events()
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  return (
    select coalesce(jsonb_agg(jsonb_build_object(
      'id', e.id, 'kind', e.kind, 'ref', e.ref, 'created_at', e.created_at,
      'data', case e.kind
        when 'nivel' then jsonb_build_object('level', e.ref::int)
        when 'conquista' then (select to_jsonb(ac) || jsonb_build_object(
            'rewards', (select coalesce(jsonb_agg(jsonb_build_object('id', ic.id, 'name', ic.name, 'kind', ic.kind, 'slot', ic.slot, 'rarity', ic.rarity) order by ic.sort), '[]'::jsonb)
                          from item_catalog ic where ic.unlock_type = 'conquista' and ic.unlock_ref = ac.id))
          from achievement_catalog ac where ac.id = e.ref)
        when 'item' then (select to_jsonb(ic) from item_catalog ic where ic.id = e.ref)
        when 'chefe_vencido' then (select jsonb_build_object(
            'boss', to_jsonb(b), 'fight', to_jsonb(f),
            'xp', (select l.amount from xp_ledger l where l.user_id = uid and l.source = 'chefe' and l.ref = f.id::text),
            'rewards', case when f.rematch then '[]'::jsonb else
              (select coalesce(jsonb_agg(jsonb_build_object('id', ic.id, 'name', ic.name, 'kind', ic.kind, 'slot', ic.slot, 'rarity', ic.rarity) order by ic.sort), '[]'::jsonb)
                 from item_catalog ic where ic.unlock_type = 'chefe' and ic.unlock_ref = b.id) end)
          from user_bosses f join boss_catalog b on b.id = f.boss_id where f.id::text = e.ref and f.user_id = uid)
        when 'chefe_recuou' then (select jsonb_build_object('boss', to_jsonb(b), 'fight', to_jsonb(f))
          from user_bosses f join boss_catalog b on b.id = f.boss_id where f.id::text = e.ref and f.user_id = uid)
        when 'temporada' then (select jsonb_build_object(
            'season', sr.season, 'name', _season_name(sr.season), 'year', sr.season / 100,
            'points', sr.points, 'xp', sr.xp, 'league', to_jsonb(l),
            'rank', sr.data->'rank', 'of', sr.data->'of', 'goal_days', sr.data->'goal_days',
            'perfect_days', sr.data->'perfect_days', 'boss_wins', sr.data->'boss_wins')
          from season_results sr join league_catalog l on l.id = sr.league where sr.user_id = uid and sr.season::text = e.ref)
        when 'desafio_fim' then (select jsonb_build_object(
            'challenge', jsonb_build_object('id', c.id, 'title', c.title, 'kind', c.kind, 'metric', c.metric,
                                            'dimension', c.dimension, 'target', c.target, 'starts_on', c.starts_on, 'ends_on', c.ends_on),
            'score', cp.score, 'rank', cp.rank, 'result', cp.result, 'xp', cp.xp,
            'participants', (select count(*) from challenge_participants x where x.challenge_id = c.id and x.status = 'aceito'),
            'total', (select coalesce(sum(x.score), 0) from challenge_participants x where x.challenge_id = c.id and x.status = 'aceito'),
            'winners', (select coalesce(jsonb_agg(_lite(x.user_id)), '[]'::jsonb) from challenge_participants x
                         where x.challenge_id = c.id and x.result = 'venceu'))
          from challenges c join challenge_participants cp on cp.challenge_id = c.id and cp.user_id = uid where c.id::text = e.ref)
        when 'relatorio' then (select jsonb_build_object('week_start', r.week_start, 'week_end', r.week_start + 6,
            'missions', r.data->'missions', 'goal_days', r.data->'goal_days', 'days', r.data->'days', 'xp', r.data->'xp',
            'highlight', r.data->'highlight')
          from mentor_reports r where r.user_id = uid and r.week_start::text = e.ref)
        else jsonb_build_object('date', e.ref)
      end) order by e.id), '[]'::jsonb)
    from user_events e
    where e.user_id = uid and not e.seen
      and e.kind in ('nivel','conquista','item','chefe_vencido','chefe_recuou','modo_rebaixado','temporada','desafio_fim','relatorio'));
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 13. Permissões
-- ════════════════════════════════════════════════════════════════════════════

revoke insert, update, delete, truncate on all tables in schema public from anon, authenticated;
grant select on all tables in schema public to authenticated;

revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function
  -- MVP
  public.submit_assessment(jsonb),
  public.ensure_today(),
  public.complete_mission(uuid),
  public.undo_completion(uuid),
  public.create_custom_mission(text, text, text, int, int, boolean),
  public.adjust_habit(uuid, int, boolean),
  public.update_profile(text, text, int),
  public.get_journey(),
  public.xp_for_level(int),
  public.level_for_xp(int),
  -- Etapa 3
  public.get_bosses(),
  public.start_boss(text),
  public.abandon_boss(),
  public.get_achievements(),
  public.update_avatar(jsonb),
  public.set_title(text),
  public.set_mode(text, boolean),
  public.get_mode_info(),
  public.pending_events(),
  public.mark_events_seen(bigint[]),
  -- Etapa 4: plano, amigos, feed, grupos, desafios e temporadas
  public.get_plan_info(),
  public.get_social(),
  public.update_privacy(jsonb),
  public.reset_friend_code(),
  public.lookup_friend_code(text),
  public.send_friend_request(text),
  public.respond_friend_request(uuid, boolean),
  public.remove_friend(uuid),
  public.friend_profile(uuid),
  public.friends_feed(bigint),
  public.share_post(text, text),
  public.delete_post(bigint),
  public.send_cheer(bigint, uuid, text),
  public.get_notifications(),
  public.create_group(text, text),
  public.join_group(text),
  public.leave_group(uuid),
  public.remove_group_member(uuid, uuid),
  public.update_group(uuid, text, text),
  public.reset_group_code(uuid),
  public.get_groups(),
  public.group_detail(uuid),
  public.create_challenge(jsonb),
  public.respond_challenge(uuid, boolean),
  public.leave_challenge(uuid),
  public.cancel_challenge(uuid),
  public.get_challenges(),
  public.challenge_detail(uuid),
  public.get_season(),
  public.get_ranking(text, uuid, text),
  -- Etapa 4: ferramentas e Mentor
  public.update_tool_settings(jsonb),
  public.get_tool(text),
  public.log_tool(text, jsonb),
  public.delete_tool_log(bigint),
  public.tools_overview(),
  public.tool_history(text, int),
  public.get_diary(int),
  public.get_books(),
  public.save_book(uuid, text, text, int),
  public.set_book_status(uuid, text),
  public.habit_tracker(),
  public.set_mentor(boolean),
  public.get_mentor(),
  public.respond_suggestion(uuid, boolean),
  public.get_report(date)
to authenticated;
