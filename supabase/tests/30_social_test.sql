-- Testes da Etapa 4 (parte 1): Premium aberto, amigos, privacidade, feed, incentivos, grupos,
-- desafios entre amigos, temporadas e ranking. Rodam com: supabase/tests/run.sh
\set ON_ERROR_STOP on
set client_min_messages = notice;

\set answers '{"display_name":"Teste","daily_minutes":30,"exercise":1,"diet":2,"sleep_hours":1,"sleep_quality":1,"stress":1,"rest":2,"reflection":1,"reading":0,"learning":1,"planning":1,"procrastination":1,"discipline":2,"screen_time":0,"phone_morning":0,"focus":1,"water":1,"morning_routine":2,"environment":2,"main_goal":"intelectual"}'

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', 'ana@teste.dev',  '{"name":"Ana"}'),
  ('00000000-0000-0000-0000-0000000000b1', 'bia@teste.dev',  '{"name":"Bia"}'),
  ('00000000-0000-0000-0000-0000000000c1', 'caio@teste.dev', '{"name":"Caio"}'),
  ('00000000-0000-0000-0000-000000000099', 'gil@teste.dev',  '{"name":"Gil"}');

-- Ajudantes (rodam como administrador, com datas controladas)
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
create function pg_temp.reset_user(p_uid uuid, start date) returns void language plpgsql as $$
begin
  delete from public.missions where user_id = p_uid;
  delete from public.xp_ledger where user_id = p_uid;
  delete from public.user_events where user_id = p_uid;
  delete from public.user_achievements where user_id = p_uid;
  delete from public.user_items where user_id = p_uid;
  delete from public.season_results where user_id = p_uid;
  update public.profiles set program_start = start where id = p_uid;
  perform public._recalc_stats(p_uid);
  delete from public.user_events where user_id = p_uid;
end $$;

-- Todo mundo faz a avaliação inicial
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', false);
select public.submit_assessment(:'answers') is not null as ok \gset
select public.ensure_today() is not null as ok \gset
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000b1', false);
select public.submit_assessment(:'answers') is not null as ok \gset
select public.ensure_today() is not null as ok \gset
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000c1', false);
select public.submit_assessment(:'answers') is not null as ok \gset
select public.ensure_today() is not null as ok \gset
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000099', false);
select public.submit_assessment(:'answers') is not null as ok \gset
select public.ensure_today() is not null as ok \gset
reset role;

update public.profiles set display_name = 'Ana'  where id = '00000000-0000-0000-0000-0000000000a1';
update public.profiles set display_name = 'Bia'  where id = '00000000-0000-0000-0000-0000000000b1';
update public.profiles set display_name = 'Caio' where id = '00000000-0000-0000-0000-0000000000c1';
update public.profiles set display_name = 'Gil'  where id = '00000000-0000-0000-0000-000000000099';
select set_config('t.code_a', friend_code, false) from public.profiles where id = '00000000-0000-0000-0000-0000000000a1';
select set_config('t.code_b', friend_code, false) from public.profiles where id = '00000000-0000-0000-0000-0000000000b1';
select set_config('t.code_c', friend_code, false) from public.profiles where id = '00000000-0000-0000-0000-0000000000c1';
select set_config('t.code_g', friend_code, false) from public.profiles where id = '00000000-0000-0000-0000-000000000099';

-- ════════════════════════════════════════════════════════════════════════════
-- A. Premium liberado para todos, com data de fim definida depois
-- ════════════════════════════════════════════════════════════════════════════
do $$ begin
  assert (select premium_aberto and premium_aberto_ate is null from public.app_config), 'Premium aberto e sem data';
  assert (select count(*) from public.premium_features where premium) = 7, 'mapa de recursos premium';
  assert (select count(*) from public.profiles where friend_code ~ '^[2-9A-HJKMNP-Z]{6}$') = (select count(*) from public.profiles),
    'todo mundo ganhou um código de amizade';
  assert (select count(distinct friend_code) from public.profiles) = (select count(*) from public.profiles), 'códigos únicos';
end $$;

set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', false);
do $$
declare p jsonb;
begin
  p := public.get_plan_info();
  assert p->>'plan' = 'free' and (p->>'premium')::boolean and p->>'via' = 'liberado' and p->'open_until' = 'null'::jsonb,
    format('plano: %s', p);
  assert (select bool_and((f->>'allowed')::boolean) from jsonb_array_elements(p->'features') f), 'tudo liberado';
  assert (public.ensure_today()->>'premium')::boolean;

  perform public.create_custom_mission('Alongar', '', 'fisica', 1, 10, true);
  perform public.create_custom_mission('Ler poesia', '', 'intelectual', 1, 10, true);
  perform public.create_custom_mission('Respirar fundo', '', 'mental', 1, 5, true);
  assert (select count(*) from public.user_habits where is_custom and active) = 3, 'mais de 2 hábitos com o Premium aberto';

  begin perform public.admin_set_premium_aberto(false); assert false, 'administração fechada ao app';
  exception when insufficient_privilege then null; end;
  begin perform public.admin_set_feature('chefes', false); assert false, 'administração fechada ao app';
  exception when insufficient_privilege then null; end;
  begin update public.app_config set premium_aberto = false; assert false, 'configuração só pelo administrador';
  exception when insufficient_privilege then null; end;
  begin perform public._has_premium(auth.uid()); assert false, 'funções internas fechadas';
  exception when insufficient_privilege then null; end;
  raise notice 'OK Premium aberto para todos';
end $$;

