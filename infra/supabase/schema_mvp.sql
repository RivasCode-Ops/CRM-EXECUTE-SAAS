-- Schema inicial de referencia para o MVP.
-- Ajustar e aplicar via Supabase SQL Editor ou migrations.

do $$
begin
  if not exists (select 1 from pg_type where typname = 'process_status') then
    create type process_status as enum (
      'novo',
      'documentos_em_coleta',
      'protocolado',
      'em_analise',
      'com_exigencia',
      'aguardando_cliente',
      'retorno_agendado',
      'atrasado',
      'concluido',
      'arquivado',
      'cancelado'
    );
  end if;
end $$;

create table if not exists clients (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  full_name text not null,
  cpf_cnpj text not null unique,
  phone text,
  email text,
  city_uf text,
  created_at timestamptz not null default now()
);

create table if not exists processes (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  internal_code text not null unique,
  public_code text,
  client_id uuid not null references clients(id) on delete cascade,
  title text not null,
  service_type text not null,
  status process_status not null default 'novo',
  current_stage text not null default 'abertura',
  protocol_number text,
  due_date date,
  created_at timestamptz not null default now()
);

create table if not exists process_history (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  process_id uuid not null references processes(id) on delete cascade,
  action text not null,
  description text,
  created_at timestamptz not null default now()
);

