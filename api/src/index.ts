import Fastify from "fastify";
import cors from "@fastify/cors";
import jwt from "@fastify/jwt";

const fastify = Fastify({ logger: true });

await fastify.register(cors, { origin: true });
await fastify.register(jwt, {
  secret: process.env.JWT_SECRET || "supersecret",
});

fastify.get("/health", async () => ({
  status: "ok",
  timestamp: new Date(),
}));

fastify.register(
  async (app) => {
    app.get("/processos", async () => {
      // TODO: consultar projeções do Supabase
      return { processos: [] };
    });
  },
  { prefix: "/api/v1" },
);

const start = async () => {
  try {
    await fastify.listen({ port: 3001, host: "0.0.0.0" });
    console.log("API rodando em http://localhost:3001");
  } catch (err) {
    fastify.log.error(err);
    process.exit(1);
  }
};

start();
