# Passo 5 — Checklist final e deploy

**Pré-requisitos:** Passos 2 (schema), 3 (API) e 4 (web) concluídos.

## 5.1. Pendências imediatas (local)

| Tarefa | Ação |
|--------|------|
| Usuário Auth | Supabase → Authentication → Users → Add user |
| Bootstrap admin | SQL Editor → `infra/supabase/bootstrap_admin.sql` (trocar `SEU_UUID_AQUI`) |
| Seed opcional | `infra/supabase/seed.sql` (assinatura pro) |
| Env web | `web/.env.local` — URL, anon key, `NEXT_PUBLIC_API_URL` |
| Env API | `api/.env` — Supabase, Redis, `JWT_SECRET` |
| Verificação | `infra/supabase/verify.sql` |

### Terminais (dev)

```bash
# 1 — API
cd api && npm run dev

# 2 — Worker
cd api && npm run worker

# 3 — Web
cd web && npm run dev
```

### Teste do fluxo

1. http://localhost:3000/login — entrar com usuário Auth
2. http://localhost:3000/dashboard — listar processos (`GET /api/v1/processos`)
3. Criar processo (curl ou futuro formulário):

```bash
# Token: DevTools após login → session.access_token
curl -X POST http://localhost:3001/api/v1/processos \
  -H "Authorization: Bearer SEU_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"tipo\":\"compra_venda\",\"cliente_id\":\"UUID_CLIENTE\",\"imovel_descricao\":\"Teste\"}"
```

## 5.2. Deploy Vercel (frontend)

1. [vercel.com/new](https://vercel.com/new) → repo **CRM-EXECUTE-SAAS**
2. **Root Directory:** `web`
3. **Build:** `npm run build` · **Output:** `.next`
4. Variáveis (Production + Preview):

| Variável | Valor |
|----------|--------|
| `NEXT_PUBLIC_SUPABASE_URL` | Supabase → Settings → API |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | idem |
| `NEXT_PUBLIC_API_URL` | URL pública da API (ex. Railway) |

Guia completo: [deploy-producao.md](deploy-producao.md) · [deploy-vercel-supabase.md](deploy-vercel-supabase.md)

## 5.3. API em produção

A API Fastify + worker Redis **não roda na Vercel** como está hoje. Opções:

- **Railway / Render / Fly.io** — Node + `npm run start` + worker em segundo serviço
- Manter API local até validar o fluxo completo

## 5.4. Checklist “pronto para produção”

### Segurança e dados

- [x] RLS nas tabelas principais (schema)
- [x] `organization_id` multi-tenant
- [x] `deleted_at` em tabelas selecionadas (clientes, processos, documentos)
- [x] Rate limit na API (100 req/min)

### Backend

- [x] Fastify + `/health`
- [x] Rotas `/api/v1/processos`, `/api/v1/me`
- [x] Worker de projeção
- [ ] `JWT_SECRET` forte em produção (hoje API usa Supabase JWT, não Fastify JWT)
- [ ] Deploy da API

### Frontend

- [x] Login + dashboard + sidebar
- [x] Listagem de processos via API
- [ ] Deploy Vercel

### Banco

- [x] Schema + ENUMs
- [ ] `bootstrap_admin.sql` executado
- [ ] `seed.sql` (opcional)

### Pós-deploy

- [ ] Stripe (assinaturas)
- [ ] Monitoramento (Sentry)
- [ ] Backup automático do banco

## 5.5. Terraform (opcional)

```bash
cd infra/terraform
copy terraform.tfvars.example terraform.tfvars
terraform init && terraform apply
```

---

Quando login + dashboard + processos funcionarem localmente, confirme: **"Passo 5 concluído – tudo funcionando"**.
