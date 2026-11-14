-- Forja · 0007 · Caminho Sagrado e correção do Mentor
--
-- Sagrado: um sexto atributo, opcional, que mede a dedicação entregue a Deus. Cresce com as práticas da área
-- "Vida espiritual" (devocional, leitura bíblica, meditação na Palavra, louvor e gratidão a Deus).
-- Quem não ativa o Caminho Sagrado não vê nada disso, e nada muda no jogo dessa pessoa.
--
-- Mentor: "Ritmo firme" e "Ritmo mais lento" podiam aparecer juntos. A tendência agora compara só dias completos,
-- exige uma diferença real e, quando a meta diária segue firme, usa uma mensagem que não contradiz a constância.
--
-- Pode ser rodada mais de uma vez. Nada é apagado: XP, níveis, conquistas e itens existentes ficam como estão.

-- ── Estrutura ────────────────────────────────────────────────────────────────

alter table public.profiles add column if not exists sagrado boolean not null default false;
alter table public.character_stats add column if not exists base_sagrado integer not null default 0;
alter table public.character_stats add column if not exists sagrado integer not null default 0;
alter table public.xp_ledger add column if not exists sagrado integer not null default 0;

alter table public.xp_ledger drop constraint if exists xp_ledger_check;
alter table public.xp_ledger add constraint xp_ledger_check
  check (amount = disciplina + foco + vitalidade + conhecimento + determinacao + sagrado);

alter table public.mission_templates drop constraint if exists mission_templates_dimension_check;
alter table public.mission_templates add constraint mission_templates_dimension_check
  check (dimension in ('fisica','mental','intelectual','produtividade','digital','autocuidado','espiritual'));
alter table public.mission_templates drop constraint if exists mission_templates_attr_primary_check;
alter table public.mission_templates add constraint mission_templates_attr_primary_check
  check (attr_primary in ('disciplina','foco','vitalidade','conhecimento','determinacao','sagrado'));
alter table public.mission_templates drop constraint if exists mission_templates_attr_secondary_check;
alter table public.mission_templates add constraint mission_templates_attr_secondary_check
  check (attr_secondary in ('disciplina','foco','vitalidade','conhecimento','determinacao','sagrado'));
alter table public.achievement_catalog drop constraint if exists achievement_catalog_attr_check;
alter table public.achievement_catalog add constraint achievement_catalog_attr_check
  check (attr in ('disciplina','foco','vitalidade','conhecimento','determinacao','sagrado'));
alter table public.achievement_catalog drop constraint if exists achievement_catalog_category_check;
alter table public.achievement_catalog add constraint achievement_catalog_category_check
  check (category in ('missoes','sequencia','programa','nivel','atributos','habitos','chefes','modos','social','temporadas','ferramentas','sagrado'));
alter table public.challenges drop constraint if exists challenges_dimension_check;
alter table public.challenges add constraint challenges_dimension_check
  check (dimension in ('fisica','mental','intelectual','produtividade','digital','autocuidado','espiritual'));

-- ── Práticas do Caminho Sagrado ──────────────────────────────────────────────
-- tier 7: fora do plano automático do questionário; só entram quando a pessoa escolhe.

insert into public.mission_templates
  (id, dimension, name, description, attr_primary, attr_secondary, difficulty, unit, base_value, step, max_value, est_minutes, period, tier, sort, passive)
values
  ('esp_devocional', 'espiritual', 'Devocional',
   'Separe um momento com Deus: leia o devocional do dia, ore e anote uma frase que falou com você.',
   'sagrado', 'disciplina', 1, 'min', 10, 5, 30, 0, 'manha', 7, 1, false),
  ('esp_biblia', 'espiritual', 'Leitura bíblica',
   'Leia a Bíblia com calma, um trecho por vez. Se quiser, siga um plano de leitura.',
   'sagrado', 'conhecimento', 2, 'min', 10, 5, 30, 0, 'qualquer', 7, 2, false),
  ('esp_meditacao', 'espiritual', 'Meditação na Palavra',
   'Escolha um versículo, leia devagar algumas vezes e pense no que ele diz para a sua vida hoje.',
   'sagrado', 'foco', 2, 'min', 5, 5, 20, 0, 'qualquer', 7, 3, false),
  ('esp_louvor', 'espiritual', 'Louvor',
   'Cante ou ouça louvores com atenção, adorando a Deus de coração.',
   'sagrado', 'vitalidade', 1, 'min', 10, 5, 30, 0, 'qualquer', 7, 4, false),
  ('esp_gratidao', 'espiritual', 'Gratidão a Deus',
   'Agradeça a Deus por três coisas de hoje, em oração ou por escrito.',
   'sagrado', 'determinacao', 1, 'vez', 1, 0, 1, 5, 'noite', 7, 5, false)
