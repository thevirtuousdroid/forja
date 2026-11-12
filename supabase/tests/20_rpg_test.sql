-- Testes da Etapa 3: itens, avatar, títulos, conquistas, chefes e modos. Rodam com: supabase/tests/run.sh
\set ON_ERROR_STOP on
set client_min_messages = notice;

\set answers '{"display_name":"Teste","daily_minutes":30,"exercise":1,"diet":2,"sleep_hours":1,"sleep_quality":1,"stress":1,"rest":2,"reflection":1,"reading":0,"learning":1,"planning":1,"procrastination":1,"discipline":2,"screen_time":0,"phone_morning":0,"focus":1,"water":1,"morning_routine":2,"environment":2,"main_goal":"intelectual"}'

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000d1', 'd@teste.dev', '{"name":"Dora"}'),
  ('00000000-0000-0000-0000-0000000000e1', 'e@teste.dev', '{"name":"Edu"}'),
  ('00000000-0000-0000-0000-0000000000f1', 'f@teste.dev', '{"name":"Fê"}');

-- Ajudantes (rodam como administrador, com datas controladas)
create function pg_temp.ts(d date) returns timestamptz language sql as $$
  select (d + time '12:00') at time zone 'America/Sao_Paulo'
$$;
create function pg_temp.open_day(p_uid uuid, d date) returns void language plpgsql as $$
begin
  perform public._ensure_day(p_uid, d);
  perform public._daily_maintenance(p_uid, d, pg_temp.ts(d));
end $$;
-- Conclui até p_n missões diárias pendentes do dia (opcionalmente só de uma área)
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
-- Começa a pessoa do zero numa data do passado
create function pg_temp.reset_user(p_uid uuid, start date) returns void language plpgsql as $$
begin
  delete from public.missions where user_id = p_uid;
  delete from public.xp_ledger where user_id = p_uid;
  delete from public.user_events where user_id = p_uid;
  delete from public.user_achievements where user_id = p_uid;
  delete from public.user_items where user_id = p_uid;
  update public.profiles set program_start = start where id = p_uid;
  perform public._recalc_stats(p_uid);
  delete from public.user_events where user_id = p_uid;
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- A. Itens iniciais, avatar e títulos (pela API, como a pessoa)
-- ════════════════════════════════════════════════════════════════════════════
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000d1', false);
select public.submit_assessment(:'answers') is not null as ok \gset
select public.ensure_today() is not null as ok \gset

