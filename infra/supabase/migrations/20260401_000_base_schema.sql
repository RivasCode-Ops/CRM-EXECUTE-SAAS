-- =============================================================================
-- Migration 000 — Base Schema (fonte de verdade, substitui schema_mvp.sql)
-- Idempotente: seguro rodar múltiplas vezes em DB vazio ou existente.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- TABELA RAIZ: tenants
-- Todas as outras tabelas referenciam esta via FK tenant_id.
-- ---------------------------------------------------------------------------
create table if not exists tenants (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  slug        text not null unique,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- ENUMS
-- ---------------------------------------------------------------------------
do $$ begin
  if not exists (select 1 from pg_type where typname = 'process_status') then
    create type process_status as enum (
      'novo', 'documentos_em_coleta', 'protocolado', 'em_analise',
      'com_exigencia', 'aguardando_cliente', 'retorno_agendado',
      'atrasado', 'concluido', 'arquivado', 'cancelado'
    );
  end if;
end $$;

do $$ begin
  if not exists (select 1 from pg_type where typname = 'document_status') then
    create type document_status as enum ('pendente', 'recebido');
  end if;
end $$;

do $$ begin
  if not exists (select 1 from pg_type where typname = 'budget_status') then
    create type budget_status as enum ('rascunho', 'enviado', 'aprovado', 'rejeitado');
  end if;
end $$;

do $$ begin
  if not exists (select 1 from pg_type where typname = 'contract_status') then
    create type contract_status as enum ('ativo', 'encerrado', 'cancelado');
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- USER PROFILES
-- ---------------------------------------------------------------------------
create table if not exists user_profiles (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  tenant_id  uuid not null references tenants(id) on delete cascade,
  role       text not null check (role in ('admin', 'operador')),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- CLIENTS
-- cpf_cnpj único por tenant (não global) — corrige H4 da auditoria
-- ---------------------------------------------------------------------------
create table if not exists clients (
  id         uuid primary key default gen_random_uuid(),
  tenant_id  uuid not null references tenants(id) on delete cascade,
  full_name  text not null,
  cpf_cnpj   text not null,
  phone      text,
  email      text,
  city_uf    text,
  created_at timestamptz not null default now(),
  constraint uq_clients_tenant_cpf unique (tenant_id, cpf_cnpj)
);

-- ---------------------------------------------------------------------------
-- PROCESSES
-- internal_code único por tenant (não global) — corrige H4
-- ---------------------------------------------------------------------------
create table if not exists processes (
  id              uuid primary key default gen_random_uuid(),
  tenant_id       uuid not null references tenants(id) on delete cascade,
  internal_code   text not null,
  public_code     text,
  client_id       uuid not null references clients(id) on delete cascade,
  title           text not null,
  service_type    text not null,
  status          process_status not null default 'novo',
  current_stage   text not null default 'abertura',
  protocol_number text,
  due_date        date,
  created_at      timestamptz not null default now(),
  constraint uq_processes_tenant_code unique (tenant_id, internal_code)
);

-- ---------------------------------------------------------------------------
-- PROCESS — tabelas filhas
-- ---------------------------------------------------------------------------
create table if not exists process_history (
  id         uuid primary key default gen_random_uuid(),
  tenant_id  uuid not null references tenants(id) on delete cascade,
  process_id uuid not null references processes(id) on delete cascade,
  action     text not null,
  description text,
  created_at timestamptz not null default now()
);

create table if not exists process_checklist (
  id         uuid primary key default gen_random_uuid(),
  tenant_id  uuid not null references tenants(id) on delete cascade,
  process_id uuid not null references processes(id) on delete cascade,
  title      text not null,
  is_done    boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists process_deadlines (
  id         uuid primary key default gen_random_uuid(),
  tenant_id  uuid not null references tenants(id) on delete cascade,
  process_id uuid not null references processes(id) on delete cascade,
  title      text not null,
  due_date   timestamptz not null,
  is_done    boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists process_documents (
  id         uuid primary key default gen_random_uuid(),
  tenant_id  uuid not null references tenants(id) on delete cascade,
  process_id uuid not null references processes(id) on delete cascade,
  name       text not null,
  status     document_status not null default 'pendente',
  file_url   text,
  created_at timestamptz not null default now()
);

create table if not exists process_observations (
  id         uuid primary key default gen_random_uuid(),
  tenant_id  uuid not null references tenants(id) on delete cascade,
  process_id uuid not null references processes(id) on delete cascade,
  content    text not null,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- BUDGETS
-- code único por tenant — corrige H4
-- ---------------------------------------------------------------------------
create table if not exists budgets (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null references tenants(id) on delete cascade,
  code        text not null,
  client_id   uuid not null references clients(id) on delete cascade,
  process_id  uuid not null references processes(id) on delete cascade,
  description text not null,
  amount      numeric(14,2) not null default 0,
  valid_until timestamptz not null,
  status      budget_status not null default 'rascunho',
  created_at  timestamptz not null default now(),
  constraint uq_budgets_tenant_code unique (tenant_id, code)
);

-- ---------------------------------------------------------------------------
-- SERVICE CONTRACTS
-- code único por tenant — corrige H4
-- ---------------------------------------------------------------------------
create table if not exists service_contracts (
  id            uuid primary key default gen_random_uuid(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  code          text not null,
  budget_id     uuid references budgets(id) on delete set null,
  client_id     uuid not null references clients(id) on delete cascade,
  process_id    uuid references processes(id) on delete set null,
  scope         text not null,
  closed_amount numeric(14,2) not null default 0,
  starts_at     timestamptz not null,
  ends_at       timestamptz not null,
  status        contract_status not null default 'ativo',
  created_at    timestamptz not null default now(),
  constraint uq_service_contracts_tenant_code unique (tenant_id, code)
);

-- ---------------------------------------------------------------------------
-- SERVICE TYPES & CHECKLIST TEMPLATES
-- name único por tenant — corrige H4/H5
-- ---------------------------------------------------------------------------
create table if not exists service_types (
  id         uuid primary key default gen_random_uuid(),
  tenant_id  uuid not null references tenants(id) on delete cascade,
  name       text not null,
  is_active  boolean not null default true,
  created_at timestamptz not null default now(),
  constraint uq_service_types_tenant_name unique (tenant_id, name)
);

create table if not exists checklist_templates (
  id         uuid primary key default gen_random_uuid(),
  tenant_id  uuid not null references tenants(id) on delete cascade,
  service    text not null,
  title      text not null,
  is_active  boolean not null default true,
  created_at timestamptz not null default now(),
  constraint uq_checklist_templates_tenant unique (tenant_id, service, title)
);

-- ---------------------------------------------------------------------------
-- ÍNDICES
-- ---------------------------------------------------------------------------
create index if not exists idx_user_profiles_tenant_id        on user_profiles (tenant_id);
create index if not exists idx_clients_tenant_id              on clients (tenant_id);
create index if not exists idx_processes_tenant_id            on processes (tenant_id);
create index if not exists idx_process_history_process_id     on process_history (process_id);
create index if not exists idx_process_checklist_process_id   on process_checklist (process_id);
create index if not exists idx_process_deadlines_process_id   on process_deadlines (process_id);
create index if not exists idx_process_documents_process_id   on process_documents (process_id);
create index if not exists idx_process_observations_process_id on process_observations (process_id);
create index if not exists idx_budgets_process_id             on budgets (process_id);
create index if not exists idx_budgets_client_id              on budgets (client_id);
create index if not exists idx_budgets_tenant_id              on budgets (tenant_id);
create index if not exists idx_service_contracts_process_id   on service_contracts (process_id);
create index if not exists idx_service_contracts_budget_id    on service_contracts (budget_id);
create index if not exists idx_service_contracts_tenant_id    on service_contracts (tenant_id);
create index if not exists idx_service_types_tenant_id        on service_types (tenant_id);
create index if not exists idx_checklist_templates_tenant_id  on checklist_templates (tenant_id);

-- ---------------------------------------------------------------------------
-- STORAGE BUCKET — privado (corrige C7 da auditoria)
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('process-documents', 'process-documents', false)
on conflict (id) do update set public = false;

-- ---------------------------------------------------------------------------
-- RLS — habilitar em todas as tabelas
-- ---------------------------------------------------------------------------
alter table tenants              enable row level security;
alter table user_profiles        enable row level security;
alter table clients              enable row level security;
alter table processes            enable row level security;
alter table process_history      enable row level security;
alter table process_checklist    enable row level security;
alter table process_deadlines    enable row level security;
alter table process_documents    enable row level security;
alter table process_observations enable row level security;
alter table budgets              enable row level security;
alter table service_contracts    enable row level security;
alter table service_types        enable row level security;
alter table checklist_templates  enable row level security;

-- ---------------------------------------------------------------------------
-- FUNÇÕES AUXILIARES
-- ---------------------------------------------------------------------------
create or replace function app_current_role()
returns text
language sql stable security invoker
set search_path = public
as $$
  select coalesce(
    (select role from user_profiles where user_id = auth.uid()),
    'operador'
  );
$$;

create or replace function app_current_tenant_id()
returns uuid
language sql stable security invoker
set search_path = public
as $$
  select tenant_id from user_profiles where user_id = auth.uid();
$$;

-- ---------------------------------------------------------------------------
-- POLICIES BASELINE (using(true) — serão substituídas nas migrations 004-007)
-- ---------------------------------------------------------------------------
do $$ begin
  -- tenants: cada usuário vê só o seu
  if not exists (select 1 from pg_policies where tablename='tenants' and policyname='tenant_own_read') then
    create policy tenant_own_read on tenants for select to authenticated
      using (id = app_current_tenant_id());
  end if;

  -- user_profiles: cada um vê o próprio
  if not exists (select 1 from pg_policies where tablename='user_profiles' and policyname='authenticated_own_user_profile') then
    create policy authenticated_own_user_profile on user_profiles for select to authenticated
      using (user_id = auth.uid());
  end if;

  -- tabelas operacionais: baseline using(true) — substituídas em 004-007
  if not exists (select 1 from pg_policies where tablename='clients' and policyname='authenticated_full_clients') then
    create policy authenticated_full_clients on clients for all to authenticated using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where tablename='processes' and policyname='authenticated_full_processes') then
    create policy authenticated_full_processes on processes for all to authenticated using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where tablename='process_history' and policyname='authenticated_full_process_history') then
    create policy authenticated_full_process_history on process_history for all to authenticated using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where tablename='process_checklist' and policyname='authenticated_full_process_checklist') then
    create policy authenticated_full_process_checklist on process_checklist for all to authenticated using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where tablename='process_deadlines' and policyname='authenticated_full_process_deadlines') then
    create policy authenticated_full_process_deadlines on process_deadlines for all to authenticated using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where tablename='process_documents' and policyname='authenticated_full_process_documents') then
    create policy authenticated_full_process_documents on process_documents for all to authenticated using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where tablename='process_observations' and policyname='authenticated_full_process_observations') then
    create policy authenticated_full_process_observations on process_observations for all to authenticated using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where tablename='budgets' and policyname='authenticated_full_budgets') then
    create policy authenticated_full_budgets on budgets for all to authenticated using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where tablename='service_contracts' and policyname='authenticated_full_service_contracts') then
    create policy authenticated_full_service_contracts on service_contracts for all to authenticated using (true) with check (true);
  end if;

  -- service_types e checklist_templates: leitura livre, escrita só admin
  if not exists (select 1 from pg_policies where tablename='service_types' and policyname='authenticated_read_service_types') then
    create policy authenticated_read_service_types on service_types for select to authenticated using (true);
  end if;
  if not exists (select 1 from pg_policies where tablename='service_types' and policyname='admin_write_service_types') then
    create policy admin_write_service_types on service_types for all to authenticated
      using (app_current_role() = 'admin') with check (app_current_role() = 'admin');
  end if;
  if not exists (select 1 from pg_policies where tablename='checklist_templates' and policyname='authenticated_read_checklist_templates') then
    create policy authenticated_read_checklist_templates on checklist_templates for select to authenticated using (true);
  end if;
  if not exists (select 1 from pg_policies where tablename='checklist_templates' and policyname='admin_write_checklist_templates') then
    create policy admin_write_checklist_templates on checklist_templates for all to authenticated
      using (app_current_role() = 'admin') with check (app_current_role() = 'admin');
  end if;
end $$;