-- A liberação acabou ontem
reset role;
select public.admin_set_premium_aberto(true, current_date - 1) is not null as ok \gset
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', false);
do $$
declare p jsonb;
begin
  p := public.get_plan_info();
  assert not (p->>'premium')::boolean and p->>'via' is null and p->'open_until' = 'null'::jsonb, format('fim da liberação: %s', p);
  assert not (public.ensure_today()->>'premium')::boolean;
  begin perform public.create_custom_mission('Quarto hábito', '', 'mental', 1, 5, true); assert false, 'limite do gratuito';
  exception when raise_exception then assert sqlerrm = 'limite_gratuito_personalizadas', sqlerrm; end;
  perform public.create_custom_mission('Avulsa', '', 'mental', 1, 5, false);
  begin perform public.start_boss('tempestade'); assert false, 'chefes são premium';
  exception when raise_exception then assert sqlerrm = 'recurso_premium', sqlerrm; end;
  begin perform public.set_mode('desafio', true); assert false, 'modos exigentes são premium';
  exception when raise_exception then assert sqlerrm = 'recurso_premium', sqlerrm; end;
  perform public.set_mode('normal', false);
  begin perform public.get_season(); assert false, 'temporadas são premium';
  exception when raise_exception then assert sqlerrm = 'recurso_premium', sqlerrm; end;
  assert (select count(*) from public.user_habits where is_custom and active) = 3, 'nada é apagado quando o Premium acaba';
end $$;

-- O administrador torna os chefes gratuitos; depois dá Premium para uma pessoa
reset role;
select public.admin_set_feature('chefes', false) is not null as ok \gset
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', false);
do $$ begin
  begin perform public.start_boss('tempestade');
  exception when raise_exception then assert sqlerrm <> 'recurso_premium', format('chefes gratuitos: %s', sqlerrm); end;
end $$;
reset role;
select public.admin_set_feature('chefes', true) is not null as ok \gset
do $$ begin perform public.admin_set_plan('ana@teste.dev', 'premium'); end $$;
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', false);
do $$
declare p jsonb;
begin
  p := public.get_plan_info();
  assert (p->>'premium')::boolean and p->>'via' = 'plano', format('Premium individual: %s', p);
end $$;
reset role;
do $$ begin perform public.admin_set_plan('ana@teste.dev', 'free'); end $$;
select public.admin_set_premium_aberto(true, current_date + 30) is not null as ok \gset
set role authenticated;
do $$
declare p jsonb;
begin
  p := public.get_plan_info();
  assert (p->>'premium')::boolean and (p->>'open_until')::date = current_date + 30, format('liberado até: %s', p);
  raise notice 'OK fim da liberação, recursos pagos e Premium individual';
end $$;
reset role;
select public.admin_set_premium_aberto(true, null) is not null as ok \gset

-- ════════════════════════════════════════════════════════════════════════════
-- B. Pedidos de amizade, privacidade e conquistas sociais
-- ════════════════════════════════════════════════════════════════════════════
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', false);
do $$
declare r jsonb; code_b text := current_setting('t.code_b');
begin
  r := public.lookup_friend_code(lower(substr(code_b, 1, 3) || '-' || substr(code_b, 4)));
  assert r->>'name' = 'Bia' and r->>'status' = 'nenhum' and (r->>'accepts')::boolean, format('código digitado de outro jeito: %s', r);
  assert not r ? 'id', 'a busca não revela o id';
  begin perform public.lookup_friend_code(current_setting('t.code_a')); assert false, 'próprio código';
  exception when raise_exception then assert sqlerrm = 'codigo_proprio', sqlerrm; end;
  begin perform public.send_friend_request('ZZZZZZ'); assert false, 'código inexistente';
  exception when raise_exception then assert sqlerrm = 'codigo_invalido', sqlerrm; end;

  r := public.send_friend_request(code_b);
  assert r->>'status' = 'pendente' and r->>'name' = 'Bia', format('pedido: %s', r);
  begin perform public.send_friend_request(code_b); assert false, 'pedido repetido';
  exception when raise_exception then assert sqlerrm = 'pedido_ja_enviado', sqlerrm; end;
  r := public.send_friend_request(current_setting('t.code_c'));
  assert r->>'status' = 'pendente';
  assert jsonb_array_length(public.get_social()->'outgoing') = 2, 'dois pedidos enviados';

  begin insert into public.friendships (requester, addressee) values (auth.uid(), '00000000-0000-0000-0000-000000000099');
        assert false, 'amizade só pelas funções'; exception when insufficient_privilege then null; end;
  begin perform public._card(auth.uid(), '00000000-0000-0000-0000-0000000000b1'); assert false, 'funções internas fechadas';
  exception when insufficient_privilege then null; end;
end $$;

