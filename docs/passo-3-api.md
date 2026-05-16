# Passo 3 — Backend Fastify (API de negócios)

**Pré-requisito:** Passo 2 concluído (schema OK no Supabase).

## 3.1. Variáveis da API

```bash
cd api
copy .env.example .env
```

Copie `api/.env.example` → `api/.env` e preencha:

- `SUPABASE_URL` / `SUPABASE_ANON_KEY` — iguais ao `web/.env.local`
- `SUPABASE_SERVICE_ROLE_KEY` — só servidor (Settings → API)
- `REDIS_URL` + `REDIS_TOKEN` — Upstash (opcional, para filas)
- `JWT_SECRET` — string longa aleatória

## 3.2. Rodar a API

```bash
cd api
npm run dev
```

Teste: http://localhost:3001/health

## 3.3. Rotas (autenticadas)

Envie o **access_token** do Supabase (após login no web):

```
Authorization: Bearer <access_token>
```

| Método | Rota | Descrição |
|--------|------|-----------|
| GET | `/api/v1/me` | Usuário + organizações |
| GET | `/api/v1/processos` | Lista processos (projection ou fallback) |
| GET | `/api/v1/processos/:id` | Detalhe do processo |

## 3.4. Testar com curl

1. Faça login em http://localhost:3000/login  
2. No DevTools → Application → cookies ou use Supabase session  
3. Ou no console do browser após login:

```js
const { data } = await supabase.auth.getSession()
console.log(data.session.access_token)
```

```bash
curl -H "Authorization: Bearer SEU_TOKEN" http://localhost:3001/api/v1/processos
```

## Estrutura do código

```
api/src/
├── index.ts
├── lib/env.ts
├── lib/supabase.ts
├── plugins/auth.ts
└── routes/v1/
    ├── me.ts
    └── processos.ts
```

A API usa o JWT do Supabase e **RLS** — cada usuário só vê dados da própria organização.
