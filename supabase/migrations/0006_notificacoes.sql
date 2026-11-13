-- Forja · 0006 · Notificações no celular (Web Push)
-- Pode rodar de novo sem estragar nada.
--
-- Como funciona
--   1. O app pede permissão no aparelho e guarda a inscrição dele (push_subscriptions).
--   2. O banco decide o que enviar e põe na fila (push_queue): os lembretes da meta, conferidos a cada
--      minuto pelo pg_cron, e os avisos sociais (pedidos, convites, incentivos) na hora em que acontecem.
--   3. Para enviar, o banco cria um lote com um código de uso único e chama a função /api/push do app
--      pelo pg_net. O pedido só sai depois que a transação termina.
--   4. A função pega o lote com esse código (push_claim), envia pelo Web Push e devolve o resultado
--      (push_report). Inscrições canceladas pelo aparelho saem sozinhas.
--   As chaves VAPID são geradas pela própria função na primeira vez e ficam só aqui no banco
--   (push_config, sem acesso pelo app). Ninguém precisa copiar chave nenhuma.
--
-- Depois de rodar, o administrador informa uma vez o endereço do app:
--   select admin_set_push_url('https://seu-app.vercel.app');

-- ════════════════════════════════════════════════════════════════════════════
-- 0. Extensões do Supabase (agendador e pedidos HTTP)
-- ════════════════════════════════════════════════════════════════════════════

do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_net') then
    create extension if not exists pg_net with schema extensions;
  end if;
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron with schema pg_catalog;
    grant usage on schema cron to postgres;
    grant all privileges on all tables in schema cron to postgres;
  end if;
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 1. Tabelas
-- ════════════════════════════════════════════════════════════════════════════

-- Configuração do envio (uma linha só; nunca lida pelo app)
create table if not exists public.push_config (
  id          boolean primary key default true check (id),
  app_url     text,               -- endereço do app (https://…), definido pelo administrador
  public_key  text,               -- chave VAPID pública (vai para o app)
  private_key text,               -- chave VAPID privada (nunca sai do servidor)
  keys_at     timestamptz,
  updated_at  timestamptz not null default now()
);
insert into public.push_config (id) values (true) on conflict do nothing;

-- Aparelhos inscritos (um por navegador/app instalado)
create table if not exists public.push_subscriptions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  endpoint    text not null unique check (char_length(endpoint) <= 1000),
  p256dh      text not null,
  auth        text not null,
  device      text not null default '' check (char_length(device) <= 40),
  created_at  timestamptz not null default now(),
  seen_at     timestamptz not null default now(),   -- última vez que o app confirmou a inscrição
  last_ok_at  timestamptz,                          -- última entrega aceita
  last_status int,
  last_error  text,
  failures    int not null default 0                -- falhas seguidas
);
create index if not exists push_subscriptions_user_idx on public.push_subscriptions (user_id);

-- Lotes de envio: cada um tem um código de uso único que só o banco e a função conhecem
create table if not exists public.push_batches (
  id          uuid primary key default gen_random_uuid(),
  token       text not null unique,
  need_keys   boolean not null default false,
  created_at  timestamptz not null default now(),
  claimed_at  timestamptz,
  reported_at timestamptz,
  sent        int,
  failed      int,
  abandoned   boolean not null default false
);
create index if not exists push_batches_open_idx on public.push_batches (created_at) where reported_at is null;

-- Fila: o que mandar para cada pessoa (vai para todos os aparelhos dela)
create table if not exists public.push_queue (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  kind        text not null check (kind in ('lembrete','risco','social','teste')),
  payload     jsonb not null,     -- { title, body, url, tag }
  ttl         int not null default 3600 check (ttl between 60 and 86400),
  urgency     text not null default 'normal' check (urgency in ('low','normal','high')),
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null,
  batch_id    uuid references public.push_batches(id) on delete set null,
  attempts    int not null default 0,
  sent_at     timestamptz,
  done        boolean not null default false   -- entregue, vencido ou desistido
);
create index if not exists push_queue_pending_idx on public.push_queue (id) where not done;
create index if not exists push_queue_batch_idx on public.push_queue (batch_id) where batch_id is not null;
create index if not exists push_queue_user_idx on public.push_queue (user_id, created_at desc);