do $$
declare av jsonb;
begin
  assert (select count(*) from public.user_items) = 5,
    format('5 itens iniciais (%s)', (select string_agg(item_id, ',') from public.user_items));
  assert exists (select 1 from public.user_items where item_id = 'tit_aprendiz'), 'título inicial';
  assert not exists (select 1 from public.user_events where kind = 'item'), 'itens iniciais não geram aviso';
  select avatar into av from public.profiles;
  assert av->'equip'->>'corpo' = 'cor_tunica' and av->'equip'->>'moldura' = 'mol_bronze', format('equipamento inicial: %s', av);
  assert (av->>'personalizado')::boolean = false and (av->>'pele')::int between 0 and 5, 'aparência inicial gerada';
  assert (select display_name from public.profiles) = 'Teste', 'nome vem do questionário';

  begin perform public.update_avatar('{"pele":1,"cabelo":2,"corCabelo":3,"barba":0,"corRoupa":1,"equip":{"cabeca":"cab_capuz"}}');
        assert false, 'item que a pessoa não tem'; exception when raise_exception then null; end;
  begin perform public.update_avatar('{"pele":1,"cabelo":2,"corCabelo":3,"barba":0,"corRoupa":1,"equip":{"corpo":"cab_faixa"}}');
        assert false, 'item no lugar errado'; exception when raise_exception then null; end;
  begin perform public.update_avatar('{"pele":9,"cabelo":2,"corCabelo":3,"barba":0,"corRoupa":1}');
        assert false, 'aparência fora do intervalo'; exception when raise_exception then null; end;
  begin perform public.update_avatar('{"pele":"1","cabelo":2,"corCabelo":3,"barba":0,"corRoupa":1}');
        assert false, 'aparência com tipo errado'; exception when raise_exception then null; end;

  av := public.update_avatar('{"pele":2,"cabelo":4,"corCabelo":1,"barba":1,"corRoupa":3,"equip":{"cabeca":"cab_faixa","arma":"arm_martelo"},"extra":"ignorado"}');
  assert av->'equip'->>'cabeca' = 'cab_faixa' and av->'equip'->>'corpo' = 'cor_tunica', format('avatar salvo: %s', av);
  assert (av->>'personalizado')::boolean and not av ? 'extra', 'campos desconhecidos são descartados';

  begin perform public.set_title('tit_lenda'); assert false, 'título que a pessoa não tem'; exception when raise_exception then null; end;
  perform public.set_title('tit_aprendiz');
  assert (select active_title from public.profiles) = 'tit_aprendiz';
  perform public.set_title(null);

  begin insert into public.user_items (user_id, item_id, source) values (auth.uid(), 'cab_coroa', 'trapaça');
        assert false, 'não pode se dar itens'; exception when insufficient_privilege then null; end;
  begin update public.profiles set avatar = '{}'; assert false, 'não pode editar o avatar direto'; exception when insufficient_privilege then null; end;
  begin insert into public.user_bosses (user_id, boss_id, started_on, deadline, hp, status) values (auth.uid(), 'juiz', current_date, current_date, 1, 'vencido');
        assert false, 'não pode registrar vitória'; exception when insufficient_privilege then null; end;
  begin perform public._grant_items(auth.uid()); assert false, 'funções internas fechadas'; exception when insufficient_privilege then null; end;
  begin perform public._start_boss(auth.uid(), 'juiz', current_date, now()); assert false, 'funções internas fechadas'; exception when insufficient_privilege then null; end;
  begin perform public._set_mode(auth.uid(), 'extremo', true, current_date); assert false, 'funções internas fechadas'; exception when insufficient_privilege then null; end;
  assert (select count(*) from public.user_items where user_id <> auth.uid()) = 0, 'só enxerga os próprios itens';
  raise notice 'OK itens iniciais, avatar, títulos e bloqueios';
end $$;

-- Primeira missão: conquista, XP e aviso
do $$
declare
  r jsonb; ev jsonb; ach jsonb; ids bigint[];
begin
  r := public.complete_mission((select id from public.missions where kind = 'diaria' order by name limit 1));
  assert (r->>'xp')::int > 0;
  assert exists (select 1 from public.user_achievements where achievement_id = 'm_1'), 'Primeira faísca';
  assert (select amount from public.xp_ledger where source = 'conquista' and ref = 'm_1') = 20, 'XP da conquista';
  assert (select total_xp from public.character_stats) = (select sum(amount) from public.xp_ledger), 'XP coerente';

  ev := public.pending_events();
  assert exists (select 1 from jsonb_array_elements(ev) e where e->>'kind' = 'conquista' and e->>'ref' = 'm_1'
                   and e->'data'->>'name' = 'Primeira faísca'), format('aviso de conquista: %s', ev);
  select array_agg((e->>'id')::bigint) into ids from jsonb_array_elements(ev) e;
  assert (public.mark_events_seen(ids)->>'marked')::int = jsonb_array_length(ev);
  assert jsonb_array_length(public.pending_events()) = 0, 'avisos marcados como vistos';
  assert (public.mark_events_seen(ids)->>'marked')::int = 0;

  ach := public.get_achievements();
  assert jsonb_array_length(ach->'items') = 44, format('44 conquistas (%s)', jsonb_array_length(ach->'items'));
  assert exists (select 1 from jsonb_array_elements(ach->'items') a where a->>'id' = 'm_1' and a->>'unlocked_at' is not null);
  assert exists (select 1 from jsonb_array_elements(ach->'items') a where a->>'id' = 'm_25' and (a->>'current')::int = 1 and a->>'unlocked_at' is null);
  assert exists (select 1 from jsonb_array_elements(ach->'items') a where a->>'id' = 'h_fenix'
                   and a->'rewards' @> '[{"id":"cap_fenix"}]'), 'conquista mostra a recompensa';
  raise notice 'OK conquista, XP e avisos';
end $$;

