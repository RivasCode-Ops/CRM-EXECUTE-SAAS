-- Migration: auth, rls and document storage baseline
-- Run after the base schema on new or existing environments.

alter table if exists process_documents
  add column if not exists file_path text;

insert into storage.buckets (id, name, public)
values ('process-documents', 'process-documents', true)
on conflict (id) do nothing;

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
create table if not exists user_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('admin', 'operador')),
  created_at timestamptz not null default now()
);
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
