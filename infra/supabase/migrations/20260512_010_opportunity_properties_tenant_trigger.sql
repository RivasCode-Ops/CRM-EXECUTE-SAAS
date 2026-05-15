-- 010: Valida imovel x oportunidade no mesmo tenant e preenche tenant_id (tabela 005)
-- Nao recria opportunity_properties — apenas trigger BEFORE INSERT/UPDATE.

create or replace function public.sync_opportunity_properties_tenant()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_prop_tenant uuid;
  v_opp_tenant uuid;
begin
  select tenant_id into v_prop_tenant from public.properties where id = new.property_id;
  select tenant_id into v_opp_tenant from public.opportunities where id = new.opportunity_id;

  if v_prop_tenant is null then
    raise exception 'PROPERTY_NOT_FOUND'
      using errcode = 'P0001';
  end if;

  if v_opp_tenant is null then
    raise exception 'OPPORTUNITY_NOT_FOUND'
      using errcode = 'P0001';
  end if;

  if v_prop_tenant is distinct from v_opp_tenant then
    raise exception 'TENANT_MISMATCH'
      using errcode = 'P0001';
  end if;

  new.tenant_id := v_prop_tenant;
  return new;
end;
$$;

drop trigger if exists set_opp_prop_tenant on public.opportunity_properties;

create trigger set_opp_prop_tenant
  before insert or update of opportunity_id, property_id on public.opportunity_properties
  for each row
  execute function public.sync_opportunity_properties_tenant();

comment on function public.sync_opportunity_properties_tenant() is
  'Alinha tenant_id ao imovel e impede vinculo entre oportunidade e imovel de tenants diferentes.';
