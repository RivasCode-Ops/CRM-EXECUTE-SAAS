import type { SupabaseClient } from "@supabase/supabase-js";

export async function listProcessos(supabase: SupabaseClient) {
  const { data: projection, error: projError } = await supabase
    .from("processos_projection")
    .select("*")
    .order("ultima_atualizacao", { ascending: false });

  if (!projError && projection && projection.length > 0) {
    return { processos: projection, source: "projection" as const };
  }

  const { data: processos, error } = await supabase
    .from("processos")
    .select(
      `
      id,
      numero,
      tipo,
      status,
      data_entrada,
      prazo_conclusao,
      imovel_descricao,
      cliente_id,
      clientes ( nome )
    `,
    )
    .is("deleted_at", null)
    .order("criado_em", { ascending: false });

  if (error) throw error;

  return {
    processos: (processos ?? []).map((p) => ({
      id: p.id,
      numero: p.numero,
      tipo: p.tipo,
      status: p.status,
      data_entrada: p.data_entrada,
      prazo_conclusao: p.prazo_conclusao,
      imovel_descricao: p.imovel_descricao,
      cliente_id: p.cliente_id,
      cliente_nome:
        p.clientes && typeof p.clientes === "object" && "nome" in p.clientes
          ? (p.clientes as { nome: string }).nome
          : null,
    })),
    source: "processos" as const,
  };
}