on conflict (id) do update set
  dimension = excluded.dimension, name = excluded.name, description = excluded.description,
  attr_primary = excluded.attr_primary, attr_secondary = excluded.attr_secondary, difficulty = excluded.difficulty,
  unit = excluded.unit, base_value = excluded.base_value, step = excluded.step, max_value = excluded.max_value,
  est_minutes = excluded.est_minutes, period = excluded.period, tier = excluded.tier, sort = excluded.sort, passive = excluded.passive;

insert into public.achievement_catalog (id, category, name, description, rarity, metric, threshold, xp, attr, hidden, sort) values
  ('sg_1',  'sagrado', 'Primeiro altar',       'Conclua sua primeira prática do Caminho Sagrado.', 'comum',    'missoes_sagrado', 1,  20,  'sagrado', false, 110),
  ('sg_7',  'sagrado', 'Sete dias na Palavra', 'Pratique o Caminho Sagrado em 7 dias.',            'raro',     'dias_sagrado',    7,  60,  'sagrado', false, 111),
  ('sg_30', 'sagrado', 'Raízes profundas',     'Pratique o Caminho Sagrado em 30 dias.',           'epico',    'dias_sagrado',    30, 150, 'sagrado', false, 112),
  ('sg_66', 'sagrado', 'Aliança de 66 dias',   'Pratique o Caminho Sagrado em 66 dias.',           'lendario', 'dias_sagrado',    66, 250, 'sagrado', false, 113),
  ('sg_n5', 'sagrado', 'Altar aceso',          'Alcance o nível 5 em Sagrado.',                    'raro',     'attr_sagrado',    5,  0,   'sagrado', false, 114)
on conflict (id) do update set
  category = excluded.category, name = excluded.name, description = excluded.description, rarity = excluded.rarity,
  metric = excluded.metric, threshold = excluded.threshold, xp = excluded.xp, attr = excluded.attr, sort = excluded.sort;

-- ── Atributo e área ──────────────────────────────────────────────────────────

create or replace function public._attr_for_dimension(p_dim text, out primary_attr text, out secondary_attr text)
language sql immutable as $$
  select case p_dim
           when 'fisica' then 'vitalidade' when 'mental' then 'foco' when 'intelectual' then 'conhecimento'
           when 'produtividade' then 'disciplina' when 'digital' then 'foco' when 'espiritual' then 'sagrado' else 'disciplina' end,
         case p_dim
           when 'fisica' then 'determinacao' when 'mental' then 'vitalidade' when 'intelectual' then 'foco'
           when 'produtividade' then 'foco' when 'digital' then 'disciplina' when 'espiritual' then 'determinacao' else 'vitalidade' end
$$;

create or replace function public._dim_label(p_dim text)
returns text language sql immutable as $$
  select case p_dim when 'fisica' then 'Saúde física' when 'mental' then 'Saúde mental'
                    when 'intelectual' then 'Desenvolvimento intelectual' when 'produtividade' then 'Disciplina e produtividade'
                    when 'digital' then 'Saúde digital' when 'espiritual' then 'Vida espiritual' else 'Autocuidado e rotina' end
$$;

-- Toda XP que vai para o Sagrado passa por aqui: as funções de missão e de conquista distribuem os cinco
-- atributos de sempre, e a parte que era do Sagrado (quando a missão ou a conquista é do Sagrado) entra nesta coluna.
create or replace function public._xp_sagrado()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_rest int;
begin
  v_rest := new.amount - (new.disciplina + new.foco + new.vitalidade + new.conhecimento + new.determinacao + new.sagrado);
  if v_rest > 0 and (
       (new.mission_id is not null and exists (select 1 from missions m where m.id = new.mission_id
                                                and 'sagrado' in (m.attr_primary, m.attr_secondary)))
    or (new.source = 'conquista' and exists (select 1 from achievement_catalog a where a.id = new.ref and a.attr = 'sagrado'))) then
    new.sagrado := new.sagrado + v_rest;
  end if;
  return new;
