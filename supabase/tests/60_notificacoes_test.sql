-- Testes das notificações (Web Push): configuração, chaves, inscrições, avisos sociais, lotes,
-- resultados de envio, lembretes e permissões. Rodam com: supabase/tests/run.sh
-- O pg_net é simulado: os pedidos ficam em net.pedidos, e o teste faz o papel da função /api/push.
\set ON_ERROR_STOP on
set client_min_messages = warning;

\set answers '{"display_name":"Teste","daily_minutes":30,"exercise":1,"diet":2,"sleep_hours":1,"sleep_quality":1,"stress":1,"rest":2,"reflection":1,"reading":0,"learning":1,"planning":1,"procrastination":1,"discipline":2,"screen_time":0,"phone_morning":0,"focus":1,"water":1,"morning_routine":2,"environment":2,"main_goal":"intelectual"}'
\set eva '00000000-0000-0000-0000-0000000000a6'
\set leo '00000000-0000-0000-0000-0000000000b6'
-- Chaves no formato real (P-256), geradas só para o teste
\set pub 'BA8sZrg1zwDxgzWYJ_IaRM-BmZFLsdnfdJoJC5qcA_aLWQZx5n9wpJ4rMC0XFNG4p3NVHTGfKeCtXIkNkOPEqA0'
\set priv 'EXUiDmTwA-yi2_TJtiWr6W3oYq9b0RXl0Ngd2F-As54'
\set p256 'BJkXO7tr-aL3ko_K9MsWYsblH0LQVYRPPFMzy7tlyHrUZLL6xQvt065hvQuppkV7ouHXle59J-207_N-sN7FAqQ'
\set auth '50i2V_sTC7CaIuk0NQCccw'

insert into auth.users (id, email, raw_user_meta_data) values
  (:'eva', 'eva@teste.dev', '{"name":"Eva"}'),
  (:'leo', 'leo@teste.dev', '{"name":"Leo"}');

set role authenticated;
select set_config('request.jwt.claim.sub', :'eva', false);
select public.submit_assessment(:'answers') is not null as ok \gset
select public.update_profile('Eva', null, null) is not null as ok \gset
select public.ensure_today() is not null as ok \gset
select set_config('request.jwt.claim.sub', :'leo', false);
select public.submit_assessment(:'answers') is not null as ok \gset
select public.update_profile('Leo', null, null) is not null as ok \gset
select public.ensure_today() is not null as ok \gset
reset role;

-- ── 1. Sem endereço do app, nada sai ──────────────────────────────────────────
update public.push_config set app_url = null, public_key = null, private_key = null where id;
delete from net.pedidos;
set role authenticated;
select set_config('request.jwt.claim.sub', :'eva', false);
select public.get_notify()::text as n \gset
reset role;
select set_config('t.n', :'n', false);
do $$
declare n jsonb := current_setting('t.n')::jsonb;
begin
  assert not (n->>'configured')::boolean and not (n->>'ready')::boolean, format('sem configuração: %s', n);
  assert n->'settings' = '{"lembrete": true, "lembrete_hora": "09:00", "risco": true, "risco_hora": "20:00", "social": true}'::jsonb,
    format('padrões: %s', n->'settings');
  assert (select count(*) from net.pedidos) = 0, 'nenhum pedido sem endereço';
  begin
    perform public.admin_set_push_url('http://inseguro.dev');
    raise exception 'devia recusar';
  exception when others then assert sqlerrm = 'endereco_invalido', sqlerrm;
  end;
  assert public.admin_set_push_url('https://app.test/')->>'funcao' = 'https://app.test/api/push';
  raise warning 'OK notificações: configuração';
end $$;

-- ── 2. Chaves: a tela pede, a função gera, o banco guarda (uma vez só) ────────
set role authenticated;
select set_config('request.jwt.claim.sub', :'eva', false);
select (public.get_notify()->>'ready') as ready \gset
select (public.get_notify()->>'ready') as ready2 \gset
reset role;
select body->>'token' as tok from net.pedidos order by id desc limit 1 \gset
do $$
begin
  assert (select count(*) from net.pedidos) = 1, format('um pedido de chaves por minuto, veio %s', (select count(*) from net.pedidos));
  assert (select url from net.pedidos) = 'https://app.test/api/push';
  assert (select need_keys from public.push_batches order by created_at desc limit 1);
