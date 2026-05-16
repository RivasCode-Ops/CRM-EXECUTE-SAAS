import { Redis } from "ioredis";
import { Queue } from "bullmq";
import { env, hasRedis } from "./env";

const redisUrl = env.redisUrl;
const redisToken = env.redisToken;

const isPlaceholderRedis =
  /\bseu-redis\.upstash\.io\b/i.test(redisUrl) ||
  /^seu-token$/i.test(redisToken.trim());

if (hasRedis() && isPlaceholderRedis) {
  throw new Error(
    "REDIS_URL / REDIS_TOKEN ainda têm valores de exemplo (.env.example). " +
      "No Upstash (Redis da base), copia o endpoint real (https://….upstash.io) e a password para api/.env, guarda o ficheiro e volta a arrancar."
  );
}

export const redis: Redis | null = hasRedis()
  ? new Redis({
      host: redisUrl.replace("https://", "").split(":")[0],
      port: 6379,
      password: redisToken,
      tls: {},
      maxRetriesPerRequest: null,
    })
  : null;

export const eventQueue = redis
  ? new Queue("event-processing", { connection: redis })
  : null;

export const notificationQueue = redis
  ? new Queue("notifications", { connection: redis })
  : null;

export const agentQueue = redis
  ? new Queue("agent-tasks", { connection: redis })
  : null;