-- Bia aceita
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000b1', false);
do $$
declare s jsonb; n jsonb; r jsonb;
begin
  assert (public.ensure_today()->>'social_unseen')::int = 1, 'aviso de pedido aparece no início';
  n := public.get_notifications();
  assert (n->>'unseen')::int = 1 and n->'items'->0->>'kind' = 'pedido_amizade'
     and n->'items'->0->'data'->'user'->>'name' = 'Ana', format('avisos: %s', n);
  assert jsonb_array_length(public.pending_events()) = 0
      or not exists (select 1 from jsonb_array_elements(public.pending_events()) e where e->>'kind' = 'pedido_amizade'),
    'avisos sociais não vão para a tela de recompensa';
  s := public.get_social();
  assert jsonb_array_length(s->'incoming') = 1 and s->'incoming'->0->'user'->>'name' = 'Ana';
  r := public.respond_friend_request((s->'incoming'->0->>'id')::uuid, true);
  assert r->>'status' = 'aceita' and r->'user'->>'name' = 'Ana';
  assert (public.get_notifications()->>'unseen')::int = 0, 'responder marca o pedido como visto';
  s := public.get_social();
  assert jsonb_array_length(s->'friends') = 1 and s->'friends'->0->>'name' = 'Ana' and (s->'friends'->0->>'level')::int >= 1,
    format('amiga na lista: %s', s->'friends');
  assert exists (select 1 from public.user_achievements where achievement_id = 'so_amigo'), 'conquista Em boa companhia';
  assert exists (select 1 from public.feed_posts where kind = 'conquista' and ref = 'so_amigo'), 'conquista publicada no feed';
  begin perform public.respond_friend_request((s->'friends'->0->>'friendship_id')::uuid, true); assert false, 'pedido já respondido';
  exception when raise_exception then assert sqlerrm = 'pedido_nao_encontrado', sqlerrm; end;
end $$;

-- Caio recusa; Ana não pode insistir logo em seguida; Caio muda de ideia e pede, Ana pede de volta e vira amizade
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000c1', false);
do $$ begin
  perform public.respond_friend_request((public.get_social()->'incoming'->0->>'id')::uuid, false);
  assert jsonb_array_length(public.get_social()->'friends') = 0;
end $$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', false);
do $$ begin
  assert (select count(*) from public.user_achievements where achievement_id = 'so_amigo') = 1, 'quem pediu também ganha a conquista';
  assert exists (select 1 from jsonb_array_elements(public.get_notifications()->'items') i
                  where i->>'kind' = 'amizade_aceita' and i->'data'->'user'->>'name' = 'Bia'), 'aviso de amizade aceita';
  begin perform public.send_friend_request(current_setting('t.code_c')); assert false, 'pedido recusado há pouco';
  exception when raise_exception then assert sqlerrm = 'pedido_recusado_recente', sqlerrm; end;
end $$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000c1', false);
do $$ begin
  assert public.send_friend_request(current_setting('t.code_a'))->>'status' = 'pendente', 'quem recusou pode pedir depois';
end $$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', false);
do $$
declare r jsonb;
begin
  assert public.lookup_friend_code(current_setting('t.code_c'))->>'status' = 'pedido_recebido';
  r := public.send_friend_request(current_setting('t.code_c'));
  assert r->>'status' = 'aceita', format('pedidos cruzados viram amizade: %s', r);
  assert jsonb_array_length(public.get_social()->'friends') = 2;
  begin perform public.send_friend_request(current_setting('t.code_c')); assert false, 'já são amigos';
  exception when raise_exception then assert sqlerrm = 'ja_sao_amigos', sqlerrm; end;
end $$;

-- Gil não aceita pedidos
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000099', false);
do $$
declare pv jsonb;
begin
  pv := public.update_privacy('{"aceitar_pedidos": false}');
  assert not (pv->>'aceitar_pedidos')::boolean and (pv->>'mostrar_nivel')::boolean, format('privacidade: %s', pv);
  begin perform public.update_privacy('{"mostrar_senha": true}'); assert false, 'opção desconhecida';
  exception when raise_exception then assert sqlerrm = 'privacidade_invalida', sqlerrm; end;
  begin perform public.update_privacy('{"mostrar_nivel": "sim"}'); assert false, 'valor inválido';
  exception when raise_exception then assert sqlerrm = 'privacidade_invalida', sqlerrm; end;
end $$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', false);
do $$ begin
  assert (public.lookup_friend_code(current_setting('t.code_g'))->>'accepts')::boolean = false;
  begin perform public.send_friend_request(current_setting('t.code_g')); assert false, 'pedidos desativados';
  exception when raise_exception then assert sqlerrm = 'pedidos_desativados', sqlerrm; end;
  begin perform public.friend_profile('00000000-0000-0000-0000-000000000099'); assert false, 'desconhecido não aparece';
  exception when raise_exception then assert sqlerrm = 'perfil_indisponivel', sqlerrm; end;
  assert (select count(*) from public.friendships) = (select count(*) from public.friendships where auth.uid() in (requester, addressee)),
    'só enxerga as próprias amizades';
  raise notice 'OK pedidos de amizade';
end $$;

-- Privacidade no perfil do amigo
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000b1', false);
select public.update_privacy('{"mostrar_nivel": false, "mostrar_conquistas": false}') is not null as ok \gset
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', false);
do $$
declare p jsonb;
begin
  p := public.friend_profile('00000000-0000-0000-0000-0000000000b1');
  assert p->>'relation' = 'amigo' and p->'card'->>'name' = 'Bia', format('perfil: %s', p);
  assert not p->'card' ? 'level' and not p->'card' ? 'title', 'nível escondido';
  assert not p->'card' ? 'achievements' and not p ? 'achievements' and not p ? 'bosses', 'conquistas escondidas';
  assert p ? 'attributes' and p ? 'my_attributes', 'atributos continuam visíveis';
  assert p->'card' ? 'streak' and jsonb_array_length(p->'week') between 1 and 7, 'sequência visível';
  assert not p->'card' ? 'areas', 'hábitos ficam escondidos por padrão';
  assert (p->'me'->>'level')::int >= 1, 'comparação com os meus dados';
  assert p->'privacy'->>'nivel' = 'false';
  raise notice 'OK privacidade';
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- C. Feed e incentivos
-- ════════════════════════════════════════════════════════════════════════════
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', false);
do $$
declare
  f jsonb; post_b bigint; post_a bigint; r jsonb;
