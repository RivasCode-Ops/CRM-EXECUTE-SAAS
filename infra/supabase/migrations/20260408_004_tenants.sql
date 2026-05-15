-- 004: tabela `tenants` (RECRIADA — original perdido).
--
-- ORDEM DE EXECUCAO: este arquivo tem timestamp `20260408` (anterior a 003 = `20260430`)
-- porque 003 cria leads/opportunities/tasks/activities com `references public.tenants(id)`.
-- Sem 004 rodando primeiro, 003 falha com `relation "public.tenants" does not exist`.
--
-- Schema decidido: minimo + slug unico (multi-tenant SaaS basico).
-- Tenant signup/admin: usar service_role em server action (RLS abaixo nao permite insert via authenticated).

create table if not exists public.tenants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null,
  created_at timestamptz not null default now(),
  constraint tenants_slug_format check (slug ~ '^[a-z0-9][a-z0-9-]{2,62}$')
);

create unique index if not exists tenants_slug_key on public.tenants (slug);

alter table public.tenants enable row level security;

-- Helper de tenant atual — sera SUBSTITUIDO pela versao completa em 008
-- (com fallback `request.jwt.claims` para uso fora do PostgREST).
-- Aqui fica a versao minima para policies funcionarem desde ja.
create or replace function public.app_current_tenant_id()
returns uuid
language sql
stable
security invoker
set search_path = public
as $$
  select nullif((auth.jwt() ->> 'tenant_id'), '')::uuid;
$$;

comment on function public.app_current_tenant_id() is
  'Tenant atual via claim JWT tenant_id (versao minima; sera estendida em 008).';

-- Policy: usuario autenticado le APENAS o proprio tenant.
-- Sem policy de INSERT/UPDATE/DELETE para authenticated: signup/admin vai por service_role.
do $$
begin
  if not exists (select 1 from pg_policies where policyname = 'tenants_select_own') then
    create policy tenants_select_own on public.tenants
      for select
      to authenticated
      using (id = app_current_tenant_id());
  end if;
end $$;

comment on table public.tenants is
  'Tenants do CRM multi-tenant. RLS: cada usuario ve apenas seu proprio tenant.';
