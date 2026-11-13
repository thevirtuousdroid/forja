-- Testes do motor do jogo. Rodam com: supabase/tests/run.sh
\set ON_ERROR_STOP on
set client_min_messages = notice;

-- Respostas de referência: pessoa com sono ruim, pouca água e bastante tela
\set answers '{"age_range":"25-34","wake_time":1,"free_period":"noite","daily_minutes":30,"exercise":1,"diet":2,"sleep_hours":1,"sleep_quality":1,"stress":1,"rest":2,"reflection":1,"reading":0,"learning":1,"planning":1,"procrastination":1,"discipline":2,"screen_time":0,"phone_morning":0,"focus":1,"water":1,"morning_routine":2,"environment":2,"main_goal":"intelectual","difficulties":["procrastinacao","celular"]}'

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-00000000000a', 'a@teste.dev', '{"name":"Ana"}'),
  ('00000000-0000-0000-0000-00000000000b', 'b@teste.dev', '{"name":"Bruno"}'),
  ('00000000-0000-0000-0000-00000000000c', 'c@teste.dev', '{"name":"Caio"}');

-- ── Fórmulas ────────────────────────────────────────────────────────────────
do $$ begin
  assert public._xp_for(1, 10, 'diaria') = 10, 'xp caminhada 10min';
  assert public._xp_for(3, 30, 'diaria') = 38, format('xp treino 30min = %s', public._xp_for(3, 30, 'diaria'));
  assert public._xp_for(2, 20, 'diaria') = 21, 'xp leitura 20min';
  assert public._xp_for(5, 600, 'diaria') = 100, 'tempo tem teto (x2.5)';
  assert public._xp_for(1, 1, 'personalizada') < public._xp_for(1, 1, 'diaria'), 'personalizada rende menos';
  assert public.level_for_xp(0) = 1 and public.level_for_xp(99) = 1 and public.level_for_xp(100) = 2, 'nível 2 em 100 XP';
  assert public.level_for_xp(1213) = 5 and public.level_for_xp(1212) = 4, 'nível 5 em 1213 XP';
  assert public._phase_for_day(7) = 1 and public._phase_for_day(8) = 2 and public._phase_for_day(66) = 6 and public._phase_for_day(67) = 7, 'fases';
  raise notice 'OK fórmulas';
end $$;

do $$ begin
  assert (select count(*) from public.profiles) = 3, 'gatilho cria perfis';
  assert (select display_name from public.profiles where id = '00000000-0000-0000-0000-00000000000a') = 'Ana', 'nome vem do cadastro';
  assert (select count(*) from public.character_stats) = 3, 'gatilho cria personagem';
end $$;

-- ── Fluxo do usuário A como "authenticated" ─────────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);

-- Resposta inválida é recusada
do $$ begin
  begin
    perform public.submit_assessment('{"main_goal":"intelectual","daily_minutes":30}');
    assert false, 'deveria recusar respostas incompletas';
  exception when raise_exception then null;
  end;
end $$;

select public.submit_assessment(:'answers') as resultado_a \gset

do $$
declare
  n_habits int; n_missions int; prio text[];
begin
  select count(*) into n_habits from public.user_habits where start_day = 1;
  select count(*) into n_missions from public.missions;
  select priorities into prio from public.assessments limit 1;
  assert prio[1] = 'intelectual', 'objetivo principal vem primeiro';
  assert array_length(prio, 1) = 3, 'três prioridades';
  assert n_habits >= 2, format('ao menos 2 hábitos no dia 1 (%s)', n_habits);
  assert exists (select 1 from public.user_habits where template_id = 'auto_agua'), 'água entra quando a resposta indica';
  assert exists (select 1 from public.user_habits where template_id = 'fis_sono'), 'sono entra quando a resposta indica';
  assert exists (select 1 from public.user_habits where start_day > 1), 'há hábitos agendados para fases seguintes';
  assert n_missions = n_habits + 1, format('missões de hoje = hábitos do dia 1 + revisão semanal (%s vs %s)', n_missions, n_habits);
  assert (select vitalidade from public.character_stats) > 0, 'atributos iniciais vêm da avaliação';
  raise notice 'OK avaliação e plano: % hábitos no dia 1', n_habits;
end $$;

-- Segunda chamada de ensure_today não duplica nada
do $$
declare before int; after int;
begin
  select count(*) into before from public.missions;
  perform public.ensure_today();
  perform public.ensure_today();
  select count(*) into after from public.missions;
  assert before = after, 'ensure_today é idempotente';
end $$;