begin
  f := public.friends_feed(null);
  select (e->>'id')::bigint into post_b from jsonb_array_elements(f) e where e->'author'->>'name' = 'Bia' and e->>'kind' = 'conquista';
  select (e->>'id')::bigint into post_a from jsonb_array_elements(f) e where (e->>'mine')::boolean limit 1;
  assert post_b is not null and post_a is not null, format('feed com a amiga e comigo: %s', f);
  assert (select e->'data'->>'name' from jsonb_array_elements(f) e where (e->>'id')::bigint = post_b) = 'Em boa companhia';

  r := public.send_cheer(post_b, null, 'parabens');
  assert r->>'state' = 'parabens';
  r := public.send_cheer(post_b, null, 'parabens');
  assert r->'state' = 'null'::jsonb, 'tocar de novo desfaz';
  assert not exists (select 1 from public.cheers where post_id = post_b), 'incentivo removido';
  perform public.send_cheer(post_b, null, 'forca');
  r := public.send_cheer(post_b, null, 'brasa');
  assert r->>'state' = 'brasa' and (select count(*) from public.cheers where post_id = post_b) = 1, 'trocar de reação';
  f := public.friends_feed(null);
  assert (select e->>'my_cheer' from jsonb_array_elements(f) e where (e->>'id')::bigint = post_b) = 'brasa';
  assert (select (e->'cheers'->>'brasa')::int from jsonb_array_elements(f) e where (e->>'id')::bigint = post_b) = 1;

  begin perform public.send_cheer(post_a, null, 'forca'); assert false, 'sem incentivo para si';
  exception when raise_exception then assert sqlerrm = 'incentivo_proprio', sqlerrm; end;
  begin perform public.send_cheer(post_b, null, 'volta'); assert false, 'reação inválida';
  exception when raise_exception then assert sqlerrm = 'incentivo_invalido', sqlerrm; end;

  r := public.send_cheer(null, '00000000-0000-0000-0000-0000000000b1', 'volta');
  assert r->>'state' = 'volta';
  begin perform public.send_cheer(null, '00000000-0000-0000-0000-0000000000b1', 'forca'); assert false, 'um por dia';
  exception when raise_exception then assert sqlerrm = 'incentivo_ja_enviado_hoje', sqlerrm; end;
  begin perform public.send_cheer(null, '00000000-0000-0000-0000-000000000099', 'forca'); assert false, 'só para amigos';
  exception when raise_exception then assert sqlerrm = 'amigo_nao_encontrado', sqlerrm; end;

  begin insert into public.cheers (sender, receiver, kind) values (auth.uid(), '00000000-0000-0000-0000-0000000000b1', 'forca');
        assert false, 'incentivo só pelas funções'; exception when insufficient_privilege then null; end;
  begin insert into public.feed_posts (author, kind, ref) values (auth.uid(), 'nivel', '99');
        assert false, 'publicação só pelas funções'; exception when insufficient_privilege then null; end;

  -- Compartilhar manualmente: só o que é da pessoa
  r := public.share_post('nivel', '1');
  assert (r->>'id') is not null and not (r->>'already')::boolean, format('nível 1 compartilhado: %s', r);
  assert (public.share_post('nivel', '1')->>'already')::boolean, 'sem publicação repetida';
  begin perform public.share_post('nivel', '50'); assert false, 'nível que não tem';
  exception when raise_exception then assert sqlerrm = 'publicacao_invalida', sqlerrm; end;
  begin perform public.share_post('conquista', 'm_750'); assert false, 'conquista que não tem';
  exception when raise_exception then assert sqlerrm = 'publicacao_invalida', sqlerrm; end;
  assert (public.delete_post((r->>'id')::bigint)->>'ok')::boolean, 'apagar a própria publicação';
  assert not (public.delete_post(post_b)->>'ok')::boolean, 'não apaga a dos outros';
end $$;

-- Gil (sem amizade) não vê nem reage às publicações da Bia
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000099', false);
do $$
declare post_b bigint;
begin
  assert not exists (select 1 from jsonb_array_elements(public.friends_feed(null)) e where e->'author'->>'name' = 'Bia'), 'feed só de amigos';
  assert (select count(*) from public.feed_posts) = (select count(*) from public.feed_posts where author = auth.uid()), 'leitura protegida';
end $$;
reset role;
select set_config('t.post_b', (select id::text from public.feed_posts where author = '00000000-0000-0000-0000-0000000000b1' and ref = 'so_amigo'), false);
set role authenticated;
do $$ begin
  begin perform public.send_cheer(current_setting('t.post_b')::bigint, null, 'forca'); assert false, 'só amigos reagem';
  exception when raise_exception then assert sqlerrm = 'publicacao_nao_encontrada', sqlerrm; end;
end $$;

