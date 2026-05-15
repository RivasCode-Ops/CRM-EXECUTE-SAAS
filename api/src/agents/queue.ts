import {
  agentQueue,
  eventQueue,
  notificationQueue,
} from "../utils/redis";

export { agentQueue, eventQueue, notificationQueue } from "../utils/redis";

export async function enqueueEvent(
  name: string,
  data: Record<string, unknown>,
): Promise<void> {
  if (!eventQueue) return;
  await eventQueue.add(name, data);
}

export async function enqueueNotification(
  name: string,
  data: Record<string, unknown>,
): Promise<void> {
  if (!notificationQueue) return;
  await notificationQueue.add(name, data);
}

export async function enqueueAgentTask(
  name: string,
  data: Record<string, unknown>,
): Promise<void> {
  if (!agentQueue) return;
  await agentQueue.add(name, data);
}
