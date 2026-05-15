import type { FastifyReply, FastifyRequest } from "fastify";
import type { FastifyPluginAsync } from "fastify";
import type { SupabaseClient } from "@supabase/supabase-js";
import fp from "fastify-plugin";
import { createAuthenticatedClient } from "../lib/supabase";

export interface AuthUser {
  id: string;
  email: string;
  organization_id: string;
  role: string;
}

export type AuthRequest = FastifyRequest & {
  user?: AuthUser;
  supabase?: SupabaseClient;
};

declare module "fastify" {
  interface FastifyRequest {
    user?: AuthUser;
    supabase?: SupabaseClient;
  }
}

export async function authMiddleware(
  request: FastifyRequest,
  reply: FastifyReply,
): Promise<void> {
  try {
    const token = request.headers.authorization?.replace("Bearer ", "");

    if (!token) {
      reply.status(401).send({ error: "Token não fornecido" });
      return;
    }

    const supabase = createAuthenticatedClient(token);
    const {
      data: { user },
      error,
    } = await supabase.auth.getUser();

    if (error || !user) {
      reply.status(401).send({ error: "Token inválido" });
      return;
    }

    const { data: member, error: memberError } = await supabase
      .from("organization_members")
      .select("organization_id, perfil")
      .eq("user_id", user.id)
      .eq("ativo", true)
      .maybeSingle();

    if (memberError || !member) {
      reply.status(403).send({ error: "Usuário não pertence a nenhuma organização" });
      return;
    }

    request.user = {
      id: user.id,
      email: user.email ?? "",
      organization_id: member.organization_id,
      role: member.perfil,
    };
    request.supabase = supabase;
  } catch {
    reply.status(401).send({ error: "Erro na autenticação" });
  }
}

export const authenticate = authMiddleware;

const authPlugin: FastifyPluginAsync = async () => {
  /* user e supabase definidos em authMiddleware */
};

export default fp(authPlugin);
