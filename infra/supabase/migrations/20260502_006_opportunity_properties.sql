-- 006: opportunities.property_id + tabela de juncao opportunity_properties (RECRIADA).
--
-- Reconstruido a partir de:
--   - src/types/supabase.ts (Row tipos para opportunity_properties e opportunities.property_id)
--   - src/app/actions/link-property-to-opportunity.ts (insert + select + update opportunities.property_id)
--   - supabase/migrations/20260512_010_*.sql (trigger sync_opportunity_properties_tenant)
--
-- Dependencias: 003 (opportunities, has_permission), 005 (properties).
-- Trigger de tenant em opportunity_properties continua sendo definido pela 010.

-- ---------------------------------------------------------------------------
-- Coluna principal: opportunities.property_id (imovel "primario" da oportunidade)
-- O link N:N fica em opportunity_properties; o "primario" e sincronizado pela
-- server action linkPropertyToOpportunityAction.
-- ---------------------------------------------------------------------------

alter table public.opportunities
  add column if not exists property_id uuid references public.properties(id) on delete set null;

create index if not exists idx_opportunities_property_id
  on public.opportunities (property_id);

-- ---------------------------------------------------------------------------
-- opportunity_properties: vinculo N:N + metadata de interesse
-- ---------------------------------------------------------------------------

create table if not exists public.opportunity_properties (
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  opportunity_id uuid not null references public.opportunities(id) on delete cascade,
  property_id uuid not null references public.properties(id) on delete cascade,
  interesse_tipo text not null default 'ambos'
    check (interesse_tipo in ('compra', 'locacao', 'ambos')),
  prioridade integer not null default 5
    check (prioridade between 1 and 10),
  criado_em timestamptz not null default now(),
  primary key (opportunity_id, property_id)
);

create index if not exists idx_opp_props_tenant
  on public.opportunity_properties (tenant_id);

create index if not exists idx_opp_props_property
  on public.opportunity_properties (property_id);

create index if not exists idx_opp_props_opp_priority
  on public.opportunity_properties (opportunity_id, prioridade, criado_em);

alter table public.opportunity_properties enable row level security;

-- ---------------------------------------------------------------------------
-- RLS — exige permissao em ambas as entidades, e tenant_id valido.
-- A coluna tenant_id sera preenchida automaticamente pelo trigger da migration 010.
-- ---------------------------------------------------------------------------

do $$
begin
  if not exists (select 1 from pg_policies where policyname = 'opportunity_properties_select') then
    create policy opportunity_properties_select on public.opportunity_properties
      for select to authenticated
      using (
        tenant_id = app_current_tenant_id()
        and has_permission('opportunities.read')
        and has_permission('properties.read')
      );
  end if;

  if not exists (select 1 from pg_policies where policyname = 'opportunity_properties_insert') then
    create policy opportunity_properties_insert on public.opportunity_properties
      for insert to authenticated
      with check (
        -- tenant_id pode chegar null aqui — trigger 010 preenche; mas a igualdade
        -- e validada porque o trigger lanca TENANT_MISMATCH se property/opportunity
        -- pertencerem a tenants diferentes.
        has_permission('opportunities.write')
        and has_permission('properties.read')
      );
  end if;

  if not exists (select 1 from pg_policies where policyname = 'opportunity_properties_update') then
    create policy opportunity_properties_update on public.opportunity_properties
      for update to authenticated
      using (
        tenant_id = app_current_tenant_id()
        and has_permission('opportunities.write')
      )
      with check (
        tenant_id = app_current_tenant_id()
        and has_permission('opportunities.write')
      );
  end if;

  if not exists (select 1 from pg_policies where policyname = 'opportunity_properties_delete') then
    create policy opportunity_properties_delete on public.opportunity_properties
      for delete to authenticated
      using (
        tenant_id = app_current_tenant_id()
        and has_permission('opportunities.write')
      );
  end if;
end $$;

comment on table public.opportunity_properties is
  'Vinculo N:N oportunidade <-> imovel. tenant_id preenchido pelo trigger em 010.';
comment on column public.opportunities.property_id is
  'Imovel "primario" da oportunidade (menor prioridade em opportunity_properties).';