-- Lembretes já conferidos em cada dia (um de cada tipo por dia, enviado ou não)
create table if not exists public.push_log (
  user_id uuid not null references public.profiles(id) on delete cascade,
  kind    text not null check (kind in ('lembrete','risco')),
  day     date not null,
  sent    boolean not null default true,   -- false: conferido, mas a meta já estava cumprida
  primary key (user_id, kind, day)
);

-- Preferências de cada pessoa
alter table public.profiles add column if not exists notify jsonb not null
  default '{"lembrete": true, "lembrete_hora": "09:00", "risco": true, "risco_hora": "20:00", "social": true}';

alter table public.push_config        enable row level security;
alter table public.push_subscriptions enable row level security;
alter table public.push_batches       enable row level security;
alter table public.push_queue         enable row level security;
alter table public.push_log           enable row level security;
-- Sem políticas: o app não lê essas tabelas; tudo passa pelas funções abaixo.

-- ════════════════════════════════════════════════════════════════════════════
-- 2. Peças internas
-- ════════════════════════════════════════════════════════════════════════════

-- "1 missão", "3 missões"
create or replace function public._missoes(n int)
returns text language sql immutable as $$
  select n || case when n = 1 then ' missão' else ' missões' end
$$;

-- Preferências com os valores padrão preenchidos
create or replace function public._notify_settings(p jsonb)
returns jsonb language sql immutable as $$
  select jsonb_build_object(
    'lembrete',      coalesce((p->>'lembrete')::boolean, true),
    'lembrete_hora', coalesce(p->>'lembrete_hora', '09:00'),
    'risco',         coalesce((p->>'risco')::boolean, true),
    'risco_hora',    coalesce(p->>'risco_hora', '20:00'),
    'social',        coalesce((p->>'social')::boolean, true))
$$;

-- Põe uma notificação na fila (só para quem tem aparelho inscrito)
create or replace function public._push_enqueue(p_uid uuid, p_kind text, p_payload jsonb, p_ttl int, p_urgency text default 'normal')
returns bigint language plpgsql security definer set search_path = public as $$
declare v_id bigint;
begin
  if not exists (select 1 from push_subscriptions where user_id = p_uid) then return null; end if;
  insert into push_queue (user_id, kind, payload, ttl, urgency, expires_at)
  values (p_uid, p_kind, p_payload, p_ttl, p_urgency, now() + make_interval(secs => p_ttl))
  returning id into v_id;
  return v_id;
end $$;

-- Cria um lote com o que está pendente e chama a função de envio do app.
-- p_need_keys: o lote serve também para a função gerar as chaves VAPID.
create or replace function public._push_kick(p_need_keys boolean default false)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_cfg   push_config;
  v_batch uuid;
  v_token text;
  v_n     int;
begin
  select * into v_cfg from push_config where id;
  if v_cfg.app_url is null
     or not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                     where n.nspname = 'net' and p.proname = 'http_post') then
    return null;
  end if;
  -- Sem chaves não há como enviar: só um lote pedido de propósito (para gerá-las) segue em frente
  if v_cfg.public_key is null and not p_need_keys then return null; end if;
  if not p_need_keys
     and not exists (select 1 from push_queue where not done and batch_id is null and expires_at > now()) then
    return null;
  end if;

  v_token := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
  insert into push_batches (token, need_keys) values (v_token, p_need_keys) returning id into v_batch;
  update push_queue set batch_id = v_batch
   where id in (select id from push_queue
                 where not done and batch_id is null and expires_at > now()
                 order by id limit 200 for update skip locked);
  get diagnostics v_n = row_count;
  if v_n = 0 and not p_need_keys then
    delete from push_batches where id = v_batch;
    return null;
  end if;

  -- O pedido só sai depois do commit: a função encontra o lote já gravado
  perform net.http_post(
    url := v_cfg.app_url || '/api/push',
    body := jsonb_build_object('token', v_token),
    timeout_milliseconds := 20000);
  return v_batch;
end $$;

-- Ao fim de cada transação que pôs algo na fila, um lote sai (um só, mesmo com várias linhas)
create or replace function public._push_queue_kick()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform _push_kick();
  return null;
end $$;
drop trigger if exists push_queue_kick on public.push_queue;
create constraint trigger push_queue_kick after insert on public.push_queue
  deferrable initially deferred for each row execute function public._push_queue_kick();

-- Texto de um aviso social
create or replace function public._push_social_payload(e user_events)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_name text;
  v jsonb;
  f friendships;
  c record;
  v_other uuid;
