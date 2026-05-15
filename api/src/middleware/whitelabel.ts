import type { FastifyReply, FastifyRequest } from "fastify";
import { supabase } from "../lib/supabase";

export interface WhiteLabelContext {
  organization_id: string;
  slug: string;
  logo_url: string | null;
  primary_color: string | null;
}

declare module "fastify" {
  interface FastifyRequest {
    whiteLabel?: WhiteLabelContext;
  }
}

/** Resolve organização pelo domínio customizado (Host header). */
export async function whiteLabelMiddleware(
  request: FastifyRequest,
  _reply: FastifyReply,
): Promise<void> {
  const host = request.headers.host?.split(":")[0];
  if (!host || host === "localhost" || host.endsWith(".railway.app")) {
    return;
  }

  const { data: org } = await supabase
    .from("organizations")
    .select("id, slug, logo_url, primary_color, custom_domain")
    .eq("custom_domain", host)
    .maybeSingle();

  if (org) {
    request.whiteLabel = {
      organization_id: org.id,
      slug: org.slug,
      logo_url: org.logo_url,
      primary_color: org.primary_color,
    };
  }
}
