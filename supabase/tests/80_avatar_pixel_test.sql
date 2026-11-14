-- Testes da 0008: aparência com tipo de corpo e cor dos olhos. Rodam com: supabase/tests/run.sh
\set ON_ERROR_STOP on
set client_min_messages = notice;

\set answers '{"display_name":"Lia","daily_minutes":45,"exercise":1,"diet":2,"sleep_hours":2,"sleep_quality":2,"stress":1,"rest":2,"reflection":1,"reading":1,"learning":1,"planning":1,"procrastination":1,"discipline":2,"screen_time":1,"phone_morning":1,"focus":1,"water":2,"morning_routine":2,"environment":2,"main_goal":"mental"}'

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a8', 'lia@teste.dev', '{"name":"Lia"}');

set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a8', false);
select public.submit_assessment(:'answers') is not null as ok \gset

-- A. Guarda tipo e olhos
do $$
declare a jsonb;
begin
  a := public.update_avatar('{"pele":1,"cabelo":6,"corCabelo":0,"barba":0,"corRoupa":2,"tipo":"f","olhos":"verde","equip":{}}');
  if a->>'tipo' <> 'f' or a->>'olhos' <> 'verde' then raise exception 'A: tipo/olhos não salvos: %', a; end if;
  if a->'equip'->>'moldura' <> 'mol_bronze' then raise exception 'A: moldura padrão sumiu: %', a; end if;
end $$;

-- B. Sem os campos novos, entra o padrão
do $$
declare a jsonb;
begin
  a := public.update_avatar('{"pele":1,"cabelo":1,"corCabelo":0,"barba":1,"corRoupa":2}');
  if a->>'tipo' <> 'm' or a->>'olhos' <> 'castanho' then raise exception 'B: padrão errado: %', a; end if;
end $$;

-- C. Valores inválidos são recusados
do $$
begin
  begin
    perform public.update_avatar('{"pele":1,"cabelo":1,"corCabelo":0,"barba":1,"corRoupa":2,"tipo":"x"}');
    raise exception 'C: tipo inválido aceito';
  exception when raise_exception then
    if sqlerrm not like 'aparencia_invalida%' then raise; end if;
  end;
  begin
    perform public.update_avatar('{"pele":1,"cabelo":1,"corCabelo":0,"barba":1,"corRoupa":2,"olhos":"roxo"}');
    raise exception 'C: olhos inválidos aceitos';
  exception when raise_exception then
    if sqlerrm not like 'aparencia_invalida%' then raise; end if;
  end;
end $$;

reset role;
select 'ok 0008 avatar pixel' as resultado;