create table if not exists process_checklist (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  process_id uuid not null references processes(id) on delete cascade,
  title text not null,
  is_done boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists process_deadlines (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  process_id uuid not null references processes(id) on delete cascade,
  title text not null,
  due_date timestamptz not null,
  is_done boolean not null default false,
  created_at timestamptz not null default now()
);

do $$
begin
  if not exists (select 1 from pg_type where typname = 'document_status') then
    create type document_status as enum ('pendente', 'recebido');
  end if;
end $$;

create table if not exists process_documents (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  process_id uuid not null references processes(id) on delete cascade,
  name text not null,
  status document_status not null default 'pendente',
  file_url text,
  created_at timestamptz not null default now()
);

create table if not exists process_observations (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  process_id uuid not null references processes(id) on delete cascade,
  content text not null,
  created_at timestamptz not null default now()
);

do $$
begin
  if not exists (select 1 from pg_type where typname = 'budget_status') then
    create type budget_status as enum ('rascunho', 'enviado', 'aprovado', 'rejeitado');
  end if;
end $$;

create table if not exists budgets (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  code text not null unique,
  client_id uuid not null references clients(id) on delete cascade,
  process_id uuid not null references processes(id) on delete cascade,
  description text not null,
  amount numeric(14,2) not null default 0,
  valid_until timestamptz not null,
  status budget_status not null default 'rascunho',
  created_at timestamptz not null default now()
);

do $$
begin
  if not exists (select 1 from pg_type where typname = 'contract_status') then
    create type contract_status as enum ('ativo', 'encerrado', 'cancelado');
  end if;
end $$;

create table if not exists service_contracts (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  code text not null unique,
  budget_id uuid references budgets(id) on delete set null,
  client_id uuid not null references clients(id) on delete cascade,
  process_id uuid references processes(id) on delete set null,
  scope text not null,
  closed_amount numeric(14,2) not null default 0,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status contract_status not null default 'ativo',
  created_at timestamptz not null default now()
);

create table if not exists service_types (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  name text not null unique,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists checklist_templates (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  service text not null,
  title text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists user_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  tenant_id uuid not null,
  role text not null check (role in ('admin', 'operador')),
  created_at timestamptz not null default now()
);

create unique index if not exists idx_checklist_templates_unique_active_title
  on checklist_templates (service, title);

create index if not exists idx_processes_tenant_id on processes (tenant_id);
create index if not exists idx_process_history_process_id on process_history (process_id);
create index if not exists idx_process_checklist_process_id on process_checklist (process_id);
create index if not exists idx_process_deadlines_process_id on process_deadlines (process_id);
create index if not exists idx_process_documents_process_id on process_documents (process_id);
create index if not exists idx_process_observations_process_id on process_observations (process_id);
create index if not exists idx_budgets_process_id on budgets (process_id);
create index if not exists idx_budgets_client_id on budgets (client_id);
create index if not exists idx_budgets_tenant_id on budgets (tenant_id);
create index if not exists idx_service_contracts_process_id on service_contracts (process_id);
create index if not exists idx_service_contracts_budget_id on service_contracts (budget_id);
create index if not exists idx_service_contracts_tenant_id on service_contracts (tenant_id);
create index if not exists idx_service_types_tenant_id on service_types (tenant_id);
create index if not exists idx_checklist_templates_tenant_id on checklist_templates (tenant_id);

-- Storage bucket for uploaded process documents
insert into storage.buckets (id, name, public)
values ('process-documents', 'process-documents', true)
on conflict (id) do nothing;

-- Minimal RLS baseline
alter table clients enable row level security;
alter table processes enable row level security;
alter table process_history enable row level security;
alter table process_checklist enable row level security;
alter table process_deadlines enable row level security;
alter table process_documents enable row level security;
alter table process_observations enable row level security;
alter table budgets enable row level security;
alter table service_contracts enable row level security;
alter table service_types enable row level security;
alter table checklist_templates enable row level security;
alter table user_profiles enable row level security;

create or replace function app_current_role()
returns text
language sql
stable
as $$
  select coalesce((select role from user_profiles where user_id = auth.uid()), 'operador');
$$;

do $$
begin
  if not exists (select 1 from pg_policies where policyname = 'authenticated_full_clients') then
    create policy authenticated_full_clients on clients for all to authenticated using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where policyname = 'authenticated_full_processes') then
    create policy authenticated_full_processes on processes for all to authenticated using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where policyname = 'authenticated_full_process_history') then
    create policy authenticated_full_process_history on process_history for all to authenticated using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where policyname = 'authenticated_full_process_checklist') then
    create policy authenticated_full_process_checklist on process_checklist for all to authenticated using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where policyname = 'authenticated_full_process_deadlines') then
    create policy authenticated_full_process_deadlines on process_deadlines for all to authenticated using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where policyname = 'authenticated_full_process_documents') then
    create policy authenticated_full_process_documents on process_documents for all to authenticated using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where policyname = 'authenticated_full_process_observations') then
    create policy authenticated_full_process_observations on process_observations for all to authenticated using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where policyname = 'authenticated_full_budgets') then
    create policy authenticated_full_budgets on budgets for all to authenticated using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where policyname = 'authenticated_full_service_contracts') then
    create policy authenticated_full_service_contracts on service_contracts for all to authenticated using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where policyname = 'authenticated_full_service_types') then
    create policy authenticated_full_service_types on service_types for all to authenticated using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where policyname = 'authenticated_full_checklist_templates') then
    create policy authenticated_full_checklist_templates on checklist_templates for all to authenticated using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where policyname = 'authenticated_own_user_profile') then
    create policy authenticated_own_user_profile on user_profiles for select to authenticated using (user_id = auth.uid());
  end if;
end $$;

drop policy if exists authenticated_full_service_types on service_types;
drop policy if exists authenticated_full_checklist_templates on checklist_templates;

do $$
begin
  if not exists (select 1 from pg_policies where policyname = 'authenticated_read_service_types') then
    create policy authenticated_read_service_types on service_types for select to authenticated using (true);
  end if;
  if not exists (select 1 from pg_policies where policyname = 'admin_write_service_types') then
    create policy admin_write_service_types on service_types for all to authenticated using (app_current_role() = 'admin') with check (app_current_role() = 'admin');
  end if;
  if not exists (select 1 from pg_policies where policyname = 'authenticated_read_checklist_templates') then
    create policy authenticated_read_checklist_templates on checklist_templates for select to authenticated using (true);
  end if;
  if not exists (select 1 from pg_policies where policyname = 'admin_write_checklist_templates') then
    create policy admin_write_checklist_templates on checklist_templates for all to authenticated using (app_current_role() = 'admin') with check (app_current_role() = 'admin');
  end if;
end $$;
