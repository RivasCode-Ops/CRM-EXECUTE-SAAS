# Agents / Workers

Filas BullMQ (Upstash Redis):

| Fila | Nome | Uso |
|------|------|-----|
| `eventQueue` | `event-processing` | Projeções / event sourcing |
| `notificationQueue` | `notifications` | WhatsApp, e-mail |
| `agentQueue` | `agent-tasks` | Tarefas de IA |

Requer `REDIS_URL` + `REDIS_TOKEN` no `.env`. Sem Redis, as filas ficam `null` e a API sobe normalmente.

Helpers: `enqueueEvent`, `enqueueNotification`, `enqueueAgentTask` em `queue.ts`.

## Worker

```bash
npm run worker:events
```

Processa fila `event-processing`: grava `processos` + `processos_projection`.
