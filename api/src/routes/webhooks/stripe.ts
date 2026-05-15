import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify";
import type Stripe from "stripe";
import { supabase } from "../../lib/supabase";
import { getStripe } from "../../lib/stripe";

type RawBodyRequest = FastifyRequest & { rawBody?: Buffer };

async function syncOrganizationPlano(organizationId: string, planoId: string) {
  const { data: plano } = await supabase
    .from("planos")
    .select("max_usuarios, max_processos, max_storage_mb")
    .eq("id", planoId)
    .single();

  await supabase
    .from("organizations")
    .update({
      plano: planoId,
      status: "ativo",
      max_usuarios: plano?.max_usuarios ?? undefined,
      max_processos: plano?.max_processos ?? undefined,
      max_storage_mb: plano?.max_storage_mb ?? undefined,
      expira_em: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
    })
    .eq("id", organizationId);
}

export async function stripeWebhookRoutes(fastify: FastifyInstance) {
  const stripe = getStripe();
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

  if (!stripe || !webhookSecret) {
    fastify.log.warn(
      "Stripe webhook desabilitado: defina STRIPE_SECRET_KEY e STRIPE_WEBHOOK_SECRET",
    );
    return;
  }

  fastify.post(
    "/webhooks/stripe",
    {
      preParsing: async (request, _reply, payload) => {
        const chunks: Buffer[] = [];
        for await (const chunk of payload) {
          chunks.push(typeof chunk === "string" ? Buffer.from(chunk) : chunk);
        }
        const rawBody = Buffer.concat(chunks);
        (request as RawBodyRequest).rawBody = rawBody;
        return rawBody;
      },
    },
    async (request: RawBodyRequest, reply: FastifyReply) => {
      const sig = request.headers["stripe-signature"];
      if (!sig || !request.rawBody) {
        return reply.status(400).send({ error: "Assinatura ou body ausente" });
      }

      let event: Stripe.Event;
      try {
        event = stripe.webhooks.constructEvent(
          request.rawBody,
          sig,
          webhookSecret,
        );
      } catch (err) {
        const message = err instanceof Error ? err.message : "Webhook inválido";
        return reply.status(400).send({ error: message });
      }

      switch (event.type) {
        case "checkout.session.completed": {
          const session = event.data.object as Stripe.Checkout.Session;
          const organizationId = session.client_reference_id;
          const planoId = session.metadata?.plano ?? "basico";
          const subscriptionId =
            typeof session.subscription === "string"
              ? session.subscription
              : session.subscription?.id;

          if (organizationId) {
            await supabase
              .from("assinaturas")
              .update({ status: "cancelada", cancelado_em: new Date().toISOString() })
              .eq("organization_id", organizationId)
              .eq("status", "ativa");

            await supabase.from("assinaturas").insert({
              organization_id: organizationId,
              plano_id: planoId,
              status: "ativa",
              gateway_id: subscriptionId ?? null,
              data_inicio: new Date().toISOString(),
            });

            await syncOrganizationPlano(organizationId, planoId);
          }
          break;
        }
        case "customer.subscription.deleted": {
          const subscription = event.data.object as Stripe.Subscription;
          await supabase
            .from("assinaturas")
            .update({ status: "cancelada", cancelado_em: new Date().toISOString() })
            .eq("gateway_id", subscription.id);
          break;
        }
        default:
          break;
      }

      return reply.send({ received: true });
    },
  );
}