end $$;

set role anon;
select set_config('request.jwt.claim.sub', '', false);
select public.push_claim(:'tok')::text as claim \gset
\set ON_ERROR_STOP off
select public.push_claim(:'tok');                                   -- código já usado
select public.push_set_keys(:'tok', 'curta', 'curta');              -- chaves inválidas
\set ON_ERROR_STOP on
select public.push_set_keys(:'tok', :'pub', :'priv')::text as keys \gset
select public.push_report(:'tok', '[]')::text as rep \gset
reset role;
select set_config('t.claim', :'claim', false), set_config('t.keys', :'keys', false);
do $$
declare c jsonb := current_setting('t.claim')::jsonb; k jsonb := current_setting('t.keys')::jsonb;
begin
  assert c->'vapid' = 'null'::jsonb and c->>'subject' = 'https://app.test' and c->'items' = '[]'::jsonb, format('lote de chaves: %s', c);
  assert length(k->>'public_key') = 87 and length(k->>'private_key') = 43, format('chaves: %s', k);
  assert (select public_key from public.push_config) = k->>'public_key';
  assert (select reported_at is not null from public.push_batches where need_keys order by created_at desc limit 1);
end $$;

-- Um segundo par nunca substitui o primeiro
select public._push_kick(true) is not null as ok \gset
select body->>'token' as tok2 from net.pedidos order by id desc limit 1 \gset
set role anon;
select public.push_claim(:'tok2') is not null as ok \gset
select (public.push_set_keys(:'tok2', repeat('A', 87), repeat('B', 43))->>'public_key') as kept \gset
select public.push_report(:'tok2', '[]') is not null as ok \gset
reset role;
select set_config('t.kept', :'kept', false);
do $$ begin
  assert current_setting('t.kept') = (select public_key from public.push_config) and current_setting('t.kept') <> repeat('A', 87),
    'as chaves não mudam depois de criadas';
  raise warning 'OK notificações: chaves geradas uma vez, pelo lote';
end $$;

-- ── 3. Inscrições de aparelhos ────────────────────────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', :'eva', false);
do $$
begin
  begin perform public.save_push_subscription('ftp://x', 'a', 'b', 'iPhone'); raise exception 'devia recusar';
  exception when others then assert sqlerrm = 'inscricao_invalida', sqlerrm; end;
  begin perform public.save_push_subscription('https://web.push.apple.com/abc', 'curta', 'k8JV6sjdbhAi-n3h6Aq5rA', 'iPhone'); raise exception 'devia recusar';
  exception when others then assert sqlerrm = 'inscricao_invalida', sqlerrm; end;
end $$;
select public.save_push_subscription('https://web.push.apple.com/eva-1', :'p256', :'auth', 'iPhone')->>'devices' as d1 \gset
select public.save_push_subscription('https://web.push.apple.com/eva-1', :'p256', :'auth', 'iPhone')->>'devices' as d1b \gset
select public.save_push_subscription('https://fcm.googleapis.com/fcm/send/eva-2', :'p256', :'auth', 'Android')->>'devices' as d2 \gset
-- O mesmo aparelho entra com a conta do Leo e depois volta para a Eva
select set_config('request.jwt.claim.sub', :'leo', false);
select public.save_push_subscription('https://fcm.googleapis.com/fcm/send/eva-2', :'p256', :'auth', 'Android')->>'devices' as leo1 \gset
select set_config('request.jwt.claim.sub', :'eva', false);
select jsonb_array_length(public.get_notify()->'devices') as eva_after \gset
select public.save_push_subscription('https://fcm.googleapis.com/fcm/send/eva-2', :'p256', :'auth', 'Android')->>'devices' as back \gset
reset role;
select set_config('t.v', concat_ws(',', :'d1', :'d1b', :'d2', :'leo1', :'eva_after', :'back'), false);
do $$ begin
  assert current_setting('t.v') = '1,1,2,1,1,2', format('aparelhos: %s', current_setting('t.v'));
end $$;

-- No máximo 10 aparelhos por pessoa
set role authenticated;
select set_config('request.jwt.claim.sub', :'leo', false);
select max((public.save_push_subscription('https://web.push.apple.com/leo-' || g, :'p256', :'auth', 'iPhone')->>'devices')::int) as leo_max
  from generate_series(1, 12) g \gset