begin
  case e.kind
    when 'pedido_amizade' then
      select * into f from friendships where id::text = e.ref;
      if f.id is null or f.status <> 'pendente' then return null; end if;
      select nullif(display_name, '') into v_name from profiles where id = f.requester;
      v := jsonb_build_object('title', 'Pedido de amizade',
                              'body', format('%s te mandou um pedido de amizade.', coalesce(v_name, 'Alguém')),
                              'url', '/social/avisos', 'tag', 'pedido-' || f.id);
    when 'amizade_aceita' then
      select * into f from friendships where id::text = e.ref and status = 'aceita';
      if f.id is null then return null; end if;
      v_other := case when f.requester = e.user_id then f.addressee else f.requester end;
      select nullif(display_name, '') into v_name from profiles where id = v_other;
      v := jsonb_build_object('title', 'Nova amizade',
                              'body', format('%s aceitou seu pedido de amizade.', coalesce(v_name, 'Alguém')),
                              'url', '/social/amigos/' || v_other, 'tag', 'amizade-' || f.id);
    when 'incentivo' then
      select ch.kind, ch.post_id, nullif(p.display_name, '') as name into c
        from cheers ch join profiles p on p.id = ch.sender where ch.id::text = e.ref;
      if c.kind is null then return null; end if;
      v := jsonb_build_object(
        'title', case when c.post_id is null then 'Incentivo' else 'Reação' end,
        'body', case when c.post_id is null
                  then format('%s te mandou %s.', coalesce(c.name, 'Alguém'),
                         case c.kind when 'parabens' then '👏 Parabéns' when 'forca' then '💪 Força'
                                     when 'brasa' then '🔥 Mandou bem' when 'foco' then '🎯 Foco'
                                     when 'volta' then '🤝 Bora voltar' else 'um incentivo' end)
                  else format('%s reagiu com %s à sua publicação.', coalesce(c.name, 'Alguém'),
                         case c.kind when 'parabens' then '👏' when 'forca' then '💪' when 'brasa' then '🔥'
                                     when 'foco' then '🎯' else '🤝' end) end,
        'url', '/social/avisos', 'tag', 'incentivo');
    when 'desafio_convite' then
      select ch.id, ch.title, nullif(p.display_name, '') as name into c
        from challenges ch join profiles p on p.id = ch.creator where ch.id::text = e.ref;
      if c.id is null then return null; end if;
      v := jsonb_build_object('title', 'Convite para desafio',
                              'body', format('%s te convidou para o desafio “%s”.', coalesce(c.name, 'Alguém'), c.title),
                              'url', '/social/desafios/' || c.id, 'tag', 'desafio-' || c.id);
    when 'grupo_entrada' then
      select g.id, g.name, nullif(p.display_name, '') as who into c
        from social_groups g join profiles p on p.id::text = split_part(e.ref, ':', 2)
       where g.id::text = split_part(e.ref, ':', 1);
      if c.id is null then return null; end if;
      v := jsonb_build_object('title', 'Novo membro no grupo',
                              'body', format('%s entrou no grupo %s.', coalesce(c.who, 'Alguém'), c.name),
                              'url', '/social/grupos/' || c.id, 'tag', 'grupo-' || c.id);
    else
      return null;
  end case;
  return v || jsonb_build_object('kind', e.kind);
end $$;

-- Avisos sociais viram notificação na hora
create or replace function public._push_on_event()
returns trigger language plpgsql security definer set search_path = public as $$
declare v jsonb;
begin
  if new.seen or new.kind not in ('pedido_amizade','amizade_aceita','incentivo','desafio_convite','grupo_entrada') then
    return null;
  end if;
  -- Scripts administrativos (como a conta de teste) desligam o envio com esta marca
  if coalesce(current_setting('forja.sem_push', true), '') = 'on' then return null; end if;
  if not exists (select 1 from push_subscriptions where user_id = new.user_id) then return null; end if;
  if not (_notify_settings((select notify from profiles where id = new.user_id))->>'social')::boolean then return null; end if;
  -- Várias reações seguidas viram uma notificação só (as outras aparecem no app)
  if new.kind = 'incentivo' and exists (
       select 1 from push_queue where user_id = new.user_id and kind = 'social'
          and payload->>'kind' = 'incentivo' and created_at > now() - interval '10 minutes') then
    return null;
  end if;
  v := _push_social_payload(new);
  if v is not null then perform _push_enqueue(new.user_id, 'social', v, 86400, 'normal'); end if;
  return null;