-- Bia recebe os incentivos como avisos sociais
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000b1', false);
do $$
declare n jsonb; ids bigint[];
begin
  n := public.get_notifications();
  assert (n->>'unseen')::int = 2, format('dois incentivos (a reação desfeita sumiu): %s', n);
  assert exists (select 1 from jsonb_array_elements(n->'items') i where i->>'kind' = 'incentivo' and i->'data'->>'cheer' = 'brasa'
                   and i->'data'->'post'->'data'->>'name' = 'Em boa companhia');
  assert exists (select 1 from jsonb_array_elements(n->'items') i where i->>'kind' = 'incentivo' and i->'data'->>'cheer' = 'volta'
                   and i->'data'->'post' = 'null'::jsonb);
  select array_agg((i->>'id')::bigint) into ids from jsonb_array_elements(n->'items') i where not (i->>'seen')::boolean;
  perform public.mark_events_seen(ids);
  assert (public.get_notifications()->>'unseen')::int = 0;
  raise notice 'OK feed e incentivos';
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- D. Grupos
-- ════════════════════════════════════════════════════════════════════════════
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', false);
do $$
declare r jsonb;
begin
  begin perform public.create_group('X', ''); assert false, 'nome curto';
  exception when raise_exception then assert sqlerrm = 'nome_grupo_invalido', sqlerrm; end;
  r := public.create_group('  Forja dos amigos ', 'Quem treina junto, evolui junto.');
  assert r->>'invite_code' ~ '^[2-9A-HJKMNP-Z]{7}$', format('código do grupo: %s', r);
  perform set_config('t.group', r->>'id', false);
  perform set_config('t.group_code', r->>'invite_code', false);
  assert (select name from public.social_groups) = 'Forja dos amigos';
end $$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000b1', false);
do $$
declare r jsonb;
begin
  r := public.join_group(lower(current_setting('t.group_code')));
  assert r->>'name' = 'Forja dos amigos' and not (r->>'already')::boolean;
  assert (public.join_group(current_setting('t.group_code'))->>'already')::boolean, 'entrar de novo não duplica';
  begin perform public.update_group(current_setting('t.group')::uuid, 'Outro nome', ''); assert false, 'só o dono edita';
  exception when raise_exception then assert sqlerrm = 'so_o_dono', sqlerrm; end;
end $$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000099', false);
do $$ begin perform public.join_group(current_setting('t.group_code')); end $$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000c1', false);
do $$ begin
  begin perform public.group_detail(current_setting('t.group')::uuid); assert false, 'quem não é do grupo não vê';
  exception when raise_exception then assert sqlerrm = 'grupo_nao_encontrado', sqlerrm; end;
  begin perform public.join_group('ZZZZZZZ'); assert false, 'código errado';
  exception when raise_exception then assert sqlerrm = 'grupo_nao_encontrado', sqlerrm; end;
end $$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', false);
do $$
declare g jsonb; p jsonb; n jsonb;
begin
  g := public.group_detail(current_setting('t.group')::uuid);
  assert g->>'role' = 'dono' and jsonb_array_length(g->'members') = 3, format('grupo: %s', g);
  assert g->'members'->0->>'role' = 'dono';
  assert exists (select 1 from jsonb_array_elements(g->'members') m where m->>'name' = 'Gil' and not (m->>'friend')::boolean);
  -- Colega de grupo aparece, mesmo sem amizade
  p := public.friend_profile('00000000-0000-0000-0000-000000000099');
  assert p->>'relation' = 'grupo' and p->'groups_in_common'->0->>'name' = 'Forja dos amigos', format('perfil via grupo: %s', p);
  n := public.get_notifications();
  assert (select count(*) from jsonb_array_elements(n->'items') i where i->>'kind' = 'grupo_entrada') = 2, 'dono sabe quem entrou';
  assert jsonb_array_length(public.get_groups()) = 1 and (public.get_groups()->0->>'members')::int = 3;
  assert (public.remove_group_member(current_setting('t.group')::uuid, '00000000-0000-0000-0000-000000000099')->>'ok')::boolean;
  assert (public.reset_group_code(current_setting('t.group')::uuid)->>'invite_code') <> current_setting('t.group_code'), 'código novo';
end $$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000099', false);
do $$ begin
  begin perform public.friend_profile('00000000-0000-0000-0000-0000000000a1'); assert false, 'fora do grupo, perfil fechado';
  exception when raise_exception then assert sqlerrm = 'perfil_indisponivel', sqlerrm; end;
  assert jsonb_array_length(public.get_groups()) = 0;
end $$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', false);
do $$ begin
  perform public.leave_group(current_setting('t.group')::uuid);
end $$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000b1', false);
do $$
declare g jsonb;
begin
  g := public.group_detail(current_setting('t.group')::uuid);
  assert g->>'role' = 'dono' and jsonb_array_length(g->'members') = 1, format('dono saiu, Bia assume: %s', g);
