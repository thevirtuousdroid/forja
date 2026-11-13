-- Testes da Etapa 4 (parte 2): ferramentas, rastreador de hábitos e Mentor. Rodam com: supabase/tests/run.sh
\set ON_ERROR_STOP on
set client_min_messages = notice;

\set answers '{"display_name":"Teo","daily_minutes":45,"exercise":1,"diet":2,"sleep_hours":1,"sleep_quality":1,"stress":1,"rest":2,"reflection":1,"reading":0,"learning":1,"planning":1,"procrastination":1,"discipline":2,"screen_time":0,"phone_morning":0,"focus":1,"water":0,"morning_routine":2,"environment":2,"main_goal":"intelectual"}'

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000e7', 'teo@teste.dev', '{"name":"Teo"}'),
  ('00000000-0000-0000-0000-0000000000e8', 'uma@teste.dev', '{"name":"Uma"}');

create function pg_temp.ts(d date) returns timestamptz language sql as $$
  select (d + time '12:00') at time zone 'America/Sao_Paulo'
$$;
create function pg_temp.open_day(p_uid uuid, d date) returns void language plpgsql as $$
begin
  perform public._ensure_day(p_uid, d);
  perform public._daily_maintenance(p_uid, d, pg_temp.ts(d));
end $$;
create function pg_temp.complete(p_uid uuid, d date, p_n int, p_dim text default null) returns int language plpgsql as $$
declare r record; n int := 0;
begin
  for r in select id from public.missions
            where user_id = p_uid and mission_date = d and status = 'pendente' and kind = 'diaria'
              and (p_dim is null or dimension = p_dim)
            order by name limit p_n loop
    perform public._complete_mission(p_uid, r.id, pg_temp.ts(d));
    n := n + 1;
  end loop;
  return n;
end $$;

set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000e8', false);
select public.submit_assessment(:'answers') is not null as ok \gset
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000e7', false);
select public.submit_assessment(:'answers') is not null as ok \gset
select public.ensure_today() is not null as ok \gset
reset role;