end $$;
drop trigger if exists user_events_push on public.user_events;
create trigger user_events_push after insert on public.user_events
  for each row execute function public._push_on_event();

-- Lembretes do horário de cada pessoa. Devolve quantos foram para a fila.
--   lembrete: no horário escolhido, se a meta do dia ainda não foi cumprida.
--             Na fase Domínio (dias 46 a 60) só aparece se a meta do dia anterior também falhou.
--   risco:    à noite, se ainda faltar missão para a meta.
create or replace function public._push_reminders(p_now timestamptz)
returns int language plpgsql security definer set search_path = public as $$
declare
  r        record;
  s        record;
  v_set    jsonb;
  v_local  timestamp;
  v_day    date;
  v_time   time;
  v_at     time;
  v_streak int;
  v_goal   text;
  v_left   int;
  v_known  boolean;
  v_greet  text;
  v_body   text;
  v_title  text;
  v_ttl    int;
  v_n      int := 0;
begin
  for r in
    select p.id, p.timezone, p.notify, p.program_start
      from profiles p
     where p.onboarding_done and p.program_start is not null
       and exists (select 1 from push_subscriptions ps where ps.user_id = p.id)
  loop
    v_set := _notify_settings(r.notify);
    v_local := p_now at time zone r.timezone;
    v_day := v_local::date;
    v_time := v_local::time;
    continue when r.program_start > v_day;

    -- Lembrete da meta (a linha em push_log garante um por dia, mesmo com duas rodadas ao mesmo tempo)
    v_at := (v_set->>'lembrete_hora')::time;
    if (v_set->>'lembrete')::boolean and v_time >= v_at and v_time - v_at < interval '90 minutes'
       and not exists (select 1 from push_log where user_id = r.id and kind = 'lembrete' and day = v_day) then
      insert into push_log (user_id, kind, day, sent) values (r.id, 'lembrete', v_day, false) on conflict do nothing;
      continue when not found;
      select * into s from _day_stats(r.id, v_day, v_day);
      if s.goal_met
         or (v_day - r.program_start + 1 between 46 and 60
             and coalesce((select d.goal_met from _day_stats(r.id, v_day - 1, v_day - 1) d), false)) then
        null;   -- conferido; não precisa avisar
      else
        v_streak := coalesce((_journey(r.id, v_day)->>'current_streak')::int, 0);
        v_greet := case when extract(hour from v_time) < 12 then 'Bom dia!'
                        when extract(hour from v_time) < 18 then 'Boa tarde!' else 'Boa noite!' end;
        v_goal := case when s.daily_total = 0 and s.mode = 'desafio' then '60% das missões diárias'
                       when s.daily_total = 0 and s.mode = 'extremo' then 'todas as missões diárias'
                       else _missoes(s.goal) end;
        v_body := case
          when s.done > 0 and s.daily_total > 0 then format('%s Você já fez %s de %s da meta de hoje.', v_greet, s.done, _missoes(s.goal))
          when v_streak >= 2 then format('%s Sua sequência está em %s dias. Meta de hoje: %s.', v_greet, v_streak, v_goal)
          else format('%s Meta de hoje: %s.', v_greet, v_goal) end;
        perform _push_enqueue(r.id, 'lembrete',
          jsonb_build_object('title', 'Missões de hoje', 'body', v_body, 'url', '/', 'tag', 'lembrete', 'kind', 'lembrete'),
          7200, 'normal');
        update push_log set sent = true where user_id = r.id and kind = 'lembrete' and day = v_day;
        v_n := v_n + 1;
      end if;
    end if;

    -- Sequência em risco
    v_at := (v_set->>'risco_hora')::time;
    if (v_set->>'risco')::boolean and v_time >= v_at and v_time - v_at < interval '90 minutes'
       and not exists (select 1 from push_log where user_id = r.id and kind = 'risco' and day = v_day) then
      insert into push_log (user_id, kind, day, sent) values (r.id, 'risco', v_day, false) on conflict do nothing;
      continue when not found;
      select * into s from _day_stats(r.id, v_day, v_day);
      if s.goal_met then
        null;
      else
        v_streak := coalesce((_journey(r.id, v_day)->>'current_streak')::int, 0);
        -- Nos modos Desafio e Extremo, a meta depende das missões do dia (que só existem depois de abrir o app)
        v_known := s.daily_total > 0 or s.mode = 'normal';
        v_left := greatest(1, case when s.mode = 'extremo' then greatest(s.daily_total - s.daily_done, s.min_daily - s.done)
                                   else s.goal - s.done end);
        v_title := case when v_streak >= 2 then 'Sequência em risco' else 'Meta de hoje' end;
        v_body := case
          when v_known and v_streak >= 2 then format('Faltam %s para a meta de hoje e sua sequência de %s dias continua.', _missoes(v_left), v_streak)
          when v_known then format('Ainda dá tempo: faltam %s para a meta de hoje.', _missoes(v_left))
          when v_streak >= 2 then format('Ainda dá tempo de cumprir a meta de hoje e manter a sequência de %s dias.', v_streak)
          else 'Ainda dá tempo de cumprir a meta de hoje.' end;
        -- Vale até a meia-noite de lá (um aviso de "hoje" não serve amanhã)
        v_ttl := least(21600, greatest(900, extract(epoch from (v_day + 1)::timestamp - v_local)::int));
        perform _push_enqueue(r.id, 'risco',
          jsonb_build_object('title', v_title, 'body', v_body, 'url', '/missoes', 'tag', 'risco', 'kind', 'risco'),
          v_ttl, 'high');
        update push_log set sent = true where user_id = r.id and kind = 'risco' and day = v_day;
        v_n := v_n + 1;
      end if;
    end if;
  end loop;
  return v_n;