reset role;
do $$ begin
  assert (select count(*) from public.push_subscriptions where user_id = '00000000-0000-0000-0000-0000000000b6') = 10, 'até 10 aparelhos';
  delete from public.push_subscriptions where user_id = '00000000-0000-0000-0000-0000000000b6' and endpoint <> 'https://web.push.apple.com/leo-12';
  raise warning 'OK notificações: inscrições (validação, troca de conta e limite)';
end $$;

-- ── 4. Aviso social → fila → lote → envio → resultado ─────────────────────────
delete from net.pedidos;
select friend_code as eva_code from public.profiles where id = :'eva' \gset
set role authenticated;
select set_config('request.jwt.claim.sub', :'leo', false);
select public.send_friend_request(:'eva_code') is not null as ok \gset
reset role;
select body->>'token' as tok from net.pedidos order by id desc limit 1 \gset
do $$
declare q public.push_queue;
begin
  select * into q from public.push_queue where user_id = '00000000-0000-0000-0000-0000000000a6' order by id desc limit 1;
  assert q.kind = 'social' and q.payload->>'title' = 'Pedido de amizade'
     and q.payload->>'body' = 'Leo te mandou um pedido de amizade.' and q.payload->>'url' = '/social/avisos', format('fila: %s', q.payload);
  assert q.batch_id is not null and (select count(*) from net.pedidos) = 1, 'um lote, um pedido ao fim da transação';
end $$;

set role anon;
select public.push_claim(:'tok')::text as claim \gset
reset role;
select set_config('t.claim', :'claim', false);
-- Resultado: o Android recebeu, o iPhone cancelou a inscrição
select set_config('t.results', (
  select jsonb_agg(jsonb_build_object('queue', i->'queue', 'subscription', i->'subscription',
                   'status', case when i->>'endpoint' like '%apple%' then 410 else 201 end))::text
    from jsonb_array_elements(current_setting('t.claim')::jsonb->'items') i), false) as r \gset
set role anon;
select public.push_report(:'tok', :'r'::jsonb)::text as rep \gset
reset role;
select set_config('t.rep', :'rep', false);
do $$
declare c jsonb := current_setting('t.claim')::jsonb; rep jsonb := current_setting('t.rep')::jsonb;
begin
  assert jsonb_array_length(c->'items') = 2 and (c->'vapid'->>'public_key') = (select public_key from public.push_config),
    format('lote: %s', c);
  assert (c->'items'->0->'payload'->>'body') = 'Leo te mandou um pedido de amizade.';
  assert (c->'items'->0->>'ttl')::int between 86000 and 86400 and c->'items'->0->>'urgency' = 'normal';
  assert rep = '{"ok": 1, "failed": 0, "gone": 1}'::jsonb, format('relatório: %s', rep);
  assert (select count(*) from public.push_subscriptions where user_id = '00000000-0000-0000-0000-0000000000a6') = 1, 'iPhone cancelado saiu';
  assert (select done and sent_at is not null from public.push_queue where user_id = '00000000-0000-0000-0000-0000000000a6' order by id desc limit 1);
  assert (select last_ok_at is not null and failures = 0 from public.push_subscriptions where user_id = '00000000-0000-0000-0000-0000000000a6');
  raise warning 'OK notificações: aviso social do começo ao fim';
end $$;
set role anon;
\set ON_ERROR_STOP off
select public.push_report(:'tok', '[]');                            -- relatório repetido
\set ON_ERROR_STOP on
reset role;

-- ── 5. Falha temporária volta para a fila; lote sem resposta é retomado ───────
set role authenticated;
select set_config('request.jwt.claim.sub', :'eva', false);
select public.respond_friend_request((select id from public.friendships where requester = :'leo' and addressee = :'eva'), true) is not null as ok \gset
select public.push_test() is not null as ok \gset
reset role;
select body->>'token' as tok from net.pedidos order by id desc limit 1 \gset
set role anon;
select public.push_claim(:'tok')::text as claim \gset
reset role;
select set_config('t.claim', :'claim', false);
select set_config('t.results', (
  select jsonb_agg(jsonb_build_object('queue', i->'queue', 'subscription', i->'subscription', 'status', 500, 'error', 'Erro do serviço'))::text
    from jsonb_array_elements(current_setting('t.claim')::jsonb->'items') i), false) as r \gset