end $$;
-- Ana volta pelo código novo que a Bia passar
reset role;
select set_config('t.group_code', invite_code, false) from public.social_groups where id = current_setting('t.group')::uuid;
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', false);
do $$ begin
  perform public.join_group(current_setting('t.group_code'));
  raise notice 'OK grupos';
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- E. Desafios: criação e validações pela API
-- ════════════════════════════════════════════════════════════════════════════
do $$
declare r jsonb; c jsonb; cid uuid;
begin
  begin perform public.create_challenge('{"kind":"competitivo","metric":"meta_diaria","days":2,"friends":["00000000-0000-0000-0000-0000000000b1"]}');
        assert false, 'mínimo de 3 dias';
  exception when raise_exception then assert sqlerrm = 'duracao_desafio_invalida', sqlerrm; end;
  begin perform public.create_challenge('{"kind":"competitivo","metric":"meta_diaria","days":7,"friends":["00000000-0000-0000-0000-000000000099"]}');
        assert false, 'só com amigos';
  exception when raise_exception then assert sqlerrm = 'amigo_nao_encontrado', sqlerrm; end;
  begin perform public.create_challenge('{"kind":"competitivo","metric":"meta_diaria","days":7,"friends":[]}');
        assert false, 'precisa de alguém';
  exception when raise_exception then assert sqlerrm = 'desafio_sem_participantes', sqlerrm; end;
  begin perform public.create_challenge('{"kind":"coletivo","metric":"meta_diaria","days":7,"friends":["00000000-0000-0000-0000-0000000000b1"],"target":15}');
        assert false, 'meta coletiva maior que o possível';
  exception when raise_exception then assert sqlerrm = 'meta_coletiva_invalida', sqlerrm; end;
  begin perform public.create_challenge('{"kind":"competitivo","metric":"area","days":7,"friends":["00000000-0000-0000-0000-0000000000b1"]}');
        assert false, 'área obrigatória';
  exception when raise_exception then assert sqlerrm = 'dimensao_invalida', sqlerrm; end;

  r := public.create_challenge('{"kind":"competitivo","metric":"meta_diaria","days":7,"title":"Semana firme",
                                 "friends":["00000000-0000-0000-0000-0000000000b1","00000000-0000-0000-0000-0000000000c1"]}');
  cid := (r->>'id')::uuid;
  perform set_config('t.ch_api', cid::text, false);
  c := public.challenge_detail(cid);
  assert c->>'title' = 'Semana firme' and c->>'phase' = 'em_andamento' and (c->>'days')::int = 7 and (c->>'day_index')::int = 1,
    format('desafio: %s', c);
  assert (select count(*) from jsonb_array_elements(c->'participants') p where p->>'status' = 'convidado') = 2;
  assert (c->>'is_creator')::boolean;

  r := public.create_challenge(format('{"kind":"coletivo","metric":"missoes","days":5,"start_tomorrow":true,"group_id":"%s","target":20}',
                                      current_setting('t.group'))::jsonb);
  c := public.challenge_detail((r->>'id')::uuid);
  assert c->>'phase' = 'agendado' and c->'group'->>'name' = 'Forja dos amigos' and (c->>'target')::int = 20, format('coletivo do grupo: %s', c);
  assert (select count(*) from public.challenges where creator = auth.uid()) = 2;
end $$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000b1', false);
do $$
declare n jsonb; l jsonb;
begin
  n := public.get_notifications();
  assert (select count(*) from jsonb_array_elements(n->'items') i where i->>'kind' = 'desafio_convite') = 2, format('convites: %s', n);
  perform public.respond_challenge(current_setting('t.ch_api')::uuid, true);
  begin perform public.respond_challenge(current_setting('t.ch_api')::uuid, true); assert false, 'convite já respondido';
  exception when raise_exception then assert sqlerrm = 'convite_nao_encontrado', sqlerrm; end;
  l := public.get_challenges();
  assert (select e->>'my_status' from jsonb_array_elements(l) e where e->>'id' = current_setting('t.ch_api')) = 'aceito', format('lista: %s', l);
end $$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000c1', false);
do $$ begin
  perform public.respond_challenge(current_setting('t.ch_api')::uuid, false);
  assert public.challenge_detail(current_setting('t.ch_api')::uuid)->>'my_status' = 'recusado';
end $$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', false);
do $$ begin
  perform public.cancel_challenge(current_setting('t.ch_api')::uuid);
  assert public.challenge_detail(current_setting('t.ch_api')::uuid)->>'status' = 'cancelado';
  begin perform public.cancel_challenge(current_setting('t.ch_api')::uuid); assert false, 'já cancelado';
  exception when raise_exception then assert sqlerrm = 'desafio_nao_encontrado', sqlerrm; end;
  begin insert into public.challenges (creator, kind, metric, title, starts_on, ends_on) values (auth.uid(), 'competitivo', 'missoes', 'Trapaça', current_date, current_date);
        assert false, 'desafio só pelas funções'; exception when insufficient_privilege then null; end;
  raise notice 'OK criação e convites de desafios';
end $$;
reset role;
delete from public.challenges;

-- ════════════════════════════════════════════════════════════════════════════
-- F. Desafios no tempo: placar, vencedor, meta coletiva e limite semanal de XP
-- ════════════════════════════════════════════════════════════════════════════
do $$
declare
  a uuid := '00000000-0000-0000-0000-0000000000a1';
  b uuid := '00000000-0000-0000-0000-0000000000b1';
  s date := '2026-10-01';
  c1 uuid; c2 uuid; c3 uuid; i int;
