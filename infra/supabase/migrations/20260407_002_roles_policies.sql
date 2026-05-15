-- Migration: roles and admin-only policies for settings tables

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