-- Ajuste consciente (conquista oculta) e registro dos ajustes
do $$
declare h public.user_habits;
begin
  select * into h from public.user_habits where step > 0 order by name limit 1;
  perform public.adjust_habit(h.id, h.base_value + h.step, true);
  assert not exists (select 1 from public.user_achievements where achievement_id = 'h_ajuste'), 'subir a meta não conta';
  perform public.adjust_habit(h.id, h.base_value, true);
  assert (select count(*) from public.habit_adjustments) = 2;
  assert exists (select 1 from public.user_achievements where achievement_id = 'h_ajuste'), 'reduzir a meta desbloqueia';
  perform public.adjust_habit(h.id, h.base_value, true);
  assert (select count(*) from public.habit_adjustments) = 2, 'sem mudança, sem registro';
  raise notice 'OK ajuste consciente';
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- B. Itens por nível e moldura que evolui sozinha
-- ════════════════════════════════════════════════════════════════════════════
reset role;
do $$
declare uid uuid := '00000000-0000-0000-0000-0000000000d1'; lvl int;
begin
  insert into public.xp_ledger (user_id, source, day, amount, disciplina) values (uid, 'marco', current_date, 800, 800);
  perform public._progress_rewards(uid, current_date);
  select level into lvl from public.character_stats where user_id = uid;
  assert lvl >= 4, format('nível %s', lvl);
  assert exists (select 1 from public.user_items where user_id = uid and item_id = 'cap_curta'), 'nível 2: capa curta';
  assert exists (select 1 from public.user_items where user_id = uid and item_id = 'cab_capuz'), 'nível 3: capuz';
  assert exists (select 1 from public.user_items where user_id = uid and item_id = 'mol_ferro'), 'nível 4: moldura de ferro';
  assert exists (select 1 from public.user_items where user_id = uid and item_id = 'tit_faisca'), 'nível 4: título';
  assert not exists (select 1 from public.user_items where user_id = uid and item_id = 'cor_gibao'), 'nível 5 ainda não';
  assert (select avatar->'equip'->>'moldura' from public.profiles where id = uid) = 'mol_ferro', 'moldura equipada sozinha';
  assert (select avatar->'equip'->>'cabeca' from public.profiles where id = uid) = 'cab_faixa', 'resto do avatar mantido';
  assert exists (select 1 from public.user_events where user_id = uid and kind = 'item' and ref = 'cab_capuz'), 'aviso de item';
  assert (select count(*) from public.user_events where user_id = uid and kind = 'nivel') = lvl - 1, 'um aviso por nível';
  raise notice 'OK itens por nível (nível %)', lvl;
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- C. Chefes: bloqueios, golpes, desfazer, vitória, revanche, recuo e cura
-- ════════════════════════════════════════════════════════════════════════════
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000e1', false);
select public.submit_assessment(:'answers') is not null as ok \gset
reset role;

do $$
declare
  uid uuid := '00000000-0000-0000-0000-0000000000e1';
  s date := '2026-10-01';
  r jsonb; b jsonb; fid uuid; i int;
