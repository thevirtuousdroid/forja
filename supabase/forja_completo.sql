-- Forja · banco completo (cole tudo no SQL Editor do Supabase e clique em Run)
-- Só para um projeto NOVO. Num banco que já está em uso, rode apenas as migrações que faltam.

-- ═══ 0001_schema.sql ═══
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

-- ═══ 0002_game_engine.sql ═══
-- Forja · 0002 · Motor do jogo (autoridade do servidor)
-- Funções com prefixo "_" são internas: não ficam expostas ao app.

-- ── Fórmulas ────────────────────────────────────────────────────────────────

create or replace function public._xp_for(p_difficulty int, p_minutes int, p_kind text)
returns int language sql immutable as $$
  select greatest(1, round(
    10
    * (case p_difficulty when 1 then 1.0 when 2 then 1.5 when 3 then 2.2 when 4 then 3.0 else 4.0 end)
    * least(2.5, greatest(0.6, sqrt(greatest(p_minutes, 1) / 10.0)))
    * (case p_kind when 'semanal' then 2.5 when 'especial' then 3.0 when 'surpresa' then 1.2
                   when 'personalizada' then 0.8 else 1.0 end)
  ))::int
$$;

-- XP acumulado necessário para atingir o nível L
create or replace function public.xp_for_level(p_level int)
returns int language sql immutable as $$
  select round(100 * power(greatest(p_level - 1, 0), 1.8))::int
$$;

create or replace function public.level_for_xp(p_xp int)
returns int language plpgsql immutable as $$
declare l int := 1;
begin
  while public.xp_for_level(l + 1) <= p_xp loop
    l := l + 1;
  end loop;
  return l;
end $$;

create or replace function public._phase_for_day(p_day int)
returns int language sql immutable as $$
  select case
    when p_day <= 7  then 1
    when p_day <= 21 then 2
    when p_day <= 33 then 3
    when p_day <= 45 then 4
    when p_day <= 60 then 5
    when p_day <= 66 then 6
    else 7 end
$$;

create or replace function public._attr_for_dimension(p_dim text, out primary_attr text, out secondary_attr text)
language sql immutable as $$
  select case p_dim
           when 'fisica' then 'vitalidade' when 'mental' then 'foco' when 'intelectual' then 'conhecimento'
           when 'produtividade' then 'disciplina' when 'digital' then 'foco' else 'disciplina' end,
         case p_dim
           when 'fisica' then 'determinacao' when 'mental' then 'vitalidade' when 'intelectual' then 'foco'
           when 'produtividade' then 'foco' when 'digital' then 'disciplina' else 'vitalidade' end
$$;

create or replace function public._local_today(p_uid uuid)
returns date language sql stable as $$
  select (now() at time zone coalesce((select timezone from public.profiles where id = p_uid), 'America/Sao_Paulo'))::date
$$;

create or replace function public._est_minutes(p_unit text, p_target int, p_est int)
returns int language sql immutable as $$
  select case when p_unit = 'min' then p_target else p_est end
$$;

-- ── Estatísticas do personagem (sempre derivadas do histórico) ───────────────

create or replace function public._recalc_stats(p_uid uuid)
returns void language plpgsql security definer set search_path = public as $$
declare t record;
begin
  select coalesce(sum(amount),0) amount,
         coalesce(sum(disciplina),0) d, coalesce(sum(foco),0) f, coalesce(sum(vitalidade),0) v,
         coalesce(sum(conhecimento),0) c, coalesce(sum(determinacao),0) de
    into t from xp_ledger where user_id = p_uid;

  update character_stats set
    total_xp     = t.amount,
    level        = level_for_xp(t.amount::int),
    disciplina   = base_disciplina   + t.d,
    foco         = base_foco         + t.f,
    vitalidade   = base_vitalidade   + t.v,
    conhecimento = base_conhecimento + t.c,
    determinacao = base_determinacao + t.de,
    updated_at   = now()
  where user_id = p_uid;
end $$;

-- ── Cadastro: cria perfil e personagem ──────────────────────────────────────

create or replace function public._handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, display_name)
    values (new.id, left(coalesce(new.raw_user_meta_data->>'name', ''), 40));
  insert into character_stats (user_id) values (new.id);
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public._handle_new_user();

-- ── Avaliação inicial e plano de 66 dias ─────────────────────────────────────

create or replace function public._add_habit(p_uid uuid, p_template text, p_start_day int)
returns void language plpgsql security definer set search_path = public as $$
begin
  insert into user_habits (user_id, template_id, name, description, dimension, attr_primary, attr_secondary,
                           difficulty, unit, base_value, step, max_value, est_minutes, current_target, start_day, period)
  select p_uid, t.id, t.name, t.description, t.dimension, t.attr_primary, t.attr_secondary,
         t.difficulty, t.unit, t.base_value, t.step, t.max_value, t.est_minutes, t.base_value, p_start_day, t.period
    from mission_templates t
   where t.id = p_template
     and not exists (select 1 from user_habits h where h.user_id = p_uid and h.template_id = p_template);
end $$;

-- Tempo de agenda que um hábito ocupa (hábitos passivos, como "manhã sem celular", não ocupam)
create or replace function public._time_cost(p_template text)
returns int language sql stable as $$
  select case when passive then 0 else _est_minutes(unit, base_value, est_minutes) end
    from public.mission_templates where id = p_template
$$;

-- p_start_budget: tempo para o dia 1 (60% do disponível); p_full_budget: tempo total disponível,
-- usado pelos hábitos que entram depois, quando a rotina já está mais estável.
create or replace function public._build_plan(p_uid uuid, p_priorities text[], p_start_budget int, p_full_budget int,
                                              p_need_water boolean, p_need_sleep boolean)
returns void language plpgsql security definer set search_path = public as $$
declare
  used int := 0;
  tmpl record;
  dim text;
  slots int[] := array[8, 22, 34];
  i int;
  cost int;
begin
  -- Dia 1: um hábito inicial por prioridade, dentro do orçamento (mínimo de dois hábitos)
  foreach dim in array p_priorities loop
    select * into tmpl from mission_templates
      where dimension = dim and tier = 1
      order by sort limit 1;
    cost := _time_cost(tmpl.id);
    if used + cost <= p_start_budget or (select count(*) from user_habits where user_id = p_uid) < 2 then
      perform _add_habit(p_uid, tmpl.id, 1);
      used := used + cost;
    end if;
  end loop;

  if p_need_water then perform _add_habit(p_uid, 'auto_agua', 1); end if;
  if p_need_sleep then perform _add_habit(p_uid, 'fis_sono', 1);  end if;

  -- Dias 8, 22 e 34: hábitos de continuação, em ordem de prioridade
  for i in 1 .. least(array_length(p_priorities, 1), 3) loop
    for tmpl in select * from mission_templates t
      where t.dimension = p_priorities[i] and t.tier in (1, 2)
        and not exists (select 1 from user_habits h where h.user_id = p_uid and h.template_id = t.id)
      order by t.tier desc, t.sort loop
      cost := _time_cost(tmpl.id);
      if used + cost <= p_full_budget then
        perform _add_habit(p_uid, tmpl.id, slots[i]);
        used := used + cost;
        exit;
      end if;
    end loop;
  end loop;
end $$;

