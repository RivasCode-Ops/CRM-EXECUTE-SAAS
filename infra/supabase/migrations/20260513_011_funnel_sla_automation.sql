-- 011: SLA de funil — stage_updated_at + funnel_sla_alerts + RLS
-- Stages reais: opportunities.stage (003): novo, qualificacao, proposta_enviada, negociacao, ganho, perdido

alter table public.opportunities
  add column if not exists stage_updated_at timestamptz not null default now();

update public.opportunities
set stage_updated_at = created_at
where stage_updated_at is null;

create or replace function public.trg_update_opportunity_stage_timestamp()
returns trigger
language plpgsql
as $$
begin
  if old.stage is distinct from new.stage then
    new.stage_updated_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists update_opportunity_stage_timestamp on public.opportunities;

create trigger update_opportunity_stage_timestamp
  before update of stage on public.opportunities
  for each row
  execute function public.trg_update_opportunity_stage_timestamp();

create index if not exists idx_opportunities_sla_scan
  on public.opportunities (tenant_id, stage, stage_updated_at);

-- ---------------------------------------------------------------------------
-- Alertas SLA (regra: stale_<stage> alinhada ao nome real do stage)
-- ---------------------------------------------------------------------------

create table if not exists public.funnel_sla_alerts (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  opportunity_id uuid not null references public.opportunities (id) on delete cascade,
  rule_type text not null
    check (
      rule_type in (
        'stale_novo',
        'stale_qualificacao',
        'stale_proposta_enviada',
        'stale_negociacao',
        'stale_ganho',
        'stale_perdido'
      )
    ),
  status text not null default 'active' check (status in ('active', 'acknowledged', 'resolved')),
  triggered_at timestamptz not null default now(),
  acknowledged_at timestamptz,
  unique (opportunity_id, rule_type, status)
);

create index if not exists idx_funnel_sla_alerts_tenant_status
  on public.funnel_sla_alerts (tenant_id, status);

alter table public.funnel_sla_alerts enable row level security;

drop policy if exists funnel_sla_alerts_select on public.funnel_sla_alerts;
drop policy if exists funnel_sla_alerts_insert on public.funnel_sla_alerts;
drop policy if exists funnel_sla_alerts_update on public.funnel_sla_alerts;

create policy funnel_sla_alerts_select on public.funnel_sla_alerts
  for select
  to authenticated
  using (
    tenant_id = app_current_tenant_id()
    and has_permission('opportunities.read')
  );

create policy funnel_sla_alerts_insert on public.funnel_sla_alerts
  for insert
  to authenticated
  with check (
    tenant_id = app_current_tenant_id()
    and has_permission('opportunities.write')
  );

create policy funnel_sla_alerts_update on public.funnel_sla_alerts
  for update
  to authenticated
  using (
    tenant_id = app_current_tenant_id()
    and has_permission('opportunities.write')
  )
  with check (
    tenant_id = app_current_tenant_id()
    and has_permission('opportunities.write')
  );

create or replace function public.trg_set_sla_alert_tenant()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant uuid;
begin
  select tenant_id into v_tenant from public.opportunities where id = new.opportunity_id;
  if v_tenant is null then
    raise exception 'OPPORTUNITY_NOT_FOUND'
      using errcode = 'P0001';
  end if;
  new.tenant_id := v_tenant;
  return new;
end;
$$;

drop trigger if exists set_sla_alert_tenant on public.funnel_sla_alerts;

create trigger set_sla_alert_tenant
  before insert on public.funnel_sla_alerts
  for each row
  execute function public.trg_set_sla_alert_tenant();

comment on table public.funnel_sla_alerts is
  'Alertas de SLA do funil; tenant_id preenchido pelo trigger a partir da oportunidade.';
