import { Redis } from "ioredis";
import { Queue } from "bullmq";
import { env, hasRedis } from "./env";

const redisUrl = env.redisUrl;
const redisToken = env.redisToken;

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
