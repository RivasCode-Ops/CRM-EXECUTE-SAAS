-- Migration 003: comercial (leads/opportunities/tasks/activities) + permissions

create table if not exists leads (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  name text not null,
  phone text,
  email text,
  source text,
  status text not null default 'novo' check (status in ('novo', 'contatado', 'qualificado', 'convertido', 'perdido')),
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists opportunities (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  lead_id uuid references leads(id) on delete set null,
  title text not null,
  stage text not null default 'novo' check (stage in ('novo', 'qualificacao', 'proposta_enviada', 'negociacao', 'ganho', 'perdido')),
  estimated_value numeric(12,2) not null default 0,
  probability integer not null default 0 check (probability >= 0 and probability <= 100),
  expected_close_date date,
  created_at timestamptz not null default now()
);

create table if not exists tasks (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  lead_id uuid references leads(id) on delete set null,
  opportunity_id uuid references opportunities(id) on delete set null,
  title text not null,
  description text,
  assignee text not null,
  due_date date,
  status text not null default 'pendente' check (status in ('pendente', 'em_andamento', 'concluida', 'cancelada')),
  created_at timestamptz not null default now()
);

create table if not exists activities (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  lead_id uuid references leads(id) on delete set null,
  opportunity_id uuid references opportunities(id) on delete set null,
  task_id uuid references tasks(id) on delete set null,
  activity_type text not null check (activity_type in ('nota', 'ligacao', 'whatsapp', 'email', 'reuniao')),
  description text not null,
  author text not null,
  created_at timestamptz not null default now()
);

create table if not exists role_permissions (
  id uuid primary key default gen_random_uuid(),
  role text not null check (role in ('admin', 'operador')),
  permission_key text not null,
  created_at timestamptz not null default now(),
  unique (role, permission_key)
);

insert into role_permissions (role, permission_key)
values
  ('admin', 'leads.read'),
  ('admin', 'leads.write'),
  ('admin', 'opportunities.read'),
  ('admin', 'opportunities.write'),
  ('admin', 'tasks.read'),
  ('admin', 'tasks.write'),
  ('admin', 'activities.read'),
  ('admin', 'activities.write'),
  ('admin', 'supervisors.manage'),
  ('operador', 'leads.read'),
  ('operador', 'leads.write'),
  ('operador', 'opportunities.read'),
  ('operador', 'opportunities.write'),
  ('operador', 'tasks.read'),
  ('operador', 'tasks.write'),
  ('operador', 'activities.read'),
  ('operador', 'activities.write')
on conflict (role, permission_key) do nothing;

create or replace function has_permission(p_permission text)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from role_permissions rp
    where rp.role = app_current_role()
      and rp.permission_key = p_permission
  );
$$;

create or replace function app_current_tenant_id()
returns uuid
language sql
stable
as $$
  select nullif((auth.jwt() ->> 'tenant_id'), '')::uuid;
$$;

create index if not exists idx_leads_tenant_created on leads (tenant_id, created_at desc);
create index if not exists idx_leads_status on leads (status);
create index if not exists idx_opportunities_tenant_created on opportunities (tenant_id, created_at desc);
create index if not exists idx_opportunities_stage on opportunities (stage);
create index if not exists idx_opportunities_lead_id on opportunities (lead_id);
create index if not exists idx_tasks_tenant_created on tasks (tenant_id, created_at desc);
create index if not exists idx_tasks_status on tasks (status);
create index if not exists idx_tasks_due_date on tasks (due_date);
create index if not exists idx_tasks_lead_id on tasks (lead_id);
create index if not exists idx_tasks_opportunity_id on tasks (opportunity_id);
create index if not exists idx_tasks_assignee on tasks (assignee);
create index if not exists idx_activities_tenant_created on activities (tenant_id, created_at desc);
create index if not exists idx_activities_activity_type on activities (activity_type);
create index if not exists idx_activities_lead_id on activities (lead_id);
create index if not exists idx_activities_opportunity_id on activities (opportunity_id);
create index if not exists idx_activities_task_id on activities (task_id);

