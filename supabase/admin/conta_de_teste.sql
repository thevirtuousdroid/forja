-- ════════════════════════════════════════════════════════════════════════════
-- Forja · Conta de teste "no máximo"
-- ════════════════════════════════════════════════════════════════════════════
-- Transforma UMA conta numa conta veterana, para testar o app inteiro sem esperar semanas:
--   • 70 dias de histórico simulado: programa de 66 dias concluído, sequência de 68 dias, um escudo usado
--   • passou pelos modos Desafio e Extremo; todos os modos ficam liberados (ela termina no Normal)
--   • todos os chefes vencidos e uma revanche em andamento, a um golpe da vitória
--   • TODAS as conquistas, equipamentos e títulos, com a melhor aparência equipada; plano Premium
--   • hoje fica com as missões em aberto para você testar
--   • com a atualização da Etapa 4 instalada, também: 4 amigos de teste ("bots"), grupo, desafios,
--     feed, incentivos, pedidos e convites pendentes, temporadas passadas, 3 semanas de registros
--     nas ferramentas, Mentor ligado e relatórios semanais
--
-- Como usar:
--   1. Supabase → Authentication → Users → Add user → Create new user.
--      Use um e-mail só para testes e marque "Auto Confirm User".
--      Dica: no Gmail, seunome+teste@gmail.com chega no seu e-mail normal e conta como outra conta.
--   2. Troque o e-mail na linha marcada abaixo e rode este arquivo inteiro no SQL Editor.
--   3. O resultado aparece numa tabelinha embaixo. Entre no app com esse e-mail e a senha que você escolheu.
--
-- Atenção: APAGA o progresso da conta indicada e refaz tudo do zero (pode rodar de novo para "resetar").
-- Por segurança, recusa contas que já têm progresso de verdade, a menos que você mude v_forcar para true.
-- Para apagar a conta de teste e os bots depois, veja o fim do arquivo.

do $$
declare
  -- ▼▼▼ TROQUE AQUI ▼▼▼
  v_email   text    := 'seunome+teste@gmail.com';
  v_forcar  boolean := false;   -- true só se tiver certeza de que é uma conta de teste
  -- ▲▲▲
  v_dias    int     := 70;      -- dias de histórico (70 = programa de 66 dias concluído)

  v_answers jsonb := '{"display_name":"Teste","daily_minutes":90,"exercise":1,"diet":1,"sleep_hours":1,"sleep_quality":1,
                       "stress":1,"rest":1,"reflection":1,"reading":1,"learning":1,"planning":1,"procrastination":1,
                       "discipline":2,"screen_time":1,"phone_morning":1,"focus":1,"water":1,"morning_routine":1,
                       "environment":1,"main_goal":"intelectual"}';
  v_etapa4  boolean := to_regclass('public.tool_logs') is not null;
  v_t0      timestamptz := clock_timestamp();

  v_uid uuid; v_tz text; v_today date; v_start date; d date; v_n int; v_quota int; v_done int; v_ts timestamptz;
  v_tpl text; v_day int; m record; b record; c record; v_bot uuid; v_bots uuid[] := '{}'; v_names text[];
  v_group uuid; v_ch uuid; v_req uuid; v_post bigint; v_book1 uuid; v_book2 uuid; v_s int; v_sp jsonb; v_lg record;
  v_rank int; v_of int; v_pts int; i int; k int; v_rate int; v_goal int;
