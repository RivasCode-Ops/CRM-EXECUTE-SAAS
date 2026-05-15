-- =============================================================================
-- Migration 014 — RLS tenant-aware nas tabelas legadas (C5)
--
-- PROBLEMA: app_current_tenant_id() só lê JWT claim 'tenant_id'.
-- Como o app não injeta esse claim, a função retorna NULL no browser
-- e policies tenant-aware bloqueiam tudo.
--
-- SOLUÇÃO: adicionar fallback a user_profiles (já usado em comercial-auth.ts).
-- Ordem de prioridade:
--   1. JWT claim tenant_id (produção futura com Auth Hook)
--   2. request.jwt.claims (PostgREST)
--   3. user_profiles (funciona hoje, sem configuração extra)
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Corrige app_current_tenant_id() com fallback a user_profiles
-- ---------------------------------------------------------------------------
create or replace function public.app_current_tenant_id()
returns uuid
language sql
stable
security invoker
set search_path = public
as $$
  select coalesce(
    nullif((auth.jwt() ->> 'tenant_id'), '')::uuid,
    nullif((current_setting('request.jwt.claims', true)::json ->> 'tenant_id'), '')::uuid,
    (select tenant_id from public.user_profiles where user_id = auth.uid())
  );
$$;

comment on function public.app_current_tenant_id() is
  'Tenant atual: JWT claim tenant_id → request.jwt.claims → user_profiles (fallback).';

-- ---------------------------------------------------------------------------
-- 2. Drop das policies baseline using(true) nas tabelas legadas
-- ---------------------------------------------------------------------------
drop policy if exists authenticated_full_clients on public.clients;
drop policy if exists authenticated_full_processes on public.processes;
drop policy if exists authenticated_full_process_history on public.process_history;
drop policy if exists authenticated_full_process_checklist on public.process_checklist;
drop policy if exists authenticated_full_process_deadlines on public.process_deadlines;
drop policy if exists authenticated_full_process_documents on public.process_documents;
drop policy if exists authenticated_full_process_observations on public.process_observations;
drop policy if exists authenticated_full_budgets on public.budgets;
drop policy if exists authenticated_full_service_contracts on public.service_contracts;

-- ---------------------------------------------------------------------------
-- 3. Policies tenant-aware (drop antes de create — idempotente em dev)
-- ---------------------------------------------------------------------------

-- clients
drop policy if exists clients_tenant_select on public.clients;
drop policy if exists clients_tenant_insert on public.clients;
drop policy if exists clients_tenant_update on public.clients;
drop policy if exists clients_tenant_delete on public.clients;

create policy clients_tenant_select on public.clients
  for select to authenticated
  using (tenant_id = public.app_current_tenant_id());

create policy clients_tenant_insert on public.clients
  for insert to authenticated
  with check (tenant_id = public.app_current_tenant_id());

create policy clients_tenant_update on public.clients
  for update to authenticated
  using (tenant_id = public.app_current_tenant_id())
  with check (tenant_id = public.app_current_tenant_id());

create policy clients_tenant_delete on public.clients
  for delete to authenticated
  using (tenant_id = public.app_current_tenant_id());

-- processes
drop policy if exists processes_tenant_select on public.processes;
drop policy if exists processes_tenant_insert on public.processes;
drop policy if exists processes_tenant_update on public.processes;
drop policy if exists processes_tenant_delete on public.processes;

create policy processes_tenant_select on public.processes
  for select to authenticated
  using (tenant_id = public.app_current_tenant_id());

create policy processes_tenant_insert on public.processes
  for insert to authenticated
  with check (tenant_id = public.app_current_tenant_id());

create policy processes_tenant_update on public.processes
  for update to authenticated
  using (tenant_id = public.app_current_tenant_id())
  with check (tenant_id = public.app_current_tenant_id());

create policy processes_tenant_delete on public.processes
  for delete to authenticated
  using (tenant_id = public.app_current_tenant_id());

-- process_history
drop policy if exists process_history_tenant_select on public.process_history;
drop policy if exists process_history_tenant_insert on public.process_history;
drop policy if exists process_history_tenant_update on public.process_history;
drop policy if exists process_history_tenant_delete on public.process_history;

create policy process_history_tenant_select on public.process_history
  for select to authenticated
  using (tenant_id = public.app_current_tenant_id());

create policy process_history_tenant_insert on public.process_history
  for insert to authenticated
  with check (tenant_id = public.app_current_tenant_id());

create policy process_history_tenant_update on public.process_history
  for update to authenticated
  using (tenant_id = public.app_current_tenant_id())
  with check (tenant_id = public.app_current_tenant_id());

create policy process_history_tenant_delete on public.process_history
  for delete to authenticated
  using (tenant_id = public.app_current_tenant_id());

-- process_checklist
drop policy if exists process_checklist_tenant_select on public.process_checklist;
drop policy if exists process_checklist_tenant_insert on public.process_checklist;
drop policy if exists process_checklist_tenant_update on public.process_checklist;
drop policy if exists process_checklist_tenant_delete on public.process_checklist;