end $$;

-- Roda a cada minuto (pg_cron)
create or replace function public._push_tick()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_b   record;
  v_n   int;
  v_cfg push_config;
begin
  -- Lotes sem resposta há 3 minutos (função fora do ar, rede…): os itens voltam para a fila
  for v_b in select id from push_batches
              where reported_at is null and created_at < now() - interval '3 minutes'
              for update skip locked loop
    update push_queue set batch_id = null, attempts = attempts + 1, done = attempts + 1 >= 3 or expires_at <= now()
     where batch_id = v_b.id and not done;
    update push_batches set reported_at = now(), abandoned = true where id = v_b.id;
  end loop;
  update push_queue set done = true where not done and batch_id is null and expires_at <= now();

  v_n := _push_reminders(now());

  -- Chaves ainda não geradas: pede à função (no máximo a cada 10 minutos)
  select * into v_cfg from push_config where id;
  if v_cfg.public_key is null and v_cfg.app_url is not null
     and not exists (select 1 from push_batches where need_keys and created_at > now() - interval '10 minutes') then
    perform _push_kick(true);
  end if;
  -- Itens que voltaram para a fila
  perform _push_kick();

  -- Limpeza, uma vez por hora
  if extract(minute from now())::int = 7 then
    delete from push_queue where done and created_at < now() - interval '14 days';
    delete from push_batches where created_at < now() - interval '3 days';
    delete from push_log where day < current_date - 40;
  end if;
  return jsonb_build_object('lembretes', v_n);
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 3. Funções do app
-- ════════════════════════════════════════════════════════════════════════════

create or replace function public.get_notify()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_cfg push_config;
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  select * into v_cfg from push_config where id;
  -- Primeira vez: pede as chaves à função (a tela confere de novo em seguida)
  if v_cfg.public_key is null and v_cfg.app_url is not null
     and not exists (select 1 from push_batches where need_keys and created_at > now() - interval '1 minute') then
    perform _push_kick(true);
  end if;
  return jsonb_build_object(
    'configured', v_cfg.app_url is not null,
    'ready', v_cfg.public_key is not null,
    'public_key', v_cfg.public_key,
    'settings', _notify_settings((select notify from profiles where id = v_uid)),
    'devices', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', s.id, 'endpoint', s.endpoint, 'device', s.device, 'created_at', s.created_at,
               'last_ok_at', s.last_ok_at, 'last_status', s.last_status, 'last_error', s.last_error)
             order by s.created_at)
        from push_subscriptions s where s.user_id = v_uid), '[]'::jsonb));
end $$;