begin
  -- Nada do que este script cria vira notificação no celular
  perform set_config('forja.sem_push', 'on', true);

  -- ── 1. A conta ────────────────────────────────────────────────────────────
  select id into v_uid from auth.users where lower(email) = lower(trim(v_email));
  if v_uid is null then
    raise exception 'Não achei a conta %. Crie em Authentication → Users → Add user e rode de novo.', v_email;
  end if;
  if not v_forcar
     and not coalesce((select (raw_app_meta_data->>'forja_teste')::boolean from auth.users where id = v_uid), false)
     and exists (select 1 from public.missions where user_id = v_uid and status = 'concluida') then
    raise exception 'A conta % já tem progresso de verdade e não foi apagada. Se for mesmo uma conta de teste, mude v_forcar para true.', v_email;
  end if;
  update auth.users set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || '{"forja_teste": true}'::jsonb
   where id = v_uid;

  -- Recomeça do zero (todo o progresso da conta sai junto com o perfil)
  delete from public.profiles where id = v_uid;
  insert into public.profiles (id, display_name) values (v_uid, 'Teste');
  insert into public.character_stats (user_id) values (v_uid);

  -- Avaliação inicial feita "como" a própria conta
  perform set_config('request.jwt.claim.sub', v_uid::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  perform public.submit_assessment(v_answers);

  select timezone into v_tz from public.profiles where id = v_uid;
  v_today := public._local_today(v_uid);
  v_start := v_today - (v_dias - 1);

  -- ── 2. Plano completo (todas as áreas) e viagem no tempo ──────────────────
  delete from public.missions where user_id = v_uid;
  delete from public.user_habits where user_id = v_uid;
  delete from public.progression_checks where user_id = v_uid;
  foreach v_tpl in array array['auto_agua:1','fis_caminhada:1','men_meditacao:1','int_leitura:1','pro_planejar:1',
                               'dig_redes:8','men_reflexao:8','fis_sono:22','pro_tarefa:22','int_estudo:34'] loop
    perform public._add_habit(v_uid, split_part(v_tpl, ':', 1), split_part(v_tpl, ':', 2)::int);
  end loop;
  -- Um hábito personalizado (Premium permite mais de 2)
  insert into public.user_habits (user_id, name, description, dimension, attr_primary, attr_secondary, difficulty,
                                  unit, base_value, step, max_value, est_minutes, current_target, start_day, is_custom)
  select v_uid, 'Praticar violão', 'Hábito criado pela pessoa.', 'mental', a.primary_attr, a.secondary_attr, 2,
         'min', 15, 0, 15, 15, 15, 40, true
    from public._attr_for_dimension('mental') a;

  update public.profiles set program_start = v_start, min_daily_missions = 3, plan = 'premium' where id = v_uid;
  update public.rules_history set started_on = v_start, min_daily = 3 where user_id = v_uid;
  update public.assessments set created_at = v_start::timestamp at time zone v_tz where user_id = v_uid;
  perform public._recalc_stats(v_uid);

  -- ── 3. Os dias passados ───────────────────────────────────────────────────
  for v_day in 1 .. v_dias - 1 loop
    d := v_start + v_day - 1;
    perform public._ensure_day(v_uid, d);
    perform public._daily_maintenance(v_uid, d, (d + time '07:00') at time zone v_tz);

    -- Modos: Desafio no dia 15, Extremo no 31, de volta ao Normal no 46
    if v_day = 15 then perform public._set_mode(v_uid, 'desafio', true, d); end if;
    if v_day = 31 then perform public._set_mode(v_uid, 'extremo', true, d); end if;
    if v_day = 46 then perform public._set_mode(v_uid, 'normal', false, d); end if;

    -- Chefes: enfrenta o próximo disponível; com todos vencidos, uma revanche da Hidra perto do fim
    if not exists (select 1 from public.user_bosses where user_id = v_uid and status = 'ativo') then
      for b in select bc.* from public.boss_catalog bc
                where not exists (select 1 from public.user_bosses ub where ub.user_id = v_uid and ub.boss_id = bc.id and ub.status = 'vencido')
                order by bc.sort loop
        if public._boss_lock(v_uid, (select x from public.boss_catalog x where x.id = b.id), v_day) is null then
          perform public._start_boss(v_uid, b.id, d, (d + time '07:05') at time zone v_tz);
          exit;
        end if;
      end loop;
      if v_day = v_dias - 6 and not exists (select 1 from public.user_bosses where user_id = v_uid and status = 'ativo') then
        perform public._start_boss(v_uid, 'hidra', d, (d + time '07:05') at time zone v_tz);
      end if;
    end if;

    -- Conclusões: quase tudo; no dia 5 só a meta e o dia 11 em branco (protegido por um escudo)
    v_quota := case v_day when 5 then 3 when 11 then 0 else 999 end;
    v_done := 0;
    for m in select ms.id, ms.kind, ms.period, h.template_id
               from public.missions ms left join public.user_habits h on h.id = ms.habit_id
              where ms.user_id = v_uid and d between ms.mission_date and ms.due_date and ms.status = 'pendente'
              order by ms.kind <> 'diaria', array_position(array['manha','tarde','noite','qualquer'], ms.period), ms.name loop
      -- Nos últimos dias a leitura fica de lado (o Mentor vai notar)
      continue when v_day >= v_dias - 5 and m.template_id = 'int_leitura';
      if m.kind = 'diaria' then
        continue when v_done >= v_quota;
        v_done := v_done + 1;
      elsif v_quota < 999 then
        continue;
      end if;
      v_ts := (d + case m.period when 'manha' then time '08:10' when 'tarde' then time '14:20'
                                  when 'noite' then time '21:00' else time '12:30' end) at time zone v_tz;
      perform public._complete_mission(v_uid, m.id, v_ts);
    end loop;
  end loop;

  -- Hoje: o dia aberto, com uma missão já feita e o resto para você
  perform public._ensure_day(v_uid, v_today);
  perform public._daily_maintenance(v_uid, v_today, now());
  select ms.id into v_ch from public.missions ms join public.user_habits h on h.id = ms.habit_id
   where ms.user_id = v_uid and ms.mission_date = v_today and ms.status = 'pendente' and h.template_id = 'pro_planejar' limit 1;
  if v_ch is not null then perform public._complete_mission(v_uid, v_ch, now()); end if;

  -- ── 4. Etapa 4: amigos de teste, grupo, desafios, temporadas, ferramentas e Mentor ──
  if v_etapa4 then
    -- Bots (não conseguem entrar no app: não têm senha)
    delete from auth.users where email like '%@bots.forja.invalid';
    v_names := array['Lia (bot)', 'Rafa (bot)', 'Nina (bot)', 'Téo (bot)'];
    for i in 1 .. 4 loop
      v_bot := gen_random_uuid();
      execute 'insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                 confirmation_token, recovery_token, email_change_token_new, email_change,
                 raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
               values (''00000000-0000-0000-0000-000000000000'', $1, ''authenticated'', ''authenticated'', $2, '''', now(),
                 '''', '''', '''', '''', ''{"provider":"email","providers":["email"],"forja_bot":true}'', $3, now(), now())'
        using v_bot, 'bot' || i || '@bots.forja.invalid', jsonb_build_object('name', v_names[i]);
      v_bots := v_bots || v_bot;

      perform set_config('request.jwt.claim.sub', v_bot::text, true);
      perform set_config('request.jwt.claims', jsonb_build_object('sub', v_bot, 'role', 'authenticated')::text, true);
      perform public.submit_assessment(v_answers || jsonb_build_object(
        'display_name', v_names[i], 'daily_minutes', 45,
        'main_goal', (array['fisica','produtividade','mental','intelectual'])[i]));
      k := case when i = 4 then 10 else 28 end;              -- Téo chegou há pouco
      delete from public.missions where user_id = v_bot;
      delete from public.progression_checks where user_id = v_bot;
      update public.profiles set program_start = v_today - (k - 1) where id = v_bot;
      update public.rules_history set started_on = v_today - (k - 1) where user_id = v_bot;
      for v_day in 1 .. k - 1 loop
        d := v_today - k + v_day;
        perform public._ensure_day(v_bot, d);
        perform public._daily_maintenance(v_bot, d, (d + time '07:00') at time zone v_tz);
        v_rate := case i when 1 then case when v_day in (5, 13) then 1 else 99 end                -- Lia: quase sempre tudo
                         when 2 then case when v_day in (4, 9, 15, 20) then 1 else 99 end         -- Rafa: tropeça de vez em quando
                         when 3 then case when v_day >= k - 3 then 99 when v_day % 5 = 0 then 0
                                          when v_day % 2 = 0 then 2 else 1 end                      -- Nina: oscila, voltando agora
                         else 2 end;
        v_done := 0;
        for m in select ms.id from public.missions ms
                  where ms.user_id = v_bot and ms.mission_date = d and ms.status = 'pendente' and ms.kind = 'diaria'
                  order by ms.name loop
          exit when v_done >= v_rate;
          perform public._complete_mission(v_bot, m.id, (d + time '13:00') at time zone v_tz);
          v_done := v_done + 1;
        end loop;
      end loop;
      perform public._ensure_day(v_bot, v_today);
      perform public._daily_maintenance(v_bot, v_today, now());
      update public.user_events set seen = true where user_id = v_bot;
    end loop;
    perform set_config('request.jwt.claim.sub', v_uid::text, true);
    perform set_config('request.jwt.claims', jsonb_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
    update public.profiles set privacy = '{"mostrar_nivel": false}' where id = v_bots[3];   -- Nina esconde o nível

    -- Amizades: Lia, Rafa e Nina aceitas; Téo mandou um pedido que espera resposta
    insert into public.friendships (requester, addressee, status, created_at, responded_at) values
      (v_uid, v_bots[1], 'aceita', now() - interval '25 days', now() - interval '25 days'),
      (v_bots[2], v_uid, 'aceita', now() - interval '20 days', now() - interval '20 days'),
      (v_uid, v_bots[3], 'aceita', now() - interval '12 days', now() - interval '12 days'),
      (v_bots[1], v_bots[2], 'aceita', now() - interval '20 days', now() - interval '20 days');
    insert into public.friendships (requester, addressee) values (v_bots[4], v_uid) returning id into v_req;
    insert into public.user_events (user_id, kind, ref) values (v_uid, 'pedido_amizade', v_req::text);

    -- Grupo
    insert into public.social_groups (name, description, owner, invite_code)
      values ('Forja dos Testes', 'Grupo de teste com os bots.', v_uid, public._new_group_code()) returning id into v_group;
    insert into public.group_members (group_id, user_id, role, joined_at) values
      (v_group, v_uid, 'dono', now() - interval '18 days'), (v_group, v_bots[1], 'membro', now() - interval '18 days'),
      (v_group, v_bots[2], 'membro', now() - interval '17 days'), (v_group, v_bots[3], 'membro', now() - interval '10 days');

    -- Desafios: um encerrado, dois em andamento e um convite esperando resposta
    insert into public.challenges (creator, kind, metric, title, starts_on, ends_on, created_at)
      values (v_uid, 'competitivo', 'meta_diaria', 'Semana firme', v_today - 13, v_today - 7, now() - interval '14 days')
      returning id into v_ch;
    insert into public.challenge_participants (challenge_id, user_id, status, responded_at)
      select v_ch, u, 'aceito', now() - interval '14 days' from unnest(array[v_uid, v_bots[1], v_bots[2]]) u;
    perform public._finalize_challenge(v_ch, now() - interval '6 days');

    insert into public.challenges (creator, kind, metric, title, starts_on, ends_on)
      values (v_bots[1], 'competitivo', 'missoes', 'Quem faz mais missões', v_today - 3, v_today + 3) returning id into v_ch;
    insert into public.challenge_participants (challenge_id, user_id, status, responded_at)
      select v_ch, u, 'aceito', now() - interval '3 days' from unnest(array[v_bots[1], v_uid, v_bots[2]]) u;

    insert into public.challenges (creator, group_id, kind, metric, title, target, starts_on, ends_on)
      values (v_uid, v_group, 'coletivo', 'meta_diaria', 'Meta coletiva do grupo', 38, v_today - 6, v_today + 7) returning id into v_ch;
    insert into public.challenge_participants (challenge_id, user_id, status, responded_at)
      select v_ch, u, 'aceito', now() - interval '6 days' from unnest(array[v_uid, v_bots[1], v_bots[2], v_bots[3]]) u;

    insert into public.challenges (creator, kind, metric, dimension, title, starts_on, ends_on)
      values (v_bots[3], 'competitivo', 'area', 'fisica', 'Duelo de movimento', v_today + 1, v_today + 7) returning id into v_ch;
    insert into public.challenge_participants (challenge_id, user_id, status, responded_at) values
      (v_ch, v_bots[3], 'aceito', now()), (v_ch, v_uid, 'convidado', null);
    insert into public.user_events (user_id, kind, ref) values (v_uid, 'desafio_convite', v_ch::text);

    -- Incentivos nas suas publicações e um "força" direto
    for c in select fp.id, row_number() over (order by fp.id desc) as rn
               from public.feed_posts fp where fp.author = v_uid order by fp.id desc limit 3 loop
      insert into public.cheers (post_id, sender, receiver, kind)
        values (c.id, v_bots[c.rn::int], v_uid, (array['parabens','brasa','forca'])[c.rn::int]) returning id into v_post;
      insert into public.user_events (user_id, kind, ref) values (v_uid, 'incentivo', v_post::text);
    end loop;
    insert into public.cheers (post_id, sender, receiver, kind) values (null, v_bots[1], v_uid, 'forca') returning id into v_post;
    insert into public.user_events (user_id, kind, ref) values (v_uid, 'incentivo', v_post::text);
    select id into v_post from public.feed_posts where author = v_bots[1] order by id desc limit 1;
    if v_post is not null then
      insert into public.cheers (post_id, sender, receiver, kind) values (v_post, v_uid, v_bots[1], 'parabens');
    end if;

    -- Ferramentas: 3 semanas de registros
    update public.profiles set tool_settings = '{"agua_meta": 8, "tela_limite": 120, "sono_meta": 480, "sono_deitar": "23:00"}'
     where id = v_uid;
    insert into public.books (user_id, title, author, total_pages, current_page, status, started_on, finished_on)
      values (v_uid, 'Dom Casmurro', 'Machado de Assis', 256, 256, 'concluido', v_today - 21, v_today - 11) returning id into v_book1;
    insert into public.books (user_id, title, author, total_pages, current_page, status, started_on)
      values (v_uid, 'O Hobbit', 'J. R. R. Tolkien', 310, 0, 'lendo', v_today - 10) returning id into v_book2;
    for v_day in 1 .. 21 loop
      d := v_today - 22 + v_day;
      insert into public.tool_logs (user_id, tool, day, data) values
        (v_uid, 'agua', d, jsonb_build_object('cups', case when v_day % 4 = 0 then 6 else 8 end)),
        (v_uid, 'sono', d, jsonb_build_object('bed', case when v_day % 3 = 0 then '00:30' else '23:10' end, 'wake', '07:00',
                                              'minutes', case when v_day % 3 = 0 then 390 else 470 end, 'quality', 3 + v_day % 3)),
        (v_uid, 'foco', d, jsonb_build_object('minutes', 25, 'label', 'Estudo')),
        (v_uid, 'meditacao', d, jsonb_build_object('minutes', case when v_day % 2 = 0 then 10 else 5 end, 'kind', 'meditacao')),
        (v_uid, 'tela', d, jsonb_build_object('minutes', 90 + (v_day % 5) * 15)),
        (v_uid, 'alimentacao', d, '{"meal": "cafe", "name": "Pão, ovos e café", "kcal": 380}'),
        (v_uid, 'alimentacao', d, '{"meal": "almoco", "name": "Arroz, feijão, frango e salada", "kcal": 720}'),
        (v_uid, 'alimentacao', d, '{"meal": "jantar", "name": "Sopa de legumes"}');
      if v_day % 2 = 0 then
        insert into public.tool_logs (user_id, tool, day, data) values (v_uid, 'foco', d, jsonb_build_object('minutes', 50, 'label', 'Projeto'));
      end if;
      if v_day <= 11 then
        insert into public.tool_logs (user_id, tool, day, data) values (v_uid, 'leitura', d,
          jsonb_build_object('pages', case when v_day = 11 then 16 else 24 end, 'minutes', 30, 'book_id', v_book1,
                             'book_title', 'Dom Casmurro', 'book_pages', case when v_day = 11 then 16 else 24 end));
      elsif v_day <= 14 then
        insert into public.tool_logs (user_id, tool, day, data) values (v_uid, 'leitura', d,
          jsonb_build_object('pages', 20, 'minutes', 25, 'book_id', v_book2, 'book_title', 'O Hobbit', 'book_pages', 20));
      end if;
      if v_day % 3 <> 0 then
        insert into public.tool_logs (user_id, tool, day, data) values (v_uid, 'diario', d, jsonb_build_object(
          'mood', case when v_day % 2 = 0 then 4 else 3 end + case when v_day % 7 = 0 then 1 else 0 end,
          'text', (array['Dia produtivo. Consegui manter o foco pela manhã.', 'Cansado, mas cumpri o principal.',
                         'Treino bom e uma conversa ótima no fim do dia.', 'Dia corrido; amanhã quero começar mais cedo.',
                         'Me senti mais calmo depois da meditação.'])[1 + v_day % 5],
          'gratitude', (array['Um café com calma', 'Ajuda de um amigo', 'Ter dormido bem'])[1 + v_day % 3]));
      end if;
    end loop;
    update public.books set current_page = 60 where id = v_book2;
    insert into public.tool_logs (user_id, tool, day, data) values (v_uid, 'agua', v_today, '{"cups": 3}');

    -- Temporadas passadas (só desta conta, com a posição entre os amigos)
    v_s := public._season_of(v_start);
    while v_s < public._season_of(v_today) loop
      v_sp := public._season_points(v_uid, v_s, v_today);
      v_pts := (v_sp->>'points')::int;
      select * into v_lg from public.league_catalog where min_points <= v_pts order by min_points desc limit 1;
      v_rank := 1; v_of := 1;
      for i in 1 .. 3 loop
        v_of := v_of + 1;
        if (public._season_points(v_bots[i], v_s, v_today)->>'points')::int > v_pts then v_rank := v_rank + 1; end if;
      end loop;
      insert into public.season_results (user_id, season, points, league, xp, data)
        values (v_uid, v_s, v_pts, v_lg.id, v_lg.xp_reward, v_sp || jsonb_build_object('rank', v_rank, 'of', v_of))
        on conflict do nothing;
      if v_lg.xp_reward > 0 then
        insert into public.xp_ledger (user_id, source, ref, day, amount, disciplina, determinacao)
          values (v_uid, 'temporada', v_s::text, public._season_end(v_s) + 1, v_lg.xp_reward, v_lg.xp_reward / 2, v_lg.xp_reward - v_lg.xp_reward / 2)
          on conflict do nothing;
      end if;
      insert into public.user_events (user_id, kind, ref) values (v_uid, 'temporada', v_s::text) on conflict do nothing;
      v_s := public._season_next(v_s);
    end loop;

    -- Mentor ligado, relatórios refeitos com os registros das ferramentas e sugestões do dia
    for c in select generate_series(date_trunc('week', v_start::timestamp)::date, (date_trunc('week', v_today::timestamp))::date - 7, interval '7 days')::date as w loop
      if c.w + 6 >= v_start then
        insert into public.mentor_reports (user_id, week_start, data) values (v_uid, c.w, public._weekly_report(v_uid, c.w, c.w + 6))
          on conflict (user_id, week_start) do update set data = excluded.data;
      end if;
    end loop;
    update public.profiles set mentor_enabled = true, mentor_checked_on = null where id = v_uid;
    perform public._mentor_refresh(v_uid, v_today);
  end if;

  -- ── 5. Tudo no máximo: todas as conquistas (com o XP de cada uma), itens e títulos ──
  for c in select ac.* from public.achievement_catalog ac
            where not exists (select 1 from public.user_achievements ua where ua.user_id = v_uid and ua.achievement_id = ac.id)
            order by ac.sort loop
    insert into public.user_achievements (user_id, achievement_id) values (v_uid, c.id);
    if c.xp > 0 then
      insert into public.xp_ledger (user_id, source, ref, day, amount, disciplina, foco, vitalidade, conhecimento, determinacao)
      values (v_uid, 'conquista', c.id, v_today, c.xp,
              case when c.attr = 'disciplina' then c.xp else 0 end, case when c.attr = 'foco' then c.xp else 0 end,
              case when c.attr = 'vitalidade' then c.xp else 0 end, case when c.attr = 'conhecimento' then c.xp else 0 end,
              case when c.attr = 'determinacao' then c.xp else 0 end)
      on conflict do nothing;
    end if;
  end loop;
  perform public._progress_rewards(v_uid, v_today);
  insert into public.user_items (user_id, item_id, source) select v_uid, id, 'teste' from public.item_catalog on conflict do nothing;
  update public.profiles set
    avatar = jsonb_set(coalesce(avatar, '{}'::jsonb), '{equip}',
               (select jsonb_object_agg(x.slot, x.id) from (
                  select distinct on (ic.slot) ic.slot, ic.id from public.item_catalog ic
                   where ic.kind = 'equipamento'
                   order by ic.slot, array_position(array['comum','raro','epico','lendario'], ic.rarity) desc, ic.sort desc) x)),
    active_title = 'tit_66'
  where id = v_uid;

  -- Datas coerentes com o histórico simulado (tudo foi criado agora, mas aconteceu nos dias simulados)
  foreach v_bot in array array[v_uid] || v_bots loop
    update public.user_achievements ua set unlocked_at = (l.day + time '20:30') at time zone v_tz
      from public.xp_ledger l
     where ua.user_id = v_bot and l.user_id = v_bot and l.source = 'conquista' and l.ref = ua.achievement_id and l.day < v_today;
    -- Conquistas de nível não dão XP: a data é o dia em que o XP acumulado chegou ao nível
    update public.user_achievements ua set unlocked_at = (x.day + time '21:00') at time zone v_tz
      from (select ac.id, (select min(dd.day) from (select day, sum(sum(amount)) over (order by day) as cum
                                                       from public.xp_ledger where user_id = v_bot group by day) dd
                            where dd.cum >= public.xp_for_level(ac.threshold)) as day
              from public.achievement_catalog ac where ac.metric = 'nivel') x
     where ua.user_id = v_bot and ua.achievement_id = x.id and x.day is not null and x.day < v_today;
    if v_etapa4 then
      update public.feed_posts fp set created_at = ua.unlocked_at
        from public.user_achievements ua
       where fp.author = v_bot and fp.kind = 'conquista' and ua.user_id = v_bot and ua.achievement_id = fp.ref;
      update public.feed_posts fp set created_at = f.finished_at
        from public.user_bosses f
       where fp.author = v_bot and fp.kind = 'chefe' and f.id::text = fp.ref and f.finished_at is not null;
      update public.feed_posts fp set created_at = (x.day + time '21:00') at time zone v_tz
        from (select fp2.id, (select min(dd.day) from (select day, sum(sum(amount)) over (order by day) as cum
                                                           from public.xp_ledger where user_id = v_bot group by day) dd
                                where dd.cum >= public.xp_for_level(fp2.ref::int)) as day
                from public.feed_posts fp2 where fp2.author = v_bot and fp2.kind = 'nivel') x
       where fp.id = x.id and x.day is not null;
      update public.feed_posts fp set created_at = (public._season_end(fp.ref::int) + 1 + time '09:00') at time zone v_tz
       where fp.author = v_bot and fp.kind = 'temporada';
    end if;
  end loop;

  -- Avisos antigos já vistos (ficam só os sociais novos: pedido, convite e incentivos)
  update public.user_events set seen = true
   where user_id = v_uid and kind not in ('pedido_amizade','desafio_convite','incentivo');

  raise notice 'Conta de teste pronta em % s: dia % do programa, nível %, % XP, % conquistas, % itens%.',
    round(extract(epoch from clock_timestamp() - v_t0)::numeric, 1),
    v_dias, (select level from public.character_stats where user_id = v_uid),
    (select total_xp from public.character_stats where user_id = v_uid),
    (select count(*) from public.user_achievements where user_id = v_uid),
    (select count(*) from public.user_items where user_id = v_uid),
    case when v_etapa4 then ', 4 bots, grupo, desafios, temporadas, ferramentas e Mentor' else '' end;
end $$;

-- Resumo das contas de teste
select u.email as conta, s.level as nivel, s.total_xp as xp,
       (select count(*) from public.user_achievements a where a.user_id = u.id) as conquistas,
       (select count(*) from public.user_items i where i.user_id = u.id) as itens,
       (select count(*) from public.missions m where m.user_id = u.id and m.status = 'concluida') as missoes_feitas,
       p.plan as plano
  from auth.users u join public.profiles p on p.id = u.id join public.character_stats s on s.user_id = u.id
 where (u.raw_app_meta_data->>'forja_teste')::boolean;

-- ── Para apagar depois (tire os dois traços do começo da linha e rode) ──
-- delete from auth.users where email like '%@bots.forja.invalid';     -- remove os bots
-- delete from auth.users where email = 'seunome+teste@gmail.com';      -- remove a conta de teste
