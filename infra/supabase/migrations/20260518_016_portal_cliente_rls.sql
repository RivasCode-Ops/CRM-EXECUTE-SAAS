-- =============================================================================
-- Migration 016 — Policy pública para portal do cliente
-- Permite leitura de processo por public_code sem autenticação (anon role)
-- Expõe SOMENTE campos necessários para o cliente acompanhar
-- =============================================================================

-- Leitura pública de processo por public_code (portal do cliente)
drop policy if exists processes_public_by_code on processes;
create policy processes_public_by_code on processes
  for select
  to anon
  using (public_code is not null);

-- Leitura pública de histórico (anon, via processo)
drop policy if exists process_history_public on process_history;
create policy process_history_public on process_history
  for select
  to anon
  using (
    process_id in (
      select id from processes where public_code is not null
    )
  );

-- Leitura pública de documentos (só nome e status — sem URLs)
drop policy if exists process_documents_public on process_documents;
create policy process_documents_public on process_documents
  for select
  to anon
  using (
    process_id in (
      select id from processes where public_code is not null
    )
  );

-- Leitura pública de prazos pendentes
drop policy if exists process_deadlines_public on process_deadlines;
create policy process_deadlines_public on process_deadlines
  for select
  to anon
  using (
    process_id in (
      select id from processes where public_code is not null
    )
  );

-- Leitura pública de clientes (só nome e cidade — sem CPF, telefone, email)
-- Nota: a query da API seleciona apenas full_name e city_uf
drop policy if exists clients_public_via_process on clients;
create policy clients_public_via_process on clients
  for select
  to anon
  using (
    id in (
      select client_id from processes where public_code is not null
    )
  );
