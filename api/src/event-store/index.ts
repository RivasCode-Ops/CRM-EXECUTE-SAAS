import type { SupabaseClient } from "@supabase/supabase-js";

export type DomainEvent = {
  aggregateType: string;
  aggregateId: string;
  eventType: string;
  payload: Record<string, unknown>;
  organizationId: string;
  userId?: string;
  correlationId?: string;
  metadata?: Record<string, unknown>;
};

export async function appendEvent(
  supabase: SupabaseClient,
  event: DomainEvent,
): Promise<{ id: string }> {
  const { data, error } = await supabase
    .from("event_store")
    .insert({
      aggregate_type: event.aggregateType,
      aggregate_id: event.aggregateId,
      event_type: event.eventType,
      payload: event.payload,
      organization_id: event.organizationId,
      user_id: event.userId ?? null,
      correlation_id: event.correlationId ?? null,
      metadata: event.metadata ?? null,
    })
    .select("id")
    .single();

  if (error) throw error;
  return { id: data.id };
}