end $$;

drop trigger if exists xp_sagrado on public.xp_ledger;
create trigger xp_sagrado before insert on public.xp_ledger
  for each row execute function public._xp_sagrado();

-- ── Funções atualizadas (versões mais recentes, com o Sagrado) ─────────────────

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
         coalesce(sum(conhecimento),0) c, coalesce(sum(determinacao),0) de, coalesce(sum(sagrado),0) sg
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
    sagrado      = base_sagrado      + t.sg,
    updated_at   = now()
  where user_id = p_uid;

  if new_level > coalesce(old_level, 1) then
    insert into user_events (user_id, kind, ref)
      select p_uid, 'nivel', l::text from generate_series(coalesce(old_level, 1) + 1, new_level) l
    on conflict do nothing;
  end if;
end $$;

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
    'attr_sagrado',     _attr_level(st.sagrado),
    'missoes_sagrado',  (select count(*) from missions where user_id = p_uid and status = 'concluida' and dimension = 'espiritual'),
    'dias_sagrado',     (select count(distinct mission_date) from missions where user_id = p_uid and status = 'concluida' and dimension = 'espiritual'),
    'attr_min',         least(_attr_level(st.disciplina), _attr_level(st.foco), _attr_level(st.vitalidade),
                              _attr_level(st.conhecimento), _attr_level(st.determinacao)),
    'areas',            (select count(distinct dimension) from missions where user_id = p_uid and status = 'concluida' and dimension <> 'espiritual'),
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
        'vitalidade', _attr_level(st.vitalidade), 'conhecimento', _attr_level(st.conhecimento), 'determinacao', _attr_level(st.determinacao))
        || case when (select sagrado from profiles where id = p_user) then jsonb_build_object('sagrado', _attr_level(st.sagrado)) else '{}'::jsonb end,
      'my_attributes', jsonb_build_object('disciplina', _attr_level(me.disciplina), 'foco', _attr_level(me.foco),
        'vitalidade', _attr_level(me.vitalidade), 'conhecimento', _attr_level(me.conhecimento), 'determinacao', _attr_level(me.determinacao))
        || case when (select sagrado from profiles where id = v_uid) then jsonb_build_object('sagrado', _attr_level(me.sagrado)) else '{}'::jsonb end);
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
  if p_dimension not in ('fisica','mental','intelectual','produtividade','digital','autocuidado','espiritual') then raise exception 'dimensao_invalida'; end if;
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
    if v_dim is null or v_dim not in ('fisica','mental','intelectual','produtividade','digital','autocuidado','espiritual') then raise exception 'dimensao_invalida'; end if;
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

-- ── Mentor: tendência sem contradizer a constância ─────────────────────────────

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

  -- 2. Tendência: os últimos 7 dias completos contra os 7 anteriores (hoje ainda não acabou e fica de fora).
  -- Só fala de queda ou alta quando a diferença é real (pelo menos 3 missões e 20%), e nunca contradiz a constância.
  select count(*) filter (where x.d between p_today - 7 and p_today - 1), count(*) filter (where x.d between p_today - 14 and p_today - 8)
    into v_cur, v_prev
    from (select (m.completed_at at time zone v_prof.timezone)::date as d from missions m
           where m.user_id = p_uid and m.status = 'concluida'
             and m.completed_at >= ((p_today - 14)::timestamp at time zone v_prof.timezone)
             and m.completed_at < (p_today::timestamp at time zone v_prof.timezone)) x;
  if p_today - v_prof.program_start >= 14 and v_cur + v_prev >= 4 then
    if v_cur - v_prev >= 3 and v_cur >= v_prev * 1.2 then
      v_res := v_res || jsonb_build_object('id', 'tendencia', 'tone', 'positivo', 'title', 'Em alta',
        'text', format('%s missões nos últimos 7 dias, %s a mais que nos 7 anteriores.', v_cur, v_cur - v_prev));
    elsif v_prev - v_cur >= 3 and v_cur <= v_prev * 0.8 then
      if v_days >= 7 and v_met * 1.0 / v_days >= 0.8 then
        v_res := v_res || jsonb_build_object('id', 'tendencia', 'tone', 'neutro', 'title', 'Semana mais leve',
          'text', format('%s missões nos últimos 7 dias, contra %s nos 7 anteriores, e a meta diária seguiu cumprida. Semanas mais leves também fazem parte.', v_cur, v_prev));
      else
        v_res := v_res || jsonb_build_object('id', 'tendencia', 'tone', 'atencao', 'title', 'Ritmo mais lento',
          'text', format('%s missões nos últimos 7 dias, contra %s nos 7 anteriores. Quedas acontecem: recomeçar pela missão mais fácil do dia ajuda.', v_cur, v_prev));
      end if;
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
-- ── Caminho Sagrado: ativar, escolher práticas e acompanhar ──────────────────