set role anon;
select public.push_report(:'tok', :'r'::jsonb)::text as rep \gset
reset role;
do $$
declare q public.push_queue;
begin
  assert jsonb_array_length(current_setting('t.claim')::jsonb->'items') = 1, 'o teste vai para o aparelho que sobrou';
  assert (current_setting('t.claim')::jsonb->'items'->0->>'urgency') = 'high';
  select * into q from public.push_queue where user_id = '00000000-0000-0000-0000-0000000000a6' and kind = 'teste';
  assert not q.done and q.batch_id is null and q.attempts = 1, format('volta para a fila: %s', row_to_json(q));
  assert (select last_status = 500 and failures = 1 and last_error = 'Erro do serviço'
            from public.push_subscriptions where user_id = '00000000-0000-0000-0000-0000000000a6');
end $$;
-- A cada minuto, o que voltou para a fila sai de novo
delete from net.pedidos;
select public._push_tick() is not null as ok \gset
select body->>'token' as tok from net.pedidos order by id desc limit 1 \gset
do $$ begin
  assert (select count(*) from net.pedidos) = 1, 'nova tentativa';
  -- Este lote fica sem resposta (função fora do ar): depois de 3 minutos, o item volta
  update public.push_batches set created_at = now() - interval '4 minutes' where reported_at is null;
end $$;
select public._push_tick() is not null as ok \gset
do $$ declare q public.push_queue;
begin
  select * into q from public.push_queue where user_id = '00000000-0000-0000-0000-0000000000a6' and kind = 'teste';
  assert q.attempts = 2 and not q.done, format('segunda tentativa: %s', row_to_json(q));
  assert (select count(*) from public.push_batches where abandoned) >= 1;
  -- Terceira falha: desiste
  update public.push_batches set created_at = now() - interval '4 minutes' where reported_at is null;
end $$;
select public._push_tick() is not null as ok \gset
do $$ begin
  assert (select done and sent_at is null and attempts = 3 from public.push_queue
           where user_id = '00000000-0000-0000-0000-0000000000a6' and kind = 'teste'), 'desiste depois de 3 tentativas';
  update public.push_batches set reported_at = now() where reported_at is null;
  -- Vencido não sai
  insert into public.push_queue (user_id, kind, payload, ttl, expires_at)
    values ('00000000-0000-0000-0000-0000000000a6', 'social', '{"title":"x","body":"y"}', 60, now() - interval '1 second');
end $$;
select public._push_tick() is not null as ok \gset
do $$ begin
  assert (select bool_and(done) from public.push_queue where user_id = '00000000-0000-0000-0000-0000000000a6'), 'vencidos encerrados';
  update public.push_batches set reported_at = now() where reported_at is null;
  raise warning 'OK notificações: novas tentativas, lote sem resposta e vencidos';
end $$;

-- ── 6. Preferências ───────────────────────────────────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', :'eva', false);
do $$
declare s jsonb;
begin
  begin perform public.set_notify('{"volume": 3}'); raise exception 'devia recusar';
  exception when others then assert sqlerrm = 'configuracao_invalida', sqlerrm; end;
  begin perform public.set_notify('{"lembrete": "sim"}'); raise exception 'devia recusar';
  exception when others then assert sqlerrm = 'configuracao_invalida', sqlerrm; end;
  begin perform public.set_notify('{"risco_hora": "25:00"}'); raise exception 'devia recusar';
  exception when others then assert sqlerrm = 'horario_invalido', sqlerrm; end;
  begin perform public.set_notify('{"lembrete_hora": "03:00"}'); raise exception 'devia recusar';
  exception when others then assert sqlerrm = 'horario_invalido', sqlerrm; end;
  begin perform public.set_notify('{"lembrete_hora": "abc"}'); raise exception 'devia recusar';
  exception when others then assert sqlerrm = 'horario_invalido', sqlerrm; end;
  s := public.set_notify('{"risco_hora": "21:30", "social": false}');
  assert s = '{"lembrete": true, "lembrete_hora": "09:00", "risco": true, "risco_hora": "21:30", "social": false}'::jsonb, format('%s', s);
  raise warning 'OK notificações: preferências';
end $$;
reset role;