create or replace function public.set_notify(p_settings jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_cur jsonb;
  k text;
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  if jsonb_typeof(p_settings) <> 'object' then raise exception 'configuracao_invalida'; end if;
  for k in select jsonb_object_keys(p_settings) loop
    if k in ('lembrete', 'risco', 'social') then
      if jsonb_typeof(p_settings->k) <> 'boolean' then raise exception 'configuracao_invalida'; end if;
    elsif k in ('lembrete_hora', 'risco_hora') then
      if jsonb_typeof(p_settings->k) <> 'string' or (p_settings->>k) !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then
        raise exception 'horario_invalido';
      end if;
      if (p_settings->>k)::time not between '05:00' and '23:30' then raise exception 'horario_invalido'; end if;
    else
      raise exception 'configuracao_invalida';
    end if;
  end loop;
  select notify into v_cur from profiles where id = v_uid for update;
  v_cur := _notify_settings(coalesce(v_cur, '{}'::jsonb) || p_settings);
  update profiles set notify = v_cur where id = v_uid;
  return v_cur;
end $$;

create or replace function public.save_push_subscription(p_endpoint text, p_p256dh text, p_auth text, p_device text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  if p_endpoint is null or char_length(p_endpoint) > 1000
     or p_endpoint !~ '^(https://|http://(localhost|127\.0\.0\.1)(:[0-9]+)?/)'
     or coalesce(p_p256dh, '') !~ '^[A-Za-z0-9_-]{80,100}=*$'
     or coalesce(p_auth, '') !~ '^[A-Za-z0-9_-]{16,32}=*$' then
    raise exception 'inscricao_invalida';
  end if;
  insert into push_subscriptions (user_id, endpoint, p256dh, auth, device, seen_at)
  values (v_uid, p_endpoint, p_p256dh, p_auth, left(coalesce(p_device, ''), 40), clock_timestamp())
  on conflict (endpoint) do update
    set user_id = excluded.user_id, p256dh = excluded.p256dh, auth = excluded.auth, device = excluded.device,
        seen_at = clock_timestamp(),
        -- O mesmo aparelho com outra conta começa do zero
        failures    = case when push_subscriptions.user_id = excluded.user_id then push_subscriptions.failures else 0 end,
        last_ok_at  = case when push_subscriptions.user_id = excluded.user_id then push_subscriptions.last_ok_at end,
        last_status = case when push_subscriptions.user_id = excluded.user_id then push_subscriptions.last_status end,
        last_error  = case when push_subscriptions.user_id = excluded.user_id then push_subscriptions.last_error end;
  -- No máximo 10 aparelhos: os mais antigos saem
  delete from push_subscriptions where id in (
    select id from push_subscriptions where user_id = v_uid order by seen_at desc, created_at desc offset 10);
  return jsonb_build_object('devices', (select count(*) from push_subscriptions where user_id = v_uid));
end $$;

create or replace function public.remove_push_subscription(p_endpoint text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  delete from push_subscriptions where endpoint = p_endpoint and user_id = v_uid;
  return jsonb_build_object('devices', (select count(*) from push_subscriptions where user_id = v_uid));
end $$;

create or replace function public.push_test()
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'nao_autenticado'; end if;
  if not exists (select 1 from push_subscriptions where user_id = v_uid) then raise exception 'push_sem_aparelho'; end if;
  if exists (select 1 from push_queue where user_id = v_uid and kind = 'teste' and created_at > now() - interval '20 seconds') then
    raise exception 'push_espere';
  end if;
  perform _push_enqueue(v_uid, 'teste',
    jsonb_build_object('title', 'Forja', 'body', 'Notificações ligadas! É assim que os lembretes vão aparecer.',
                       'url', '/perfil/notificacoes', 'tag', 'teste', 'kind', 'teste'),
    600, 'high');
  return jsonb_build_object('devices', (select count(*) from push_subscriptions where user_id = v_uid));
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 4. Funções da função de envio (chamadas com a chave pública, protegidas pelo código do lote)
-- ════════════════════════════════════════════════════════════════════════════

create or replace function public.push_claim(p_token text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_b   push_batches;
  v_cfg push_config;
begin
  if p_token is null or p_token !~ '^[0-9a-f]{64}$' then raise exception 'lote_invalido'; end if;
  update push_batches set claimed_at = now()
   where token = p_token and claimed_at is null and created_at > now() - interval '3 minutes'
   returning * into v_b;
  if v_b.id is null then raise exception 'lote_invalido'; end if;
  select * into v_cfg from push_config where id;
  return jsonb_build_object(
    'subject', v_cfg.app_url,
    'vapid', case when v_cfg.public_key is not null
                  then jsonb_build_object('public_key', v_cfg.public_key, 'private_key', v_cfg.private_key) end,
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
               'queue', q.id, 'subscription', s.id, 'endpoint', s.endpoint, 'p256dh', s.p256dh, 'auth', s.auth,
               'payload', q.payload, 'ttl', greatest(60, least(q.ttl, extract(epoch from q.expires_at - now())::int)),
               'urgency', q.urgency)
             order by q.id, s.created_at)
        from push_queue q join push_subscriptions s on s.user_id = q.user_id
       where q.batch_id = v_b.id and not q.done), '[]'::jsonb));