-- Escrita direta é negada
do $$ begin
  begin
    insert into public.xp_ledger (user_id, source, day, amount, foco) values (auth.uid(), 'marco', current_date, 9999, 9999);
    assert false, 'não pode inserir XP diretamente';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.missions set xp_reward = 9999;
    assert false, 'não pode alterar missões diretamente';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.profiles set plan = 'premium';
    assert false, 'não pode se dar premium';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public._complete_mission(auth.uid(), (select id from public.missions limit 1), now() + interval '1 day');
    assert false, 'funções internas não são expostas';
  exception when insufficient_privilege then null;
  end;
  raise notice 'OK escrita direta bloqueada';
end $$;

-- Concluir, tentar de novo, bônus e desfazer
do $$
declare
  m1 uuid; m2 uuid; r jsonb; r2 jsonb; xp_after_two int;
begin
  select id into m1 from public.missions where kind = 'diaria' order by name limit 1;
  select id into m2 from public.missions where kind = 'diaria' and id <> m1 order by name limit 1;

  r := public.complete_mission(m1);
  assert (r->>'xp')::int > 0, 'concluir gera XP';
  assert (r->>'ja_concluida')::boolean = false;

  r2 := public.complete_mission(m1);
  assert (r2->>'ja_concluida')::boolean = true, 'segunda conclusão é ignorada';
  assert (select count(*) from public.xp_ledger where source = 'missao') = 1, 'só um registro de XP por missão';

  r := public.complete_mission(m2);
  assert jsonb_array_length(r->'bonus') = 1 and r->'bonus'->0->>'tipo' = 'meta_diaria', format('bônus de meta diária: %s', r);
  select total_xp into xp_after_two from public.character_stats;
  assert xp_after_two = (select sum(amount) from public.xp_ledger), 'XP total = soma do histórico';

  r := public.undo_completion(m2);
  assert (r->>'desfeita')::boolean, 'desfazer no mesmo dia';
  assert not exists (select 1 from public.xp_ledger where source = 'meta_diaria'), 'bônus sai quando a meta deixa de ser atingida';
  assert (select total_xp from public.character_stats) < xp_after_two, 'XP recalculado após desfazer';
  assert (select status from public.missions where id = m2) = 'pendente';
  raise notice 'OK concluir / duplicidade / bônus / desfazer';
end $$;

-- Missões personalizadas e limites (sem a liberação do Premium da Etapa 4, vale o limite do plano gratuito)
reset role;
update public.app_config set premium_aberto = false;
set role authenticated;
do $$ begin
  begin
    perform public.create_custom_mission('Supermissão', '', 'fisica', 5, 30, false);
    assert false, 'dificuldade acima de 3 é recusada';
  exception when raise_exception then null;
  end;
  perform public.create_custom_mission('Tocar violão', '', 'intelectual', 2, 20, true);
  perform public.create_custom_mission('Regar plantas', '', 'autocuidado', 1, 5, true);
  begin
    perform public.create_custom_mission('Terceira', '', 'mental', 1, 5, true);
    assert false, 'plano gratuito limita hábitos personalizados';
  exception when raise_exception then null;
  end;
  assert exists (select 1 from public.missions where name = 'Tocar violão'), 'hábito personalizado gera missão hoje';
  perform public.create_custom_mission('Ligar para minha avó', '', 'mental', 1, 15, false);
  assert exists (select 1 from public.missions where name = 'Ligar para minha avó' and kind = 'personalizada');
  raise notice 'OK personalizadas';
end $$;
reset role;
update public.app_config set premium_aberto = true;
set role authenticated;

-- Ajuste de meta
do $$
declare h public.user_habits; xp_before int; xp_now int;
begin
  select * into h from public.user_habits where template_id = 'int_leitura';
  begin
    perform public.adjust_habit(h.id, h.max_value + 1, true);
    assert false, 'meta acima do teto é recusada';
  exception when raise_exception then null;
  end;
  select xp_reward into xp_before from public.missions where habit_id = h.id;
  perform public.adjust_habit(h.id, h.max_value, true);
  select xp_reward into xp_now from public.missions where habit_id = h.id;
  assert xp_now > xp_before, 'missão de hoje acompanha a nova meta';
  perform public.adjust_habit(h.id, h.base_value, true);
  raise notice 'OK ajuste de meta';
end $$;

