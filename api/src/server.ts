import "dotenv/config";
import Fastify from "fastify";
import cors from "@fastify/cors";
import helmet from "@fastify/helmet";
import rateLimit from "@fastify/rate-limit";
import multipart from "@fastify/multipart";
import sensible from "@fastify/sensible";
import { assertSupabaseEnv } from "./utils/env";
import { isCorsOriginAllowed } from "./utils/cors";
import { healthRoutes } from "./routes/health";
import { processosRoutes } from "./routes/processos";
import meRoutes from "./routes/v1/me";
import { checkoutRoutes } from "./routes/v1/checkout";
import { stripeWebhookRoutes } from "./routes/webhooks/stripe";
import { whiteLabelMiddleware } from "./middleware/whitelabel";

const isProd = process.env.NODE_ENV === "production";

async function buildServer() {
  assertSupabaseEnv();

  const fastify = Fastify({
    logger: {
      level: isProd ? "info" : "debug",
      transport: isProd
        ? undefined
        : {
            target: "pino-pretty",
            options: {
              translateTime: "HH:MM:ss Z",
              ignore: "pid,hostname",
            },
          },
    },
  });

  await fastify.register(cors, {
    origin: (origin, callback) => {
      if (!origin) {
        callback(null, true);
        return;
      }
      const ok = isCorsOriginAllowed(origin);
      callback(ok ? null : new Error("CORS bloqueado"), ok);
    },
    credentials: true,
  });

  await fastify.register(helmet);
  await fastify.register(rateLimit, {
    max: 100,
    timeWindow: "1 minute",
  });
  await fastify.register(multipart, {
    limits: { fileSize: 10 * 1024 * 1024 },
  });
  await fastify.register(sensible);

  fastify.addHook("onRequest", whiteLabelMiddleware);

  await fastify.register(stripeWebhookRoutes);
  await fastify.register(healthRoutes);
  await fastify.register(processosRoutes, { prefix: "/api" });
  await fastify.register(checkoutRoutes, { prefix: "/api" });
  await fastify.register(meRoutes, { prefix: "/api/v1" });

  fastify.setErrorHandler((error, _request, reply) => {
    fastify.log.error(error);
    const err = error as { statusCode?: number; message?: string };
    const statusCode = err.statusCode ?? 500;
    reply.status(statusCode).send({
      error: err.message ?? "Erro interno",
      statusCode,
    });
  });

  return fastify;
}

async function start() {
  try {
    const fastify = await buildServer();
    const port = parseInt(process.env.PORT || "3001", 10);

    await fastify.listen({ port, host: "0.0.0.0" });

    console.log(`API rodando em http://localhost:${port}`);
    console.log(`Health check: http://localhost:${port}/health`);
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
}

start();