-- Hábitos que as ferramentas acompanham (água, leitura, meditação, redes e reflexão), todos desde hoje
do $$
declare u uuid := '00000000-0000-0000-0000-0000000000e7'; t text;
begin
  foreach t in array array['auto_agua','int_leitura','men_meditacao','dig_redes','men_reflexao'] loop
    if not exists (select 1 from public.user_habits where user_id = u and template_id = t) then
      perform public._add_habit(u, t, 1);
    end if;
  end loop;
  update public.user_habits set start_day = 1 where user_id = u;
  perform public._ensure_day(u, public._local_today(u));
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- A. Ferramentas pela API
-- ════════════════════════════════════════════════════════════════════════════
set role authenticated;
do $$
declare o jsonb; d jsonb; s jsonb; mid uuid; bid uuid; lid bigint;
begin
  o := public.tools_overview();
  assert (o->>'extras')::boolean and (select count(*) from jsonb_object_keys(o->'summary')) = 8, format('visão geral: %s', o);

  -- Ajustes
  begin perform public.update_tool_settings('{"agua_meta": 50}'); assert false, 'meta de água absurda';
  exception when raise_exception then assert sqlerrm = 'ajuste_invalido', sqlerrm; end;
  begin perform public.update_tool_settings('{"sono_deitar": "25:00"}'); assert false, 'horário inválido';
  exception when raise_exception then assert sqlerrm = 'ajuste_invalido', sqlerrm; end;
  s := public.update_tool_settings('{"tela_limite": 90, "sono_deitar": "22:30", "foco_min": 30}');
  assert (s->>'tela_limite')::int = 90 and s->>'sono_deitar' = '22:30' and (s->>'agua_ml')::int = 250, format('ajustes: %s', s);

  -- Água: a meta vem do hábito de água; a missão fica pronta ao chegar na meta
  d := public.log_tool('agua', '{"cups": 2}');
  d := public.log_tool('agua', '{"cups": 1}');
  assert (d->'summary'->>'cups')::int = 3 and (d->'summary'->>'goal')::int = 4, format('água: %s', d->'summary');
  assert jsonb_array_length(d->'missions') = 1 and not (d->'missions'->0->>'ready')::boolean;
  begin perform public.log_tool('agua', '{"cups": -4}'); assert false, 'não fica negativo';
  exception when raise_exception then assert sqlerrm = 'registro_invalido', sqlerrm; end;
  begin perform public.log_tool('agua', '{"cups": 0}'); assert false, 'zero não registra';
  exception when raise_exception then assert sqlerrm = 'registro_invalido', sqlerrm; end;
  d := public.log_tool('agua', '{"cups": 1}');
  assert (d->'missions'->0->>'ready')::boolean, format('missão de água pronta: %s', d->'missions');
  assert (select status from public.missions where id = (d->'missions'->0->>'id')::uuid) = 'pendente', 'a ferramenta não conclui sozinha';
  perform public.complete_mission((d->'missions'->0->>'id')::uuid);
  d := public.get_tool('agua');
  assert d->'missions'->0->>'status' = 'concluida' and not (d->'missions'->0->>'ready')::boolean;
  assert (public.tools_overview()->'summary'->'agua'->>'cups')::int = 4;

  -- Foco: sessão ligada a uma missão em minutos
  d := public.get_tool('foco');
  assert jsonb_array_length(d->'focusable') >= 1, format('missões para focar: %s', d->'focusable');
  select (d->'focusable'->0->>'id')::uuid into mid;
  d := public.log_tool('foco', format('{"minutes": 25, "mission_id": "%s", "label": "Estudo"}', mid)::jsonb);
  assert (d->'summary'->>'minutes')::int = 25 and (d->'summary'->>'sessions')::int = 1;
  assert exists (select 1 from jsonb_array_elements(d->'missions') m where (m->>'id')::uuid = mid and (m->>'progress')::int = 25);
  begin perform public.log_tool('foco', '{"minutes": 0}'); assert false, 'sessão vazia';
  exception when raise_exception then assert sqlerrm = 'registro_invalido', sqlerrm; end;
  begin perform public.log_tool('foco', '{"minutes": 200}'); assert false, 'sessão longa demais';
  exception when raise_exception then assert sqlerrm = 'registro_invalido', sqlerrm; end;
  begin perform public.log_tool('foco', '{"minutes": 25, "mission_id": "00000000-0000-0000-0000-000000000000"}'); assert false, 'missão de outra pessoa';
  exception when raise_exception then assert sqlerrm = 'missao_nao_encontrada', sqlerrm; end;

  -- Sono: um registro por dia, horas calculadas no servidor
  d := public.log_tool('sono', '{"bed": "23:10", "wake": "07:00", "quality": 4}');
  assert (d->'summary'->>'minutes')::int = 470 and (d->'summary'->>'quality')::int = 4, format('sono: %s', d->'summary');
  d := public.log_tool('sono', '{"bed": "22:30", "wake": "06:30"}');
  assert (d->'summary'->>'minutes')::int = 480 and jsonb_array_length(d->'entries') = 1, 'o novo registro substitui o anterior';
  begin perform public.log_tool('sono', '{"bed": "06:00", "wake": "06:30"}'); assert false, 'sono curto demais';
  exception when raise_exception then assert sqlerrm = 'registro_invalido', sqlerrm; end;
  begin perform public.log_tool('sono', '{"bed": "24:00", "wake": "06:30"}'); assert false, 'horário inválido';
  exception when raise_exception then assert sqlerrm = 'registro_invalido', sqlerrm; end;

  -- Alimentação: calorias são opcionais
  perform public.log_tool('alimentacao', '{"meal": "almoco", "name": "Arroz, feijão e salada", "kcal": 650}');
  d := public.log_tool('alimentacao', '{"meal": "lanche", "name": "Fruta"}');
  assert (d->'summary'->>'kcal')::int = 650 and (d->'summary'->>'meals')::int = 2 and (d->'summary'->>'with_kcal')::int = 1,
    format('alimentação: %s', d->'summary');
  begin perform public.log_tool('alimentacao', '{"meal": "ceia", "name": "Pão"}'); assert false, 'refeição inválida';
  exception when raise_exception then assert sqlerrm = 'registro_invalido', sqlerrm; end;

  -- Leitura com livro: páginas avançam, o livro termina e volta se o registro for apagado
  bid := (public.save_book(null, 'O Hobbit', 'J. R. R. Tolkien', 300)->>'id')::uuid;
  d := public.log_tool('leitura', format('{"pages": 20, "minutes": 25, "book_id": "%s"}', bid)::jsonb);
  assert (d->'summary'->>'pages')::int = 20 and (d->'summary'->'book'->>'current_page')::int = 20, format('leitura: %s', d->'summary');
  assert exists (select 1 from jsonb_array_elements(d->'missions') m where (m->>'ready')::boolean), format('missão de leitura pronta: %s', d->'missions');
  d := public.log_tool('leitura', format('{"pages": 290, "book_id": "%s"}', bid)::jsonb);
  assert (select status from public.books where id = bid) = 'concluido' and (select current_page from public.books where id = bid) = 300;
  assert exists (select 1 from public.user_achievements where achievement_id = 'fe_livro'), 'Última página';
  lid := (d->'entries'->0->>'id')::bigint;
  perform public.delete_tool_log(lid);
  assert (select status from public.books where id = bid) = 'lendo' and (select current_page from public.books where id = bid) = 20, 'registro apagado volta o livro';
  begin perform public.log_tool('leitura', '{"pages": 0}'); assert false, 'leitura vazia';
  exception when raise_exception then assert sqlerrm = 'registro_invalido', sqlerrm; end;
  assert jsonb_array_length(public.get_books()) = 1;

  -- Meditação e tempo de tela
  d := public.log_tool('meditacao', '{"minutes": 10, "kind": "respiracao"}');
  assert (d->'summary'->>'minutes')::int = 10;
  assert exists (select 1 from jsonb_array_elements(d->'missions') m where (m->>'ready')::boolean), format('missão de meditação: %s', d->'missions');
  d := public.log_tool('tela', '{"minutes": 120}');
  assert not (d->'missions'->0->>'ready')::boolean, 'acima do limite';
  d := public.log_tool('tela', '{"minutes": 80}');
  assert (d->'missions'->0->>'ready')::boolean and jsonb_array_length(d->'entries') = 1, format('dentro do limite: %s', d);

  -- Diário: um por dia, só a própria pessoa lê
  perform public.log_tool('diario', '{"text": "Primeira versão", "mood": 3}');
  d := public.log_tool('diario', '{"text": "Hoje foi um bom dia.", "mood": 4, "gratitude": "Café com a minha irmã"}');
  assert (d->'summary'->>'written')::boolean and (d->'summary'->>'mood')::int = 4 and jsonb_array_length(d->'entries') = 1;
  assert (d->'missions'->0->>'ready')::boolean, 'missão de reflexão pronta';
  assert jsonb_array_length(public.get_diary(10)) = 1 and public.get_diary(10)->0->>'gratitude' = 'Café com a minha irmã';
  begin perform public.log_tool('diario', '{"text": "", "mood": 4}'); assert false, 'diário vazio';
  exception when raise_exception then assert sqlerrm = 'registro_invalido', sqlerrm; end;

  -- Histórico, visão geral e rastreador de hábitos
  d := public.tool_history('agua', 7);
  assert jsonb_array_length(d->'days') = 7 and (d->'days'->6->>'value')::int = 4 and (d->'days'->6->>'extra')::int = 4, format('histórico: %s', d);
  assert (public.tools_overview()->>'ready')::int >= 3, format('missões prontas: %s', public.tools_overview()->'ready');
  d := public.habit_tracker();
  assert jsonb_array_length(d) >= 5 and jsonb_array_length(d->0->'days') = 28, format('rastreador: %s', d->0);
  assert exists (select 1 from jsonb_array_elements(d) h where h->'habit'->>'name' = 'Água' and (h->>'streak')::int = 1
                   and h->'days'->27->>'status' = 'feito'), 'água feita hoje';

  begin insert into public.tool_logs (user_id, tool, day, data) values (auth.uid(), 'foco', current_date, '{"minutes":999}');
        assert false, 'registro só pelas funções'; exception when insufficient_privilege then null; end;
  begin perform public.log_tool('martelo', '{}'); assert false, 'ferramenta inválida';
  exception when raise_exception then assert sqlerrm = 'ferramenta_invalida', sqlerrm; end;
  begin perform public._tool_summary(auth.uid(), 'agua', current_date); assert false, 'funções internas fechadas';
  exception when insufficient_privilege then null; end;
  raise notice 'OK ferramentas';
