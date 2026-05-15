import type { FastifyInstance, FastifyReply } from "fastify";
import { authMiddleware, type AuthRequest } from "../../middleware/auth";
import { getStripe, resolveStripePriceId } from "../../lib/stripe";

type CheckoutBody = {
  plano_id: string;
  annual?: boolean;
  success_url: string;
  cancel_url: string;
};

export async function checkoutRoutes(fastify: FastifyInstance) {
  fastify.post(
    "/v1/create-checkout",
    { preHandler: authMiddleware },
    async (request: AuthRequest, reply: FastifyReply) => {
      const stripe = getStripe();
      if (!stripe) {
        return reply.status(503).send({ error: "Stripe não configurado" });
      }

      const body = request.body as CheckoutBody;
      const { plano_id, annual = false, success_url, cancel_url } = body;

      if (!plano_id || !success_url || !cancel_url) {
        return reply.status(400).send({
          error: "plano_id, success_url e cancel_url são obrigatórios",
        });
      }

      const priceId = resolveStripePriceId(plano_id, annual);
      if (!priceId) {
        return reply.status(400).send({
          error: `Price ID não configurado para ${plano_id} (${annual ? "anual" : "mensal"})`,
        });
      }

      const organizationId = request.user!.organization_id;

      const session = await stripe.checkout.sessions.create({
        mode: "subscription",
        payment_method_types: ["card"],
        line_items: [{ price: priceId, quantity: 1 }],
        success_url,
        cancel_url,
        client_reference_id: organizationId,
        metadata: {
          plano: plano_id,
          organization_id: organizationId,
        },
      });

      if (!session.url) {
        return reply.status(500).send({ error: "Falha ao criar sessão de checkout" });
      }

      return { url: session.url };
    },
  );
}