begin
  perform pg_temp.reset_user(a, s);
  perform pg_temp.reset_user(b, s);

  insert into public.challenges (creator, kind, metric, title, starts_on, ends_on)
    values (a, 'competitivo', 'meta_diaria', 'Três dias', s, s + 2) returning id into c1;
  insert into public.challenges (creator, kind, metric, title, target, starts_on, ends_on)
    values (a, 'coletivo', 'missoes', 'Juntos', 8, s + 3, s + 5) returning id into c2;
  insert into public.challenges (creator, kind, metric, dimension, title, starts_on, ends_on)
    values (b, 'competitivo', 'area', 'intelectual', 'Leitura', s + 3, s + 5) returning id into c3;
  insert into public.challenge_participants (challenge_id, user_id, status)
    select c, u, 'aceito' from unnest(array[c1, c2, c3]) c, unnest(array[a, b]) u;

  for i in 0 .. 5 loop
    perform pg_temp.open_day(a, s + i);
    perform pg_temp.open_day(b, s + i);
    perform pg_temp.complete(a, s + i, 2);
    if i <> 2 then perform pg_temp.complete(b, s + i, 2); end if;
  end loop;

  -- Placar ao vivo
  assert public._challenge_score(a, (select x from public.challenges x where id = c1), s + 2) = 3;
  assert public._challenge_score(b, (select x from public.challenges x where id = c1), s + 2) = 2;

  perform pg_temp.open_day(a, s + 6);
  assert (select status from public.challenges where id = c1) = 'encerrado', 'encerrado na abertura do dia';
  assert (select result from public.challenge_participants where challenge_id = c1 and user_id = a) = 'venceu';
  assert (select result from public.challenge_participants where challenge_id = c1 and user_id = b) = 'participou';
  assert (select xp from public.challenge_participants where challenge_id = c1 and user_id = a) = 40;
  assert (select amount from public.xp_ledger where user_id = a and source = 'desafio' and ref = c1::text) = 40, 'XP do vencedor';
  assert not exists (select 1 from public.xp_ledger where user_id = b and source = 'desafio' and ref = c1::text);
  assert exists (select 1 from public.user_events where user_id = b and kind = 'desafio_fim' and ref = c1::text), 'aviso para todos';

  -- Coletivo: 2 missões por dia × 2 pessoas × 3 dias = 12 ≥ 8
  assert (select status from public.challenges where id = c2) = 'encerrado';
  assert (select count(*) from public.challenge_participants where challenge_id = c2 and result = 'meta_coletiva') = 2;
  assert (select score from public.challenge_participants where challenge_id = c2 and user_id = a) = 6;

  -- Terceira recompensa na mesma semana não dá XP
  assert (select status from public.challenges where id = c3) = 'encerrado';
  assert (select count(*) from public.xp_ledger where user_id = a and source = 'desafio') = 2,
    format('no máximo 2 recompensas por semana (%s)', (select count(*) from public.xp_ledger where user_id = a and source = 'desafio'));
  assert exists (select 1 from public.user_achievements where user_id = a and achievement_id = 'so_desafio'), 'Duelo amistoso';
  assert (select total_xp from public.character_stats where user_id = a) = (select sum(amount) from public.xp_ledger where user_id = a),
    'XP coerente';
  raise notice 'OK desafios: placar, vencedor, meta coletiva e limite semanal';
end $$;

set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000b1', false);
do $$
declare ev jsonb; v jsonb;
begin
  ev := public.pending_events();
  select e into v from jsonb_array_elements(ev) e where e->>'kind' = 'desafio_fim' and e->'data'->'challenge'->>'title' = 'Três dias';
  assert v->'data'->>'result' = 'participou' and (v->'data'->>'score')::int = 2 and (v->'data'->>'participants')::int = 2
     and v->'data'->'winners'->0->>'name' = 'Ana', format('resultado do desafio: %s', v);
  assert not exists (select 1 from jsonb_array_elements(ev) e where e->>'kind' in ('incentivo','pedido_amizade','desafio_convite'));
end $$;
reset role;

-- ════════════════════════════════════════════════════════════════════════════
-- G. Temporadas: pontos, limites anti-fraude, fechamento do mês, liga e ranking
-- ════════════════════════════════════════════════════════════════════════════
update public.app_config set seasons_since = '2026-09-01';
do $$
declare
  a uuid := '00000000-0000-0000-0000-0000000000a1';
  b uuid := '00000000-0000-0000-0000-0000000000b1';
  s date := '2026-10-01';
  sp jsonb; sp2 jsonb; exp_pts int; i int; g int; p int; m int; n int; mid uuid;
begin
  -- Ana faz o plano inteiro do dia 7 ao 20 de outubro
  for i in 6 .. 19 loop
    perform pg_temp.open_day(a, s + i);
    perform pg_temp.complete(a, s + i, 20);
  end loop;

  -- Conferência independente da fórmula
  sp := public._season_points(a, 202610, '2026-10-31');
  select count(*) filter (where goal_met), count(*) filter (where daily_total > 0 and daily_done = daily_total)
    into g, p from public._day_stats(a, s, '2026-10-31');
  select coalesce(sum(least(cnt, 5) * 2), 0) into m from public._plan_done(a, s, '2026-10-31');
  select count(*) into n from public.challenge_participants cp join public.challenges c on c.id = cp.challenge_id
   where cp.user_id = a and cp.result in ('venceu','meta_coletiva') and c.ends_on between s and '2026-10-31';
  exp_pts := g * 10 + p * 5 + m + least(n, 4) * 10
           + case when g >= 15 then 30 else 0 end + case when p >= 3 then 20 else 0 end;
  assert (sp->>'points')::int = exp_pts, format('pontos %s, esperado %s: %s', sp->>'points', exp_pts, sp);
  assert g = 20 and (sp->>'goal_days')::int = 20 and (sp->>'perfect_days')::int >= 14, format('dias: %s', sp);
  assert (sp->'breakdown'->>'objetivos')::int = 50, 'dois objetivos da temporada';
  assert (sp->'breakdown'->>'missoes')::int = m and m <= g * 10, 'no máximo 5 missões (10 pontos) por dia';
  raise notice 'temporada de outubro: % (máximo de missões num dia: %)', sp->'breakdown',
    (select max(cnt) from public._plan_done(a, s, '2026-10-31'));

  -- Missões avulsas não dão pontos de temporada
  perform public._insert_mission(a, null, 'teste:avulsa1', 'personalizada', 'Avulsa', '', 'mental', 'foco', 'vitalidade', 1, 10, 'min', 10, 'qualquer', 'unica', s + 19, s + 19);
  select id into mid from public.missions where user_id = a and dedupe_key = 'teste:avulsa1';
  perform public._complete_mission(a, mid, pg_temp.ts(s + 19));
  sp2 := public._season_points(a, 202610, '2026-10-31');
  assert (sp2->>'points')::int = (sp->>'points')::int, 'avulsa não pontua';

  -- Fechamento do mês no primeiro acesso de novembro
  assert public._finalize_seasons(a, '2026-11-01') = 1;
  assert public._finalize_seasons(a, '2026-11-02') = 0, 'fecha uma vez só';
  assert (select points from public.season_results where user_id = a and season = 202610) = (sp->>'points')::int;
  assert (select league from public.season_results where user_id = a and season = 202610)
       = (select id from public.league_catalog where min_points <= (sp->>'points')::int order by min_points desc limit 1);
  assert (select amount from public.xp_ledger where user_id = a and source = 'temporada' and ref = '202610')
       = (select xp_reward from public.league_catalog l join public.season_results r on r.league = l.id where r.user_id = a and r.season = 202610),
    'XP da liga';
  assert exists (select 1 from public.user_events where user_id = a and kind = 'temporada' and ref = '202610');
  assert exists (select 1 from public.feed_posts where author = a and kind = 'temporada' and ref = '202610'), 'temporada publicada';
  assert not exists (select 1 from public.season_results where user_id = a and season = 202609), 'antes do início do programa não conta';
  perform public._progress_rewards(a, '2026-11-01');
  assert exists (select 1 from public.user_achievements where user_id = a and achievement_id = 'tp_1'), 'Primeira temporada';
  assert (select (data->>'of')::int from public.season_results where user_id = a and season = 202610) = 3, 'posição entre 3 (Ana, Bia e Caio)';
  raise notice 'OK temporada fechada: % pontos, liga %', sp->>'points',
    (select league from public.season_results where user_id = a and season = 202610);
