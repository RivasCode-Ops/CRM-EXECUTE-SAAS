-- 015: Prazos (process_deadlines) com lembrete WhatsApp configurável + RPC para o cron

alter table public.process_deadlines
  add column if not exists reminder_days_before integer not null default 1
    check (reminder_days_before >= 0 and reminder_days_before <= 365);

alter table public.process_deadlines
  add column if not exists whatsapp_reminder_sent_at timestamptz;

comment on column public.process_deadlines.reminder_days_before is
  'Dias antes da data do prazo (due_date) para enviar lembrete WhatsApp (0 = mesmo dia).';

comment on column public.process_deadlines.whatsapp_reminder_sent_at is
  'Quando foi enviado o lembrete WhatsApp desta linha; evita reenvio no mesmo ciclo.';

create index if not exists idx_process_deadlines_reminder_scan
  on public.process_deadlines (tenant_id, due_date)
  where is_done = false and whatsapp_reminder_sent_at is null;

-- Linhas cujo "dia de envio" = hoje (UTC): (due_date em UTC como data) - N dias = hoje
create or replace function public.deadlines_for_whatsapp_reminder()
returns table (
  deadline_id uuid,
  tenant_id uuid,
  process_id uuid,
  deadline_title text,
  due_date timestamptz,
  client_phone text,
  client_name text,
  process_reference text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    pd.id,
    pd.tenant_id,
    pd.process_id,
    pd.title,
    pd.due_date,
    coalesce(nullif(trim(c.phone::text), ''), '') as client_phone,
    coalesce(c.full_name::text, '') as client_name,
    coalesce(p.internal_code::text, p.public_code::text, p.id::text) as process_reference
  from public.process_deadlines pd
  inner join public.processes p on p.id = pd.process_id
  inner join public.clients c on c.id = p.client_id
  where not pd.is_done
    and pd.whatsapp_reminder_sent_at is null
    and nullif(trim(c.phone::text), '') is not null
    and ((pd.due_date at time zone 'utc')::date - pd.reminder_days_before)
      = ((timezone('utc', now()))::date);
$$;

comment on function public.deadlines_for_whatsapp_reminder() is
  'Prazos pendentes cujo lembrete deve ser enviado hoje (UTC), com telefone do cliente.';

revoke all on function public.deadlines_for_whatsapp_reminder() from public;
grant execute on function public.deadlines_for_whatsapp_reminder() to service_role;
