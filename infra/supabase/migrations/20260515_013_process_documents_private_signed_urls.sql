-- C7: bucket process-documents privado; RLS em storage.objects para leitura/escrita autenticada (signed URLs + upload).

update storage.buckets
set public = false
where id = 'process-documents';

drop policy if exists process_documents_storage_all on storage.objects;

create policy process_documents_storage_all on storage.objects
  for all
  to authenticated
  using (bucket_id = 'process-documents')
  with check (bucket_id = 'process-documents');
