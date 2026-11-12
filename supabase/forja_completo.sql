-- Forja · banco completo (cole tudo no SQL Editor do Supabase e clique em Run)

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
