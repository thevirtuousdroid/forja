-- Simula o mínimo do Supabase para testar as migrações num Postgres local.
-- NÃO rodar no Supabase de verdade.
create role anon nologin;
create role authenticated nologin;
create schema auth;
grant usage on schema auth to authenticated, anon;
grant usage on schema public to authenticated, anon;

create table auth.users (
  id uuid primary key default gen_random_uuid(),
  email text unique,
  raw_user_meta_data jsonb default '{}'::jsonb
);

create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
grant execute on function auth.uid() to authenticated, anon;