end $$;

-- Outra pessoa não vê nem apaga os registros
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000e8', false);
do $$ begin
  assert (select count(*) from public.tool_logs) = 0 and (select count(*) from public.books) = 0, 'leitura protegida';
  begin perform public.delete_tool_log((select max(id) from public.tool_logs)); assert false;
  exception when raise_exception then assert sqlerrm = 'registro_nao_encontrado', sqlerrm; end;
  assert jsonb_array_length(public.get_diary(10)) = 0;
end $$;
reset role;

-- Ferramentas extras são Premium; foco, água e diário continuam gratuitos
select public.admin_set_premium_aberto(false) is not null as ok \gset
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000e7', false);
do $$ begin
  begin perform public.log_tool('sono', '{"bed": "23:00", "wake": "07:00"}'); assert false, 'sono é premium';
  exception when raise_exception then assert sqlerrm = 'recurso_premium', sqlerrm; end;
  perform public.log_tool('agua', '{"cups": 1}');
  perform public.log_tool('foco', '{"minutes": 5}');
  assert not (public.tools_overview()->>'extras')::boolean;
  begin perform public.set_mentor(true); assert false, 'Mentor é premium';
  exception when raise_exception then assert sqlerrm = 'recurso_premium', sqlerrm; end;
  raise notice 'OK limites do plano gratuito nas ferramentas';