begin
  perform pg_temp.reset_user(uid, s);
  perform pg_temp.open_day(uid, s);

  begin perform public._start_boss(uid, 'tempestade', s, pg_temp.ts(s)); assert false, 'dia 1: ainda bloqueado';
  exception when raise_exception then assert sqlerrm = 'chefe_bloqueado_dia', sqlerrm; end;

  perform pg_temp.open_day(uid, s + 1);
  begin perform public._start_boss(uid, 'tempestade', s + 1, pg_temp.ts(s + 1)); assert false, 'sem hábito de saúde mental';
  exception when raise_exception then assert sqlerrm = 'chefe_bloqueado_habito', sqlerrm; end;
  begin perform public._start_boss(uid, 'hidra', s + 1, pg_temp.ts(s + 1)); assert false, 'hidra só no dia 8';
  exception when raise_exception then assert sqlerrm = 'chefe_bloqueado_dia', sqlerrm; end;

  b := public._bosses(uid, s + 1);
  assert jsonb_array_length(b->'bosses') = 7;
  assert (select e->'lock'->>'reason' from jsonb_array_elements(b->'bosses') e where e->>'id' = 'tempestade') = 'habito';
  assert (select e->'lock'->>'reason' from jsonb_array_elements(b->'bosses') e where e->>'id' = 'juiz') = 'dia';

  -- Ganha um hábito de saúde mental e enfrenta a Tempestade
  perform public._add_habit(uid, 'men_respiracao', 1);
  perform pg_temp.open_day(uid, s + 1);
  r := public._start_boss(uid, 'tempestade', s + 1, pg_temp.ts(s + 1));
  fid := (r->>'fight_id')::uuid;
  assert (select hp from public.user_bosses where id = fid) = 5;
  assert (select deadline from public.user_bosses where id = fid) = s + 7, 'prazo de 7 dias';
  begin perform public._start_boss(uid, 'adiador', s + 1, pg_temp.ts(s + 1)); assert false, 'um chefe por vez';
  exception when raise_exception then assert sqlerrm = 'chefe_ja_ativo', sqlerrm; end;

  -- Missão de outra área não golpeia
  perform pg_temp.complete(uid, s + 1, 1, 'fisica');
  assert (select hits from public.user_bosses where id = fid) = 0, 'outra área não conta';

  -- Golpe, desfazer, golpe de novo
  r := public._complete_mission(uid, (select id from public.missions where user_id = uid and mission_date = s + 1 and dimension = 'mental'), pg_temp.ts(s + 1));
  assert (r->'chefe'->>'effective')::int = 1 and (r->'chefe'->>'before')::int = 0 and (r->'chefe'->>'today_hit')::boolean,
    format('primeiro golpe: %s', r->'chefe');
  perform public._undo_completion(uid, (select id from public.missions where user_id = uid and mission_date = s + 1 and dimension = 'mental'), pg_temp.ts(s + 1));
  assert (select hits from public.user_bosses where id = fid) = 0, 'desfazer tira o golpe';
  perform pg_temp.complete(uid, s + 1, 1, 'mental');
  assert (select hits from public.user_bosses where id = fid) = 1;

  -- Só um golpe por dia, mesmo com várias missões da área
  perform public._add_habit(uid, 'men_reflexao', 1);
  perform pg_temp.open_day(uid, s + 1);
  perform pg_temp.complete(uid, s + 1, 1, 'mental');
  assert (select hits from public.user_bosses where id = fid) = 1, 'um golpe por dia';

  for i in 2 .. 5 loop
    perform pg_temp.open_day(uid, s + i);
    r := public._complete_mission(uid, (select id from public.missions where user_id = uid and mission_date = s + i and dimension = 'mental' and status = 'pendente' order by name limit 1), pg_temp.ts(s + i));
  end loop;
  assert r->'chefe'->>'status' = 'vencido', format('vitória no 5º golpe: %s', r->'chefe');
  assert (select status from public.user_bosses where id = fid) = 'vencido';
  assert (select amount from public.xp_ledger where user_id = uid and source = 'chefe' and ref = fid::text) = 100, 'XP da vitória';
  assert exists (select 1 from public.user_items where user_id = uid and item_id = 'amu_calma'), 'amuleto do chefe';
  assert exists (select 1 from public.user_items where user_id = uid and item_id = 'tit_tempestade'), 'título do chefe';
  assert exists (select 1 from public.user_achievements where user_id = uid and achievement_id = 'c_1'), 'Primeira vitória';
  assert exists (select 1 from public.user_events where user_id = uid and kind = 'chefe_vencido' and ref = fid::text);

  -- Vitória é permanente: desfazer a última missão não tira a vitória
  perform public._undo_completion(uid, (select id from public.missions where user_id = uid and mission_date = s + 5 and dimension = 'mental' and status = 'concluida' limit 1), pg_temp.ts(s + 5));
  assert (select status from public.user_bosses where id = fid) = 'vencido', 'vitória continua';
  perform pg_temp.complete(uid, s + 5, 1, 'mental');

  -- Revanche: metade do XP, sem itens repetidos
  perform pg_temp.open_day(uid, s + 6);
  fid := (public._start_boss(uid, 'tempestade', s + 6, pg_temp.ts(s + 6))->>'fight_id')::uuid;
  assert (select rematch from public.user_bosses where id = fid);
  for i in 6 .. 10 loop
    if i > 6 then perform pg_temp.open_day(uid, s + i); end if;
    perform pg_temp.complete(uid, s + i, 1, 'mental');
  end loop;
  assert (select status from public.user_bosses where id = fid) = 'vencido', 'revanche vencida';
  assert (select amount from public.xp_ledger where user_id = uid and source = 'chefe' and ref = fid::text) = 50, 'revanche rende metade';
  assert (select count(*) from public.user_items where user_id = uid and item_id = 'amu_calma') = 1;

  -- Recuo: prazo acaba sem golpes suficientes
  perform pg_temp.open_day(uid, s + 11);
  fid := (public._start_boss(uid, 'tempestade', s + 11, pg_temp.ts(s + 11))->>'fight_id')::uuid;
  perform pg_temp.complete(uid, s + 11, 1, 'mental');
  for i in 12 .. 18 loop perform pg_temp.open_day(uid, s + i); end loop;
  assert (select status from public.user_bosses where id = fid) = 'recuou', 'chefe recua depois do prazo';
  assert (select hits from public.user_bosses where id = fid) = 1;
  assert exists (select 1 from public.user_events where user_id = uid and kind = 'chefe_recuou' and ref = fid::text);
  assert not exists (select 1 from public.xp_ledger where user_id = uid and source = 'chefe' and ref = fid::text), 'recuo não dá XP';

  -- Desistir encerra sem custo
  fid := (public._start_boss(uid, 'tempestade', s + 18, pg_temp.ts(s + 18))->>'fight_id')::uuid;
  update public.user_bosses set status = 'desistiu', finished_at = now() where id = fid;

  -- Cura no modo Desafio: dia em branco devolve um golpe ao chefe
  perform public._set_mode(uid, 'desafio', true, s + 18);
  fid := (public._start_boss(uid, 'tempestade', s + 18, pg_temp.ts(s + 18))->>'fight_id')::uuid;
  perform pg_temp.complete(uid, s + 18, 1, 'mental');
  assert (select hits from public.user_bosses where id = fid) = 1;
  perform pg_temp.open_day(uid, s + 19);                 -- dia 20 em branco
  perform pg_temp.open_day(uid, s + 20);
  b := public._boss_progress(uid, fid, s + 20);
  assert (b->>'effective')::int = 0 and (b->>'heals')::int = 1, format('dia em branco curou: %s', b);
  assert (select hits from public.user_bosses where id = fid) = 0, 'barra atualizada na abertura do dia';
  perform pg_temp.complete(uid, s + 20, 1, 'mental');
  assert (select hits from public.user_bosses where id = fid) = 1;
  raise notice 'OK chefes: bloqueios, golpes, desfazer, vitória, revanche, recuo e cura';