create or replace function public._sagrado_state(p_uid uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_prof profiles;
  st character_stats;
  v_today date := _local_today(p_uid);
begin
  select * into v_prof from profiles where id = p_uid;
  select * into st from character_stats where user_id = p_uid;
  return jsonb_build_object(
    'enabled', coalesce(v_prof.sagrado, false),
    'practices', (select coalesce(jsonb_agg(jsonb_build_object(
                     'id', t.id, 'name', t.name, 'description', t.description, 'unit', t.unit, 'base_value', t.base_value,
                     'active', coalesce(h.active, false), 'target', h.current_target) order by t.sort), '[]'::jsonb)
                    from mission_templates t
                    left join user_habits h on h.user_id = p_uid and h.template_id = t.id
                   where t.dimension = 'espiritual'),
    'xp', coalesce(st.sagrado, 0),
    'level', _attr_level(coalesce(st.sagrado, 0)),
    'days', (select count(distinct mission_date) from missions
              where user_id = p_uid and status = 'concluida' and dimension = 'espiritual'),
    'today_done', (select count(*) from missions
                    where user_id = p_uid and status = 'concluida' and dimension = 'espiritual' and mission_date = v_today),
    'today_total', (select count(*) from missions
                     where user_id = p_uid and dimension = 'espiritual' and mission_date = v_today and kind = 'diaria'));
end $$;

create or replace function public.get_sagrado()
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  return _sagrado_state(v_uid);
end $$;

-- Ativa (com as práticas escolhidas) ou desativa o Caminho Sagrado. Desativar só pausa as práticas:
-- a XP e o nível de Sagrado já conquistados ficam guardados.
create or replace function public.set_sagrado(p_enabled boolean, p_practices text[])
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_prof profiles;
  v_today date;
  v_day int;
  v_keep text[] := '{}';
  t record;
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  select * into v_prof from profiles where id = v_uid;
  if not v_prof.onboarding_done or v_prof.program_start is null then raise exception 'programa_nao_iniciado'; end if;
  v_today := _local_today(v_uid);
  v_day := greatest(1, (v_today - v_prof.program_start) + 1);

  if coalesce(p_enabled, false) then
    select coalesce(array_agg(distinct x), '{}') into v_keep from unnest(coalesce(p_practices, '{}')) x
     where exists (select 1 from mission_templates where id = x and dimension = 'espiritual');
    if cardinality(v_keep) = 0 then raise exception 'escolha_uma_pratica'; end if;
  end if;

  update profiles set sagrado = coalesce(p_enabled, false) where id = v_uid;

  for t in select id from mission_templates where dimension = 'espiritual' loop
    if t.id = any(v_keep) then
      if exists (select 1 from user_habits where user_id = v_uid and template_id = t.id) then
        update user_habits set active = true, start_day = least(start_day, v_day) where user_id = v_uid and template_id = t.id;
      else
        perform _add_habit(v_uid, t.id, v_day);
      end if;
    else
      update user_habits set active = false where user_id = v_uid and template_id = t.id;
      delete from missions m using user_habits h
       where h.user_id = v_uid and h.template_id = t.id and m.habit_id = h.id
         and m.status = 'pendente' and m.mission_date >= v_today;
    end if;
  end loop;

  -- As práticas escolhidas já aparecem hoje
  perform _ensure_day(v_uid, v_today);
  return _sagrado_state(v_uid);
end $$;

-- ── Permissões ───────────────────────────────────────────────────────────────

revoke execute on function public._xp_sagrado(), public._sagrado_state(uuid), public.get_sagrado(), public.set_sagrado(boolean, text[])
  from public, anon, authenticated;
grant execute on function public.get_sagrado(), public.set_sagrado(boolean, text[]) to authenticated;
