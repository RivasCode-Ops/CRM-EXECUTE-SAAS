import Stripe from "stripe";

export function getStripe(): Stripe | null {
  const key = process.env.STRIPE_SECRET_KEY;
  if (!key) return null;
  return new Stripe(key, { apiVersion: "2025-08-27.basil" });
}

/** Mapeia plano + periodicidade → Price ID do Stripe (env). */
export function resolveStripePriceId(
  planoId: string,
  annual: boolean,
): string | null {
  const envKey = `STRIPE_PRICE_${planoId.toUpperCase()}_${annual ? "ANUAL" : "MENSAL"}`;
  return process.env[envKey] ?? null;
}