-- Social desligado: incentivo não vira notificação; marca dos scripts também desliga
delete from public.push_queue;
set role authenticated;
select set_config('request.jwt.claim.sub', :'leo', false);
select public.send_cheer(null, :'eva', 'forca') is not null as ok \gset
reset role;
do $$ begin
  assert not exists (select 1 from public.push_queue), 'social desligado';
  update public.profiles set notify = notify || '{"social": true}' where id = '00000000-0000-0000-0000-0000000000a6';
  perform set_config('forja.sem_push', 'on', true);
  insert into public.user_events (user_id, kind, ref) values ('00000000-0000-0000-0000-0000000000a6', 'incentivo', 'sem-push');
  assert not exists (select 1 from public.push_queue), 'marca dos scripts desliga o envio';
end $$;
-- Incentivos em sequência: uma notificação a cada 10 minutos
do $$
declare c1 bigint; c2 bigint;
begin
  insert into public.cheers (post_id, sender, receiver, kind)
    values (null, '00000000-0000-0000-0000-0000000000b6', '00000000-0000-0000-0000-0000000000a6', 'foco') returning id into c1;
  insert into public.cheers (post_id, sender, receiver, kind)
    values (null, '00000000-0000-0000-0000-0000000000b6', '00000000-0000-0000-0000-0000000000a6', 'volta') returning id into c2;
  insert into public.user_events (user_id, kind, ref) values ('00000000-0000-0000-0000-0000000000a6', 'incentivo', c1::text);
  insert into public.user_events (user_id, kind, ref) values ('00000000-0000-0000-0000-0000000000a6', 'incentivo', c2::text);
  assert (select count(*) from public.push_queue where kind = 'social') = 1, 'só uma notificação de incentivo';
  assert (select payload->>'body' from public.push_queue where kind = 'social') = 'Leo te mandou 🎯 Foco.',
    (select payload->>'body' from public.push_queue where kind = 'social');
end $$;
do $$ begin
  update public.push_queue set done = true;
  update public.push_batches set reported_at = now() where reported_at is null;
  raise warning 'OK notificações: social desligado, marca dos scripts e incentivos agrupados';
end $$;

-- ── 7. Lembretes do horário ───────────────────────────────────────────────────
-- Eva: nada feito hoje. Leo: meta cumprida hoje.
do $$
declare
  v_now  time := date_trunc('minute', (now() at time zone 'America/Sao_Paulo')::time);
  v_hora text := to_char(v_now, 'HH24:MI');
  v_leo  uuid := '00000000-0000-0000-0000-0000000000b6';
  r record;
begin
  -- Lembretes valem a partir das 05:00; de madrugada o teste usa as preferências sem validação
  update public.profiles set notify = jsonb_build_object('lembrete', true, 'lembrete_hora', v_hora, 'risco', false, 'risco_hora', '20:00', 'social', true)
   where id in ('00000000-0000-0000-0000-0000000000a6', v_leo);
  for r in select id from public.missions where user_id = v_leo and mission_date = public._local_today(v_leo)
            and status = 'pendente' and kind = 'diaria' order by name loop
    perform public._complete_mission(v_leo, r.id, now());
  end loop;
  delete from public.push_log;
end $$;
select public._push_tick()->>'lembretes' as n1 \gset
select public._push_tick()->>'lembretes' as n2 \gset
select set_config('t.n', :'n1' || ',' || :'n2', false);
do $$
declare q public.push_queue;
begin
  assert current_setting('t.n') = '1,0', format('um lembrete, uma vez só: %s', current_setting('t.n'));
  select * into q from public.push_queue where kind = 'lembrete';
  assert q.user_id = '00000000-0000-0000-0000-0000000000a6' and q.payload->>'title' = 'Missões de hoje'
     and q.payload->>'body' ~ '^(Bom dia|Boa tarde|Boa noite)! Meta de hoje: [0-9]+ miss(ão|ões)\.$', format('%s', q.payload);
  assert (select sent from public.push_log where user_id = '00000000-0000-0000-0000-0000000000a6' and kind = 'lembrete');
  assert (select not sent from public.push_log where user_id = '00000000-0000-0000-0000-0000000000b6' and kind = 'lembrete'),
    'meta cumprida: conferido, sem aviso';
end $$;

-- Sequência em risco, à noite (Eva ainda sem missões feitas)
do $$
declare v_hora text := to_char(date_trunc('minute', (now() at time zone 'America/Sao_Paulo')::time), 'HH24:MI');
begin
  update public.profiles set notify = notify || jsonb_build_object('lembrete', false, 'risco', true, 'risco_hora', v_hora)
   where id = '00000000-0000-0000-0000-0000000000a6';
