-- 005: properties + property_price_history (RECRIADAS — originais perdidos).
--
-- Reconstruido a partir de:
--   - src/types/supabase.ts (contract gerado das migrations originais)
--   - src/app/actions/update-property-price.ts (consumer)
--   - supabase/migrations/20260511_009_*.sql (adiciona `tipo_registro` aqui)
--   - supabase/migrations/20260512_010_*.sql (assume FKs property_id/opportunity_id)
--
-- Dependencias: 004 (tenants), 003 (app_current_role, has_permission, role_permissions).

-- ---------------------------------------------------------------------------
-- properties
-- ---------------------------------------------------------------------------

create table if not exists public.properties (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  address_full text not null,
  city text,
  price numeric(14,2) not null default 0 check (price >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_properties_tenant_created
  on public.properties (tenant_id, created_at desc);

create index if not exists idx_properties_tenant_address
  on public.properties (tenant_id, address_full);

alter table public.properties enable row level security;

create or replace function public.trg_properties_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists set_properties_updated_at on public.properties;
create trigger set_properties_updated_at
  before update on public.properties
  for each row
  execute function public.trg_properties_set_updated_at();

-- ---------------------------------------------------------------------------
-- property_price_history (append-only via RPC 009 update_price_with_history)
-- ---------------------------------------------------------------------------

create table if not exists public.property_price_history (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  property_id uuid not null references public.properties(id) on delete cascade,
  previous_price numeric(14,2) not null default 0,
  new_price numeric(14,2) not null check (new_price > 0),
  note text,
  created_at timestamptz not null default now(),
  alterado_por uuid references auth.users(id) on delete set null,
  justificativa text,
  correcao boolean not null default false
  -- coluna `tipo_registro` e seu check sao adicionados em 009.
);

create index if not exists idx_pph_property_created
  on public.property_price_history (property_id, created_at desc);

create index if not exists idx_pph_tenant_created
  on public.property_price_history (tenant_id, created_at desc);

alter table public.property_price_history enable row level security;

-- ---------------------------------------------------------------------------
-- RLS policies (tenant_id + has_permission do 003)
-- ---------------------------------------------------------------------------

do $$
begin
  if not exists (select 1 from pg_policies where policyname = 'properties_select') then
    create policy properties_select on public.properties
      for select to authenticated
      using (tenant_id = app_current_tenant_id() and has_permission('properties.read'));
  end if;
  if not exists (select 1 from pg_policies where policyname = 'properties_insert') then
    create policy properties_insert on public.properties
      for insert to authenticated
      with check (tenant_id = app_current_tenant_id() and has_permission('properties.write'));
  end if;
  if not exists (select 1 from pg_policies where policyname = 'properties_update') then
    create policy properties_update on public.properties
      for update to authenticated
      using (tenant_id = app_current_tenant_id() and has_permission('properties.write'))
      with check (tenant_id = app_current_tenant_id() and has_permission('properties.write'));
  end if;
  if not exists (select 1 from pg_policies where policyname = 'properties_delete_admin') then
    create policy properties_delete_admin on public.properties
      for delete to authenticated
      using (tenant_id = app_current_tenant_id() and app_current_role() = 'admin');
  end if;

  -- property_price_history e append-only: select + insert apenas (RPC 009 controla insert real).
  if not exists (select 1 from pg_policies where policyname = 'property_price_history_select') then
    create policy property_price_history_select on public.property_price_history
      for select to authenticated
      using (tenant_id = app_current_tenant_id() and has_permission('properties.read'));
  end if;
  if not exists (select 1 from pg_policies where policyname = 'property_price_history_insert') then
    create policy property_price_history_insert on public.property_price_history
      for insert to authenticated
      with check (tenant_id = app_current_tenant_id() and has_permission('properties.write'));
  end if;
  -- intencional: SEM update/delete (audit trail nao se altera).
end $$;

comment on table public.properties is
  'Imoveis cadastrados por tenant (despachante imobiliario).';
comment on table public.property_price_history is
  'Historico append-only de precos; insert via RPC update_price_with_history (009).';