alter table leads enable row level security;
alter table opportunities enable row level security;
alter table tasks enable row level security;
alter table activities enable row level security;
alter table role_permissions enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where policyname = 'leads_select') then
    create policy leads_select on leads for select to authenticated using (tenant_id = app_current_tenant_id() and has_permission('leads.read'));
  end if;
  if not exists (select 1 from pg_policies where policyname = 'leads_insert') then
    create policy leads_insert on leads for insert to authenticated with check (tenant_id = app_current_tenant_id() and has_permission('leads.write'));
  end if;
  if not exists (select 1 from pg_policies where policyname = 'leads_update') then
    create policy leads_update on leads for update to authenticated using (tenant_id = app_current_tenant_id() and has_permission('leads.write')) with check (tenant_id = app_current_tenant_id() and has_permission('leads.write'));
  end if;
  if not exists (select 1 from pg_policies where policyname = 'leads_delete_admin') then
    create policy leads_delete_admin on leads for delete to authenticated using (tenant_id = app_current_tenant_id() and app_current_role() = 'admin');
  end if;

  if not exists (select 1 from pg_policies where policyname = 'opportunities_select') then
    create policy opportunities_select on opportunities for select to authenticated using (tenant_id = app_current_tenant_id() and has_permission('opportunities.read'));
  end if;
  if not exists (select 1 from pg_policies where policyname = 'opportunities_insert') then
    create policy opportunities_insert on opportunities for insert to authenticated with check (tenant_id = app_current_tenant_id() and has_permission('opportunities.write'));
  end if;
  if not exists (select 1 from pg_policies where policyname = 'opportunities_update') then
    create policy opportunities_update on opportunities for update to authenticated using (tenant_id = app_current_tenant_id() and has_permission('opportunities.write')) with check (tenant_id = app_current_tenant_id() and has_permission('opportunities.write'));
  end if;
  if not exists (select 1 from pg_policies where policyname = 'opportunities_delete_admin') then
    create policy opportunities_delete_admin on opportunities for delete to authenticated using (tenant_id = app_current_tenant_id() and app_current_role() = 'admin');
  end if;

  if not exists (select 1 from pg_policies where policyname = 'tasks_select') then
    create policy tasks_select on tasks for select to authenticated using (tenant_id = app_current_tenant_id() and has_permission('tasks.read'));
  end if;
  if not exists (select 1 from pg_policies where policyname = 'tasks_insert') then
    create policy tasks_insert on tasks for insert to authenticated with check (tenant_id = app_current_tenant_id() and has_permission('tasks.write'));
  end if;
  if not exists (select 1 from pg_policies where policyname = 'tasks_update') then
    create policy tasks_update on tasks for update to authenticated using (tenant_id = app_current_tenant_id() and has_permission('tasks.write')) with check (tenant_id = app_current_tenant_id() and has_permission('tasks.write'));
  end if;
  if not exists (select 1 from pg_policies where policyname = 'tasks_delete_admin') then
    create policy tasks_delete_admin on tasks for delete to authenticated using (tenant_id = app_current_tenant_id() and app_current_role() = 'admin');
  end if;

  if not exists (select 1 from pg_policies where policyname = 'activities_select') then
    create policy activities_select on activities for select to authenticated using (tenant_id = app_current_tenant_id() and has_permission('activities.read'));
  end if;
  if not exists (select 1 from pg_policies where policyname = 'activities_insert') then
    create policy activities_insert on activities for insert to authenticated with check (tenant_id = app_current_tenant_id() and has_permission('activities.write'));
  end if;
  if not exists (select 1 from pg_policies where policyname = 'activities_update') then
    create policy activities_update on activities for update to authenticated using (tenant_id = app_current_tenant_id() and has_permission('activities.write')) with check (tenant_id = app_current_tenant_id() and has_permission('activities.write'));
  end if;
  if not exists (select 1 from pg_policies where policyname = 'activities_delete_admin') then
    create policy activities_delete_admin on activities for delete to authenticated using (tenant_id = app_current_tenant_id() and app_current_role() = 'admin');
  end if;

  if not exists (select 1 from pg_policies where policyname = 'authenticated_read_role_permissions') then
    create policy authenticated_read_role_permissions on role_permissions for select to authenticated using (app_current_role() = 'admin');
  end if;
end $$;