end $$;
select public._push_tick()->>'lembretes' as n3 \gset
do $$
declare q public.push_queue;
begin
  select * into q from public.push_queue where kind = 'risco';
  assert q.payload->>'title' = 'Meta de hoje' and q.payload->>'body' ~ '^Ainda dá tempo: faltam [0-9]+ miss(ão|ões) para a meta de hoje\.$'
     and q.urgency = 'high' and q.ttl between 900 and 21600, format('%s / ttl %s', q.payload, q.ttl);
end $$;

-- Fase Domínio (dias 46 a 60): lembrete só se a meta de ontem falhou
do $$
declare
  v_leo uuid := '00000000-0000-0000-0000-0000000000b6';
  v_today date := public._local_today(v_leo);
begin
  -- As conclusões de hoje do Leo passam para ontem: ontem com meta, hoje sem nada
  update public.missions set mission_date = mission_date - 1, due_date = due_date - 1, completed_at = completed_at - interval '1 day'
   where user_id = v_leo and mission_date = v_today;
  update public.profiles set program_start = v_today - 49 where id in (v_leo, '00000000-0000-0000-0000-0000000000a6');
  update public.profiles set notify = notify || '{"lembrete": true, "risco": false}' where id = '00000000-0000-0000-0000-0000000000a6';
  assert (select goal_met from public._day_stats(v_leo, v_today - 1, v_today - 1)) and
         not (select goal_met from public._day_stats(v_leo, v_today, v_today)), 'preparação do Leo';
  delete from public.push_log;
  delete from public.push_queue;
end $$;
select public._push_tick()->>'lembretes' as n4 \gset
select set_config('t.n', :'n4', false);
do $$ begin
  assert current_setting('t.n') = '1', format('só a Eva recebe: %s', current_setting('t.n'));
  assert (select user_id from public.push_queue where kind = 'lembrete') = '00000000-0000-0000-0000-0000000000a6';
  assert (select not sent from public.push_log where user_id = '00000000-0000-0000-0000-0000000000b6' and kind = 'lembrete'),
    'Leo, dia 50 com a meta de ontem cumprida: sem lembrete';
  update public.push_queue set done = true;
  update public.push_batches set reported_at = now() where reported_at is null;
  raise warning 'OK notificações: lembrete, sequência em risco e fase Domínio';
end $$;

-- ── 8. Permissões ─────────────────────────────────────────────────────────────
set role anon;
select set_config('request.jwt.claim.sub', '', false);
do $$
begin
  begin perform public.get_notify(); raise exception 'devia recusar';
  exception when insufficient_privilege then null; end;
  begin perform 1 from public.push_config; raise exception 'devia recusar';
  exception when insufficient_privilege then null; end;
  begin perform public._push_tick(); raise exception 'devia recusar';
  exception when insufficient_privilege then null; end;
  begin perform public.admin_set_push_url('https://outro.dev'); raise exception 'devia recusar';
  exception when insufficient_privilege then null; end;
  begin perform public.push_claim('0000000000000000000000000000000000000000000000000000000000000000'); raise exception 'devia recusar';
  exception when others then assert sqlerrm = 'lote_invalido', sqlerrm; end;
end $$;
set role authenticated;
select set_config('request.jwt.claim.sub', :'eva', false);
do $$
begin
  begin perform public.push_claim('x'); raise exception 'devia recusar';
  exception when insufficient_privilege then null; end;
  begin perform 1 from public.push_config; raise exception 'devia recusar';
  exception when insufficient_privilege then null; end;
  begin perform 1 from public.push_subscriptions; raise exception 'devia recusar';
  exception when insufficient_privilege then null; end;
  begin perform public._push_kick(true); raise exception 'devia recusar';
  exception when insufficient_privilege then null; end;
  -- Teste sem aparelho
  delete from public.push_subscriptions;
exception when insufficient_privilege then null;  -- o delete acima também é negado, como deve ser
end $$;
reset role;
do $$ begin
  assert (select count(*) from public.push_subscriptions) > 0, 'o app não apaga inscrições direto na tabela';
  raise warning 'OK notificações: permissões';
end $$;

do $$ begin raise warning 'TESTES DAS NOTIFICAÇÕES PASSARAM'; end $$;