-- ── Isolamento entre usuários ───────────────────────────────────────────────
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', false);
do $$
declare other uuid;
begin
  assert (select count(*) from public.missions) = 0, 'B não vê missões de A';
  assert (select count(*) from public.xp_ledger) = 0, 'B não vê XP de A';
  assert (select count(*) from public.profiles) = 1, 'B vê só o próprio perfil';
  reset role;
  select id into other from public.missions where user_id = '00000000-0000-0000-0000-00000000000a' and status = 'pendente' limit 1;
  set role authenticated;
  begin
    perform public.complete_mission(other);
    assert false, 'B não conclui missão de A';
  exception when raise_exception then null;
  end;
  raise notice 'OK isolamento';
end $$;

-- ── Simulação de 30 dias (usuário C, funções internas com relógio controlado) ──
reset role;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', false);
set role authenticated;
select public.submit_assessment(:'answers');
reset role;

create temp table sim_log (day int, streak int, shields int, status text);

do $$
declare
  uid uuid := '00000000-0000-0000-0000-00000000000c';
  start date := current_date - 29;
  d date;
  i int;
  m record;
  j jsonb;
  walk_before int;
  walk_after int;
  r jsonb;
begin
  delete from missions where user_id = uid;
  delete from xp_ledger where user_id = uid;
  update profiles set program_start = start where id = uid;
  select current_target into walk_before from user_habits where user_id = uid and template_id = 'int_leitura';

  for i in 1 .. 30 loop
    d := start + i - 1;
    perform _ensure_day(uid, d);

    -- dia 12 em branco (protegido por escudo), dias 20 e 21 em branco (o 2º zera a sequência no limite de escudos)
    if i in (12, 20, 21) then continue; end if;

    -- não pode concluir missão de outro dia
    if i = 13 then  -- tenta concluir uma missão do dia 12 (que ficou em branco)
      begin
        perform _complete_mission(uid, (select id from missions where user_id = uid and mission_date = d - 1 and kind = 'diaria' limit 1),
                                  (d + time '12:00') at time zone 'America/Sao_Paulo');
        raise exception 'deveria recusar missão vencida';
      exception when raise_exception then
        if sqlerrm not like '%fora_do_prazo%' then raise; end if;
      end;
    end if;

    for m in select id from missions where user_id = uid and mission_date = d and kind = 'diaria' and status = 'pendente' loop
      r := _complete_mission(uid, m.id, (d + time '12:00') at time zone 'America/Sao_Paulo');
      if i = 13 and (r->'bonus') @> '[{"tipo":"retorno"}]' then
        insert into sim_log values (13, -1, -1, 'retorno');
      end if;
    end loop;
  end loop;

  j := _journey(uid, start + 29);
  select current_target into walk_after from user_habits where user_id = uid and template_id = 'int_leitura';

  assert walk_after > walk_before, format('progressão semanal aumentou a meta (%s → %s)', walk_before, walk_after);
  assert walk_after <= (select max_value from user_habits where user_id = uid and template_id = 'int_leitura'), 'meta respeita o teto';
  assert (select count(*) from progression_events where user_id = uid) > 0, 'progressão registrada';
  assert (j->'days'->11->>'status') = 'protegido', format('dia 12 protegido por escudo: %s', j->'days'->11);
  assert exists (select 1 from sim_log where status = 'retorno'), 'bônus de retorno no dia 13';
  assert (j->>'best_streak')::int = 18, format('melhor sequência: %s', j->>'best_streak');
  assert (j->>'current_streak')::int = 9, format('sequência atual após os dias 20–21: %s', j->>'current_streak');
  assert (j->>'consistency')::int between 85 and 95, format('consistência: %s', j->>'consistency');
  assert exists (select 1 from missions where user_id = uid and kind = 'surpresa'), 'missões surpresa a partir da fase 2';
  assert exists (select 1 from missions where user_id = uid and kind = 'especial'), 'missões especiais a partir da fase 3';
  assert exists (select 1 from missions where user_id = uid and kind = 'semanal' and mission_date = start + 7), 'revisão semanal';
  assert exists (select 1 from missions where user_id = uid and status = 'expirada'), 'missões vencidas expiram';
  assert (select count(*) from user_habits h where user_id = uid and start_day = 8) =
         (select count(distinct mm.habit_id) from missions mm join user_habits h on h.id = mm.habit_id
           where mm.user_id = uid and h.start_day = 8), 'hábitos da fase 2 entram no dia 8';
  assert (select total_xp from character_stats where user_id = uid) = (select sum(amount) from xp_ledger where user_id = uid), 'XP consistente';
  raise notice 'OK simulação de 30 dias: nível %, XP %, melhor sequência %, consistência %',
    (select level from character_stats where user_id = uid), (select total_xp from character_stats where user_id = uid),
    j->>'best_streak', (j->>'consistency') || '%';
end $$;

\echo 'TODOS OS TESTES PASSARAM'