-- Respostas pontuadas de 0 (mais difícil) a 3 (melhor situação)
create or replace function public.submit_assessment(p_answers jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  prof profiles;
  q text;
  v int;
  scores jsonb;
  dims text[] := array['fisica','mental','intelectual','produtividade','digital','autocuidado'];
  goal text := p_answers->>'main_goal';
  minutes int := (p_answers->>'daily_minutes')::int;
  prio text[];
  first_time boolean;
  required text[] := array['exercise','diet','sleep_hours','sleep_quality','stress','rest','reflection',
                           'reading','learning','planning','procrastination','discipline',
                           'screen_time','phone_morning','focus','water','morning_routine','environment'];
  function_result jsonb;
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  select * into prof from profiles where id = uid for update;

  foreach q in array required loop
    v := (p_answers->>q)::int;
    if v is null or v < 0 or v > 3 then raise exception 'resposta_invalida: %', q; end if;
  end loop;
  if goal is null or not goal = any(dims) then raise exception 'resposta_invalida: main_goal'; end if;
  if minutes is null or minutes not in (15, 30, 45, 60, 90) then raise exception 'resposta_invalida: daily_minutes'; end if;

  scores := jsonb_build_object(
    'fisica',        round(((p_answers->>'exercise')::int + (p_answers->>'diet')::int + (p_answers->>'sleep_hours')::int + (p_answers->>'sleep_quality')::int) / 12.0 * 100),
    'mental',        round(((p_answers->>'stress')::int + (p_answers->>'rest')::int + (p_answers->>'reflection')::int) / 9.0 * 100),
    'intelectual',   round(((p_answers->>'reading')::int + (p_answers->>'learning')::int) / 6.0 * 100),
    'produtividade', round(((p_answers->>'planning')::int + (p_answers->>'procrastination')::int + (p_answers->>'discipline')::int) / 9.0 * 100),
    'digital',       round(((p_answers->>'screen_time')::int + (p_answers->>'phone_morning')::int + (p_answers->>'focus')::int) / 9.0 * 100),
    'autocuidado',   round(((p_answers->>'water')::int + (p_answers->>'morning_routine')::int + (p_answers->>'environment')::int) / 9.0 * 100)
  );

  -- Prioridades: objetivo principal + as duas dimensões mais fracas
  select array[goal] || array(
           select d from unnest(dims) d
            where d <> goal
            order by (scores->>d)::int, array_position(dims, d)
            limit 2)
    into prio;

  first_time := not prof.onboarding_done;

  insert into assessments (user_id, answers, scores, priorities)
    values (uid, p_answers, scores, prio);

  if char_length(trim(coalesce(p_answers->>'display_name', ''))) > 0 then
    update profiles set display_name = left(trim(p_answers->>'display_name'), 40) where id = uid;
  end if;

  if first_time then
    update profiles set program_start = _local_today(uid), onboarding_done = true,
                        min_daily_missions = case when (p_answers->>'discipline')::int <= 1 then 1 else 2 end
     where id = uid;

    perform _build_plan(uid, prio, round(minutes * 0.6)::int, minutes,
                        (p_answers->>'water')::int <= 1,
                        (p_answers->>'sleep_hours')::int <= 1 or (p_answers->>'sleep_quality')::int <= 1);

    update character_stats set
      base_disciplina   = round(((scores->>'produtividade')::int + (scores->>'autocuidado')::int) / 2.0 * 0.6),
      base_foco         = round(((scores->>'digital')::int + (scores->>'mental')::int) / 2.0 * 0.6),
      base_vitalidade   = round((scores->>'fisica')::int * 0.6),
      base_conhecimento = round((scores->>'intelectual')::int * 0.6),
      base_determinacao = round((p_answers->>'discipline')::int / 3.0 * 60)
    where user_id = uid;
    perform _recalc_stats(uid);
    perform _ensure_day(uid, _local_today(uid));
  end if;

  return jsonb_build_object('scores', scores, 'priorities', to_jsonb(prio), 'first_time', first_time);
end $$;

-- ── Geração diária de missões (idempotente) ─────────────────────────────────

create or replace function public._insert_mission(
  p_uid uuid, p_habit uuid, p_key text, p_kind text, p_name text, p_desc text, p_dim text,
  p_a1 text, p_a2 text, p_diff int, p_target int, p_unit text, p_est int, p_period text,
  p_freq text, p_date date, p_due date)
returns void language sql security definer set search_path = public as $$
  insert into missions (user_id, habit_id, dedupe_key, kind, name, description, dimension, attr_primary, attr_secondary,
                        difficulty, estimated_minutes, target_value, unit, period, frequency, xp_reward, mission_date, due_date)
  values (p_uid, p_habit, p_key, p_kind, p_name, p_desc, p_dim, p_a1, p_a2,
          p_diff, _est_minutes(p_unit, p_target, p_est), p_target, p_unit, p_period, p_freq,
          _xp_for(p_diff, _est_minutes(p_unit, p_target, p_est), p_kind), p_date, p_due)
  on conflict (user_id, dedupe_key) do nothing
$$;

create or replace function public._ensure_day(p_uid uuid, p_today date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  prof profiles;
  day_n int;
  phase int;
  week int;
  h record;
  t record;
  done int;
  new_target int;
  n_surprise int;
begin
  select * into prof from profiles where id = p_uid;
  if not prof.onboarding_done then
    return jsonb_build_object('onboarding_done', false);
  end if;

  day_n := (p_today - prof.program_start) + 1;
  phase := _phase_for_day(day_n);
  week  := (day_n - 1) / 7 + 1;

  -- Expira o que passou do prazo
  update missions set status = 'expirada'
   where user_id = p_uid and status = 'pendente' and due_date < p_today;

  -- Progressão semanal (uma vez por semana do programa)
  if day_n > 1 and (day_n - 1) % 7 = 0 then
    insert into progression_checks (user_id, week) values (p_uid, week) on conflict do nothing;
    if found then
      for h in select * from user_habits
                where user_id = p_uid and active and step > 0
                  and current_target < max_value and start_day <= day_n - 7 loop
        select count(*) into done from missions
         where habit_id = h.id and status = 'concluida'
           and mission_date between p_today - 7 and p_today - 1;
        if done >= 5 then
          new_target := least(h.current_target + h.step, h.max_value);
          update user_habits set current_target = new_target where id = h.id;
          insert into progression_events (user_id, habit_id, week, old_target, new_target, completed_days)
            values (p_uid, h.id, week, h.current_target, new_target, done);
        end if;
      end loop;
    end if;
  end if;

  -- Missões diárias dos hábitos ativos
  for h in select * from user_habits where user_id = p_uid and active and start_day <= day_n loop
    perform _insert_mission(p_uid, h.id, 'h:' || h.id || ':' || p_today, 'diaria', h.name, h.description, h.dimension,
                            h.attr_primary, h.attr_secondary, h.difficulty, h.current_target, h.unit, h.est_minutes,
                            h.period, 'diaria', p_today, p_today);
  end loop;

  -- Missão semanal: revisão da semana, no primeiro dia de cada semana do programa
  if (day_n - 1) % 7 = 0 then
    perform _insert_mission(p_uid, null, 'sem:' || week, 'semanal', 'Revisão da semana',
      'Olhe para os últimos dias: o que funcionou, o que travou e qual é a sua prioridade nesta semana. Anote em poucas linhas.',
      'produtividade', 'disciplina', 'determinacao', 2, 15, 'min', 15, 'qualquer', 'semanal', p_today, p_today + 6);
  end if;

  -- Missão surpresa opcional a partir da fase 2
  if phase >= 2 then
    select count(*) into n_surprise from mission_templates where tier = 9;
    select * into t from mission_templates where tier = 9 order by sort offset (day_n % n_surprise) limit 1;
    perform _insert_mission(p_uid, null, 'sur:' || p_today, 'surpresa', t.name, t.description, t.dimension,
      t.attr_primary, t.attr_secondary, t.difficulty, t.base_value, t.unit, t.est_minutes, t.period, 'unica', p_today, p_today);
  end if;

  -- Missão especial a partir da fase 3, no 4º dia de cada semana: sessão estendida de um hábito
  if phase >= 3 and (day_n - 1) % 7 = 3 then
    select * into h from user_habits
     where user_id = p_uid and active and unit = 'min' and start_day <= day_n
     order by (select count(*) from missions m where m.habit_id = user_habits.id and m.status = 'concluida') desc, created_at
     limit 1;
    if found then
      perform _insert_mission(p_uid, h.id, 'esp:' || week, 'especial', 'Sessão estendida: ' || h.name,
        'Uma vez nesta semana, faça uma sessão maior que a sua meta diária. Vale em qualquer dia até o fim da semana.',
        h.dimension, h.attr_primary, 'determinacao', least(h.difficulty + 1, 5),
        least(h.current_target * 2, h.max_value * 2), 'min', h.est_minutes, h.period, 'unica', p_today, p_today + 3);
    end if;
  end if;

  return jsonb_build_object('onboarding_done', true, 'today', p_today, 'day', day_n, 'phase', phase, 'week', week);
end $$;

create or replace function public.ensure_today()
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  return _ensure_day(uid, _local_today(uid));
end $$;

-- ── Concluir e desfazer missões ─────────────────────────────────────────────

create or replace function public._completed_on(p_uid uuid, p_day date, p_tz text)
returns int language sql stable as $$
  select count(*)::int from public.missions
   where user_id = p_uid and status = 'concluida'
     and (completed_at at time zone p_tz)::date = p_day
$$;

create or replace function public._apply_day_bonuses(p_uid uuid, p_day date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  prof profiles;
  n int;
  bonuses jsonb := '[]'::jsonb;
  prev_any boolean;
begin
  select * into prof from profiles where id = p_uid;
  n := _completed_on(p_uid, p_day, prof.timezone);

  if n >= prof.min_daily_missions then
    insert into xp_ledger (user_id, source, day, amount, disciplina)
      values (p_uid, 'meta_diaria', p_day, 15, 15) on conflict do nothing;
    if found then bonuses := bonuses || '[{"tipo":"meta_diaria","xp":15}]'::jsonb; end if;

    -- Retorno: ontem em branco, mas havia atividade antes disso
    if p_day - 1 >= prof.program_start
       and _completed_on(p_uid, p_day - 1, prof.timezone) = 0 then
      select exists (select 1 from missions where user_id = p_uid and status = 'concluida'
                      and (completed_at at time zone prof.timezone)::date < p_day - 1) into prev_any;
      if prev_any then
        insert into xp_ledger (user_id, source, day, amount, determinacao)
          values (p_uid, 'retorno', p_day, 20, 20) on conflict do nothing;
        if found then bonuses := bonuses || '[{"tipo":"retorno","xp":20}]'::jsonb; end if;
      end if;
    end if;
  else
    -- Abaixo da meta (ex.: após desfazer): os bônus do dia deixam de valer
    delete from xp_ledger where user_id = p_uid and day = p_day and source in ('meta_diaria','retorno');
  end if;
  return bonuses;
end $$;

create or replace function public._complete_mission(p_uid uuid, p_mission uuid, p_now timestamptz)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  m missions;
  prof profiles;
  today date;
  xp int;
  n_today int;
  n_custom int;
  part1 int;
  lvl_before int;
  stats character_stats;
  bonuses jsonb;
begin
  select * into prof from profiles where id = p_uid;
  today := (p_now at time zone prof.timezone)::date;

  select * into m from missions where id = p_mission and user_id = p_uid for update;
  if not found then raise exception 'missao_nao_encontrada'; end if;
  if m.status = 'concluida' then
    return jsonb_build_object('ja_concluida', true);
  end if;
  if today < m.mission_date or today > m.due_date then
    raise exception 'fora_do_prazo';
  end if;

  select level into lvl_before from character_stats where user_id = p_uid;

  n_today := _completed_on(p_uid, today, prof.timezone);
  select count(*) into n_custom from missions
   where user_id = p_uid and status = 'concluida' and kind = 'personalizada'
     and (completed_at at time zone prof.timezone)::date = today;

  xp := m.xp_reward;
  if m.kind = 'personalizada' and n_custom >= 3 then xp := greatest(1, round(xp * 0.25)); end if;
  if n_today >= 12 then xp := greatest(1, round(xp * 0.5)); end if;

  update missions set status = 'concluida', completed_at = p_now where id = m.id;

  part1 := round(xp * 0.7);
  insert into xp_ledger (user_id, mission_id, source, day, amount, disciplina, foco, vitalidade, conhecimento, determinacao)
  values (p_uid, m.id, 'missao', today, xp,
    (case when m.attr_primary = 'disciplina'   then part1 else 0 end) + (case when m.attr_secondary = 'disciplina'   then xp - part1 else 0 end),
    (case when m.attr_primary = 'foco'         then part1 else 0 end) + (case when m.attr_secondary = 'foco'         then xp - part1 else 0 end),
    (case when m.attr_primary = 'vitalidade'   then part1 else 0 end) + (case when m.attr_secondary = 'vitalidade'   then xp - part1 else 0 end),
    (case when m.attr_primary = 'conhecimento' then part1 else 0 end) + (case when m.attr_secondary = 'conhecimento' then xp - part1 else 0 end),
    (case when m.attr_primary = 'determinacao' then part1 else 0 end) + (case when m.attr_secondary = 'determinacao' then xp - part1 else 0 end));

  bonuses := _apply_day_bonuses(p_uid, today);
  perform _recalc_stats(p_uid);
  select * into stats from character_stats where user_id = p_uid;

  return jsonb_build_object(
    'ja_concluida', false,
    'xp', xp,
    'bonus', bonuses,
    'nivel_antes', lvl_before,
    'nivel', stats.level,
    'xp_total', stats.total_xp);
end $$;

create or replace function public.complete_mission(p_mission uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  return _complete_mission(uid, p_mission, now());
end $$;

-- Desfazer só no mesmo dia (toque errado)
create or replace function public._undo_completion(p_uid uuid, p_mission uuid, p_now timestamptz)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  m missions;
  prof profiles;
  today date;
begin
  select * into prof from profiles where id = p_uid;
  today := (p_now at time zone prof.timezone)::date;
  select * into m from missions where id = p_mission and user_id = p_uid for update;
  if not found then raise exception 'missao_nao_encontrada'; end if;
  if m.status <> 'concluida' then return jsonb_build_object('desfeita', false); end if;
  if (m.completed_at at time zone prof.timezone)::date <> today then raise exception 'so_no_mesmo_dia'; end if;

  delete from xp_ledger where mission_id = m.id;
  update missions set status = 'pendente', completed_at = null where id = m.id;
  perform _apply_day_bonuses(p_uid, today);
  perform _recalc_stats(p_uid);
  return jsonb_build_object('desfeita', true);
end $$;

create or replace function public.undo_completion(p_mission uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  return _undo_completion(uid, p_mission, now());
end $$;

-- ── Missões personalizadas e ajustes ────────────────────────────────────────

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
    select count(*) into n from user_habits where user_id = uid and active and is_custom;
    if n >= 12 then raise exception 'limite_habitos'; end if;
    select count(*) into n from user_habits where user_id = uid and active and is_custom;
    if prof.plan = 'free' and n >= 2 then raise exception 'limite_gratuito_personalizadas'; end if;

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

-- Ajustar meta (entre a meta inicial e o teto) ou pausar um hábito
create or replace function public.adjust_habit(p_habit uuid, p_target int, p_active boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  h user_habits;
  today date;
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  select * into h from user_habits where id = p_habit and user_id = uid for update;
  if not found then raise exception 'habito_nao_encontrado'; end if;
  if (select mode from profiles where id = uid) = 'extremo' then raise exception 'modo_extremo_bloqueia_ajustes'; end if;
  if p_target is null or p_target not between h.base_value and h.max_value then raise exception 'meta_fora_do_intervalo'; end if;

  update user_habits set current_target = p_target, active = coalesce(p_active, active) where id = h.id;

  -- A missão pendente de hoje acompanha o ajuste
  today := _local_today(uid);
  update missions m set
    target_value = p_target,
    estimated_minutes = _est_minutes(h.unit, p_target, h.est_minutes),
    xp_reward = _xp_for(m.difficulty, _est_minutes(h.unit, p_target, h.est_minutes), m.kind)
  where m.habit_id = h.id and m.kind = 'diaria' and m.mission_date = today and m.status = 'pendente';

  if p_active = false then
    delete from missions where habit_id = h.id and mission_date = today and status = 'pendente' and kind = 'diaria';
  end if;
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.update_profile(p_display_name text, p_timezone text, p_min_daily int)
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  if p_timezone is not null and not exists (select 1 from pg_timezone_names where name = p_timezone) then
    raise exception 'fuso_invalido';
  end if;
  if p_min_daily is not null and p_min_daily not between 1 and 10 then raise exception 'meta_invalida'; end if;
  update profiles set
    display_name = coalesce(left(trim(p_display_name), 40), display_name),
    timezone = coalesce(p_timezone, timezone),
    min_daily_missions = coalesce(p_min_daily, min_daily_missions)
  where id = uid;
  return jsonb_build_object('ok', true);
end $$;

-- ── Jornada: calendário, sequência, escudos e consistência ───────────────────

create or replace function public._journey(p_uid uuid, p_today date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  prof profiles;
  d date;
  n_done int;
  n_total int;
  st text;
  streak int := 0;
  best int := 0;
  shields int := 0;
  max_shields int;
  good_days int := 0;
  past_days int := 0;
  days jsonb := '[]'::jsonb;
begin
  select * into prof from profiles where id = p_uid;
  if prof.program_start is null then return jsonb_build_object('days', days); end if;
  max_shields := case prof.mode when 'normal' then 2 when 'desafio' then 1 else 0 end;

  d := prof.program_start;
  while d <= p_today loop
    n_done := _completed_on(p_uid, d, prof.timezone);
    select count(*) into n_total from missions where user_id = p_uid and mission_date = d and kind = 'diaria';

    if n_done >= prof.min_daily_missions then
      st := 'completo';
      streak := streak + 1;
      if streak % 7 = 0 and shields < max_shields then shields := shields + 1; end if;
    elsif d = p_today then
      st := case when n_done > 0 then 'parcial' else 'hoje' end;
    elsif n_done > 0 then
      st := 'parcial';
      streak := 0;
    elsif shields > 0 then
      st := 'protegido';
      shields := shields - 1;
    else
      st := 'vazio';
      streak := 0;
    end if;

    best := greatest(best, streak);
    if d < p_today then
      past_days := past_days + 1;
      if st = 'completo' then good_days := good_days + 1; end if;
    end if;
    days := days || jsonb_build_object('date', d, 'status', st, 'done', n_done, 'total', n_total);
    d := d + 1;
  end loop;

  -- Hoje conta para a consistência só depois que a meta é batida
  if exists (select 1 from jsonb_array_elements(days) e where e->>'date' = p_today::text and e->>'status' = 'completo') then
    past_days := past_days + 1; good_days := good_days + 1;
  end if;

  return jsonb_build_object(
    'current_streak', streak,
    'best_streak', best,
    'shields', shields,
    'max_shields', max_shields,
    'consistency', case when past_days = 0 then null else round(good_days * 100.0 / past_days) end,
    'milestones', (select coalesce(jsonb_agg(m), '[]') from unnest(array[7,14,21,33,45,66,90,132]) m where m <= best),
    'days', days);
end $$;

create or replace function public.get_journey()
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  return _journey(uid, _local_today(uid));
end $$;

-- ── Administração (rodar no SQL Editor do Supabase, não é exposta ao app) ────

create or replace function public.admin_set_plan(p_email text, p_plan text)
returns void language plpgsql security definer set search_path = public as $$
begin
  update profiles set plan = p_plan
   where id = (select id from auth.users where email = p_email);
  if not found then raise exception 'usuario_nao_encontrado'; end if;
end $$;

-- ── Permissões de execução ──────────────────────────────────────────────────

revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function
  public.submit_assessment(jsonb),
  public.ensure_today(),
  public.complete_mission(uuid),
  public.undo_completion(uuid),
  public.create_custom_mission(text, text, text, int, int, boolean),
  public.adjust_habit(uuid, int, boolean),
  public.update_profile(text, text, int),
  public.get_journey(),
  public.xp_for_level(int),
  public.level_for_xp(int)
to authenticated;

-- ═══ 0003_catalog.sql ═══
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

-- ═══ 0004_rpg.sql ═══
-- Forja · 0004 · Etapa 3: personagem, inventário, títulos, conquistas, chefes e modos de dificuldade
--
-- Pode ser aplicada num banco que já tem 0001–0003 e usuários com dados.
-- Também pode ser rodada de novo sem estragar nada (tudo usa "if not exists" / "on conflict").
-- Regra geral continua a mesma: o app só LÊ; tudo que dá XP, item ou vitória passa por funções do servidor.

-- ════════════════════════════════════════════════════════════════════════════
-- 1. Tabelas
-- ════════════════════════════════════════════════════════════════════════════

alter table public.profiles add column if not exists avatar jsonb not null default '{}'::jsonb;
alter table public.profiles add column if not exists active_title text;
alter table public.profiles add column if not exists mode_cooldown_until date;

-- Histórico de regras (modo e meta mínima). Cada dia é julgado pelas regras que valiam naquele dia,
-- então mudar o modo ou a meta não reescreve o passado.
create table if not exists public.rules_history (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  started_on  date not null,
  mode        text not null check (mode in ('normal','desafio','extremo')),
  min_daily   smallint not null check (min_daily between 1 and 10),
  reason      text not null default 'escolha' check (reason in ('inicial','escolha','rebaixado')),
  created_at  timestamptz not null default now()
);
create index if not exists rules_history_user_idx on public.rules_history (user_id, started_on desc, id desc);

-- Ajustes de meta feitos pela pessoa (alimenta a conquista "Ajuste consciente" e, no futuro, a IA)
create table if not exists public.habit_adjustments (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  habit_id    uuid not null references public.user_habits(id) on delete cascade,
  old_target  integer not null,
  new_target  integer not null,
  paused      boolean not null default false,
  created_at  timestamptz not null default now()
);
create index if not exists habit_adjustments_user_idx on public.habit_adjustments (user_id);

-- Equipamentos e títulos
create table if not exists public.item_catalog (
  id            text primary key,
  kind          text not null check (kind in ('equipamento','titulo')),
  slot          text check (slot in ('cabeca','corpo','capa','arma','amuleto','moldura')),
  name          text not null,
  description   text not null,
  rarity        text not null check (rarity in ('comum','raro','epico','lendario')),
  unlock_type   text not null check (unlock_type in ('inicial','nivel','conquista','chefe')),
  unlock_level  integer,
  unlock_ref    text,
  sort          smallint not null default 0,
  check ((kind = 'equipamento') = (slot is not null)),
  check ((unlock_type = 'nivel') = (unlock_level is not null)),
  check ((unlock_type in ('conquista','chefe')) = (unlock_ref is not null))
);

create table if not exists public.user_items (
  user_id      uuid not null references public.profiles(id) on delete cascade,
  item_id      text not null references public.item_catalog(id),
  source       text not null,
  unlocked_at  timestamptz not null default now(),
  primary key (user_id, item_id)
);

-- Conquistas
create table if not exists public.achievement_catalog (
  id          text primary key,
  category    text not null check (category in ('missoes','sequencia','programa','nivel','atributos','habitos','chefes','modos')),
  name        text not null,
  description text not null,
  rarity      text not null check (rarity in ('comum','raro','epico','lendario')),
  metric      text not null,
  threshold   integer not null check (threshold > 0),
  xp          integer not null default 0 check (xp >= 0),
  attr        text not null check (attr in ('disciplina','foco','vitalidade','conhecimento','determinacao')),
  hidden      boolean not null default false,
  sort        smallint not null default 0
);

create table if not exists public.user_achievements (
  user_id         uuid not null references public.profiles(id) on delete cascade,
  achievement_id  text not null references public.achievement_catalog(id),
  unlocked_at     timestamptz not null default now(),
  primary key (user_id, achievement_id)
);

-- Chefes
create table if not exists public.boss_catalog (
  id                  text primary key,
  name                text not null,
  epithet             text not null,
  story               text not null,
  objective           text not null,
  difficulty          smallint not null check (difficulty between 1 and 5),
  hit_rule            text not null check (hit_rule in ('dimensao','meta_diaria','dia_perfeito')),
  dimension           text check (dimension in ('fisica','mental','intelectual','produtividade','digital','autocuidado')),
  hp                  smallint not null check (hp > 0),
  window_days         smallint not null,
  unlock_day          smallint not null default 1,
  requires_victories  smallint not null default 0,
  xp_reward           integer not null,
  attr_primary        text not null,
  attr_secondary      text not null,
  sort                smallint not null,
  check ((hit_rule = 'dimensao') = (dimension is not null)),
  check (window_days >= hp)
);

create table if not exists public.user_bosses (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles(id) on delete cascade,
  boss_id      text not null references public.boss_catalog(id),
  started_on   date not null,
  deadline     date not null,
  hp           integer not null,
  hits         integer not null default 0,
  heals        integer not null default 0,
  rematch      boolean not null default false,
  status       text not null default 'ativo' check (status in ('ativo','vencido','recuou','desistiu')),
  finished_at  timestamptz,
  created_at   timestamptz not null default now(),
  check (deadline >= started_on)
);
create unique index if not exists user_bosses_one_active on public.user_bosses (user_id) where status = 'ativo';
create index if not exists user_bosses_user_idx on public.user_bosses (user_id, boss_id);

-- Avisos que o app mostra uma vez (conquista, item, nível, vitória, recuo, rebaixamento)
create table if not exists public.user_events (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  kind        text not null check (kind in ('nivel','conquista','item','chefe_vencido','chefe_recuou','modo_rebaixado')),
  ref         text not null,
  seen        boolean not null default false,
  created_at  timestamptz not null default now(),
  unique (user_id, kind, ref)
);
create index if not exists user_events_unseen_idx on public.user_events (user_id) where not seen;

-- Histórico de XP: novas origens e referência (conquista ou batalha)
alter table public.xp_ledger add column if not exists ref text;
alter table public.xp_ledger drop constraint if exists xp_ledger_source_check;
alter table public.xp_ledger add constraint xp_ledger_source_check
  check (source in ('missao','meta_diaria','retorno','marco','conquista','chefe'));
drop index if exists public.xp_ledger_bonus_once;
create unique index if not exists xp_ledger_daily_bonus_once on public.xp_ledger (user_id, source, day)
  where source in ('meta_diaria','retorno');
create unique index if not exists xp_ledger_ref_once on public.xp_ledger (user_id, source, ref) where ref is not null;

-- ── Segurança das novas tabelas ─────────────────────────────────────────────
alter table public.rules_history        enable row level security;
alter table public.habit_adjustments    enable row level security;
alter table public.item_catalog         enable row level security;
alter table public.user_items           enable row level security;
alter table public.achievement_catalog  enable row level security;
alter table public.user_achievements    enable row level security;
alter table public.boss_catalog         enable row level security;
alter table public.user_bosses          enable row level security;
alter table public.user_events          enable row level security;

drop policy if exists "ler as próprias regras" on public.rules_history;
create policy "ler as próprias regras" on public.rules_history for select using (user_id = auth.uid());
drop policy if exists "ler os próprios ajustes" on public.habit_adjustments;
create policy "ler os próprios ajustes" on public.habit_adjustments for select using (user_id = auth.uid());
drop policy if exists "catálogo de itens" on public.item_catalog;
create policy "catálogo de itens" on public.item_catalog for select using (auth.uid() is not null);
drop policy if exists "ler os próprios itens" on public.user_items;
create policy "ler os próprios itens" on public.user_items for select using (user_id = auth.uid());
drop policy if exists "catálogo de conquistas" on public.achievement_catalog;
create policy "catálogo de conquistas" on public.achievement_catalog for select using (auth.uid() is not null);
drop policy if exists "ler as próprias conquistas" on public.user_achievements;
create policy "ler as próprias conquistas" on public.user_achievements for select using (user_id = auth.uid());
drop policy if exists "catálogo de chefes" on public.boss_catalog;
create policy "catálogo de chefes" on public.boss_catalog for select using (auth.uid() is not null);
drop policy if exists "ler as próprias batalhas" on public.user_bosses;
create policy "ler as próprias batalhas" on public.user_bosses for select using (user_id = auth.uid());
drop policy if exists "ler os próprios avisos" on public.user_events;
create policy "ler os próprios avisos" on public.user_events for select using (user_id = auth.uid());

-- ════════════════════════════════════════════════════════════════════════════
-- 2. Catálogos
-- ════════════════════════════════════════════════════════════════════════════

insert into public.boss_catalog
  (id, name, epithet, story, objective, difficulty, hit_rule, dimension, hp, window_days, unlock_day, requires_victories, xp_reward, attr_primary, attr_secondary, sort)
values
  ('tempestade', 'A Tempestade Interna', 'Guardiã da Sobrecarga',
   'Ela se forma quando tudo acontece ao mesmo tempo dentro da sua cabeça. Não se vence com força, e sim com pausas. Cada momento de calma tira um pouco do vento dela.',
   'Golpe: cada dia em que você concluir ao menos uma missão de Saúde mental.',
   1, 'dimensao', 'mental', 5, 7, 2, 0, 100, 'foco', 'vitalidade', 1),
  ('adiador', 'O Adiador', 'Chefe da Procrastinação',
   'Ele mora no "só mais cinco minutos". Cada tarefa adiada vira um grão na ampulheta dele, e a areia nunca cai. Golpes de execução fazem o vidro rachar.',
   'Golpe: cada dia em que você concluir ao menos uma missão de Disciplina e produtividade.',
   1, 'dimensao', 'produtividade', 5, 7, 2, 0, 100, 'disciplina', 'determinacao', 2),
  ('hidra', 'A Hidra das Notificações', 'Guardiã das Distrações',
   'Corte uma cabeça e outra pisca na tela. A Hidra se alimenta da sua atenção em pedaços e só enfraquece com períodos de foco de verdade.',
   'Golpe: cada dia em que você concluir ao menos uma missão de Saúde digital.',
   2, 'dimensao', 'digital', 7, 10, 8, 0, 160, 'foco', 'disciplina', 3),
  ('nevoa', 'A Névoa do Esquecimento', 'Guardiã do Esquecimento',
   'Ela apaga devagar o que você não revisita. Páginas viram fumaça e ideias perdem a forma. Cada sessão de leitura ou estudo abre uma clareira.',
   'Golpe: cada dia em que você concluir ao menos uma missão de Desenvolvimento intelectual.',
   2, 'dimensao', 'intelectual', 7, 10, 8, 0, 160, 'conhecimento', 'foco', 4),
  ('sentinela', 'A Sentinela de Pedra', 'Sentinela do Desconforto',
   'Ela guarda a porta entre o confortável e o possível. Não ataca: só espera que você desista de passar. Cada dia de movimento racha a pedra.',
   'Golpe: cada dia em que você concluir ao menos uma missão de Saúde física.',
   3, 'dimensao', 'fisica', 10, 14, 15, 0, 240, 'vitalidade', 'determinacao', 5),
  ('errante', 'O Errante', 'Mestre da Inconsistência',
   'Ele nunca está no mesmo lugar dois dias seguidos e quer que você também não esteja. Começa forte, some, volta. Só a constância o prende.',
   'Golpe: cada dia em que você cumprir a sua meta do dia.',
   3, 'meta_diaria', null, 12, 16, 22, 0, 300, 'disciplina', 'determinacao', 6),
  ('juiz', 'O Juiz da Bigorna', 'Desafio da Disciplina',
   'O último guardião da Forja. Não aceita meio esforço: só reconhece dias em que todo o plano foi cumprido. Vencê-lo é mostrar que a disciplina virou rotina.',
   'Golpe: cada dia em que você concluir todas as missões diárias do seu plano.',
   5, 'dia_perfeito', null, 14, 20, 34, 3, 450, 'determinacao', 'disciplina', 7)
on conflict (id) do update set
  name = excluded.name, epithet = excluded.epithet, story = excluded.story, objective = excluded.objective,
  difficulty = excluded.difficulty, hit_rule = excluded.hit_rule, dimension = excluded.dimension, hp = excluded.hp,
  window_days = excluded.window_days, unlock_day = excluded.unlock_day, requires_victories = excluded.requires_victories,
  xp_reward = excluded.xp_reward, attr_primary = excluded.attr_primary, attr_secondary = excluded.attr_secondary, sort = excluded.sort;

insert into public.achievement_catalog (id, category, name, description, rarity, metric, threshold, xp, attr, hidden, sort) values
  -- Missões
  ('m_1',   'missoes', 'Primeira faísca',  'Conclua sua primeira missão.',  'comum',    'missoes', 1,   20,  'disciplina',   false, 1),
  ('m_25',  'missoes', 'Ritmo de forja',   'Conclua 25 missões.',           'comum',    'missoes', 25,  40,  'disciplina',   false, 2),
  ('m_100', 'missoes', 'Cem golpes',       'Conclua 100 missões.',          'raro',     'missoes', 100, 100, 'determinacao', false, 3),
  ('m_300', 'missoes', 'Mão calejada',     'Conclua 300 missões.',          'epico',    'missoes', 300, 180, 'determinacao', false, 4),
  ('m_750', 'missoes', 'Incansável',       'Conclua 750 missões.',          'lendario', 'missoes', 750, 300, 'determinacao', false, 5),
  -- Sequência (marcos)
  ('s_7',   'sequencia', 'Uma semana inteira', 'Cumpra a meta do dia por 7 dias seguidos.',   'comum',    'melhor_sequencia', 7,   40,  'disciplina', false, 10),
  ('s_14',  'sequencia', 'Duas semanas firmes','Cumpra a meta do dia por 14 dias seguidos.',  'raro',     'melhor_sequencia', 14,  60,  'disciplina', false, 11),
  ('s_21',  'sequencia', 'Vinte e um dias',    'Cumpra a meta do dia por 21 dias seguidos.',  'raro',     'melhor_sequencia', 21,  80,  'disciplina', false, 12),
  ('s_33',  'sequencia', 'Trinta e três',      'Cumpra a meta do dia por 33 dias seguidos.',  'epico',    'melhor_sequencia', 33,  110, 'disciplina', false, 13),
  ('s_45',  'sequencia', 'Quarenta e cinco',   'Cumpra a meta do dia por 45 dias seguidos.',  'epico',    'melhor_sequencia', 45,  140, 'disciplina', false, 14),
  ('s_66',  'sequencia', 'A marca dos 66',     'Cumpra a meta do dia por 66 dias seguidos.',  'lendario', 'melhor_sequencia', 66,  200, 'disciplina', false, 15),
  ('s_90',  'sequencia', 'Noventa dias',       'Cumpra a meta do dia por 90 dias seguidos.',  'lendario', 'melhor_sequencia', 90,  250, 'disciplina', false, 16),
  ('s_132', 'sequencia', 'O dobro do caminho', 'Cumpra a meta do dia por 132 dias seguidos.', 'lendario', 'melhor_sequencia', 132, 320, 'disciplina', false, 17),
  -- Programa (dias ativos, não precisam ser seguidos)
  ('p_7',  'programa', 'Adaptação',         'Fique ativo em 7 dias, seguidos ou não.',  'comum',    'dias_ativos', 7,  30,  'determinacao', false, 20),
  ('p_21', 'programa', 'Construção',        'Fique ativo em 21 dias, seguidos ou não.', 'raro',     'dias_ativos', 21, 60,  'determinacao', false, 21),
  ('p_33', 'programa', 'Consolidação',      'Fique ativo em 33 dias, seguidos ou não.', 'raro',     'dias_ativos', 33, 90,  'determinacao', false, 22),
  ('p_45', 'programa', 'Evolução',          'Fique ativo em 45 dias, seguidos ou não.', 'epico',    'dias_ativos', 45, 120, 'determinacao', false, 23),
  ('p_66', 'programa', 'Programa completo', 'Fique ativo em 66 dias, seguidos ou não.', 'lendario', 'dias_ativos', 66, 220, 'determinacao', false, 24),
  -- Nível (sem XP, para não alimentar a si mesmo)
  ('n_5',  'nivel', 'Primeiro brilho', 'Alcance o nível 5.',  'comum',    'nivel', 5,  0, 'determinacao', false, 30),
  ('n_10', 'nivel', 'Aço temperado',   'Alcance o nível 10.', 'raro',     'nivel', 10, 0, 'determinacao', false, 31),
  ('n_15', 'nivel', 'Têmpera dupla',   'Alcance o nível 15.', 'epico',    'nivel', 15, 0, 'determinacao', false, 32),
  ('n_20', 'nivel', 'Liga rara',       'Alcance o nível 20.', 'epico',    'nivel', 20, 0, 'determinacao', false, 33),
  ('n_30', 'nivel', 'Metal lendário',  'Alcance o nível 30.', 'lendario', 'nivel', 30, 0, 'determinacao', false, 34),
  -- Atributos
  ('a_disciplina',   'atributos', 'Vontade de ferro', 'Leve Disciplina ao nível 5.',          'raro',  'attr_disciplina',   5, 50,  'disciplina',   false, 40),
  ('a_foco',         'atributos', 'Mente afiada',     'Leve Foco ao nível 5.',                'raro',  'attr_foco',         5, 50,  'foco',         false, 41),
  ('a_vitalidade',   'atributos', 'Corpo desperto',   'Leve Vitalidade ao nível 5.',          'raro',  'attr_vitalidade',   5, 50,  'vitalidade',   false, 42),
  ('a_conhecimento', 'atributos', 'Sede de saber',    'Leve Conhecimento ao nível 5.',        'raro',  'attr_conhecimento', 5, 50,  'conhecimento', false, 43),
  ('a_determinacao', 'atributos', 'Coração firme',    'Leve Determinação ao nível 5.',        'raro',  'attr_determinacao', 5, 50,  'determinacao', false, 44),
  ('a_equilibrio',   'atributos', 'Equilíbrio',       'Leve os cinco atributos ao nível 4.',  'epico', 'attr_min',          4, 120, 'determinacao', false, 45),
  -- Hábitos
  ('h_areas',    'habitos', 'Seis frentes',      'Conclua missões nas seis áreas.',                                   'raro',  'areas',         6,  60, 'conhecimento', false, 50),
  ('h_revisao',  'habitos', 'Olhar para trás',   'Conclua 4 revisões da semana.',                                     'comum', 'revisoes',      4,  50, 'disciplina',   false, 51),
  ('h_especial', 'habitos', 'Além da meta',      'Conclua 3 missões especiais.',                                      'raro',  'especiais',     3,  60, 'determinacao', false, 52),
  ('h_surpresa', 'habitos', 'Curiosidade',       'Conclua 10 missões surpresa.',                                      'comum', 'surpresas',     10, 50, 'conhecimento', false, 53),
  ('h_evolucao', 'habitos', 'Metas em alta',     'Tenha 5 metas aumentadas pela progressão semanal.',                 'raro',  'metas_subiram', 5,  60, 'determinacao', false, 54),
  ('h_perfeito', 'habitos', 'Dias impecáveis',   'Conclua todas as missões diárias do plano em 7 dias.',              'epico', 'dias_perfeitos',7,  90, 'disciplina',   false, 55),
  ('h_retorno',  'habitos', 'Voltar é vencer',   'Cumpra a meta logo depois de um dia em branco.',                    'comum', 'retornos',      1,  30, 'determinacao', false, 56),
  ('h_fenix',    'habitos', 'Fênix',             'Volte depois de um dia em branco 5 vezes.',                         'epico', 'retornos',      5,  80, 'determinacao', false, 57),
  ('h_ajuste',   'habitos', 'Ajuste consciente', 'Reduza uma meta que estava pesada. Ajustar também é evoluir.',      'comum', 'ajustes_baixo', 1,  20, 'foco',         true,  58),
  -- Chefes
  ('c_1', 'chefes', 'Primeira vitória',  'Vença um chefe.',               'raro',     'chefes', 1, 50,  'determinacao', false, 60),
  ('c_4', 'chefes', 'Caça-chefes',       'Vença 4 chefes diferentes.',    'epico',    'chefes', 4, 120, 'determinacao', false, 61),
  ('c_7', 'chefes', 'A forja em paz',    'Vença os 7 chefes.',            'lendario', 'chefes', 7, 300, 'determinacao', false, 62),
  -- Modos
  ('md_desafio',   'modos', 'Espírito desafiante', 'Cumpra a meta em 14 dias no modo Desafio.', 'epico',    'dias_desafio', 14, 100, 'determinacao', false, 70),
  ('md_extremo7',  'modos', 'Sem rede',            'Cumpra a meta em 7 dias no modo Extremo.',  'epico',    'dias_extremo', 7,  120, 'determinacao', false, 71),
  ('md_extremo21', 'modos', 'Inquebrável',         'Cumpra a meta em 21 dias no modo Extremo.', 'lendario', 'dias_extremo', 21, 250, 'determinacao', false, 72)
on conflict (id) do update set
  category = excluded.category, name = excluded.name, description = excluded.description, rarity = excluded.rarity,
  metric = excluded.metric, threshold = excluded.threshold, xp = excluded.xp, attr = excluded.attr,
  hidden = excluded.hidden, sort = excluded.sort;

insert into public.item_catalog (id, kind, slot, name, description, rarity, unlock_type, unlock_level, unlock_ref, sort) values
  -- Cabeça
  ('cab_faixa',         'equipamento', 'cabeca', 'Faixa de ferreiro',  'Segura o suor no primeiro dia de forja.',      'comum',    'inicial',   null, null,         10),
  ('cab_capuz',         'equipamento', 'cabeca', 'Capuz do viajante',  'Para quem já pegou a estrada.',                'comum',    'nivel',     3,    null,         11),
  ('cab_elmo_silencio', 'equipamento', 'cabeca', 'Elmo do Silêncio',   'Abafa o ruído das notificações.',              'raro',     'chefe',     null, 'hidra',      12),
  ('cab_elmo_ferro',    'equipamento', 'cabeca', 'Elmo de ferro',      'Forjado para durar.',                          'raro',     'nivel',     10,   null,         13),
  ('cab_coroa',         'equipamento', 'cabeca', 'Coroa de brasa',     'Sessenta e seis dias seguidos acesos.',        'lendario', 'conquista', null, 's_66',       14),
  -- Corpo
  ('cor_tunica',        'equipamento', 'corpo',  'Túnica de aprendiz', 'Simples e honesta.',                           'comum',    'inicial',   null, null,         20),
  ('cor_gibao',         'equipamento', 'corpo',  'Gibão de couro',     'Couro curtido no trabalho diário.',            'comum',    'nivel',     5,    null,         21),
  ('cor_malha',         'equipamento', 'corpo',  'Cota de malha',      'Mil elos, um para cada esforço.',              'raro',     'nivel',     12,   null,         22),
  ('cor_sentinela',     'equipamento', 'corpo',  'Peitoral da Sentinela', 'Pedra que não cede ao desconforto.',        'epico',    'chefe',     null, 'sentinela',  23),
  ('cor_placas',        'equipamento', 'corpo',  'Armadura de placas', 'Aço sobre aço, camada sobre camada.',          'epico',    'nivel',     20,   null,         24),
  -- Capa
  ('cap_curta',         'equipamento', 'capa',   'Capa curta',         'O primeiro passo para parecer da Forja.',      'comum',    'nivel',     2,    null,         30),
  ('cap_constante',     'equipamento', 'capa',   'Manto do Constante', 'Tecido com fios de todos os dias.',            'epico',    'chefe',     null, 'errante',    31),
  ('cap_fenix',         'equipamento', 'capa',   'Capa da Fênix',      'Para quem sempre volta.',                      'epico',    'conquista', null, 'h_fenix',    32),
  ('cap_mestre',        'equipamento', 'capa',   'Capa da Bigorna',    'Forro de brasa, peso de experiência.',         'lendario', 'nivel',     25,   null,         33),
  -- Arma (ferramenta)
  ('arm_martelo',       'equipamento', 'arma',   'Martelo de aprendiz','Leve, mas já faz faísca.',                     'comum',    'inicial',   null, null,         40),
  ('arm_cajado',        'equipamento', 'arma',   'Cajado do Erudito',  'Ilumina o que a névoa esconde.',               'raro',     'chefe',     null, 'nevoa',      41),
  ('arm_lamina',        'equipamento', 'arma',   'Lâmina do Foco',     'Corta distrações pela raiz.',                  'raro',     'conquista', null, 'a_foco',     42),
  ('arm_martelo_juiz',  'equipamento', 'arma',   'Martelo do Juiz',    'O golpe final da disciplina.',                 'lendario', 'chefe',     null, 'juiz',       43),
  -- Amuleto
  ('amu_ampulheta',     'equipamento', 'amuleto','Ampulheta quebrada', 'O tempo voltou a correr.',                     'raro',     'chefe',     null, 'adiador',    50),
  ('amu_calma',         'equipamento', 'amuleto','Pedra da calma',     'Fria na mão, quente no peito.',                'raro',     'chefe',     null, 'tempestade', 51),
  ('amu_equilibrio',    'equipamento', 'amuleto','Amuleto do equilíbrio','Cinco pontos, um centro.',                   'epico',    'conquista', null, 'a_equilibrio', 52),
  -- Moldura (evolui com o nível)
  ('mol_bronze',        'equipamento', 'moldura','Moldura de bronze',  'Onde toda forja começa.',                      'comum',    'inicial',   null, null,         60),
  ('mol_ferro',         'equipamento', 'moldura','Moldura de ferro',   'Rebites firmes, primeiros resultados.',        'comum',    'nivel',     4,    null,         61),
  ('mol_aco',           'equipamento', 'moldura','Moldura de aço',     'Duas voltas de aço temperado.',                'raro',     'nivel',     8,    null,         62),
  ('mol_runas',         'equipamento', 'moldura','Moldura rúnica',     'Marcas de quem já atravessou fases.',          'epico',    'nivel',     15,   null,         63),
  ('mol_chamas',        'equipamento', 'moldura','Moldura de chamas',  'O fogo agora é seu.',                          'lendario', 'nivel',     25,   null,         64),
  ('mol_66',            'equipamento', 'moldura','Moldura dos 66',     'Para quem completou o programa.',              'lendario', 'conquista', null, 'p_66',       65),
  -- Títulos
  ('tit_aprendiz',      'titulo', null, 'Aprendiz da Forja',   'Título inicial.',                   'comum',    'inicial',   null, null,           100),
  ('tit_faisca',        'titulo', null, 'Faísca Constante',    'Alcance o nível 4.',                'comum',    'nivel',     4,    null,           101),
  ('tit_aco',           'titulo', null, 'Aço Temperado',       'Alcance o nível 8.',                'raro',     'nivel',     8,    null,           102),
  ('tit_coracao',       'titulo', null, 'Coração de Bigorna',  'Alcance o nível 15.',               'epico',    'nivel',     15,   null,           103),
  ('tit_lenda',         'titulo', null, 'Lenda da Bigorna',    'Alcance o nível 25.',               'lendario', 'nivel',     25,   null,           104),
  ('tit_ampulhetas',    'titulo', null, 'Quebra-Ampulhetas',   'Vença o Adiador.',                  'raro',     'chefe',     null, 'adiador',      110),
  ('tit_tempestade',    'titulo', null, 'Olho da Tempestade',  'Vença a Tempestade Interna.',       'raro',     'chefe',     null, 'tempestade',   111),
  ('tit_hidra',         'titulo', null, 'Silêncio da Hidra',   'Vença a Hidra das Notificações.',   'raro',     'chefe',     null, 'hidra',        112),
  ('tit_nevoa',         'titulo', null, 'Luz na Névoa',        'Vença a Névoa do Esquecimento.',    'raro',     'chefe',     null, 'nevoa',        113),
  ('tit_muralha',       'titulo', null, 'Muralha Viva',        'Vença a Sentinela de Pedra.',       'epico',    'chefe',     null, 'sentinela',    114),
  ('tit_constante',     'titulo', null, 'Passo Constante',     'Vença o Errante.',                  'epico',    'chefe',     null, 'errante',      115),
  ('tit_juiz',          'titulo', null, 'Marca do Juiz',       'Vença o Juiz da Bigorna.',          'lendario', 'chefe',     null, 'juiz',         116),
  ('tit_fenix',         'titulo', null, 'Fênix',               'Conquista "Fênix".',                'epico',    'conquista', null, 'h_fenix',      120),
  ('tit_equilibrio',    'titulo', null, 'Centro de Equilíbrio','Conquista "Equilíbrio".',           'epico',    'conquista', null, 'a_equilibrio', 121),
  ('tit_desafiante',    'titulo', null, 'Espírito Desafiante', 'Conquista "Espírito desafiante".',  'epico',    'conquista', null, 'md_desafio',   122),
  ('tit_inquebravel',   'titulo', null, 'Inquebrável',         'Conquista "Inquebrável".',          'lendario', 'conquista', null, 'md_extremo21', 123),
  ('tit_incansavel',    'titulo', null, 'Incansável',          'Conquista "Incansável".',           'lendario', 'conquista', null, 'm_750',        124),
  ('tit_cacachefes',    'titulo', null, 'Caça-Chefes',         'Conquista "Caça-chefes".',          'epico',    'conquista', null, 'c_4',          125),
  ('tit_66',            'titulo', null, 'Chama dos 66',        'Conquista "A marca dos 66".',       'lendario', 'conquista', null, 's_66',         126)
on conflict (id) do update set
  kind = excluded.kind, slot = excluded.slot, name = excluded.name, description = excluded.description,
  rarity = excluded.rarity, unlock_type = excluded.unlock_type, unlock_level = excluded.unlock_level,
  unlock_ref = excluded.unlock_ref, sort = excluded.sort;

-- ════════════════════════════════════════════════════════════════════════════
-- 3. Regras por dia (modo e meta)
-- ════════════════════════════════════════════════════════════════════════════

create or replace function public._attr_level(p_xp int)
returns int language sql immutable as $$
  select floor(sqrt(greatest(p_xp, 0) / 30.0))::int + 1
$$;

create or replace function public._int_in(p jsonb, lo int, hi int)
returns boolean language sql immutable as $$
  select case when jsonb_typeof(p) = 'number'
              then (p::text)::numeric = trunc((p::text)::numeric) and (p::text)::numeric between lo and hi
              else false end
$$;

-- Estatística de cada dia num intervalo, julgada pelas regras daquele dia:
--   normal  → meta = mínimo diário
--   desafio → meta = maior entre o mínimo e 60% das missões diárias do dia
--   extremo → todas as missões diárias do dia (e pelo menos o mínimo)
create or replace function public._day_stats(p_uid uuid, p_from date, p_to date)
returns table(day date, done int, daily_total int, daily_done int, dims text[], mode text, min_daily int, goal int, goal_met boolean)
language sql stable security definer set search_path = public as $$
  with prof as (
    select timezone, min_daily_missions, mode from profiles where id = p_uid
  ),
  days as (
    select g::date as day from generate_series(p_from::timestamp, p_to::timestamp, interval '1 day') g
  ),
  comp as (
    select (m.completed_at at time zone prof.timezone)::date as day,
           count(*)::int as done,
           array_agg(distinct m.dimension) as dims
      from missions m cross join prof
     where m.user_id = p_uid and m.status = 'concluida'
     group by 1
  ),
  daily as (
    select m.mission_date as day, count(*)::int as total,
           (count(*) filter (where m.status = 'concluida'))::int as ddone
      from missions m
     where m.user_id = p_uid and m.kind = 'diaria' and m.mission_date between p_from and p_to
     group by 1
  ),
  base as (
    select d.day,
           coalesce(c.done, 0) as done,
           coalesce(dl.total, 0) as total,
           coalesce(dl.ddone, 0) as ddone,
           coalesce(c.dims, '{}'::text[]) as dims,
           coalesce(rh.mode, prof.mode) as mode,
           coalesce(rh.min_daily::int, prof.min_daily_missions::int) as min_daily
      from days d
      cross join prof
      left join comp c on c.day = d.day
      left join daily dl on dl.day = d.day
      left join lateral (
        select h.mode, h.min_daily from rules_history h
         where h.user_id = p_uid and h.started_on <= d.day
         order by h.started_on desc, h.id desc limit 1
      ) rh on true
  )
  select day, done, total, ddone, dims, mode, min_daily,
         case mode when 'normal'  then min_daily
                   when 'desafio' then greatest(min_daily, ceil(total * 0.6)::int)
                   else greatest(min_daily, total) end,
         case mode when 'normal'  then done >= min_daily
                   when 'desafio' then done >= greatest(min_daily, ceil(total * 0.6)::int)
                   else ddone >= total and done >= min_daily end
    from base
   order by day
$$;

-- Registra uma mudança de regra a partir de hoje (uma linha por dia; a última escolha do dia vale).
-- Na primeira mudança, guarda também as regras antigas desde o início do programa.
create or replace function public._record_rules(p_uid uuid, p_today date, p_mode text, p_min int, p_reason text)
returns void language plpgsql security definer set search_path = public as $$
declare prof profiles;
begin
  select * into prof from profiles where id = p_uid for update;
  if not exists (select 1 from rules_history where user_id = p_uid)
     and prof.program_start is not null and prof.program_start < p_today then
    insert into rules_history (user_id, started_on, mode, min_daily, reason)
      values (p_uid, prof.program_start, prof.mode, prof.min_daily_missions, 'inicial');
  end if;
  delete from rules_history where user_id = p_uid and started_on = p_today;
  insert into rules_history (user_id, started_on, mode, min_daily, reason)
    values (p_uid, p_today, p_mode, p_min, p_reason);
  update profiles set mode = p_mode, min_daily_missions = p_min where id = p_uid;
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 4. Funções do MVP atualizadas (mesmas assinaturas)
-- ════════════════════════════════════════════════════════════════════════════

-- Recalcula personagem a partir do histórico e avisa quando sobe de nível
create or replace function public._recalc_stats(p_uid uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  t record;
  old_level int;
  new_level int;
begin
  select level into old_level from character_stats where user_id = p_uid;
  select coalesce(sum(amount),0) amount,
         coalesce(sum(disciplina),0) d, coalesce(sum(foco),0) f, coalesce(sum(vitalidade),0) v,
         coalesce(sum(conhecimento),0) c, coalesce(sum(determinacao),0) de
    into t from xp_ledger where user_id = p_uid;
  new_level := level_for_xp(t.amount::int);

  update character_stats set
    total_xp     = t.amount,
    level        = new_level,
    disciplina   = base_disciplina   + t.d,
    foco         = base_foco         + t.f,
    vitalidade   = base_vitalidade   + t.v,
    conhecimento = base_conhecimento + t.c,
    determinacao = base_determinacao + t.de,
    updated_at   = now()
  where user_id = p_uid;

  if new_level > coalesce(old_level, 1) then
    insert into user_events (user_id, kind, ref)
      select p_uid, 'nivel', l::text from generate_series(coalesce(old_level, 1) + 1, new_level) l
    on conflict do nothing;
  end if;
end $$;

create or replace function public._apply_day_bonuses(p_uid uuid, p_day date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  prof profiles;
  met boolean;
  bonuses jsonb := '[]'::jsonb;
  prev_any boolean;
begin
  select * into prof from profiles where id = p_uid;
  select s.goal_met into met from _day_stats(p_uid, p_day, p_day) s;

  if met then
    insert into xp_ledger (user_id, source, day, amount, disciplina)
      values (p_uid, 'meta_diaria', p_day, 15, 15) on conflict do nothing;
    if found then bonuses := bonuses || '[{"tipo":"meta_diaria","xp":15}]'::jsonb; end if;

    if p_day - 1 >= prof.program_start
       and _completed_on(p_uid, p_day - 1, prof.timezone) = 0 then
      select exists (select 1 from missions where user_id = p_uid and status = 'concluida'
                      and (completed_at at time zone prof.timezone)::date < p_day - 1) into prev_any;
      if prev_any then
        insert into xp_ledger (user_id, source, day, amount, determinacao)
          values (p_uid, 'retorno', p_day, 20, 20) on conflict do nothing;
        if found then bonuses := bonuses || '[{"tipo":"retorno","xp":20}]'::jsonb; end if;
      end if;
    end if;
  else
    delete from xp_ledger where user_id = p_uid and day = p_day and source in ('meta_diaria','retorno');
  end if;
  return bonuses;
end $$;

-- Jornada: sequência, escudos (limite por modo), consistência e calendário
create or replace function public._journey(p_uid uuid, p_today date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  prof profiles;
  r record;
  st text;
  cap int;
  streak int := 0;
  best int := 0;
  shields int := 0;
  good_days int := 0;
  past_days int := 0;
  today_met boolean := false;
  days jsonb := '[]'::jsonb;
begin
  select * into prof from profiles where id = p_uid;
  cap := case prof.mode when 'normal' then 2 when 'desafio' then 1 else 0 end;
  if prof.program_start is null then
    return jsonb_build_object('current_streak', 0, 'best_streak', 0, 'shields', 0, 'max_shields', cap,
                              'consistency', null, 'milestones', '[]'::jsonb, 'days', days);
  end if;

  for r in select * from _day_stats(p_uid, prof.program_start, p_today) loop
    cap := case r.mode when 'normal' then 2 when 'desafio' then 1 else 0 end;
    shields := least(shields, cap);

    if r.goal_met then
      st := 'completo';
      streak := streak + 1;
      if streak % 7 = 0 and shields < cap then shields := shields + 1; end if;
    elsif r.day = p_today then
      st := case when r.done > 0 then 'parcial' else 'hoje' end;
    elsif r.done > 0 then
      st := 'parcial';
      streak := 0;
    elsif shields > 0 then
      st := 'protegido';
      shields := shields - 1;
    else
      st := 'vazio';
      streak := 0;
    end if;

    best := greatest(best, streak);
    if r.day < p_today then
      past_days := past_days + 1;
      if st = 'completo' then good_days := good_days + 1; end if;
    elsif st = 'completo' then
      today_met := true;
    end if;
    days := days || jsonb_build_object('date', r.day, 'status', st, 'done', r.done, 'total', r.daily_total,
                                       'goal', r.goal, 'mode', r.mode,
                                       'perfect', r.daily_total > 0 and r.daily_done = r.daily_total);
  end loop;

  if today_met then past_days := past_days + 1; good_days := good_days + 1; end if;

  return jsonb_build_object(
    'current_streak', streak,
    'best_streak', best,
    'shields', shields,
    'max_shields', cap,
    'consistency', case when past_days = 0 then null else round(good_days * 100.0 / past_days) end,
    'milestones', (select coalesce(jsonb_agg(m), '[]') from unnest(array[7,14,21,33,45,66,90,132]) m where m <= best),
    'days', days);
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 5. Itens, avatar e títulos
-- ════════════════════════════════════════════════════════════════════════════

-- Libera o que a pessoa já alcançou. Devolve quantos itens novos (fora os iniciais).
create or replace function public._grant_items(p_uid uuid)
returns int language plpgsql security definer set search_path = public as $$
declare
  lvl int;
  r record;
  c item_catalog;
  n int := 0;
  av jsonb;
  h bigint;
begin
  -- Aparência inicial diferente para cada pessoa (ela personaliza depois)
  select avatar into av from profiles where id = p_uid;
  if av is null or not (av ? 'equip') then
    h := abs(hashtext(p_uid::text)::bigint);
    update profiles set avatar = jsonb_build_object(
      'pele', h % 6, 'cabelo', (h / 7) % 8, 'corCabelo', (h / 61) % 8, 'barba', 0, 'corRoupa', (h / 13) % 6,
      'personalizado', false,
      'equip', jsonb_build_object('corpo', 'cor_tunica', 'moldura', 'mol_bronze'))
    where id = p_uid;
  end if;

  select level into lvl from character_stats where user_id = p_uid;

  for r in
    insert into user_items (user_id, item_id, source)
    select p_uid, ic.id, ic.unlock_type
      from item_catalog ic
     where ic.unlock_type = 'inicial'
        or (ic.unlock_type = 'nivel' and ic.unlock_level <= coalesce(lvl, 1))
        or (ic.unlock_type = 'conquista' and exists (
              select 1 from user_achievements a where a.user_id = p_uid and a.achievement_id = ic.unlock_ref))
        or (ic.unlock_type = 'chefe' and exists (
              select 1 from user_bosses b where b.user_id = p_uid and b.boss_id = ic.unlock_ref and b.status = 'vencido'))
    on conflict do nothing
    returning item_id
  loop
    select * into c from item_catalog where id = r.item_id;
    if c.unlock_type <> 'inicial' then
      n := n + 1;
      insert into user_events (user_id, kind, ref) values (p_uid, 'item', c.id) on conflict do nothing;
    end if;
    -- A moldura evolui sozinha com o nível (a pessoa pode trocar no inventário)
    if c.slot = 'moldura' and c.unlock_type = 'nivel' then
      update profiles set avatar = jsonb_set(avatar, '{equip,moldura}', to_jsonb(c.id)) where id = p_uid;
    end if;
  end loop;
  return n;
end $$;

create or replace function public.update_avatar(p_avatar jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  s text;
  v text;
  equip jsonb := '{}'::jsonb;
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  if p_avatar is null or jsonb_typeof(p_avatar) <> 'object' then raise exception 'aparencia_invalida'; end if;
  if not (_int_in(p_avatar->'pele', 0, 5) and _int_in(p_avatar->'cabelo', 0, 7) and _int_in(p_avatar->'corCabelo', 0, 7)
          and _int_in(p_avatar->'barba', 0, 2) and _int_in(p_avatar->'corRoupa', 0, 5)) then
    raise exception 'aparencia_invalida';
  end if;
  if p_avatar ? 'equip' and jsonb_typeof(p_avatar->'equip') <> 'object' then raise exception 'aparencia_invalida'; end if;

  foreach s in array array['cabeca','corpo','capa','arma','amuleto','moldura'] loop
    v := p_avatar->'equip'->>s;
    if v is not null then
      if not exists (select 1 from user_items ui join item_catalog ic on ic.id = ui.item_id
                      where ui.user_id = uid and ui.item_id = v and ic.kind = 'equipamento' and ic.slot = s) then
        raise exception 'item_nao_disponivel: %', v;
      end if;
      equip := equip || jsonb_build_object(s, v);
    end if;
  end loop;
  if not equip ? 'corpo' then equip := equip || '{"corpo":"cor_tunica"}'::jsonb; end if;
  if not equip ? 'moldura' then equip := equip || '{"moldura":"mol_bronze"}'::jsonb; end if;

  update profiles set avatar = jsonb_build_object(
    'pele', (p_avatar->>'pele')::int, 'cabelo', (p_avatar->>'cabelo')::int, 'corCabelo', (p_avatar->>'corCabelo')::int,
    'barba', (p_avatar->>'barba')::int, 'corRoupa', (p_avatar->>'corRoupa')::int,
    'personalizado', true, 'equip', equip)
  where id = uid;
  return (select avatar from profiles where id = uid);
end $$;

create or replace function public.set_title(p_title text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  if p_title is not null and not exists (
       select 1 from user_items ui join item_catalog ic on ic.id = ui.item_id
        where ui.user_id = uid and ui.item_id = p_title and ic.kind = 'titulo') then
    raise exception 'titulo_nao_disponivel';
  end if;
  update profiles set active_title = p_title where id = uid;
  return jsonb_build_object('ok', true);
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 6. Conquistas
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
    'chefes',           (select count(distinct boss_id) from user_bosses where user_id = p_uid and status = 'vencido')
  ) into res;
  return res;
end $$;

-- Desbloqueia o que foi alcançado. Conquistas são permanentes. Devolve quantas novas.
create or replace function public._check_achievements(p_uid uuid, p_today date)
returns int language plpgsql security definer set search_path = public as $$
declare
  m jsonb := _achievement_metrics(p_uid, p_today);
  r record;
  c achievement_catalog;
  n int := 0;
begin
  for r in
    insert into user_achievements (user_id, achievement_id)
    select p_uid, ac.id from achievement_catalog ac
     where coalesce((m->>ac.metric)::int, 0) >= ac.threshold
    on conflict do nothing
    returning achievement_id
  loop
    n := n + 1;
    select * into c from achievement_catalog where id = r.achievement_id;
    if c.xp > 0 then
      insert into xp_ledger (user_id, source, ref, day, amount, disciplina, foco, vitalidade, conhecimento, determinacao)
      values (p_uid, 'conquista', c.id, p_today, c.xp,
              case when c.attr = 'disciplina'   then c.xp else 0 end,
              case when c.attr = 'foco'         then c.xp else 0 end,
              case when c.attr = 'vitalidade'   then c.xp else 0 end,
              case when c.attr = 'conhecimento' then c.xp else 0 end,
              case when c.attr = 'determinacao' then c.xp else 0 end)
      on conflict do nothing;
    end if;
    insert into user_events (user_id, kind, ref) values (p_uid, 'conquista', c.id) on conflict do nothing;
  end loop;
  return n;
end $$;

-- Recalcula personagem, libera itens e conquistas (conquistas podem dar XP e subir o nível de novo).
create or replace function public._progress_rewards(p_uid uuid, p_today date)
returns void language plpgsql security definer set search_path = public as $$
declare
  i int := 0;
begin
  perform _recalc_stats(p_uid);
  perform _grant_items(p_uid);
  loop
    exit when _check_achievements(p_uid, p_today) = 0 or i >= 4;
    perform _recalc_stats(p_uid);
    perform _grant_items(p_uid);
    i := i + 1;
  end loop;
end $$;

create or replace function public._achievements(p_uid uuid, p_today date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare m jsonb := _achievement_metrics(p_uid, p_today);
begin
  return jsonb_build_object('items', (
    select coalesce(jsonb_agg(to_jsonb(ac) || jsonb_build_object(
             'unlocked_at', ua.unlocked_at,
             'current', least(coalesce((m->>ac.metric)::int, 0), ac.threshold),
             'rewards', (select coalesce(jsonb_agg(jsonb_build_object('id', ic.id, 'name', ic.name, 'kind', ic.kind, 'slot', ic.slot, 'rarity', ic.rarity) order by ic.sort), '[]'::jsonb)
                           from item_catalog ic where ic.unlock_type = 'conquista' and ic.unlock_ref = ac.id))
           order by ac.sort), '[]'::jsonb)
      from achievement_catalog ac
      left join user_achievements ua on ua.user_id = p_uid and ua.achievement_id = ac.id));
end $$;

create or replace function public.get_achievements()
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  return _achievements(uid, _local_today(uid));
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 7. Chefes
-- ════════════════════════════════════════════════════════════════════════════

-- Progresso de uma batalha, recalculado a partir das missões (sempre coerente, inclusive depois de desfazer):
--   golpe = dia que cumpre a regra do chefe
--   cura  = (Desafio) dia passado sem nenhuma missão · (Extremo) dia passado abaixo da meta
create or replace function public._boss_progress(p_uid uuid, p_fight uuid, p_today date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  f user_bosses;
  b boss_catalog;
  r record;
  q boolean;
  h boolean;
  eff int := 0;
  hits int := 0;
  heals int := 0;
  vday date;
  tday boolean := false;
  days jsonb := '[]'::jsonb;
begin
  select * into f from user_bosses where id = p_fight and user_id = p_uid;
  select * into b from boss_catalog where id = f.boss_id;

  for r in select * from _day_stats(p_uid, f.started_on, least(p_today, f.deadline)) loop
    q := case b.hit_rule
           when 'dimensao'    then b.dimension = any(r.dims)
           when 'meta_diaria' then r.goal_met
           else r.daily_total > 0 and r.daily_done = r.daily_total end;
    h := r.day < p_today and ((r.mode = 'desafio' and r.done = 0) or (r.mode = 'extremo' and not r.goal_met));
    if q then eff := eff + 1; hits := hits + 1; end if;
    if h and eff > 0 then eff := eff - 1; heals := heals + 1; else h := false; end if;
    if r.day = p_today then tday := q; end if;
    if eff >= f.hp and vday is null then vday := r.day; end if;
    days := days || jsonb_build_object('date', r.day, 'hit', q, 'heal', h);
  end loop;

  return jsonb_build_object('effective', least(eff, f.hp), 'hits', hits, 'heals', heals,
                            'victory_day', vday, 'today_hit', tday, 'days', days);
end $$;

create or replace function public._sync_boss(p_uid uuid, p_today date, p_now timestamptz)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  f user_bosses;
  b boss_catalog;
  p jsonb;
  before int;
  xp int;
  part1 int;
  st text := 'ativo';
begin
  select * into f from user_bosses where user_id = p_uid and status = 'ativo' for update;
  if not found then return null; end if;
  select * into b from boss_catalog where id = f.boss_id;
  before := f.hits;
  p := _boss_progress(p_uid, f.id, p_today);

  if (p->>'victory_day') is not null then
    st := 'vencido';
    update user_bosses set status = 'vencido', hits = f.hp, heals = (p->>'heals')::int, finished_at = p_now where id = f.id;
    xp := case when f.rematch then round(b.xp_reward * 0.5) else b.xp_reward end;
    part1 := round(xp * 0.7);
    insert into xp_ledger (user_id, source, ref, day, amount, disciplina, foco, vitalidade, conhecimento, determinacao)
    values (p_uid, 'chefe', f.id::text, p_today, xp,
      (case when b.attr_primary = 'disciplina'   then part1 else 0 end) + (case when b.attr_secondary = 'disciplina'   then xp - part1 else 0 end),
      (case when b.attr_primary = 'foco'         then part1 else 0 end) + (case when b.attr_secondary = 'foco'         then xp - part1 else 0 end),
      (case when b.attr_primary = 'vitalidade'   then part1 else 0 end) + (case when b.attr_secondary = 'vitalidade'   then xp - part1 else 0 end),
      (case when b.attr_primary = 'conhecimento' then part1 else 0 end) + (case when b.attr_secondary = 'conhecimento' then xp - part1 else 0 end),
      (case when b.attr_primary = 'determinacao' then part1 else 0 end) + (case when b.attr_secondary = 'determinacao' then xp - part1 else 0 end))
    on conflict do nothing;
    insert into user_events (user_id, kind, ref) values (p_uid, 'chefe_vencido', f.id::text) on conflict do nothing;
  elsif p_today > f.deadline then
    st := 'recuou';
    update user_bosses set status = 'recuou', hits = (p->>'effective')::int, heals = (p->>'heals')::int, finished_at = p_now
     where id = f.id;
    insert into user_events (user_id, kind, ref) values (p_uid, 'chefe_recuou', f.id::text) on conflict do nothing;
  else
    update user_bosses set hits = (p->>'effective')::int, heals = (p->>'heals')::int where id = f.id;
  end if;

  return jsonb_build_object('fight_id', f.id, 'boss_id', b.id, 'name', b.name, 'hp', f.hp, 'before', before,
                            'effective', case when st = 'vencido' then f.hp else (p->>'effective')::int end,
                            'today_hit', (p->>'today_hit')::boolean, 'status', st);
end $$;

create or replace function public._boss_lock(p_uid uuid, b boss_catalog, p_day int)
returns jsonb language plpgsql security definer set search_path = public as $$
declare wins int;
begin
  if p_day < b.unlock_day then
    return jsonb_build_object('reason', 'dia', 'day', b.unlock_day);
  end if;
  select count(distinct boss_id) into wins from user_bosses where user_id = p_uid and status = 'vencido';
  if wins < b.requires_victories then
    return jsonb_build_object('reason', 'vitorias', 'needed', b.requires_victories, 'have', wins);
  end if;
  if b.hit_rule = 'dimensao' and not exists (
       select 1 from user_habits where user_id = p_uid and active and dimension = b.dimension and start_day <= p_day) then
    return jsonb_build_object('reason', 'habito', 'dimension', b.dimension);
  end if;
  return null;
end $$;

create or replace function public._start_boss(p_uid uuid, p_boss text, p_today date, p_now timestamptz)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  prof profiles;
  b boss_catalog;
  lock jsonb;
  fid uuid;
begin
  select * into prof from profiles where id = p_uid;
  if not prof.onboarding_done then raise exception 'conclua_a_avaliacao'; end if;
  select * into b from boss_catalog where id = p_boss;
  if not found then raise exception 'chefe_nao_encontrado'; end if;
  if exists (select 1 from user_bosses where user_id = p_uid and status = 'ativo') then raise exception 'chefe_ja_ativo'; end if;

  lock := _boss_lock(p_uid, b, (p_today - prof.program_start) + 1);
  if lock is not null then raise exception 'chefe_bloqueado_%', lock->>'reason'; end if;

  insert into user_bosses (user_id, boss_id, started_on, deadline, hp, rematch)
  values (p_uid, b.id, p_today, p_today + b.window_days - 1, b.hp,
          exists (select 1 from user_bosses where user_id = p_uid and boss_id = b.id and status = 'vencido'))
  returning id into fid;

  -- Missões já concluídas hoje contam como o primeiro golpe
  perform _sync_boss(p_uid, p_today, p_now);
  perform _progress_rewards(p_uid, p_today);
  return jsonb_build_object('fight_id', fid);
end $$;

create or replace function public.start_boss(p_boss text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  return _start_boss(uid, p_boss, _local_today(uid), now());
end $$;

create or replace function public.abandon_boss()
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  update user_bosses set status = 'desistiu', finished_at = now() where user_id = uid and status = 'ativo';
  return jsonb_build_object('ok', found);
end $$;

create or replace function public._bosses(p_uid uuid, p_today date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  prof profiles;
  day_n int;
  act user_bosses;
  r boss_catalog;
  lock jsonb;
  fight jsonb;
  prog jsonb;
  st text;
  nvict int;
  last_fight jsonb;
  res jsonb := '[]'::jsonb;
begin
  select * into prof from profiles where id = p_uid;
  day_n := case when prof.program_start is null then 0 else (p_today - prof.program_start) + 1 end;
  select * into act from user_bosses where user_id = p_uid and status = 'ativo';

  for r in select * from boss_catalog order by sort loop
    lock := null; fight := null;
    select count(*) into nvict from user_bosses where user_id = p_uid and boss_id = r.id and status = 'vencido';
    select jsonb_build_object('status', status, 'finished_at', finished_at, 'hits', hits, 'hp', hp) into last_fight
      from user_bosses where user_id = p_uid and boss_id = r.id and status <> 'ativo'
     order by finished_at desc nulls last limit 1;

    if act.id is not null and act.boss_id = r.id then
      prog := _boss_progress(p_uid, act.id, p_today);
      st := 'ativo';
      fight := jsonb_build_object('id', act.id, 'started_on', act.started_on, 'deadline', act.deadline, 'hp', act.hp,
        'effective', (prog->>'effective')::int, 'heals', (prog->>'heals')::int, 'today_hit', prog->'today_hit',
        'days', prog->'days', 'days_left', act.deadline - p_today + 1, 'rematch', act.rematch);
    else
      lock := _boss_lock(p_uid, r, day_n);
      st := case when lock is not null then 'bloqueado' when nvict > 0 then 'vencido' else 'disponivel' end;
    end if;

    res := res || (to_jsonb(r) || jsonb_build_object(
      'state', st, 'lock', lock, 'fight', fight, 'victories', nvict, 'last', last_fight,
      'rewards', (select coalesce(jsonb_agg(jsonb_build_object('id', ic.id, 'name', ic.name, 'kind', ic.kind, 'slot', ic.slot, 'rarity', ic.rarity) order by ic.sort), '[]'::jsonb)
                    from item_catalog ic where ic.unlock_type = 'chefe' and ic.unlock_ref = r.id)));
  end loop;

  return jsonb_build_object('day', day_n, 'active', act.id, 'mode', prof.mode, 'bosses', res);
end $$;

create or replace function public.get_bosses()
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); today date;
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  today := _local_today(uid);
  perform _sync_boss(uid, today, now());
  return _bosses(uid, today);
end $$;

create or replace function public._active_boss_summary(p_uid uuid, p_today date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  f user_bosses;
  b boss_catalog;
  p jsonb;
begin
  select * into f from user_bosses where user_id = p_uid and status = 'ativo';
  if not found then return null; end if;
  select * into b from boss_catalog where id = f.boss_id;
  p := _boss_progress(p_uid, f.id, p_today);
  return jsonb_build_object('fight_id', f.id, 'boss_id', b.id, 'name', b.name, 'epithet', b.epithet,
    'hit_rule', b.hit_rule, 'dimension', b.dimension, 'hp', f.hp, 'effective', (p->>'effective')::int,
    'today_hit', (p->>'today_hit')::boolean, 'deadline', f.deadline, 'days_left', f.deadline - p_today + 1);
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 8. Modos de dificuldade
-- ════════════════════════════════════════════════════════════════════════════

create or replace function public._mode_since(p_uid uuid)
returns date language sql stable security definer set search_path = public as $$
  select coalesce(
    (select min(h.started_on) from rules_history h
      where h.user_id = p_uid and h.mode = p.mode
        and h.started_on > coalesce((select max(x.started_on) from rules_history x
                                      where x.user_id = p_uid and x.mode <> p.mode), '-infinity'::date)),
    p.program_start)
  from profiles p where p.id = p_uid
$$;

create or replace function public._extremo_failures(p_uid uuid, p_today date)
returns int language sql stable security definer set search_path = public as $$
  select count(*)::int
    from _day_stats(p_uid, greatest(p_today - 7, coalesce(_mode_since(p_uid), p_today)), p_today - 1) s
   where s.mode = 'extremo' and not s.goal_met
$$;

create or replace function public._mode_info(p_uid uuid, p_today date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  prof profiles;
  day_n int;
  best int;
  waiting boolean;
begin
  select * into prof from profiles where id = p_uid;
  day_n := case when prof.program_start is null then 0 else (p_today - prof.program_start) + 1 end;
  best := coalesce((_journey(p_uid, p_today)->>'best_streak')::int, 0);
  waiting := prof.mode_cooldown_until is not null and p_today < prof.mode_cooldown_until;
  return jsonb_build_object(
    'mode', prof.mode,
    'since', _mode_since(p_uid),
    'day', day_n,
    'best_streak', best,
    'cooldown_until', case when waiting then prof.mode_cooldown_until end,
    'extremo_failures', case when prof.mode = 'extremo' then _extremo_failures(p_uid, p_today) else 0 end,
    'desafio', jsonb_build_object('available', day_n >= 8, 'unlock_day', 8),
    'extremo', jsonb_build_object('available', day_n >= 22 and best >= 7 and not waiting,
                                  'unlock_day', 22, 'streak_needed', 7));
end $$;

create or replace function public.get_mode_info()
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  return _mode_info(uid, _local_today(uid));
end $$;

create or replace function public._set_mode(p_uid uuid, p_mode text, p_accept boolean, p_today date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  prof profiles;
  info jsonb;
begin
  select * into prof from profiles where id = p_uid;
  if not prof.onboarding_done then raise exception 'conclua_a_avaliacao'; end if;
  if p_mode not in ('normal','desafio','extremo') then raise exception 'modo_invalido'; end if;
  if p_mode = prof.mode then return jsonb_build_object('mode', p_mode, 'changed', false); end if;
  if p_mode <> 'normal' and not coalesce(p_accept, false) then raise exception 'aceite_as_regras'; end if;

  info := _mode_info(p_uid, p_today);
  if p_mode = 'desafio' and not (info->'desafio'->>'available')::boolean then raise exception 'modo_bloqueado_dia'; end if;
  if p_mode = 'extremo' then
    if (info->>'day')::int < 22 then raise exception 'modo_bloqueado_dia'; end if;
    if (info->>'best_streak')::int < 7 then raise exception 'modo_bloqueado_sequencia'; end if;
    if info->>'cooldown_until' is not null then raise exception 'modo_em_espera'; end if;
  end if;

  perform _record_rules(p_uid, p_today, p_mode, prof.min_daily_missions, 'escolha');
  -- Sair do Extremo antes da hora não tem custo de XP, mas é preciso esperar 7 dias para voltar
  if prof.mode = 'extremo' then
    update profiles set mode_cooldown_until = p_today + 7 where id = p_uid;
  end if;
  return jsonb_build_object('mode', p_mode, 'changed', true);
end $$;

create or replace function public.set_mode(p_mode text, p_accept boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  return _set_mode(uid, p_mode, p_accept, _local_today(uid));
end $$;

-- No Extremo, 3 dias abaixo da meta em 7 dias levam de volta ao modo Desafio
create or replace function public._check_demotion(p_uid uuid, p_today date)
returns boolean language plpgsql security definer set search_path = public as $$
declare prof profiles;
begin
  select * into prof from profiles where id = p_uid;
  if prof.mode <> 'extremo' then return false; end if;
  if _extremo_failures(p_uid, p_today) < 3 then return false; end if;
  perform _record_rules(p_uid, p_today, 'desafio', prof.min_daily_missions, 'rebaixado');
  update profiles set mode_cooldown_until = p_today + 7 where id = p_uid;
  insert into user_events (user_id, kind, ref) values (p_uid, 'modo_rebaixado', p_today::text) on conflict do nothing;
  return true;
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 9. Missões: concluir, desfazer, criar, ajustar (mesmas assinaturas do MVP)
-- ════════════════════════════════════════════════════════════════════════════

create or replace function public._complete_mission(p_uid uuid, p_mission uuid, p_now timestamptz)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  m missions;
  prof profiles;
  today date;
  xp int;
  n_today int;
  n_custom int;
  part1 int;
  lvl_before int;
  stats character_stats;
  bonuses jsonb;
  boss jsonb;
begin
  select * into prof from profiles where id = p_uid;
  today := (p_now at time zone prof.timezone)::date;

  select * into m from missions where id = p_mission and user_id = p_uid for update;
  if not found then raise exception 'missao_nao_encontrada'; end if;
  if m.status = 'concluida' then
    return jsonb_build_object('ja_concluida', true);
  end if;
  if today < m.mission_date or today > m.due_date then
    raise exception 'fora_do_prazo';
  end if;

  select level into lvl_before from character_stats where user_id = p_uid;

  n_today := _completed_on(p_uid, today, prof.timezone);
  select count(*) into n_custom from missions
   where user_id = p_uid and status = 'concluida' and kind = 'personalizada'
     and (completed_at at time zone prof.timezone)::date = today;

  xp := m.xp_reward;
  if m.kind = 'personalizada' and n_custom >= 3 then xp := greatest(1, round(xp * 0.25)); end if;
  if n_today >= 12 then xp := greatest(1, round(xp * 0.5)); end if;
  -- Regras mais exigentes rendem mais
  xp := greatest(1, round(xp * case prof.mode when 'desafio' then 1.2 when 'extremo' then 1.4 else 1.0 end));

  update missions set status = 'concluida', completed_at = p_now where id = m.id;

  part1 := round(xp * 0.7);
  insert into xp_ledger (user_id, mission_id, source, day, amount, disciplina, foco, vitalidade, conhecimento, determinacao)
  values (p_uid, m.id, 'missao', today, xp,
    (case when m.attr_primary = 'disciplina'   then part1 else 0 end) + (case when m.attr_secondary = 'disciplina'   then xp - part1 else 0 end),
    (case when m.attr_primary = 'foco'         then part1 else 0 end) + (case when m.attr_secondary = 'foco'         then xp - part1 else 0 end),
    (case when m.attr_primary = 'vitalidade'   then part1 else 0 end) + (case when m.attr_secondary = 'vitalidade'   then xp - part1 else 0 end),
    (case when m.attr_primary = 'conhecimento' then part1 else 0 end) + (case when m.attr_secondary = 'conhecimento' then xp - part1 else 0 end),
    (case when m.attr_primary = 'determinacao' then part1 else 0 end) + (case when m.attr_secondary = 'determinacao' then xp - part1 else 0 end));

  bonuses := _apply_day_bonuses(p_uid, today);
  perform _recalc_stats(p_uid);
  boss := _sync_boss(p_uid, today, p_now);
  perform _progress_rewards(p_uid, today);
  select * into stats from character_stats where user_id = p_uid;

  return jsonb_build_object(
    'ja_concluida', false,
    'xp', xp,
    'bonus', bonuses,
    'nivel_antes', lvl_before,
    'nivel', stats.level,
    'xp_total', stats.total_xp,
    'chefe', boss);
end $$;

-- Desfazer (só no mesmo dia). Conquistas e vitórias já alcançadas continuam valendo.
create or replace function public._undo_completion(p_uid uuid, p_mission uuid, p_now timestamptz)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  m missions;
  prof profiles;
  today date;
begin
  select * into prof from profiles where id = p_uid;
  today := (p_now at time zone prof.timezone)::date;
  select * into m from missions where id = p_mission and user_id = p_uid for update;
  if not found then raise exception 'missao_nao_encontrada'; end if;
  if m.status <> 'concluida' then return jsonb_build_object('desfeita', false); end if;
  if (m.completed_at at time zone prof.timezone)::date <> today then raise exception 'so_no_mesmo_dia'; end if;

  delete from xp_ledger where mission_id = m.id;
  update missions set status = 'pendente', completed_at = null where id = m.id;
  perform _apply_day_bonuses(p_uid, today);
  perform _recalc_stats(p_uid);
  perform _sync_boss(p_uid, today, p_now);
  return jsonb_build_object('desfeita', true);
end $$;

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
    -- No Extremo o programa é fixo: dá para criar missões avulsas, mas não hábitos novos
    if prof.mode = 'extremo' then raise exception 'modo_extremo_bloqueia_habitos'; end if;
    select count(*) into n from user_habits where user_id = uid and active and is_custom;
    if n >= 12 then raise exception 'limite_habitos'; end if;
    if prof.plan = 'free' and n >= 2 then raise exception 'limite_gratuito_personalizadas'; end if;

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

create or replace function public.adjust_habit(p_habit uuid, p_target int, p_active boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  h user_habits;
  today date;
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  select * into h from user_habits where id = p_habit and user_id = uid for update;
  if not found then raise exception 'habito_nao_encontrado'; end if;
  if (select mode from profiles where id = uid) = 'extremo' then raise exception 'modo_extremo_bloqueia_ajustes'; end if;
  if p_target is null or p_target not between h.base_value and h.max_value then raise exception 'meta_fora_do_intervalo'; end if;

  if p_target <> h.current_target or coalesce(p_active, h.active) <> h.active then
    insert into habit_adjustments (user_id, habit_id, old_target, new_target, paused)
      values (uid, h.id, h.current_target, p_target, coalesce(p_active, h.active) = false);
  end if;
  update user_habits set current_target = p_target, active = coalesce(p_active, active) where id = h.id;

  -- A missão pendente de hoje acompanha o ajuste
  today := _local_today(uid);
  update missions m set
    target_value = p_target,
    estimated_minutes = _est_minutes(h.unit, p_target, h.est_minutes),
    xp_reward = _xp_for(m.difficulty, _est_minutes(h.unit, p_target, h.est_minutes), m.kind)
  where m.habit_id = h.id and m.kind = 'diaria' and m.mission_date = today and m.status = 'pendente';

  if p_active = false then
    delete from missions where habit_id = h.id and mission_date = today and status = 'pendente' and kind = 'diaria';
  end if;

  perform _sync_boss(uid, today, now());
  perform _progress_rewards(uid, today);
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.update_profile(p_display_name text, p_timezone text, p_min_daily int)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  prof profiles;
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  select * into prof from profiles where id = uid;
  if p_timezone is not null and not exists (select 1 from pg_timezone_names where name = p_timezone) then
    raise exception 'fuso_invalido';
  end if;
  if p_min_daily is not null and p_min_daily not between 1 and 10 then raise exception 'meta_invalida'; end if;

  update profiles set
    display_name = coalesce(left(trim(p_display_name), 40), display_name),
    timezone = coalesce(p_timezone, timezone)
  where id = uid;

  if p_min_daily is not null and p_min_daily <> prof.min_daily_missions then
    if prof.mode = 'extremo' then raise exception 'modo_extremo_bloqueia_ajustes'; end if;
    if prof.onboarding_done then
      perform _record_rules(uid, _local_today(uid), prof.mode, p_min_daily, 'escolha');
    else
      update profiles set min_daily_missions = p_min_daily where id = uid;
    end if;
  end if;
  return jsonb_build_object('ok', true);
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 10. Abertura do dia e avisos
-- ════════════════════════════════════════════════════════════════════════════

create or replace function public._daily_maintenance(p_uid uuid, p_today date, p_now timestamptz)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform _check_demotion(p_uid, p_today);
  perform _sync_boss(p_uid, p_today, p_now);
  perform _progress_rewards(p_uid, p_today);
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
  return r;
end $$;

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
        else jsonb_build_object('date', e.ref)
      end) order by e.id), '[]'::jsonb)
    from user_events e where e.user_id = uid and not e.seen);
end $$;

create or replace function public.mark_events_seen(p_ids bigint[])
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); n int;
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  update user_events set seen = true where user_id = uid and id = any(p_ids) and not seen;
  get diagnostics n = row_count;
  return jsonb_build_object('marked', n);
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 11. Permissões
-- ════════════════════════════════════════════════════════════════════════════

revoke insert, update, delete, truncate on all tables in schema public from anon, authenticated;
grant select on all tables in schema public to authenticated;

revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function
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
  public.get_bosses(),
  public.start_boss(text),
  public.abandon_boss(),
  public.get_achievements(),
  public.update_avatar(jsonb),
  public.set_title(text),
  public.set_mode(text, boolean),
  public.get_mode_info(),
  public.pending_events(),
  public.mark_events_seen(bigint[])
to authenticated;

-- ═══ 0005_etapa4.sql ═══
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
create index if not exists feed_posts_author_idx on public.feed_posts (author, created_at desc, id desc);

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
    -- Mais recentes primeiro; p_before é a última publicação já carregada
    posts as (
      select fp.* from feed_posts fp join authors a on a.id = fp.author
       where p_before is null
          or (fp.created_at, fp.id) < (select b.created_at, b.id from feed_posts b where b.id = p_before)
       order by fp.created_at desc, fp.id desc limit 30)
    select coalesce(jsonb_agg(jsonb_build_object(
      'id', p.id, 'kind', p.kind, 'ref', p.ref, 'data', p.data, 'created_at', p.created_at,
      'author', _lite(p.author), 'mine', p.author = v_uid,
      'cheers', (select coalesce(jsonb_object_agg(k, c), '{}'::jsonb)
                   from (select ch.kind as k, count(*) as c from cheers ch where ch.post_id = p.id group by ch.kind) s),
      'cheerers', (select coalesce(jsonb_agg(_lite(s.sender)), '[]'::jsonb)
                     from (select ch.sender from cheers ch where ch.post_id = p.id order by ch.id desc limit 5) s),
      'my_cheer', (select ch.kind from cheers ch where ch.post_id = p.id and ch.sender = v_uid)
    ) order by p.created_at desc, p.id desc), '[]'::jsonb)
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

-- ═══ 0006_notificacoes.sql ═══
-- Forja · 0006 · Notificações no celular (Web Push)
-- Pode rodar de novo sem estragar nada.
--
-- Como funciona
--   1. O app pede permissão no aparelho e guarda a inscrição dele (push_subscriptions).
--   2. O banco decide o que enviar e põe na fila (push_queue): os lembretes da meta, conferidos a cada
--      minuto pelo pg_cron, e os avisos sociais (pedidos, convites, incentivos) na hora em que acontecem.
--   3. Para enviar, o banco cria um lote com um código de uso único e chama a função /api/push do app
--      pelo pg_net. O pedido só sai depois que a transação termina.
--   4. A função pega o lote com esse código (push_claim), envia pelo Web Push e devolve o resultado
--      (push_report). Inscrições canceladas pelo aparelho saem sozinhas.
--   As chaves VAPID são geradas pela própria função na primeira vez e ficam só aqui no banco
--   (push_config, sem acesso pelo app). Ninguém precisa copiar chave nenhuma.
--
-- Depois de rodar, o administrador informa uma vez o endereço do app:
--   select admin_set_push_url('https://seu-app.vercel.app');

-- ════════════════════════════════════════════════════════════════════════════
-- 0. Extensões do Supabase (agendador e pedidos HTTP)
-- ════════════════════════════════════════════════════════════════════════════

do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_net') then
    create extension if not exists pg_net with schema extensions;
  end if;
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron with schema pg_catalog;
    grant usage on schema cron to postgres;
    grant all privileges on all tables in schema cron to postgres;
  end if;
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 1. Tabelas
-- ════════════════════════════════════════════════════════════════════════════

-- Configuração do envio (uma linha só; nunca lida pelo app)
create table if not exists public.push_config (
  id          boolean primary key default true check (id),
  app_url     text,               -- endereço do app (https://…), definido pelo administrador
  public_key  text,               -- chave VAPID pública (vai para o app)
  private_key text,               -- chave VAPID privada (nunca sai do servidor)
  keys_at     timestamptz,
  updated_at  timestamptz not null default now()
);
insert into public.push_config (id) values (true) on conflict do nothing;

-- Aparelhos inscritos (um por navegador/app instalado)
create table if not exists public.push_subscriptions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  endpoint    text not null unique check (char_length(endpoint) <= 1000),
  p256dh      text not null,
  auth        text not null,
  device      text not null default '' check (char_length(device) <= 40),
  created_at  timestamptz not null default now(),
  seen_at     timestamptz not null default now(),   -- última vez que o app confirmou a inscrição
  last_ok_at  timestamptz,                          -- última entrega aceita
  last_status int,
  last_error  text,
  failures    int not null default 0                -- falhas seguidas
);
create index if not exists push_subscriptions_user_idx on public.push_subscriptions (user_id);

-- Lotes de envio: cada um tem um código de uso único que só o banco e a função conhecem
create table if not exists public.push_batches (
  id          uuid primary key default gen_random_uuid(),
  token       text not null unique,
  need_keys   boolean not null default false,
  created_at  timestamptz not null default now(),
  claimed_at  timestamptz,
  reported_at timestamptz,
  sent        int,
  failed      int,
  abandoned   boolean not null default false
);
create index if not exists push_batches_open_idx on public.push_batches (created_at) where reported_at is null;

-- Fila: o que mandar para cada pessoa (vai para todos os aparelhos dela)
create table if not exists public.push_queue (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  kind        text not null check (kind in ('lembrete','risco','social','teste')),
  payload     jsonb not null,     -- { title, body, url, tag }
  ttl         int not null default 3600 check (ttl between 60 and 86400),
  urgency     text not null default 'normal' check (urgency in ('low','normal','high')),
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null,
  batch_id    uuid references public.push_batches(id) on delete set null,
  attempts    int not null default 0,
  sent_at     timestamptz,
  done        boolean not null default false   -- entregue, vencido ou desistido
);
create index if not exists push_queue_pending_idx on public.push_queue (id) where not done;
create index if not exists push_queue_batch_idx on public.push_queue (batch_id) where batch_id is not null;
create index if not exists push_queue_user_idx on public.push_queue (user_id, created_at desc);

-- Lembretes já conferidos em cada dia (um de cada tipo por dia, enviado ou não)
create table if not exists public.push_log (
  user_id uuid not null references public.profiles(id) on delete cascade,
  kind    text not null check (kind in ('lembrete','risco')),
  day     date not null,
  sent    boolean not null default true,   -- false: conferido, mas a meta já estava cumprida
  primary key (user_id, kind, day)
);

-- Preferências de cada pessoa
alter table public.profiles add column if not exists notify jsonb not null
  default '{"lembrete": true, "lembrete_hora": "09:00", "risco": true, "risco_hora": "20:00", "social": true}';

alter table public.push_config        enable row level security;
alter table public.push_subscriptions enable row level security;
alter table public.push_batches       enable row level security;
alter table public.push_queue         enable row level security;
alter table public.push_log           enable row level security;
-- Sem políticas: o app não lê essas tabelas; tudo passa pelas funções abaixo.

-- ════════════════════════════════════════════════════════════════════════════
-- 2. Peças internas
-- ════════════════════════════════════════════════════════════════════════════

-- "1 missão", "3 missões"
create or replace function public._missoes(n int)
returns text language sql immutable as $$
  select n || case when n = 1 then ' missão' else ' missões' end
$$;

-- Preferências com os valores padrão preenchidos
create or replace function public._notify_settings(p jsonb)
returns jsonb language sql immutable as $$
  select jsonb_build_object(
    'lembrete',      coalesce((p->>'lembrete')::boolean, true),
    'lembrete_hora', coalesce(p->>'lembrete_hora', '09:00'),
    'risco',         coalesce((p->>'risco')::boolean, true),
    'risco_hora',    coalesce(p->>'risco_hora', '20:00'),
    'social',        coalesce((p->>'social')::boolean, true))
$$;

-- Põe uma notificação na fila (só para quem tem aparelho inscrito)
create or replace function public._push_enqueue(p_uid uuid, p_kind text, p_payload jsonb, p_ttl int, p_urgency text default 'normal')
returns bigint language plpgsql security definer set search_path = public as $$
declare v_id bigint;
begin
  if not exists (select 1 from push_subscriptions where user_id = p_uid) then return null; end if;
  insert into push_queue (user_id, kind, payload, ttl, urgency, expires_at)
  values (p_uid, p_kind, p_payload, p_ttl, p_urgency, now() + make_interval(secs => p_ttl))
  returning id into v_id;
  return v_id;
end $$;

-- Cria um lote com o que está pendente e chama a função de envio do app.
-- p_need_keys: o lote serve também para a função gerar as chaves VAPID.
create or replace function public._push_kick(p_need_keys boolean default false)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_cfg   push_config;
  v_batch uuid;
  v_token text;
  v_n     int;
begin
  select * into v_cfg from push_config where id;
  if v_cfg.app_url is null
     or not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                     where n.nspname = 'net' and p.proname = 'http_post') then
    return null;
  end if;
  -- Sem chaves não há como enviar: só um lote pedido de propósito (para gerá-las) segue em frente
  if v_cfg.public_key is null and not p_need_keys then return null; end if;
  if not p_need_keys
     and not exists (select 1 from push_queue where not done and batch_id is null and expires_at > now()) then
    return null;
  end if;

  v_token := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
  insert into push_batches (token, need_keys) values (v_token, p_need_keys) returning id into v_batch;
  update push_queue set batch_id = v_batch
   where id in (select id from push_queue
                 where not done and batch_id is null and expires_at > now()
                 order by id limit 200 for update skip locked);
  get diagnostics v_n = row_count;
  if v_n = 0 and not p_need_keys then
    delete from push_batches where id = v_batch;
    return null;
  end if;

  -- O pedido só sai depois do commit: a função encontra o lote já gravado
  perform net.http_post(
    url := v_cfg.app_url || '/api/push',
    body := jsonb_build_object('token', v_token),
    timeout_milliseconds := 20000);
  return v_batch;
end $$;

-- Ao fim de cada transação que pôs algo na fila, um lote sai (um só, mesmo com várias linhas)
create or replace function public._push_queue_kick()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform _push_kick();
  return null;
end $$;
drop trigger if exists push_queue_kick on public.push_queue;
create constraint trigger push_queue_kick after insert on public.push_queue
  deferrable initially deferred for each row execute function public._push_queue_kick();

-- Texto de um aviso social
create or replace function public._push_social_payload(e user_events)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_name text;
  v jsonb;
  f friendships;
  c record;
  v_other uuid;
begin
  case e.kind
    when 'pedido_amizade' then
      select * into f from friendships where id::text = e.ref;
      if f.id is null or f.status <> 'pendente' then return null; end if;
      select nullif(display_name, '') into v_name from profiles where id = f.requester;
      v := jsonb_build_object('title', 'Pedido de amizade',
                              'body', format('%s te mandou um pedido de amizade.', coalesce(v_name, 'Alguém')),
                              'url', '/social/avisos', 'tag', 'pedido-' || f.id);
    when 'amizade_aceita' then
      select * into f from friendships where id::text = e.ref and status = 'aceita';
      if f.id is null then return null; end if;
      v_other := case when f.requester = e.user_id then f.addressee else f.requester end;
      select nullif(display_name, '') into v_name from profiles where id = v_other;
      v := jsonb_build_object('title', 'Nova amizade',
                              'body', format('%s aceitou seu pedido de amizade.', coalesce(v_name, 'Alguém')),
                              'url', '/social/amigos/' || v_other, 'tag', 'amizade-' || f.id);
    when 'incentivo' then
      select ch.kind, ch.post_id, nullif(p.display_name, '') as name into c
        from cheers ch join profiles p on p.id = ch.sender where ch.id::text = e.ref;
      if c.kind is null then return null; end if;
      v := jsonb_build_object(
        'title', case when c.post_id is null then 'Incentivo' else 'Reação' end,
        'body', case when c.post_id is null
                  then format('%s te mandou %s.', coalesce(c.name, 'Alguém'),
                         case c.kind when 'parabens' then '👏 Parabéns' when 'forca' then '💪 Força'
                                     when 'brasa' then '🔥 Mandou bem' when 'foco' then '🎯 Foco'
                                     when 'volta' then '🤝 Bora voltar' else 'um incentivo' end)
                  else format('%s reagiu com %s à sua publicação.', coalesce(c.name, 'Alguém'),
                         case c.kind when 'parabens' then '👏' when 'forca' then '💪' when 'brasa' then '🔥'
                                     when 'foco' then '🎯' else '🤝' end) end,
        'url', '/social/avisos', 'tag', 'incentivo');
    when 'desafio_convite' then
      select ch.id, ch.title, nullif(p.display_name, '') as name into c
        from challenges ch join profiles p on p.id = ch.creator where ch.id::text = e.ref;
      if c.id is null then return null; end if;
      v := jsonb_build_object('title', 'Convite para desafio',
                              'body', format('%s te convidou para o desafio “%s”.', coalesce(c.name, 'Alguém'), c.title),
                              'url', '/social/desafios/' || c.id, 'tag', 'desafio-' || c.id);
    when 'grupo_entrada' then
      select g.id, g.name, nullif(p.display_name, '') as who into c
        from social_groups g join profiles p on p.id::text = split_part(e.ref, ':', 2)
       where g.id::text = split_part(e.ref, ':', 1);
      if c.id is null then return null; end if;
      v := jsonb_build_object('title', 'Novo membro no grupo',
                              'body', format('%s entrou no grupo %s.', coalesce(c.who, 'Alguém'), c.name),
                              'url', '/social/grupos/' || c.id, 'tag', 'grupo-' || c.id);
    else
      return null;
  end case;
  return v || jsonb_build_object('kind', e.kind);
end $$;

-- Avisos sociais viram notificação na hora
create or replace function public._push_on_event()
returns trigger language plpgsql security definer set search_path = public as $$
declare v jsonb;
begin
  if new.seen or new.kind not in ('pedido_amizade','amizade_aceita','incentivo','desafio_convite','grupo_entrada') then
    return null;
  end if;
  -- Scripts administrativos (como a conta de teste) desligam o envio com esta marca
  if coalesce(current_setting('forja.sem_push', true), '') = 'on' then return null; end if;
  if not exists (select 1 from push_subscriptions where user_id = new.user_id) then return null; end if;
  if not (_notify_settings((select notify from profiles where id = new.user_id))->>'social')::boolean then return null; end if;
  -- Várias reações seguidas viram uma notificação só (as outras aparecem no app)
  if new.kind = 'incentivo' and exists (
       select 1 from push_queue where user_id = new.user_id and kind = 'social'
          and payload->>'kind' = 'incentivo' and created_at > now() - interval '10 minutes') then
    return null;
  end if;
  v := _push_social_payload(new);
  if v is not null then perform _push_enqueue(new.user_id, 'social', v, 86400, 'normal'); end if;
  return null;
end $$;
drop trigger if exists user_events_push on public.user_events;
create trigger user_events_push after insert on public.user_events
  for each row execute function public._push_on_event();

-- Lembretes do horário de cada pessoa. Devolve quantos foram para a fila.
--   lembrete: no horário escolhido, se a meta do dia ainda não foi cumprida.
--             Na fase Domínio (dias 46 a 60) só aparece se a meta do dia anterior também falhou.
--   risco:    à noite, se ainda faltar missão para a meta.
create or replace function public._push_reminders(p_now timestamptz)
returns int language plpgsql security definer set search_path = public as $$
declare
  r        record;
  s        record;
  v_set    jsonb;
  v_local  timestamp;
  v_day    date;
  v_time   time;
  v_at     time;
  v_streak int;
  v_goal   text;
  v_left   int;
  v_known  boolean;
  v_greet  text;
  v_body   text;
  v_title  text;
  v_ttl    int;
  v_n      int := 0;
begin
  for r in
    select p.id, p.timezone, p.notify, p.program_start
      from profiles p
     where p.onboarding_done and p.program_start is not null
       and exists (select 1 from push_subscriptions ps where ps.user_id = p.id)
  loop
    v_set := _notify_settings(r.notify);
    v_local := p_now at time zone r.timezone;
    v_day := v_local::date;
    v_time := v_local::time;
    continue when r.program_start > v_day;

    -- Lembrete da meta (a linha em push_log garante um por dia, mesmo com duas rodadas ao mesmo tempo)
    v_at := (v_set->>'lembrete_hora')::time;
    if (v_set->>'lembrete')::boolean and v_time >= v_at and v_time - v_at < interval '90 minutes'
       and not exists (select 1 from push_log where user_id = r.id and kind = 'lembrete' and day = v_day) then
      insert into push_log (user_id, kind, day, sent) values (r.id, 'lembrete', v_day, false) on conflict do nothing;
      continue when not found;
      select * into s from _day_stats(r.id, v_day, v_day);
      if s.goal_met
         or (v_day - r.program_start + 1 between 46 and 60
             and coalesce((select d.goal_met from _day_stats(r.id, v_day - 1, v_day - 1) d), false)) then
        null;   -- conferido; não precisa avisar
      else
        v_streak := coalesce((_journey(r.id, v_day)->>'current_streak')::int, 0);
        v_greet := case when extract(hour from v_time) < 12 then 'Bom dia!'
                        when extract(hour from v_time) < 18 then 'Boa tarde!' else 'Boa noite!' end;
        v_goal := case when s.daily_total = 0 and s.mode = 'desafio' then '60% das missões diárias'
                       when s.daily_total = 0 and s.mode = 'extremo' then 'todas as missões diárias'
                       else _missoes(s.goal) end;
        v_body := case
          when s.done > 0 and s.daily_total > 0 then format('%s Você já fez %s de %s da meta de hoje.', v_greet, s.done, _missoes(s.goal))
          when v_streak >= 2 then format('%s Sua sequência está em %s dias. Meta de hoje: %s.', v_greet, v_streak, v_goal)
          else format('%s Meta de hoje: %s.', v_greet, v_goal) end;
        perform _push_enqueue(r.id, 'lembrete',
          jsonb_build_object('title', 'Missões de hoje', 'body', v_body, 'url', '/', 'tag', 'lembrete', 'kind', 'lembrete'),
          7200, 'normal');
        update push_log set sent = true where user_id = r.id and kind = 'lembrete' and day = v_day;
        v_n := v_n + 1;
      end if;
    end if;

    -- Sequência em risco
    v_at := (v_set->>'risco_hora')::time;
    if (v_set->>'risco')::boolean and v_time >= v_at and v_time - v_at < interval '90 minutes'
       and not exists (select 1 from push_log where user_id = r.id and kind = 'risco' and day = v_day) then
      insert into push_log (user_id, kind, day, sent) values (r.id, 'risco', v_day, false) on conflict do nothing;
      continue when not found;
      select * into s from _day_stats(r.id, v_day, v_day);
      if s.goal_met then
        null;
      else
        v_streak := coalesce((_journey(r.id, v_day)->>'current_streak')::int, 0);
        -- Nos modos Desafio e Extremo, a meta depende das missões do dia (que só existem depois de abrir o app)
        v_known := s.daily_total > 0 or s.mode = 'normal';
        v_left := greatest(1, case when s.mode = 'extremo' then greatest(s.daily_total - s.daily_done, s.min_daily - s.done)
                                   else s.goal - s.done end);
        v_title := case when v_streak >= 2 then 'Sequência em risco' else 'Meta de hoje' end;
        v_body := case
          when v_known and v_streak >= 2 then format('Faltam %s para a meta de hoje e sua sequência de %s dias continua.', _missoes(v_left), v_streak)
          when v_known then format('Ainda dá tempo: faltam %s para a meta de hoje.', _missoes(v_left))
          when v_streak >= 2 then format('Ainda dá tempo de cumprir a meta de hoje e manter a sequência de %s dias.', v_streak)
          else 'Ainda dá tempo de cumprir a meta de hoje.' end;
        -- Vale até a meia-noite de lá (um aviso de "hoje" não serve amanhã)
        v_ttl := least(21600, greatest(900, extract(epoch from (v_day + 1)::timestamp - v_local)::int));
        perform _push_enqueue(r.id, 'risco',
          jsonb_build_object('title', v_title, 'body', v_body, 'url', '/missoes', 'tag', 'risco', 'kind', 'risco'),
          v_ttl, 'high');
        update push_log set sent = true where user_id = r.id and kind = 'risco' and day = v_day;
        v_n := v_n + 1;
      end if;
    end if;
  end loop;
  return v_n;
end $$;

-- Roda a cada minuto (pg_cron)
create or replace function public._push_tick()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_b   record;
  v_n   int;
  v_cfg push_config;
begin
  -- Lotes sem resposta há 3 minutos (função fora do ar, rede…): os itens voltam para a fila
  for v_b in select id from push_batches
              where reported_at is null and created_at < now() - interval '3 minutes'
              for update skip locked loop
    update push_queue set batch_id = null, attempts = attempts + 1, done = attempts + 1 >= 3 or expires_at <= now()
     where batch_id = v_b.id and not done;
    update push_batches set reported_at = now(), abandoned = true where id = v_b.id;
  end loop;
  update push_queue set done = true where not done and batch_id is null and expires_at <= now();

  v_n := _push_reminders(now());

  -- Chaves ainda não geradas: pede à função (no máximo a cada 10 minutos)
  select * into v_cfg from push_config where id;
  if v_cfg.public_key is null and v_cfg.app_url is not null
     and not exists (select 1 from push_batches where need_keys and created_at > now() - interval '10 minutes') then
    perform _push_kick(true);
  end if;
  -- Itens que voltaram para a fila
  perform _push_kick();

  -- Limpeza, uma vez por hora
  if extract(minute from now())::int = 7 then
    delete from push_queue where done and created_at < now() - interval '14 days';
    delete from push_batches where created_at < now() - interval '3 days';
    delete from push_log where day < current_date - 40;
  end if;
  return jsonb_build_object('lembretes', v_n);
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 3. Funções do app
-- ════════════════════════════════════════════════════════════════════════════

create or replace function public.get_notify()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_cfg push_config;
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  select * into v_cfg from push_config where id;
  -- Primeira vez: pede as chaves à função (a tela confere de novo em seguida)
  if v_cfg.public_key is null and v_cfg.app_url is not null
     and not exists (select 1 from push_batches where need_keys and created_at > now() - interval '1 minute') then
    perform _push_kick(true);
  end if;
  return jsonb_build_object(
    'configured', v_cfg.app_url is not null,
    'ready', v_cfg.public_key is not null,
    'public_key', v_cfg.public_key,
    'settings', _notify_settings((select notify from profiles where id = v_uid)),
    'devices', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', s.id, 'endpoint', s.endpoint, 'device', s.device, 'created_at', s.created_at,
               'last_ok_at', s.last_ok_at, 'last_status', s.last_status, 'last_error', s.last_error)
             order by s.created_at)
        from push_subscriptions s where s.user_id = v_uid), '[]'::jsonb));
end $$;

create or replace function public.set_notify(p_settings jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_cur jsonb;
  k text;
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  if jsonb_typeof(p_settings) <> 'object' then raise exception 'configuracao_invalida'; end if;
  for k in select jsonb_object_keys(p_settings) loop
    if k in ('lembrete', 'risco', 'social') then
      if jsonb_typeof(p_settings->k) <> 'boolean' then raise exception 'configuracao_invalida'; end if;
    elsif k in ('lembrete_hora', 'risco_hora') then
      if jsonb_typeof(p_settings->k) <> 'string' or (p_settings->>k) !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then
        raise exception 'horario_invalido';
      end if;
      if (p_settings->>k)::time not between '05:00' and '23:30' then raise exception 'horario_invalido'; end if;
    else
      raise exception 'configuracao_invalida';
    end if;
  end loop;
  select notify into v_cur from profiles where id = v_uid for update;
  v_cur := _notify_settings(coalesce(v_cur, '{}'::jsonb) || p_settings);
  update profiles set notify = v_cur where id = v_uid;
  return v_cur;
end $$;

create or replace function public.save_push_subscription(p_endpoint text, p_p256dh text, p_auth text, p_device text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  if p_endpoint is null or char_length(p_endpoint) > 1000
     or p_endpoint !~ '^(https://|http://(localhost|127\.0\.0\.1)(:[0-9]+)?/)'
     or coalesce(p_p256dh, '') !~ '^[A-Za-z0-9_-]{80,100}=*$'
     or coalesce(p_auth, '') !~ '^[A-Za-z0-9_-]{16,32}=*$' then
    raise exception 'inscricao_invalida';
  end if;
  insert into push_subscriptions (user_id, endpoint, p256dh, auth, device, seen_at)
  values (v_uid, p_endpoint, p_p256dh, p_auth, left(coalesce(p_device, ''), 40), clock_timestamp())
  on conflict (endpoint) do update
    set user_id = excluded.user_id, p256dh = excluded.p256dh, auth = excluded.auth, device = excluded.device,
        seen_at = clock_timestamp(),
        -- O mesmo aparelho com outra conta começa do zero
        failures    = case when push_subscriptions.user_id = excluded.user_id then push_subscriptions.failures else 0 end,
        last_ok_at  = case when push_subscriptions.user_id = excluded.user_id then push_subscriptions.last_ok_at end,
        last_status = case when push_subscriptions.user_id = excluded.user_id then push_subscriptions.last_status end,
        last_error  = case when push_subscriptions.user_id = excluded.user_id then push_subscriptions.last_error end;
  -- No máximo 10 aparelhos: os mais antigos saem
  delete from push_subscriptions where id in (
    select id from push_subscriptions where user_id = v_uid order by seen_at desc, created_at desc offset 10);
  return jsonb_build_object('devices', (select count(*) from push_subscriptions where user_id = v_uid));
end $$;

create or replace function public.remove_push_subscription(p_endpoint text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  delete from push_subscriptions where endpoint = p_endpoint and user_id = v_uid;
  return jsonb_build_object('devices', (select count(*) from push_subscriptions where user_id = v_uid));
end $$;

create or replace function public.push_test()
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  if not exists (select 1 from push_subscriptions where user_id = v_uid) then raise exception 'push_sem_aparelho'; end if;
  if exists (select 1 from push_queue where user_id = v_uid and kind = 'teste' and created_at > now() - interval '20 seconds') then
    raise exception 'push_espere';
  end if;
  perform _push_enqueue(v_uid, 'teste',
    jsonb_build_object('title', 'Forja', 'body', 'Notificações ligadas! É assim que os lembretes vão aparecer.',
                       'url', '/perfil/notificacoes', 'tag', 'teste', 'kind', 'teste'),
    600, 'high');
  return jsonb_build_object('devices', (select count(*) from push_subscriptions where user_id = v_uid));
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 4. Funções da função de envio (chamadas com a chave pública, protegidas pelo código do lote)
-- ════════════════════════════════════════════════════════════════════════════

create or replace function public.push_claim(p_token text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_b   push_batches;
  v_cfg push_config;
begin
  if p_token is null or p_token !~ '^[0-9a-f]{64}$' then raise exception 'lote_invalido'; end if;
  update push_batches set claimed_at = now()
   where token = p_token and claimed_at is null and created_at > now() - interval '3 minutes'
   returning * into v_b;
  if v_b.id is null then raise exception 'lote_invalido'; end if;
  select * into v_cfg from push_config where id;
  return jsonb_build_object(
    'subject', v_cfg.app_url,
    'vapid', case when v_cfg.public_key is not null
                  then jsonb_build_object('public_key', v_cfg.public_key, 'private_key', v_cfg.private_key) end,
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
               'queue', q.id, 'subscription', s.id, 'endpoint', s.endpoint, 'p256dh', s.p256dh, 'auth', s.auth,
               'payload', q.payload, 'ttl', greatest(60, least(q.ttl, extract(epoch from q.expires_at - now())::int)),
               'urgency', q.urgency)
             order by q.id, s.created_at)
        from push_queue q join push_subscriptions s on s.user_id = q.user_id
       where q.batch_id = v_b.id and not q.done), '[]'::jsonb));
end $$;

create or replace function public.push_set_keys(p_token text, p_public text, p_private text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_cfg push_config;
begin
  if p_token is null or p_token !~ '^[0-9a-f]{64}$'
     or not exists (select 1 from push_batches where token = p_token and claimed_at is not null
                       and reported_at is null and claimed_at > now() - interval '5 minutes') then
    raise exception 'lote_invalido';
  end if;
  if coalesce(p_public, '') !~ '^[A-Za-z0-9_-]{87}$' or coalesce(p_private, '') !~ '^[A-Za-z0-9_-]{43}$' then
    raise exception 'chaves_invalidas';
  end if;
  -- Quem chegar primeiro fica; as chaves nunca são trocadas depois
  update push_config set public_key = p_public, private_key = p_private, keys_at = now(), updated_at = now()
   where id and public_key is null;
  select * into v_cfg from push_config where id;
  return jsonb_build_object('public_key', v_cfg.public_key, 'private_key', v_cfg.private_key);
end $$;

create or replace function public.push_report(p_token text, p_results jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_b      push_batches;
  r        jsonb;
  v_q      push_queue;
  v_status int;
  v_ok     int := 0;
  v_fail   int := 0;
  v_gone   int := 0;
begin
  if p_token is null or p_token !~ '^[0-9a-f]{64}$' then raise exception 'lote_invalido'; end if;
  select * into v_b from push_batches
   where token = p_token and claimed_at is not null and reported_at is null and claimed_at > now() - interval '10 minutes'
   for update;
  if v_b.id is null then raise exception 'lote_invalido'; end if;
  if jsonb_typeof(p_results) <> 'array' or jsonb_array_length(p_results) > 2000 then raise exception 'resultado_invalido'; end if;

  for r in select x from jsonb_array_elements(p_results) x loop
    -- Só vale para itens deste lote e aparelhos de quem ia receber
    continue when coalesce(r->>'queue', '') !~ '^[0-9]+$'
               or coalesce(r->>'subscription', '') !~ '^[0-9a-f-]{36}$';
    select q.* into v_q from push_queue q where q.id = (r->>'queue')::bigint and q.batch_id = v_b.id;
    continue when v_q.id is null;
    v_status := case when coalesce(r->>'status', '') ~ '^[0-9]{1,3}$' then (r->>'status')::int else 0 end;
    if v_status between 200 and 299 then
      update push_subscriptions set last_ok_at = now(), last_status = v_status, last_error = null, failures = 0
       where id = (r->>'subscription')::uuid and user_id = v_q.user_id;
      update push_queue set sent_at = coalesce(sent_at, now()), done = true where id = v_q.id;
      v_ok := v_ok + 1;
    elsif v_status in (404, 410) then
      -- O aparelho cancelou a inscrição (app removido, permissão retirada…)
      delete from push_subscriptions where id = (r->>'subscription')::uuid and user_id = v_q.user_id;
      v_gone := v_gone + 1;
    else
      update push_subscriptions set last_status = v_status, last_error = left(r->>'error', 200), failures = failures + 1
       where id = (r->>'subscription')::uuid and user_id = v_q.user_id;
      v_fail := v_fail + 1;
    end if;
  end loop;

  -- Aparelhos que falham sem parar saem (o app inscreve de novo quando for aberto)
  delete from push_subscriptions s where s.failures >= 15
     and s.user_id in (select user_id from push_queue where batch_id = v_b.id);

  -- O que não chegou em nenhum aparelho volta para a fila (até 3 tentativas)
  update push_queue q set done = true
   where q.batch_id = v_b.id and not q.done
     and not exists (select 1 from push_subscriptions s where s.user_id = q.user_id);
  update push_queue set batch_id = null, attempts = attempts + 1, done = attempts + 1 >= 3 or expires_at <= now()
   where batch_id = v_b.id and not done;

  update push_batches set reported_at = now(), sent = v_ok, failed = v_fail + v_gone where id = v_b.id;
  return jsonb_build_object('ok', v_ok, 'failed', v_fail, 'gone', v_gone);
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 5. Administração (SQL Editor do Supabase)
-- ════════════════════════════════════════════════════════════════════════════
-- Exemplo:
--   select admin_set_push_url('https://forja-kappa-wheat.vercel.app');
create or replace function public.admin_set_push_url(p_url text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v text := rtrim(trim(coalesce(p_url, '')), '/');
begin
  if v !~ '^https://[A-Za-z0-9.-]+(:[0-9]+)?$' then
    raise exception 'endereco_invalido' using hint = 'Use só o endereço do app, por exemplo https://seu-app.vercel.app';
  end if;
  update push_config set app_url = v, updated_at = now() where id;
  return jsonb_build_object('app_url', v, 'funcao', v || '/api/push');
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 6. Agendamento (pg_cron)
-- ════════════════════════════════════════════════════════════════════════════

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    -- Mesmo nome = substitui o agendamento anterior
    perform cron.schedule('forja-notificacoes', '* * * * *', 'select public._push_tick()');
    perform cron.schedule('forja-limpeza-cron', '17 4 * * *',
      $c$delete from cron.job_run_details where end_time < now() - interval '7 days'$c$);
  end if;
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 7. Permissões
-- ════════════════════════════════════════════════════════════════════════════

revoke insert, update, delete, truncate on all tables in schema public from anon, authenticated;
grant select on all tables in schema public to authenticated;
-- Chaves, códigos de lote e inscrições ficam fora do alcance do app
revoke all on public.push_config, public.push_batches, public.push_queue, public.push_log, public.push_subscriptions
  from anon, authenticated;

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
  public.get_report(date),
  -- Notificações
  public.get_notify(),
  public.set_notify(jsonb),
  public.save_push_subscription(text, text, text, text),
  public.remove_push_subscription(text),
  public.push_test()
to authenticated;

-- A função de envio do app usa a chave pública: só estas três, e só com o código de um lote válido
grant execute on function
  public.push_claim(text),
  public.push_set_keys(text, text, text),
  public.push_report(text, jsonb)
to anon;
