-- Testes da 0007: Caminho Sagrado e tendência do Mentor. Rodam com: supabase/tests/run.sh
\set ON_ERROR_STOP on
set client_min_messages = notice;

\set answers '{"display_name":"Sara","daily_minutes":45,"exercise":1,"diet":2,"sleep_hours":2,"sleep_quality":2,"stress":1,"rest":2,"reflection":1,"reading":1,"learning":1,"planning":1,"procrastination":1,"discipline":2,"screen_time":1,"phone_morning":1,"focus":1,"water":2,"morning_routine":2,"environment":2,"main_goal":"mental"}'

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a7', 'sara@teste.dev', '{"name":"Sara"}'),
  ('00000000-0000-0000-0000-0000000000b7', 'davi@teste.dev', '{"name":"Davi"}');

create function pg_temp.ts(d date) returns timestamptz language sql as $$
  select (d + time '12:00') at time zone 'America/Sao_Paulo'
$$;

set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000b7', false);
select public.submit_assessment(:'answers') is not null as ok \gset
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a7', false);
select public.submit_assessment(:'answers') is not null as ok \gset
select public.ensure_today() is not null as ok \gset
reset role;

insert into public.friendships (requester, addressee, status, responded_at)
  values ('00000000-0000-0000-0000-0000000000a7', '00000000-0000-0000-0000-0000000000b7', 'aceita', now());

-- ════════════════════════════════════════════════════════════════════════════
-- A. Ativar, praticar, ganhar Sagrado
-- ════════════════════════════════════════════════════════════════════════════
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a7', false);
do $$
declare s jsonb; mid uuid; xp int; before_other int; st record; e text;
begin
  s := public.get_sagrado();
  assert (s->>'enabled')::boolean = false, 'começa desligado';
  assert jsonb_array_length(s->'practices') = 5, 'cinco práticas no catálogo';
  assert not exists (select 1 from public.missions where dimension = 'espiritual'), 'nenhuma prática antes de ativar';

  begin perform public.set_sagrado(true, '{}'); assert false, 'precisa escolher uma prática';
  exception when others then get stacked diagnostics e = message_text; assert e = 'escolha_uma_pratica', e; end;
  begin perform public.set_sagrado(true, array['fis_treino']); assert false, 'só práticas espirituais';
  exception when others then get stacked diagnostics e = message_text; assert e = 'escolha_uma_pratica', e; end;

  s := public.set_sagrado(true, array['esp_devocional', 'esp_biblia', 'esp_gratidao', 'esp_devocional']);
  assert (s->>'enabled')::boolean, 'ativado';
  assert (select count(*) from jsonb_array_elements(s->'practices') p where (p->>'active')::boolean) = 3, format('três ativas: %s', s);
  assert (s->>'today_total')::int = 3, format('as três já aparecem hoje: %s', s);
  assert (select sagrado from public.profiles where id = auth.uid()), 'perfil marcado';

  -- Concluir o devocional: 70% da XP no Sagrado, 30% na Disciplina
  select id into mid from public.missions where user_id = auth.uid() and dimension = 'espiritual' and name = 'Devocional';
  select disciplina into before_other from public.character_stats where user_id = auth.uid();
  perform public.complete_mission(mid);
  select xp_reward into xp from public.missions where id = mid;
  select * into st from public.xp_ledger where mission_id = mid;
  assert st.sagrado = round(xp * 0.7) and st.disciplina = xp - round(xp * 0.7), format('divisão da XP: %s', row_to_json(st));
  -- Primeira prática também libera a conquista "Primeiro altar", com XP no Sagrado
  assert exists (select 1 from public.user_achievements where user_id = auth.uid() and achievement_id = 'sg_1'), 'conquista sg_1';
  assert (select sagrado from public.xp_ledger where user_id = auth.uid() and source = 'conquista' and ref = 'sg_1') = 20, 'XP da conquista no Sagrado';
  select * into st from public.character_stats where user_id = auth.uid();
  assert st.sagrado = round(xp * 0.7) + 20, format('atributo somado: %s', st.sagrado);

  s := public.get_sagrado();
  assert (s->>'xp')::int = st.sagrado and (s->>'days')::int = 1 and (s->>'today_done')::int = 1, format('estado: %s', s);

  -- Desfazer tira a XP da prática
  perform public.undo_completion(mid);
  assert (select sagrado from public.character_stats where user_id = auth.uid()) = 20, 'desfazer devolve a XP da missão';
  perform public.complete_mission(mid);
end $$;