end $$;
reset role;
select public.admin_set_premium_aberto(true, null) is not null as ok \gset

-- ════════════════════════════════════════════════════════════════════════════
-- B. Mentor: análises, sugestões com autorização e relatório semanal
-- ════════════════════════════════════════════════════════════════════════════
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000e7', false);
do $$
declare m jsonb;
begin
  m := public.get_mentor();
  assert not (m->>'enabled')::boolean and (m->>'allowed')::boolean and not m ? 'insights', format('Mentor desligado por padrão: %s', m);
  m := public.set_mentor(true);
  assert (m->>'enabled')::boolean;
end $$;
reset role;

do $$
declare
  u uuid := '00000000-0000-0000-0000-0000000000e7';
  s date := '2026-10-01';
  i int; r jsonb; n int; h record; mon date;
begin
  delete from public.missions where user_id = u;
  delete from public.xp_ledger where user_id = u;
  delete from public.tool_logs where user_id = u;
  delete from public.mentor_suggestions where user_id = u;
  update public.user_habits set current_target = base_value where user_id = u;
  update public.profiles set program_start = s, mentor_checked_on = null where id = u;
  perform public._recalc_stats(u);

  -- Duas semanas completas (as metas sobem), depois uma semana fazendo só a missão de água
  for i in 0 .. 13 loop
    perform pg_temp.open_day(u, s + i);
    perform pg_temp.complete(u, s + i, 30);
    insert into public.tool_logs (user_id, tool, day, data) values (u, 'sono', s + i, '{"bed":"01:00","wake":"06:00","minutes":300}');
  end loop;
  for i in 14 .. 20 loop
    perform pg_temp.open_day(u, s + i);
    perform public._complete_mission(u, (select m.id from public.missions m join public.user_habits uh on uh.id = m.habit_id
                                          where m.user_id = u and m.mission_date = s + i and uh.template_id = 'auto_agua'), pg_temp.ts(s + i));
    insert into public.tool_logs (user_id, tool, day, data) values (u, 'sono', s + i, '{"bed":"01:00","wake":"06:00","minutes":300}');
  end loop;
  perform pg_temp.open_day(u, s + 21);
  assert exists (select 1 from public.user_habits where user_id = u and current_target > base_value), 'metas subiram com a progressão';

  -- Análises
  r := public._mentor_insights(u, s + 21);
  assert exists (select 1 from jsonb_array_elements(r) x where x->>'id' = 'tendencia' and x->>'tone' = 'atencao'), format('tendência de queda: %s', r);
  assert exists (select 1 from jsonb_array_elements(r) x where x->>'id' = 'periodo' and x->>'text' like '%à tarde%'), 'melhor horário';
  assert exists (select 1 from jsonb_array_elements(r) x where x->>'id' = 'sono' and x->>'tone' = 'atencao' and x->>'text' like '%5h%'),
    format('sono abaixo da meta: %s', r);
  assert exists (select 1 from jsonb_array_elements(r) x where x->>'id' = 'constancia'), 'constância';
  assert not exists (select 1 from jsonb_array_elements(r) x where x->>'text' ~* 'diagn|transtorno|doença'), 'sem diagnósticos';

  -- Sugestões (rodou na abertura do dia 22)
  assert (select mentor_checked_on from public.profiles where id = u) = s + 21;
  select count(*) into n from public.mentor_suggestions where user_id = u and status = 'aberta' and kind = 'reduzir_meta';
  assert n >= 1, format('sugestões: %s', (select jsonb_agg(kind) from public.mentor_suggestions where user_id = u));
  for h in select * from public.mentor_suggestions where user_id = u and kind = 'reduzir_meta' loop
    assert (h.data->>'to')::int < (h.data->>'from')::int and h.data->>'text' like '%Ajustar também é evoluir%';
  end loop;
  assert not exists (select 1 from public.mentor_suggestions where user_id = u and kind = 'reduzir_meta' and ref = (
    select id::text from public.user_habits where user_id = u and template_id = 'auto_agua')), 'hábito em dia não recebe sugestão';
  assert public._mentor_refresh(u, s + 21) = 0, 'uma vez por dia';
  assert (select count(*) from public.mentor_suggestions where user_id = u and status = 'aberta')
       = (select count(distinct (kind, ref)) from public.mentor_suggestions where user_id = u and status = 'aberta'), 'sem repetidas';

  -- Relatório semanal: fechado na abertura da segunda-feira seguinte
  mon := date_trunc('week', (s + 21)::timestamp)::date;
  assert exists (select 1 from public.mentor_reports where user_id = u and week_start = mon - 7), 'relatório criado na segunda-feira';
  assert public._finalize_reports(u, mon + 1) = 0, 'um relatório por semana';
  assert (select count(*) from public.mentor_reports where user_id = u) = 3, 'uma por semana desde o início';
  r := (select data from public.mentor_reports where user_id = u and week_start = mon - 7);
  assert (r->>'missions')::int > 0 and (r->>'complete')::boolean and r->>'highlight' is not null, format('relatório: %s', r);
  assert exists (select 1 from public.user_events where user_id = u and kind = 'relatorio' and ref = (mon - 7)::text);
  raise notice 'OK Mentor: análises, sugestões e relatório (semana de %, % missões)', mon - 7, r->>'missions';