end $$;

-- Ranking e temporada atual pela API
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', false);
do $$
declare r jsonb; s jsonb; ev jsonb;
begin
  s := public.get_season();
  assert (s->>'id')::int = to_char(now() at time zone 'America/Sao_Paulo', 'YYYYMM')::int, format('temporada: %s', s);
  assert s->>'name' like 'Temporada de %' and jsonb_array_length(s->'leagues') = 6 and jsonb_array_length(s->'objectives') = 3;
  assert exists (select 1 from jsonb_array_elements(s->'history') h where (h->>'season')::int = 202610), 'histórico';

  r := public.get_ranking('amigos', null, 'pontos');
  assert jsonb_array_length(r->'rows') = 3, format('ranking com Ana, Bia e Caio: %s', r);
  assert (select count(*) from jsonb_array_elements(r->'rows') x where (x->>'me')::boolean) = 1;
  assert (select x->>'level' from jsonb_array_elements(r->'rows') x where x->'user'->>'name' = 'Bia') is null, 'nível da Bia escondido';
  r := public.get_ranking('grupo', current_setting('t.group')::uuid, 'constancia');
  assert jsonb_array_length(r->'rows') = 2, format('ranking do grupo: %s', r);
  begin perform public.get_ranking('mundo', null, 'pontos'); assert false; exception when raise_exception then assert sqlerrm = 'ranking_invalido'; end;
  begin perform public.get_ranking('amigos', null, 'dinheiro'); assert false; exception when raise_exception then assert sqlerrm = 'ranking_invalido'; end;

  ev := public.pending_events();
  assert exists (select 1 from jsonb_array_elements(ev) e where e->>'kind' = 'temporada' and e->'data'->>'name' = 'Temporada de outubro'
                   and (e->'data'->>'points')::int > 0 and e->'data'->'league'->>'name' is not null), format('aviso da temporada: %s', ev);
  begin perform public._season_points(auth.uid(), 202610, current_date); assert false, 'funções internas fechadas';
  exception when insufficient_privilege then null; end;
  begin perform public._finalize_seasons(auth.uid(), current_date); assert false, 'funções internas fechadas';
  exception when insufficient_privilege then null; end;
end $$;

-- Quem não quer aparecer no ranking some da lista dos outros
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000c1', false);
select public.update_privacy('{"participar_ranking": false}') is not null as ok \gset
do $$
declare r jsonb;
begin
  r := public.get_ranking('amigos', null, 'pontos');
  assert jsonb_array_length(r->'rows') = 2, format('Caio e Ana: %s', r);
  assert (select (x->>'hidden')::boolean from jsonb_array_elements(r->'rows') x where (x->>'me')::boolean),
    'Caio se vê, marcado como oculto para os outros';
end $$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', false);
do $$
declare r jsonb;
begin
  r := public.get_ranking('amigos', null, 'xp');
  assert jsonb_array_length(r->'rows') = 2 and not exists (select 1 from jsonb_array_elements(r->'rows') x where x->'user'->>'name' = 'Caio'),
    format('Caio fora do ranking: %s', r);
  raise notice 'OK temporada atual e ranking';
end $$;

-- Remover amizade
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000c1', false);
do $$ begin
  assert (public.remove_friend('00000000-0000-0000-0000-0000000000a1')->>'ok')::boolean;
  assert jsonb_array_length(public.get_social()->'friends') = 0;
  assert exists (select 1 from public.user_achievements where achievement_id = 'so_amigo'), 'conquista continua';
  raise notice 'OK remover amizade';
end $$;
reset role;
