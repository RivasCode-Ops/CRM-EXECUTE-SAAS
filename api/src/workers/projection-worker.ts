import "dotenv/config";
import { Worker } from "bullmq";
import { redis } from "../lib/redis";
import { supabase } from "../lib/supabase";
import { assertSupabaseEnv } from "../utils/env";

type ProcessoEvento = {
  aggregate_type: string;
  aggregate_id: string;
  event_type: string;
  organization_id: string;
  user_id?: string;
  payload: {
    tipo?: string;
    cliente_id?: string;
    imovel_descricao?: string;
    imovel_matricula?: string;
    prazo_conclusao?: string;
    status_anterior?: string;
    status_novo?: string;
  };
};

assertSupabaseEnv();

if (!redis) {
  console.error("REDIS_URL e REDIS_TOKEN são obrigatórios para o worker.");
  process.exit(1);
}

const worker = new Worker(
  "event-processing",
  async (job) => {
    const evento = job.data as ProcessoEvento;

    console.log(
      `Processando evento: ${evento.event_type} para agregado ${evento.aggregate_id}`,
    );

    if (evento.aggregate_type === "processo") {
      if (evento.event_type === "processo_criado") {
        const { data: cliente } = await supabase
          .from("clientes")
          .select("nome")
          .eq("id", evento.payload.cliente_id!)
          .maybeSingle();

        const { error: processoError } = await supabase.from("processos").insert({
          id: evento.aggregate_id,
          organization_id: evento.organization_id,
          tipo: evento.payload.tipo,
          status: "captacao",
          cliente_id: evento.payload.cliente_id,
          imovel_descricao: evento.payload.imovel_descricao,
          imovel_matricula: evento.payload.imovel_matricula,
          prazo_conclusao: evento.payload.prazo_conclusao,
        });

        if (processoError) {
          throw new Error(processoError.message);
        }

        const { error: projError } = await supabase
          .from("processos_projection")
          .insert({
            id: evento.aggregate_id,
            organization_id: evento.organization_id,
            tipo: evento.payload.tipo,
            status: "captacao",
            cliente_id: evento.payload.cliente_id,
            cliente_nome: cliente?.nome ?? null,
            imovel_descricao: evento.payload.imovel_descricao,
            imovel_matricula: evento.payload.imovel_matricula,
            prazo_conclusao: evento.payload.prazo_conclusao,
            data_entrada: new Date().toISOString().slice(0, 10),
            ultima_atualizacao: new Date().toISOString(),
            criado_em: new Date().toISOString(),
          });

        if (projError) {
          throw new Error(projError.message);
        }
      }

      if (evento.event_type === "processo_status_alterado") {
        const statusNovo = evento.payload.status_novo;

        await supabase
          .from("processos")
          .update({
            status: statusNovo,
            atualizado_em: new Date().toISOString(),
          })
          .eq("id", evento.aggregate_id)
          .eq("organization_id", evento.organization_id);

        const { error } = await supabase
          .from("processos_projection")
          .update({
            status: statusNovo,
            ultima_atualizacao: new Date().toISOString(),
          })
          .eq("id", evento.aggregate_id);

        if (error) {
          throw new Error(error.message);
        }
      }
    }

    return { success: true };
  },
  { connection: redis },
);

worker.on("completed", (job) => {
  console.log(`Job ${job.id} concluído`);
});

worker.on("failed", (job, err) => {
  console.error(`Job ${job?.id} falhou:`, err);
});

console.log("Worker de projeção iniciado");
