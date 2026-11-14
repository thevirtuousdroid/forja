-- Forja · 0008 · Personagem em pixel art
--
-- A aparência passa a guardar também o tipo de corpo ('m' ou 'f') e a cor dos olhos.
-- Só a função update_avatar muda: as outras partes da aparência e os equipamentos seguem as mesmas regras.
-- Quem já tem aparência salva continua com ela; os campos novos entram com valor padrão quando faltam.
-- Pode ser rodada mais de uma vez. Nada é apagado.

create or replace function public.update_avatar(p_avatar jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  s text;
  v text;
  equip jsonb := '{}'::jsonb;
  tipo text := coalesce(p_avatar->>'tipo', 'm');
  olhos text := coalesce(p_avatar->>'olhos', 'castanho');
begin
  if uid is null then raise exception 'nao_autenticado'; end if;
  if p_avatar is null or jsonb_typeof(p_avatar) <> 'object' then raise exception 'aparencia_invalida'; end if;
  if not (_int_in(p_avatar->'pele', 0, 5) and _int_in(p_avatar->'cabelo', 0, 7) and _int_in(p_avatar->'corCabelo', 0, 7)
          and _int_in(p_avatar->'barba', 0, 2) and _int_in(p_avatar->'corRoupa', 0, 5)) then
    raise exception 'aparencia_invalida';
  end if;
  if tipo not in ('m', 'f') then raise exception 'aparencia_invalida'; end if;
  if olhos not in ('castanho', 'mel', 'verde', 'azul', 'cinza', 'ciano') then raise exception 'aparencia_invalida'; end if;
  if p_avatar ? 'equip' and jsonb_typeof(p_avatar->'equip') <> 'object' then raise exception 'aparencia_invalida'; end if;

  foreach s in array array['cabeca','corpo','capa','arma','amuleto','moldura'] loop
    v := p_avatar->'equip'->>s;
    if v is not null then
      if not exists (select 1 from user_items ui join item_catalog ic on ic.id = ui.item_id
                      where ui.user_id = uid and ui.item_id = v and ic.kind = 'equipamento' and ic.slot = s) then
        raise exception 'item_nao_disponivel: %', v;
      end if;
      equip := equip || jsonb_build_object(s, v);
    end if;
  end loop;
  if not equip ? 'corpo' then equip := equip || '{"corpo":"cor_tunica"}'::jsonb; end if;
  if not equip ? 'moldura' then equip := equip || '{"moldura":"mol_bronze"}'::jsonb; end if;

  update profiles set avatar = jsonb_build_object(
    'pele', (p_avatar->>'pele')::int, 'cabelo', (p_avatar->>'cabelo')::int, 'corCabelo', (p_avatar->>'corCabelo')::int,
    'barba', (p_avatar->>'barba')::int, 'corRoupa', (p_avatar->>'corRoupa')::int,
    'tipo', tipo, 'olhos', olhos,
    'personalizado', true, 'equip', equip)
  where id = uid;
  return (select avatar from profiles where id = uid);
end $$;

revoke execute on function public.update_avatar(jsonb) from public, anon;
grant execute on function public.update_avatar(jsonb) to authenticated;