create policy process_checklist_tenant_select on public.process_checklist
  for select to authenticated
  using (tenant_id = public.app_current_tenant_id());

create policy process_checklist_tenant_insert on public.process_checklist
  for insert to authenticated
  with check (tenant_id = public.app_current_tenant_id());

create policy process_checklist_tenant_update on public.process_checklist
  for update to authenticated
  using (tenant_id = public.app_current_tenant_id())
  with check (tenant_id = public.app_current_tenant_id());

create policy process_checklist_tenant_delete on public.process_checklist
  for delete to authenticated
  using (tenant_id = public.app_current_tenant_id());

-- process_deadlines
drop policy if exists process_deadlines_tenant_select on public.process_deadlines;
drop policy if exists process_deadlines_tenant_insert on public.process_deadlines;
drop policy if exists process_deadlines_tenant_update on public.process_deadlines;
drop policy if exists process_deadlines_tenant_delete on public.process_deadlines;

create policy process_deadlines_tenant_select on public.process_deadlines
  for select to authenticated
  using (tenant_id = public.app_current_tenant_id());

create policy process_deadlines_tenant_insert on public.process_deadlines
  for insert to authenticated
  with check (tenant_id = public.app_current_tenant_id());

create policy process_deadlines_tenant_update on public.process_deadlines
  for update to authenticated
  using (tenant_id = public.app_current_tenant_id())
  with check (tenant_id = public.app_current_tenant_id());

create policy process_deadlines_tenant_delete on public.process_deadlines
  for delete to authenticated
  using (tenant_id = public.app_current_tenant_id());

-- process_documents
drop policy if exists process_documents_tenant_select on public.process_documents;
drop policy if exists process_documents_tenant_insert on public.process_documents;
drop policy if exists process_documents_tenant_update on public.process_documents;
drop policy if exists process_documents_tenant_delete on public.process_documents;

create policy process_documents_tenant_select on public.process_documents
  for select to authenticated
  using (tenant_id = public.app_current_tenant_id());

create policy process_documents_tenant_insert on public.process_documents
  for insert to authenticated
  with check (tenant_id = public.app_current_tenant_id());

create policy process_documents_tenant_update on public.process_documents
  for update to authenticated
  using (tenant_id = public.app_current_tenant_id())
  with check (tenant_id = public.app_current_tenant_id());

create policy process_documents_tenant_delete on public.process_documents
  for delete to authenticated
  using (tenant_id = public.app_current_tenant_id());

-- process_observations
drop policy if exists process_observations_tenant_select on public.process_observations;
drop policy if exists process_observations_tenant_insert on public.process_observations;
drop policy if exists process_observations_tenant_update on public.process_observations;
drop policy if exists process_observations_tenant_delete on public.process_observations;

create policy process_observations_tenant_select on public.process_observations
  for select to authenticated
  using (tenant_id = public.app_current_tenant_id());

create policy process_observations_tenant_insert on public.process_observations
  for insert to authenticated
  with check (tenant_id = public.app_current_tenant_id());

create policy process_observations_tenant_update on public.process_observations
  for update to authenticated
  using (tenant_id = public.app_current_tenant_id())
  with check (tenant_id = public.app_current_tenant_id());

create policy process_observations_tenant_delete on public.process_observations
  for delete to authenticated
  using (tenant_id = public.app_current_tenant_id());

-- budgets
drop policy if exists budgets_tenant_select on public.budgets;
drop policy if exists budgets_tenant_insert on public.budgets;
drop policy if exists budgets_tenant_update on public.budgets;
drop policy if exists budgets_tenant_delete on public.budgets;

create policy budgets_tenant_select on public.budgets
  for select to authenticated
  using (tenant_id = public.app_current_tenant_id());

create policy budgets_tenant_insert on public.budgets
  for insert to authenticated
  with check (tenant_id = public.app_current_tenant_id());

create policy budgets_tenant_update on public.budgets
  for update to authenticated
  using (tenant_id = public.app_current_tenant_id())
  with check (tenant_id = public.app_current_tenant_id());

create policy budgets_tenant_delete on public.budgets
  for delete to authenticated
  using (tenant_id = public.app_current_tenant_id());

-- service_contracts
drop policy if exists service_contracts_tenant_select on public.service_contracts;
drop policy if exists service_contracts_tenant_insert on public.service_contracts;
drop policy if exists service_contracts_tenant_update on public.service_contracts;
drop policy if exists service_contracts_tenant_delete on public.service_contracts;

create policy service_contracts_tenant_select on public.service_contracts
  for select to authenticated
  using (tenant_id = public.app_current_tenant_id());

create policy service_contracts_tenant_insert on public.service_contracts
  for insert to authenticated
  with check (tenant_id = public.app_current_tenant_id());

create policy service_contracts_tenant_update on public.service_contracts
  for update to authenticated
  using (tenant_id = public.app_current_tenant_id())
  with check (tenant_id = public.app_current_tenant_id());

create policy service_contracts_tenant_delete on public.service_contracts
  for delete to authenticated
  using (tenant_id = public.app_current_tenant_id());
