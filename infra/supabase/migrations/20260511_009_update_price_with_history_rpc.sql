-- 009: RPC transacional update_price_with_history (SECURITY INVOKER + RLS)
-- Pre-requisitos: 004–008 aplicados.

alter table public.property_price_history
  add column if not exists tipo_registro text;

alter table public.property_price_history
  drop constraint if exists property_price_history_tipo_registro_check;

alter table public.property_price_history
  add constraint property_price_history_tipo_registro_check
  check (
    tipo_registro is null
    or tipo_registro in ('ajuste', 'correcao', 'negociacao')
  );

create or replace function public.update_price_with_history(
  p_property_id uuid,
  p_previous_price_expected numeric(14, 2),
  p_new_price numeric(14, 2),
  p_justificativa text,
  p_tipo_registro text
) returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_price numeric(14, 2);
  v_tipo text;
begin
  if p_new_price is null or p_new_price <= 0 then
    raise exception 'INVALID_PRICE'
      using errcode = 'P0001';
  end if;

  select tenant_id, price into v_tenant_id, v_price
  from public.properties
  where id = p_property_id
  for update;

  if not found then
    raise exception 'PROPERTY_NOT_FOUND'
      using errcode = 'P0001';
  end if;

  if v_price is distinct from p_previous_price_expected then
    raise exception 'STALE_PRICE'
      using errcode = 'P0002';
  end if;

  v_tipo := coalesce(
    nullif(trim(coalesce(p_tipo_registro, '')), ''),
    'ajuste'
  );
  if v_tipo not in ('ajuste', 'correcao', 'negociacao') then
    v_tipo := 'ajuste';
  end if;

  insert into public.property_price_history (
    tenant_id,
    property_id,
    previous_price,
    new_price,
    note,
    justificativa,
    correcao,
    tipo_registro
  ) values (
    v_tenant_id,
    p_property_id,
    v_price,
    p_new_price,
    null,
    p_justificativa,
    v_tipo = 'correcao',
    v_tipo
  );

  update public.properties
  set
    price = p_new_price,
    updated_at = now()
  where id = p_property_id;
end;
$$;

grant execute on function public.update_price_with_history(uuid, numeric(14, 2), numeric(14, 2), text, text) to authenticated;

comment on function public.update_price_with_history(uuid, numeric(14, 2), numeric(14, 2), text, text) is
  'Atualiza properties.price e insere append-only em property_price_history na mesma transacao (RLS do caller).';
