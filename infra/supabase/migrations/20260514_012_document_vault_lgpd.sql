-- 012: Document Vault + LGPD (metadados + auditoria; criptografia = TLS + bucket privado)
-- entity_type 'contract' => service_contracts (schema CRM)

insert into public.role_permissions (role, permission_key)
values
  ('admin', 'documents.read'),
  ('admin', 'documents.write'),
  ('admin', 'documents.admin'),
  ('operador', 'documents.read'),
  ('operador', 'documents.write')
on conflict (role, permission_key) do nothing;

insert into storage.buckets (id, name, public)
values ('document-vault', 'document-vault', false)
on conflict (id) do nothing;

create table if not exists public.documents (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null default app_current_tenant_id() references public.tenants (id) on delete cascade,
  entity_type text not null check (entity_type in ('property', 'lead', 'opportunity', 'contract')),
  entity_id uuid not null,
  doc_type text not null check (
    doc_type in ('matricula', 'contrato', 'rg', 'cpf', 'iptu', 'habite-se', 'outro')
  ),
  file_name text not null,
  file_path text not null,
  file_hash text not null,
  file_size_bytes bigint not null check (file_size_bytes > 0 and file_size_bytes <= 52428800),
  mime_type text not null,
  uploaded_by uuid not null references auth.users (id) on delete restrict,
  uploaded_at timestamptz not null default now(),
  expires_at timestamptz,
  consent_version text,
  is_encrypted boolean not null default true,
  deleted_at timestamptz,
  unique (entity_type, entity_id, doc_type, file_name)
);

create table if not exists public.document_access_logs (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.documents (id) on delete cascade,
  accessed_by uuid references auth.users (id) on delete set null,
  accessed_at timestamptz not null default now(),
  action text not null check (action in ('view', 'download', 'share', 'expiry_alert')),
  ip_address inet,
  user_agent text
);

create index if not exists idx_documents_tenant_entity
  on public.documents (tenant_id, entity_type, entity_id)
  where deleted_at is null;

create index if not exists idx_documents_expiring
  on public.documents (expires_at)
  where expires_at is not null and deleted_at is null;

create index if not exists idx_access_logs_document
  on public.document_access_logs (document_id, accessed_at desc);

alter table public.documents enable row level security;
alter table public.document_access_logs enable row level security;

drop policy if exists documents_select on public.documents;
drop policy if exists documents_insert on public.documents;
drop policy if exists documents_update on public.documents;

create policy documents_select on public.documents
  for select
  to authenticated
  using (
    tenant_id = app_current_tenant_id()
    and deleted_at is null
    and has_permission('documents.read')
  );

create policy documents_insert on public.documents
  for insert
  to authenticated
  with check (
    tenant_id = app_current_tenant_id()
    and has_permission('documents.write')
  );

create policy documents_update on public.documents
  for update
  to authenticated
  using (
    tenant_id = app_current_tenant_id()
    and has_permission('documents.write')
  )
  with check (
    tenant_id = app_current_tenant_id()
    and has_permission('documents.write')
  );

drop policy if exists document_access_logs_select on public.document_access_logs;
drop policy if exists document_access_logs_insert on public.document_access_logs;

create policy document_access_logs_select on public.document_access_logs
  for select
  to authenticated
  using (
    (
      accessed_by = auth.uid()
      and exists (
        select 1 from public.documents d
        where d.id = document_access_logs.document_id
          and d.tenant_id = app_current_tenant_id()
      )
    )
    or has_permission('documents.admin')
  );

create policy document_access_logs_insert on public.document_access_logs
  for insert
  to authenticated
  with check (
    exists (
      select 1 from public.documents d
      where d.id = document_access_logs.document_id
        and d.tenant_id = app_current_tenant_id()
        and has_permission('documents.read')
    )
    and accessed_by = auth.uid()
  );

create or replace function public.trg_set_document_tenant()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_tenant uuid;
begin
  case new.entity_type
    when 'property' then
      select tenant_id into v_tenant from public.properties where id = new.entity_id;
    when 'lead' then
      select tenant_id into v_tenant from public.leads where id = new.entity_id;
    when 'opportunity' then
      select tenant_id into v_tenant from public.opportunities where id = new.entity_id;
    when 'contract' then
      select tenant_id into v_tenant from public.service_contracts where id = new.entity_id;
    else
      raise exception 'INVALID_ENTITY_TYPE' using errcode = 'P0001';
  end case;

  if v_tenant is null then
    raise exception 'ENTITY_NOT_FOUND' using errcode = 'P0001';
  end if;

  if v_tenant is distinct from app_current_tenant_id() then
    raise exception 'TENANT_MISMATCH' using errcode = 'P0001';
  end if;

  new.tenant_id := v_tenant;
  return new;
end;
$$;

drop trigger if exists set_document_tenant on public.documents;

create trigger set_document_tenant
  before insert on public.documents
  for each row
  execute function public.trg_set_document_tenant();

-- Storage: primeiro segmento do path = tenant_id (UUID)
drop policy if exists document_vault_insert on storage.objects;
drop policy if exists document_vault_select on storage.objects;
drop policy if exists document_vault_delete on storage.objects;

create policy document_vault_insert on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'document-vault'
    and split_part(name, '/', 1) = app_current_tenant_id()::text
    and has_permission('documents.write')
  );

create policy document_vault_select on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'document-vault'
    and split_part(name, '/', 1) = app_current_tenant_id()::text
    and has_permission('documents.read')
  );

create policy document_vault_delete on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'document-vault'
    and split_part(name, '/', 1) = app_current_tenant_id()::text
    and has_permission('documents.write')
  );

comment on table public.documents is 'Vault de documentos imobiliarios; tenant via trigger; soft delete para auditoria.';
comment on table public.document_access_logs is 'Auditoria LGPD de acesso; expiry_alert com accessed_by nulo (cron).';