end $$;

-- A pessoa vê a vitória com os detalhes, e só os próprios dados.
-- (A API usa a data real; o prazo da batalha simulada é estendido para ela continuar ativa.)
update public.user_bosses set deadline = current_date + 30 where user_id = '00000000-0000-0000-0000-0000000000e1' and status = 'ativo';
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000e1', false);
do $$
declare ev jsonb; v jsonb; b jsonb;
begin
  ev := public.pending_events();
  select e into v from jsonb_array_elements(ev) e where e->>'kind' = 'chefe_vencido' and not (e->'data'->'fight'->>'rematch')::boolean;
  assert v->'data'->'boss'->>'name' = 'A Tempestade Interna', format('aviso de vitória: %s', v);
  assert (v->'data'->>'xp')::int = 100;
  assert v->'data'->'rewards' @> '[{"id":"amu_calma"},{"id":"tit_tempestade"}]', 'recompensas listadas';
  assert exists (select 1 from jsonb_array_elements(ev) e where e->>'kind' = 'chefe_recuou');

  b := public.get_bosses();
  assert (b->>'active') is not null;
  assert (select e->>'state' from jsonb_array_elements(b->'bosses') e where e->>'id' = 'tempestade') = 'ativo';
  -- Desde a simulação vieram semanas sem missões no modo Desafio: as curas zeraram a barra
  assert (select (e->'fight'->>'effective')::int from jsonb_array_elements(b->'bosses') e where e->>'id' = 'tempestade') = 0,
    format('barra: %s', (select e->'fight' from jsonb_array_elements(b->'bosses') e where e->>'id' = 'tempestade'));
  assert (select (e->>'victories')::int from jsonb_array_elements(b->'bosses') e where e->>'id' = 'tempestade') = 2;
  assert (select count(*) from public.user_bosses) = (select count(*) from public.user_bosses where user_id = auth.uid()), 'só as próprias batalhas';
  perform public.abandon_boss();
  assert (select count(*) from public.user_bosses where status = 'ativo') = 0, 'desistir pela API';
end $$;

