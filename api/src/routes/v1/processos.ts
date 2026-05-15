import type { FastifyInstance, FastifyReply } from "fastify";
import { authMiddleware, type AuthRequest } from "../../middleware/auth";
import { supabase } from "../../lib/supabase";
import { eventQueue } from "../../lib/redis";

export async function processosRoutes(fastify: FastifyInstance) {
  fastify.get(
    "/v1/processos",
    { preHandler: authMiddleware },
    async (request: AuthRequest, reply: FastifyReply) => {
      const { organization_id } = request.user!;

      const { data, error } = await supabase
        .from("processos_projection")
        .select("*")
        .eq("organization_id", organization_id)
        .order("criado_em", { ascending: false });

      if (error) {
        return reply.status(500).send({ error: error.message });
      }

      return { processos: data };
    },
  );

  fastify.post(
    "/v1/processos",
    { preHandler: authMiddleware },
    async (request: AuthRequest, reply: FastifyReply) => {
      const { organization_id, id: user_id } = request.user!;
      const body = request.body as Record<string, unknown>;

      const { data: org } = await supabase
        .from("organizations")
        .select("max_processos, plano")
        .eq("id", organization_id)
        .single();

      const { count } = await supabase
        .from("processos")
        .select("*", { count: "exact", head: true })
        .eq("organization_id", organization_id);

      if (count && org?.max_processos && count >= org.max_processos) {
        return reply.status(402).send({ error: "Limite de processos do plano atingido" });
      }

      const evento = {
        aggregate_type: "processo",
        aggregate_id: crypto.randomUUID(),
        event_type: "processo_criado",
        event_version: 1,
        payload: {
          tipo: body.tipo,
          cliente_id: body.cliente_id,
          imovel_descricao: body.imovel_descricao,
          imovel_matricula: body.imovel_matricula,
          prazo_conclusao: body.prazo_conclusao,
        },
        metadata: {
          user_id,
          organization_id,
          ip: request.ip,
        },
        organization_id,
        user_id,
        correlation_id: crypto.randomUUID(),
      };

      const { error } = await supabase.from("event_store").insert(evento);

      if (error) {
        return reply.status(500).send({ error: error.message });
      }

      if (eventQueue) {
        await eventQueue.add("process-evento", evento);
      }

      return reply.status(201).send({
        message: "Processo criado com sucesso",
        aggregate_id: evento.aggregate_id,
      });
    },
  );

  fastify.get(
    "/v1/processos/:id",
    { preHandler: authMiddleware },
    async (request: AuthRequest, reply: FastifyReply) => {
      const { organization_id } = request.user!;
      const { id } = request.params as { id: string };

      const { data, error } = await supabase
        .from("processos")
        .select("*, cliente:clientes(*), honorarios(*)")
        .eq("id", id)
        .eq("organization_id", organization_id)
        .single();

      if (error) {
        return reply.status(404).send({ error: "Processo não encontrado" });
      }

      return { processo: data };
    },
  );

  fastify.patch(
    "/v1/processos/:id/status",
    { preHandler: authMiddleware },
    async (request: AuthRequest, reply: FastifyReply) => {
      const { organization_id, id: user_id } = request.user!;
      const { id } = request.params as { id: string };
      const { status } = request.body as { status: string };

      const { data: processo } = await supabase
        .from("processos")
        .select("status")
        .eq("id", id)
        .eq("organization_id", organization_id)
        .single();

      if (!processo) {
        return reply.status(404).send({ error: "Processo não encontrado" });
      }

      const evento = {
        aggregate_type: "processo",
        aggregate_id: id,
        event_type: "processo_status_alterado",
        event_version: 1,
        payload: {
          status_anterior: processo.status,
          status_novo: status,
        },
        metadata: {
          user_id,
          organization_id,
          ip: request.ip,
        },
        organization_id,
        user_id,
        correlation_id: crypto.randomUUID(),
      };

      await supabase.from("event_store").insert(evento);
      if (eventQueue) {
        await eventQueue.add("process-evento", evento);
      }

      return { message: "Status atualizado com sucesso" };
    },
  );
}
