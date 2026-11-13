-- Testa o script da conta de teste (supabase/admin/conta_de_teste.sql) sobre o banco completo.
-- Roda com: supabase/tests/run.sh
\set ON_ERROR_STOP on
set client_min_messages = warning;

-- 1. Uma conta de verdade com progresso usando o e-mail do script: ele precisa recusar
insert into auth.users (id, email, raw_user_meta_data, raw_app_meta_data) values
  ('00000000-0000-0000-0000-0000000000f9', 'seunome+teste@gmail.com', '{"name":"Real"}', '{"provider":"email"}');
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000f9', false) \gset
select public.submit_assessment('{"display_name":"Real","daily_minutes":30,"exercise":1,"diet":2,"sleep_hours":1,"sleep_quality":1,"stress":1,"rest":2,"reflection":1,"reading":0,"learning":1,"planning":1,"procrastination":1,"discipline":2,"screen_time":0,"phone_morning":0,"focus":1,"water":1,"morning_routine":2,"environment":2,"main_goal":"intelectual"}') is not null as ok \gset
select public.complete_mission((select id from public.missions order by name limit 1)) is not null as ok \gset
reset role;
\set ON_ERROR_STOP off
\ir ../admin/conta_de_teste.sql
\set ON_ERROR_STOP on
do $$ begin
  assert (select count(*) from public.missions where user_id = '00000000-0000-0000-0000-0000000000f9' and status = 'concluida') = 1,
    'a conta com progresso de verdade não foi tocada';
  assert not coalesce((select (raw_app_meta_data->>'forja_teste')::boolean from auth.users where id = '00000000-0000-0000-0000-0000000000f9'), false);
end $$;
update auth.users set email = 'real@exemplo.dev' where id = '00000000-0000-0000-0000-0000000000f9';

-- 2. A conta de teste criada pelo painel (sem avaliação, sem nada)
insert into auth.users (id, email, raw_user_meta_data, raw_app_meta_data) values
  ('00000000-0000-0000-0000-0000000000f8', 'seunome+teste@gmail.com', '{}', '{"provider":"email","providers":["email"]}');
\ir ../admin/conta_de_teste.sql

set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000f8', false) \gset
do $$
declare t jsonb; j jsonb; mi jsonb; bo jsonb; s jsonb; n jsonb; c jsonb; se jsonb; r jsonb; me jsonb;
begin
  t := public.ensure_today(); j := public.get_journey(); mi := public.get_mode_info(); bo := public.get_bosses();
  assert (t->>'day')::int = 70 and (t->>'premium')::boolean, format('dia e Premium: %s', t);
  assert (j->>'current_streak')::int >= 60 and (j->>'best_streak')::int >= 66, format('sequência: %s', j->'current_streak');
  assert (mi->'desafio'->>'available')::boolean and (mi->'extremo'->>'available')::boolean and mi->>'mode' = 'normal', format('modos: %s', mi);
  assert (select count(*) from jsonb_array_elements(bo->'bosses') x where (x->>'victories')::int >= 1) = 7, 'os 7 chefes vencidos';
  assert t->'boss'->>'boss_id' = 'hidra' and (t->'boss'->>'effective')::int = (t->'boss'->>'hp')::int - 1, format('revanche a um golpe: %s', t->'boss');
  assert (select count(*) from public.user_achievements) = (select count(*) from public.achievement_catalog), 'todas as conquistas';
  assert (select count(*) from public.user_items) = (select count(*) from public.item_catalog), 'todos os itens';
  assert (select active_title from public.profiles) = 'tit_66';
  assert (select count(*) from public.missions where mission_date = (t->>'today')::date and status = 'pendente') >= 5, 'missões de hoje abertas';
  assert jsonb_array_length(public.pending_events()) = 0, 'sem enxurrada de avisos';

  s := public.get_social(); n := public.get_notifications(); c := public.get_challenges();
  se := public.get_season(); r := public.get_ranking('amigos', null, 'pontos'); me := public.get_mentor();
  assert jsonb_array_length(s->'friends') = 3 and jsonb_array_length(s->'incoming') = 1, 'três amigos e um pedido';
  assert (n->>'unseen')::int = 6, format('avisos sociais: %s', n->'unseen');
  assert jsonb_array_length(c) = 4 and exists (select 1 from jsonb_array_elements(c) x where x->>'my_status' = 'convidado'), 'desafios e convite';
  assert jsonb_array_length(se->'history') >= 1 and jsonb_array_length(r->'rows') = 4, 'temporadas e ranking';
  assert (me->>'enabled')::boolean and jsonb_array_length(me->'reports') >= 6 and jsonb_array_length(me->'suggestions') >= 1, 'Mentor com dados';
  assert (public.tools_overview()->'summary'->'leitura'->'book'->>'title') = 'O Hobbit', 'livro em andamento';
  assert jsonb_array_length(public.tool_history('sono', 30)->'days') = 30;
end $$;
reset role;

-- 3. Rodar de novo refaz tudo, sem duplicar bots, amizades ou grupos
\ir ../admin/conta_de_teste.sql
do $$
declare u uuid := '00000000-0000-0000-0000-0000000000f8';
begin
  assert (select count(*) from auth.users where email like '%@bots.forja.invalid') = 4, 'quatro bots';
  assert (select count(*) from public.friendships where u in (requester, addressee)) = 4, 'três amizades e um pedido';
  assert (select count(*) from public.social_groups where owner = u) = 1, 'um grupo';
  assert (select count(*) from public.missions where user_id = '00000000-0000-0000-0000-0000000000f9' and status = 'concluida') = 1,
    'a outra conta continua intacta';
  raise warning 'OK conta de teste (script do painel)';
end $$;