end $$;

create or replace function public.push_set_keys(p_token text, p_public text, p_private text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_cfg push_config;
begin
  if p_token is null or p_token !~ '^[0-9a-f]{64}$'
     or not exists (select 1 from push_batches where token = p_token and claimed_at is not null
                       and reported_at is null and claimed_at > now() - interval '5 minutes') then
    raise exception 'lote_invalido';
  end if;
  if coalesce(p_public, '') !~ '^[A-Za-z0-9_-]{87}$' or coalesce(p_private, '') !~ '^[A-Za-z0-9_-]{43}$' then
    raise exception 'chaves_invalidas';
  end if;
  -- Quem chegar primeiro fica; as chaves nunca são trocadas depois
  update push_config set public_key = p_public, private_key = p_private, keys_at = now(), updated_at = now()
   where id and public_key is null;
  select * into v_cfg from push_config where id;
  return jsonb_build_object('public_key', v_cfg.public_key, 'private_key', v_cfg.private_key);
end $$;

create or replace function public.push_report(p_token text, p_results jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_b      push_batches;
  r        jsonb;
  v_q      push_queue;
  v_status int;
  v_ok     int := 0;
  v_fail   int := 0;
  v_gone   int := 0;
begin
  if p_token is null or p_token !~ '^[0-9a-f]{64}$' then raise exception 'lote_invalido'; end if;
  select * into v_b from push_batches
   where token = p_token and claimed_at is not null and reported_at is null and claimed_at > now() - interval '10 minutes'
   for update;
  if v_b.id is null then raise exception 'lote_invalido'; end if;
  if jsonb_typeof(p_results) <> 'array' or jsonb_array_length(p_results) > 2000 then raise exception 'resultado_invalido'; end if;

  for r in select x from jsonb_array_elements(p_results) x loop
    -- Só vale para itens deste lote e aparelhos de quem ia receber
    continue when coalesce(r->>'queue', '') !~ '^[0-9]+$'
               or coalesce(r->>'subscription', '') !~ '^[0-9a-f-]{36}$';
    select q.* into v_q from push_queue q where q.id = (r->>'queue')::bigint and q.batch_id = v_b.id;
    continue when v_q.id is null;
    v_status := case when coalesce(r->>'status', '') ~ '^[0-9]{1,3}$' then (r->>'status')::int else 0 end;
    if v_status between 200 and 299 then
      update push_subscriptions set last_ok_at = now(), last_status = v_status, last_error = null, failures = 0
       where id = (r->>'subscription')::uuid and user_id = v_q.user_id;
      update push_queue set sent_at = coalesce(sent_at, now()), done = true where id = v_q.id;
      v_ok := v_ok + 1;
    elsif v_status in (404, 410) then
      -- O aparelho cancelou a inscrição (app removido, permissão retirada…)
      delete from push_subscriptions where id = (r->>'subscription')::uuid and user_id = v_q.user_id;
      v_gone := v_gone + 1;
    else
      update push_subscriptions set last_status = v_status, last_error = left(r->>'error', 200), failures = failures + 1
       where id = (r->>'subscription')::uuid and user_id = v_q.user_id;
      v_fail := v_fail + 1;
    end if;
  end loop;

  -- Aparelhos que falham sem parar saem (o app inscreve de novo quando for aberto)
  delete from push_subscriptions s where s.failures >= 15
     and s.user_id in (select user_id from push_queue where batch_id = v_b.id);

  -- O que não chegou em nenhum aparelho volta para a fila (até 3 tentativas)
  update push_queue q set done = true
   where q.batch_id = v_b.id and not q.done
     and not exists (select 1 from push_subscriptions s where s.user_id = q.user_id);
  update push_queue set batch_id = null, attempts = attempts + 1, done = attempts + 1 >= 3 or expires_at <= now()
   where batch_id = v_b.id and not done;

  update push_batches set reported_at = now(), sent = v_ok, failed = v_fail + v_gone where id = v_b.id;
  return jsonb_build_object('ok', v_ok, 'failed', v_fail, 'gone', v_gone);
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 5. Administração (SQL Editor do Supabase)
-- ════════════════════════════════════════════════════════════════════════════
-- Exemplo:
--   select admin_set_push_url('https://forja-kappa-wheat.vercel.app');
create or replace function public.admin_set_push_url(p_url text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v text := rtrim(trim(coalesce(p_url, '')), '/');
begin
  if v !~ '^https://[A-Za-z0-9.-]+(:[0-9]+)?$' then
    raise exception 'endereco_invalido' using hint = 'Use só o endereço do app, por exemplo https://seu-app.vercel.app';
  end if;
  update push_config set app_url = v, updated_at = now() where id;
  return jsonb_build_object('app_url', v, 'funcao', v || '/api/push');
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 6. Agendamento (pg_cron)
-- ════════════════════════════════════════════════════════════════════════════

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    -- Mesmo nome = substitui o agendamento anterior
    perform cron.schedule('forja-notificacoes', '* * * * *', 'select public._push_tick()');
    perform cron.schedule('forja-limpeza-cron', '17 4 * * *',
      $c$delete from cron.job_run_details where end_time < now() - interval '7 days'$c$);
  end if;
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 7. Permissões
-- ════════════════════════════════════════════════════════════════════════════

revoke insert, update, delete, truncate on all tables in schema public from anon, authenticated;
grant select on all tables in schema public to authenticated;
-- Chaves, códigos de lote e inscrições ficam fora do alcance do app
revoke all on public.push_config, public.push_batches, public.push_queue, public.push_log, public.push_subscriptions
  from anon, authenticated;

revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function
  -- MVP
  public.submit_assessment(jsonb),
  public.ensure_today(),
  public.complete_mission(uuid),
  public.undo_completion(uuid),
  public.create_custom_mission(text, text, text, int, int, boolean),
  public.adjust_habit(uuid, int, boolean),
  public.update_profile(text, text, int),
  public.get_journey(),
  public.xp_for_level(int),
  public.level_for_xp(int),
  -- Etapa 3
  public.get_bosses(),
  public.start_boss(text),
  public.abandon_boss(),
  public.get_achievements(),
  public.update_avatar(jsonb),
  public.set_title(text),
  public.set_mode(text, boolean),
  public.get_mode_info(),
  public.pending_events(),
  public.mark_events_seen(bigint[]),
  -- Etapa 4: plano, amigos, feed, grupos, desafios e temporadas
  public.get_plan_info(),
  public.get_social(),
  public.update_privacy(jsonb),
  public.reset_friend_code(),
  public.lookup_friend_code(text),
  public.send_friend_request(text),
  public.respond_friend_request(uuid, boolean),
  public.remove_friend(uuid),
  public.friend_profile(uuid),
  public.friends_feed(bigint),
  public.share_post(text, text),
  public.delete_post(bigint),
  public.send_cheer(bigint, uuid, text),
  public.get_notifications(),
  public.create_group(text, text),
  public.join_group(text),
  public.leave_group(uuid),
  public.remove_group_member(uuid, uuid),
  public.update_group(uuid, text, text),
  public.reset_group_code(uuid),
  public.get_groups(),
  public.group_detail(uuid),
  public.create_challenge(jsonb),
  public.respond_challenge(uuid, boolean),
  public.leave_challenge(uuid),
  public.cancel_challenge(uuid),
  public.get_challenges(),
  public.challenge_detail(uuid),
  public.get_season(),
  public.get_ranking(text, uuid, text),
  -- Etapa 4: ferramentas e Mentor
  public.update_tool_settings(jsonb),
  public.get_tool(text),
  public.log_tool(text, jsonb),
  public.delete_tool_log(bigint),
  public.tools_overview(),
  public.tool_history(text, int),
  public.get_diary(int),
  public.get_books(),
  public.save_book(uuid, text, text, int),
  public.set_book_status(uuid, text),
  public.habit_tracker(),
  public.set_mentor(boolean),
  public.get_mentor(),
  public.respond_suggestion(uuid, boolean),
  public.get_report(date),
  -- Notificações
  public.get_notify(),
  public.set_notify(jsonb),
  public.save_push_subscription(text, text, text, text),
  public.remove_push_subscription(text),
  public.push_test()
to authenticated;

-- A função de envio do app usa a chave pública: só estas três, e só com o código de um lote válido
grant execute on function
  public.push_claim(text),
  public.push_set_keys(text, text, text),
  public.push_report(text, jsonb)
to anon;
