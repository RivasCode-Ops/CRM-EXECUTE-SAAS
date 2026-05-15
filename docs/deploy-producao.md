# Deploy em produção — Railway (API) + Vercel (Web)

**Pré-requisito:** Passo 5 local OK (login, dashboard, processos).

## 0. Por que dá trabalho — e como evitar (leia primeiro)

| Problema comum | Causa | O que fazer |
|----------------|-------|-------------|
| `Variável de ambiente ausente: SUPABASE_URL` | Variável vazia, `PREENCHER` no Raw Editor, ou só num dos serviços | **Project → Shared Variables**: cole o conteúdo real do seu `api/.env` (local). **Update Variables**. Nunca deixe placeholder. |
| `Cannot find module ... projection-worker.js` | Código `api/src` não estava no GitHub | Garantir `git push` com **toda** a pasta `api/` (inclui `src/workers/`). |
| `Missing script: start:worker` | `package.json` antigo no remoto | Já corrigido no repo; redeploy após pull. |
| Deploy failed **network** / healthcheck no **worker** | Worker não tem HTTP | Serviço **worker** → **desligar healthcheck**. Só a **api** usa `/health`. |
| Página Railway "Não encontrado" | URL do **projeto** ou domínio antigo | Usar só a URL em **serviço `api` → Settings → Networking → Generate Domain**. |
| Build não gera `dist/` | Railpack não rodou `tsc` | `api/nixpacks.toml` força `npm install` + `npm run build`. Root Directory = `api`. |

**Fluxo mínimo que funciona:** (1) `api/.env` preenchido no PC → (2) colar no **Shared Variables** → (3) deploy **api** → (4) deploy **worker** sem healthcheck → (5) `curl .../health` → (6) Vercel com `NEXT_PUBLIC_API_URL`.

---

## Arquitetura

| Componente | Produção |
|------------|----------|
| Banco | Supabase (já no ar) |
| API Fastify | Railway — serviço `api` |
| Worker BullMQ | Railway — segundo serviço `worker` |
| Frontend Next.js | Vercel — root `web` |

---

## 1. API na Railway (recomendado)

### 1.1. Criar projeto

1. [railway.app](https://railway.app) → Login GitHub
2. **New Project** → **Deploy from GitHub repo** → `CRM-EXECUTE-SAAS`
3. Serviço **api** → **Settings** → **Root Directory:** `api`

### 1.2. Variáveis de ambiente (recomendado: **Shared Variables** no projeto)

1. No PC: crie/edite **`api/.env`** a partir de `api/.env.example` (não commitar o `.env`).
2. Railway → **seu projeto** (nível projeto) → **Variables** / **Shared Variables** → **Raw Editor**.
3. Cole **todo** o conteúdo do `api/.env` (valores reais do Supabase e Upstash). Ajuste `NODE_ENV=production`.
4. **Update Variables** — assim **api** e **worker** recebem as mesmas chaves; não precisa duplicar à mão.

Lista mínima obrigatória (nomes **exatos**):

```env
SUPABASE_URL=https://SEU-PROJETO.supabase.co
SUPABASE_ANON_KEY=...
SUPABASE_SERVICE_ROLE_KEY=...
REDIS_URL=https://....upstash.io
REDIS_TOKEN=...
JWT_SECRET=...                    # string longa aleatória
NODE_ENV=production
```

Opcional na **api** (Stripe / CORS extra):

```env
CORS_ORIGINS=https://seu-app.vercel.app
STRIPE_SECRET_KEY=...
STRIPE_WEBHOOK_SECRET=...
STRIPE_PRICE_BASICO_MENSAL=price_...
```

`PORT`: na Railway costuma ser **injetada** — não é obrigatório definir.  
`CORS_ORIGINS` é opcional — já liberamos `*.vercel.app` e `*.executeconstrurent.com.br` no código.

### 1.3. Deploy

O arquivo `api/railway.json` define build e health check em `/health`.

Após o deploy, anote a URL em **serviço `api` → Settings → Networking → Generate Domain** (ex.: `https://api-production-xxxx.up.railway.app`). **Ignore** URLs antigas de outros serviços.

### 1.4. Worker (segundo serviço)

1. No mesmo projeto Railway → **Add Service** → mesmo repositório `CRM-EXECUTE-SAAS`
2. **Root Directory:** `api`
3. **Build:** deixe em branco (usa `api/nixpacks.toml`) ou `npm install && npm run build`
4. **Start Command:** `npm run start:worker` **ou** `node dist/workers/projection-worker.js`
5. **Variables:** se usou **Shared Variables** no projeto, não precisa repetir. Caso contrário, copie as mesmas da API (Supabase + Redis + `JWT_SECRET` + `NODE_ENV`) — **sem** Stripe.
6. **Healthcheck:** **desligado** (worker não expõe HTTP).

Sem o worker, eventos ficam na fila e `processos_projection` não atualiza.

---

## 2. Frontend na Vercel

1. [vercel.com/new](https://vercel.com/new) → importar `CRM-EXECUTE-SAAS`
2. **Root Directory:** `web`
3. Variáveis (Production + Preview):

| Variável | Valor |
|----------|--------|
| `NEXT_PUBLIC_SUPABASE_URL` | Supabase → Settings → API |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | idem |
| `NEXT_PUBLIC_API_URL` | URL pública da API Railway |

4. Deploy

### Domínio customizado

Vercel → Settings → Domains → ex.: `crm.executeconstrurent.com.br`  
DNS: CNAME para `cname.vercel-dns.com`

Atualize `CORS_ORIGINS` na Railway se usar domínio novo.

---

## 3. Checklist pós-deploy

- [ ] `GET https://SUA-API/health` → `{"status":"ok",...}`
- [ ] Login na URL Vercel
- [ ] Dashboard lista processos
- [ ] Logs do worker Railway processando jobs
- [ ] `JWT_SECRET` forte em produção
- [ ] Monitoramento (Sentry / Uptime Robot em `/health`)

---

## 4. CLI Railway (opcional)

```bash
cd api
npm install -g @railway/cli
railway login
railway link
railway up
```

---

## 5. Próximo: lançamento comercial

Quando API + Vercel estiverem OK em produção, confirme:

> **Deploy concluído – produção funcionando**

Próxima fase: Stripe, planos SaaS, webhooks, white-label por organização.