-- B. Trocar práticas e desligar sem perder o que foi conquistado
do $$
declare s jsonb; kept int;
begin
  s := public.set_sagrado(true, array['esp_devocional', 'esp_louvor']);
  assert (select count(*) from public.missions where user_id = auth.uid() and dimension = 'espiritual'
            and status = 'pendente' and name in ('Leitura bíblica', 'Gratidão a Deus')) = 0, 'práticas tiradas somem de hoje';
  assert exists (select 1 from public.missions where user_id = auth.uid() and name = 'Louvor'), 'louvor entrou';
  assert exists (select 1 from public.missions where user_id = auth.uid() and name = 'Devocional' and status = 'concluida'), 'concluída fica';

  select sagrado into kept from public.character_stats where user_id = auth.uid();
  s := public.set_sagrado(false, null);
  assert (s->>'enabled')::boolean = false, 'desligado';
  assert not exists (select 1 from public.user_habits where user_id = auth.uid() and dimension = 'espiritual' and active), 'práticas pausadas';
  assert not exists (select 1 from public.missions where user_id = auth.uid() and dimension = 'espiritual' and status = 'pendente'), 'pendentes removidas';
  assert (s->>'xp')::int = kept, 'XP do Sagrado guardada';

  -- Religar reaproveita os hábitos, sem duplicar
  s := public.set_sagrado(true, array['esp_devocional']);
  assert (select count(*) from public.user_habits where user_id = auth.uid() and template_id = 'esp_devocional') = 1, 'sem duplicar';
end $$;

-- C. Missão personalizada e desafio na área espiritual
do $$
declare r jsonb;
begin
  r := public.create_custom_mission('Oração pela família', 'Dez minutos de oração', 'espiritual', 1, 10, false);
  assert exists (select 1 from public.missions where user_id = auth.uid() and name = 'Oração pela família'
                   and attr_primary = 'sagrado'), 'missão personalizada vai para o Sagrado';
end $$;

-- D. Amigos só veem o Sagrado de quem ativou
do $$
declare p jsonb;
begin
  p := public.friend_profile('00000000-0000-0000-0000-0000000000b7');
  assert p->'attributes' ? 'disciplina' and not (p->'attributes' ? 'sagrado'), format('amigo sem Sagrado: %s', p->'attributes');
  assert p->'my_attributes' ? 'sagrado', 'eu vejo o meu Sagrado na comparação';
end $$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000b7', false);
do $$
declare p jsonb; e text;
begin
  p := public.friend_profile('00000000-0000-0000-0000-0000000000a7');
  assert p->'attributes' ? 'sagrado', 'amigo vê o Sagrado de quem ativou';
  assert not (p->'my_attributes' ? 'sagrado'), 'quem não ativou não ganha Sagrado na própria comparação';
  assert not exists (select 1 from public.missions where user_id = auth.uid() and dimension = 'espiritual'), 'nada muda para quem não ativou';
  begin perform public._sagrado_state(auth.uid()); assert false, 'função interna fechada';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

-- ════════════════════════════════════════════════════════════════════════════
-- E. Mentor: meta firme com menos missões não vira "Ritmo mais lento"
-- ════════════════════════════════════════════════════════════════════════════
do $$
declare
  u uuid := '00000000-0000-0000-0000-0000000000b7';
  s date := '2026-09-01';
  i int; r jsonb; mid uuid;
begin
  delete from public.missions where user_id = u;
  delete from public.xp_ledger where user_id = u;
  update public.profiles set program_start = s, mentor_checked_on = null where id = u;
  perform public._recalc_stats(u);
  -- Duas semanas fazendo tudo; depois uma semana cumprindo só a meta mínima do dia
  for i in 0 .. 21 loop
    perform public._ensure_day(u, s + i);
    for mid in select id from public.missions where user_id = u and mission_date = s + i and status = 'pendente' and kind = 'diaria'
                order by name limit (case when i < 14 then 99 else (select min_daily_missions from public.profiles where id = u) end) loop
      perform public._complete_mission(u, mid, pg_temp.ts(s + i));
    end loop;
  end loop;
  r := public._mentor_insights(u, s + 21);
  assert not (exists (select 1 from jsonb_array_elements(r) x where x->>'title' = 'Ritmo firme')
              and exists (select 1 from jsonb_array_elements(r) x where x->>'title' = 'Ritmo mais lento')),
    format('sem mensagens contraditórias: %s', r);
  if exists (select 1 from jsonb_array_elements(r) x where x->>'title' = 'Ritmo firme') then
    assert exists (select 1 from jsonb_array_elements(r) x where x->>'id' = 'tendencia' and x->>'title' = 'Semana mais leve'),
      format('queda com meta firme vira "Semana mais leve": %s', r);
  end if;

  -- Hoje, ainda pela metade, não conta como queda
  r := public._mentor_insights(u, s + 14);
  assert not exists (select 1 from jsonb_array_elements(r) x where x->>'title' = 'Ritmo mais lento'), format('dia em andamento não pesa: %s', r);
end $$;

\echo 'TESTES DO SAGRADO PASSARAM'