reset role;
select array_agg(id)::text as e_ids from public.user_events where user_id = '00000000-0000-0000-0000-0000000000e1' \gset
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000d1', false);
select public.mark_events_seen(:'e_ids'::bigint[]) as tentativa;
do $$ begin
  assert (select count(*) from public.user_events) = (select count(*) from public.user_events where user_id = auth.uid()), 'só os próprios avisos';
end $$;
reset role;
do $$ begin
  assert (select count(*) from public.user_events where user_id = '00000000-0000-0000-0000-0000000000e1' and seen) = 0,
    'uma pessoa não marca os avisos da outra';
  raise notice 'OK avisos e leitura protegida';
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- D. Modos de dificuldade e histórico de regras
-- ════════════════════════════════════════════════════════════════════════════
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000f1', false);
select public.submit_assessment(:'answers') is not null as ok \gset
reset role;

do $$
declare
  uid uuid := '00000000-0000-0000-0000-0000000000f1';
  s date := '2026-10-01';
  j jsonb; info jsonb; i int; n int; x int; mid uuid;
begin
  perform pg_temp.reset_user(uid, s);
  assert (select min_daily_missions from public.profiles where id = uid) = 2;

  -- Dias 1 a 7 no Normal, batendo a meta (2 missões)
  for i in 0 .. 6 loop
    perform pg_temp.open_day(uid, s + i);
    perform pg_temp.complete(uid, s + i, 2);
  end loop;

  begin perform public._set_mode(uid, 'desafio', true, s + 4); assert false, 'Desafio só a partir do dia 8';
  exception when raise_exception then assert sqlerrm = 'modo_bloqueado_dia', sqlerrm; end;

  perform pg_temp.open_day(uid, s + 7);  -- dia 8
  begin perform public._set_mode(uid, 'desafio', false, s + 7); assert false, 'precisa aceitar as regras';
  exception when raise_exception then assert sqlerrm = 'aceite_as_regras', sqlerrm; end;
  info := public._mode_info(uid, s + 7);
  assert (info->'desafio'->>'available')::boolean and not (info->'extremo'->>'available')::boolean, format('requisitos: %s', info);

  perform public._set_mode(uid, 'desafio', true, s + 7);
  assert (select mode from public.profiles where id = uid) = 'desafio';
  assert (select count(*) from public.rules_history where user_id = uid) = 2, 'regra antiga guardada + nova';

  -- Desafio: meta = 60% das missões diárias; XP +20%
  select count(*) into n from public.missions where user_id = uid and mission_date = s + 7 and kind = 'diaria';
  select id, xp_reward into mid, x from public.missions where user_id = uid and mission_date = s + 7 and kind = 'diaria' order by name limit 1;
  perform public._complete_mission(uid, mid, pg_temp.ts(s + 7));
  assert (select amount from public.xp_ledger where mission_id = mid) = round(x * 1.2), 'XP +20% no Desafio';
  perform pg_temp.complete(uid, s + 7, 1);             -- 2 missões: meta do Normal, não a do Desafio

  perform pg_temp.open_day(uid, s + 8);
  j := public._journey(uid, s + 8);
  assert (j->'days'->7->>'goal')::int = greatest(2, ceil(n * 0.6)::int), format('meta do Desafio: %s de %s', j->'days'->7->>'goal', n);
  assert j->'days'->7->>'status' = 'parcial', format('2 missões não bastam no Desafio: %s', j->'days'->7);
  assert j->'days'->6->>'status' = 'completo' and j->'days'->0->>'status' = 'completo', 'dias antigos julgados pelas regras antigas';
  assert (j->>'max_shields')::int = 1, 'Desafio guarda no máximo 1 escudo';
  assert j->'days'->7->>'mode' = 'desafio' and j->'days'->6->>'mode' = 'normal';

  -- Dias 9 a 21 completos no Desafio (todas as missões)
  for i in 8 .. 20 loop
    if i > 8 then perform pg_temp.open_day(uid, s + i); end if;
    perform pg_temp.complete(uid, s + i, 20);
  end loop;

  perform pg_temp.open_day(uid, s + 20);
  begin perform public._set_mode(uid, 'extremo', true, s + 20); assert false, 'Extremo só a partir do dia 22';
  exception when raise_exception then assert sqlerrm = 'modo_bloqueado_dia', sqlerrm; end;

  perform pg_temp.open_day(uid, s + 21);  -- dia 22
  info := public._mode_info(uid, s + 21);
  assert (info->'extremo'->>'available')::boolean, format('Extremo liberado: %s', info);
  perform public._set_mode(uid, 'extremo', true, s + 21);

  -- Extremo: XP +40%; meta = todas as missões diárias
  select id, xp_reward into mid, x from public.missions where user_id = uid and mission_date = s + 21 and kind = 'diaria' order by name limit 1;
  perform public._complete_mission(uid, mid, pg_temp.ts(s + 21));
  assert (select amount from public.xp_ledger where mission_id = mid) = round(x * 1.4), 'XP +40% no Extremo';
  select count(*) into n from public.missions where user_id = uid and mission_date = s + 21 and kind = 'diaria';
  perform pg_temp.complete(uid, s + 21, n - 2);         -- deixa uma diária para trás
  perform public._insert_mission(uid, null, 'teste:avulsa', 'personalizada', 'Avulsa', '', 'mental', 'foco', 'vitalidade', 1, 10, 'min', 10, 'qualquer', 'unica', s + 21, s + 21);
  perform public._complete_mission(uid, (select id from public.missions where dedupe_key = 'teste:avulsa' and user_id = uid), pg_temp.ts(s + 21));

  perform pg_temp.open_day(uid, s + 22);
  j := public._journey(uid, s + 22);
  assert j->'days'->21->>'status' = 'parcial', format('no Extremo uma avulsa não substitui uma diária: %s', j->'days'->21);
  assert (j->>'max_shields')::int = 0, 'Extremo não tem escudos';

  -- Dois dias abaixo da meta: ainda no Extremo. No terceiro, volta para o Desafio.
  perform pg_temp.complete(uid, s + 22, 1);
  perform pg_temp.open_day(uid, s + 23);
  assert (select mode from public.profiles where id = uid) = 'extremo', format('2 falhas: continua (%s)', public._extremo_failures(uid, s + 23));
  perform pg_temp.complete(uid, s + 23, 1);
  perform pg_temp.open_day(uid, s + 24);
  assert (select mode from public.profiles where id = uid) = 'desafio', 'rebaixado depois de 3 dias abaixo da meta';
  assert (select reason from public.rules_history where user_id = uid order by started_on desc, id desc limit 1) = 'rebaixado';
  assert exists (select 1 from public.user_events where user_id = uid and kind = 'modo_rebaixado');
  assert (select mode_cooldown_until from public.profiles where id = uid) = s + 31;

  begin perform public._set_mode(uid, 'extremo', true, s + 25); assert false, 'espera de 7 dias';
  exception when raise_exception then assert sqlerrm = 'modo_em_espera', sqlerrm; end;
  perform public._set_mode(uid, 'normal', false, s + 25);
  assert (select mode from public.profiles where id = uid) = 'normal', 'voltar ao Normal não exige aceite';

  assert (public._achievement_metrics(uid, s + 25)->>'dias_desafio')::int = 13, format('dias completos no Desafio: %s', public._achievement_metrics(uid, s + 25)->>'dias_desafio');
  assert (public._achievement_metrics(uid, s + 25)->>'dias_extremo')::int = 0;
  raise notice 'OK modos: requisitos, meta, escudos, XP, histórico de regras e rebaixamento';
end $$;

-- No Extremo, a pessoa não altera o plano pela API
reset role;
update public.profiles set mode = 'extremo' where id = '00000000-0000-0000-0000-0000000000f1';
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000f1', false);
do $$ begin
  begin perform public.adjust_habit((select id from public.user_habits limit 1), (select base_value from public.user_habits limit 1), false);
        assert false, 'pausar no Extremo'; exception when raise_exception then null; end;
  begin perform public.create_custom_mission('Novo hábito', '', 'mental', 1, 10, true);
        assert false, 'hábito novo no Extremo'; exception when raise_exception then assert sqlerrm = 'modo_extremo_bloqueia_habitos', sqlerrm; end;
  begin perform public.update_profile(null, null, 1);
        assert false, 'mudar a meta no Extremo'; exception when raise_exception then null; end;
  perform public.create_custom_mission('Avulsa permitida', '', 'mental', 1, 10, false);
  begin perform public.set_mode('desafio', null); assert false, 'aceite exigido pela API'; exception when raise_exception then null; end;
  raise notice 'OK Extremo bloqueia mudanças no plano';
end $$;
reset role;

\echo 'TESTES DA ETAPA 3 PASSARAM'
