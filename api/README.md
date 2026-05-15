# CRM Execute — API (Fastify)

## Desenvolvimento local

```bash
copy .env.example .env
# Preencha SUPABASE_*, REDIS_*, JWT_SECRET

npm install
npm run dev
```

Em outro terminal: `npm run worker`

## Produção (Railway)

Siga o guia completo (variáveis compartilhadas, worker sem healthcheck, URLs corretas):

**[docs/deploy-producao.md](../docs/deploy-producao.md)**

Resumo: preencha `api/.env` no PC → cole no **Shared Variables** do projeto Railway → serviços `api` + `worker` com Root `api`.