end $$;

set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000e7', false);
do $$
declare
  m jsonb; sug jsonb; r jsonb; hid uuid; before int; ev jsonb; other jsonb;
begin
  m := public.get_mentor();
  assert (m->>'enabled')::boolean and jsonb_array_length(m->'insights') >= 1 and jsonb_array_length(m->'reports') = 3, format('Mentor: %s', m);
  assert not exists (select 1 from jsonb_array_elements(m->'suggestions') x where x->>'kind' = 'aumentar_minimo'),
    'sem sugestões contraditórias com os dados de hoje';
  assert m->'this_week' is not null and not (m->'this_week'->>'complete')::boolean, 'semana atual em andamento';
  assert (public.ensure_today()->>'mentor_open')::int >= 1;

  -- Aceitar: a meta baixa e fica registrado como ajuste (conquista "Ajuste consciente")
  select s into sug from jsonb_array_elements(m->'suggestions') s where s->>'kind' = 'reduzir_meta' limit 1;
  hid := (sug->'data'->>'habit_id')::uuid;
  select current_target into before from public.user_habits where id = hid;
  r := public.respond_suggestion((sug->>'id')::uuid, true);
  assert r->>'status' = 'aceita';
  assert (select current_target from public.user_habits where id = hid) = (sug->'data'->>'to')::int and before > (sug->'data'->>'to')::int,
    'meta ajustada só depois do aceite';
  assert exists (select 1 from public.habit_adjustments where habit_id = hid and new_target < old_target);
  assert exists (select 1 from public.user_achievements where achievement_id = 'h_ajuste'), 'Ajuste consciente';
  begin perform public.respond_suggestion((sug->>'id')::uuid, true); assert false, 'já respondida';
  exception when raise_exception then assert sqlerrm = 'sugestao_nao_encontrada', sqlerrm; end;

  -- Recusar: nada muda
  select s into other from jsonb_array_elements(public.get_mentor()->'suggestions') s limit 1;
  if other is not null then
    perform public.respond_suggestion((other->>'id')::uuid, false);
    assert (select status from public.mentor_suggestions where id = (other->>'id')::uuid) = 'recusada';
  end if;

  -- Relatório pela API e aviso
  r := public.get_report(null);
  assert (r->>'missions')::int > 0;
  ev := public.pending_events();
  assert exists (select 1 from jsonb_array_elements(ev) e where e->>'kind' = 'relatorio' and (e->'data'->>'missions')::int > 0), 'aviso do relatório';

  begin perform public._mentor_refresh(auth.uid(), current_date); assert false, 'funções internas fechadas';
  exception when insufficient_privilege then null; end;
  begin perform public._adjust_habit(auth.uid(), hid, 1, true); assert false, 'funções internas fechadas';
  exception when insufficient_privilege then null; end;
  begin update public.mentor_suggestions set status = 'aceita'; assert false, 'sugestão só pelas funções';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

-- Uma sugestão recusada não volta logo em seguida
do $$
declare u uuid := '00000000-0000-0000-0000-0000000000e7'; k text; rf text;
begin
  select kind, ref into k, rf from public.mentor_suggestions where user_id = u and status = 'recusada' limit 1;
  if k is not null then
    update public.profiles set mentor_checked_on = null where id = u;
    perform public._mentor_refresh(u, public._local_today(u));
    assert not exists (select 1 from public.mentor_suggestions where user_id = u and kind = k and ref = rf and status = 'aberta'),
      'recusada não volta em 14 dias';
  end if;
end $$;

-- Desligar o Mentor encerra as sugestões abertas
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000e7', false);
do $$ begin
  perform public.set_mentor(false);
  assert not (public.get_mentor()->>'enabled')::boolean;
  assert (select count(*) from public.mentor_suggestions where status = 'aberta') = 0;
  assert (public.ensure_today()->>'mentor_open')::int = 0;
  raise notice 'OK Mentor: autorização, recusa e desligar';
end $$;
reset role;
do $$ begin raise notice 'TESTES DA ETAPA 4 PASSARAM'; end $$;
