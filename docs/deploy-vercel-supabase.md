# Deploy — Supabase e Vercel (projeto novo)

**Contexto:** o CRM antigo tinha **apenas dados de teste** (nenhum cliente real em produção). Não há migração de dados — só schema + app novo.

Decisão: **projeto Supabase e Vercel novos**, banco zerado.

## Visão

| Recurso | Ação |
|---------|------|
| Supabase | **Projeto novo** (`crm-execute-prod` ou similar) |
| Vercel | **Projeto novo** ligado a este monorepo |
| CRM antigo (`crm - execute`) | Referência de código/schema; desligar deploy |

---

## Opção A — Terraform (recomendado)

```bash
cd infra/terraform
copy terraform.tfvars.example terraform.tfvars
# Preencher tokens e organization_id
terraform init && terraform apply
```

Detalhes: [infra/terraform/README.md](../infra/terraform/README.md).

---

## Opção B — Manual

## 1. Supabase (novo)

1. [dashboard.supabase.com](https://supabase.com/dashboard) → **New project**.
2. Região próxima aos usuários; senha do DB anotada em cofre de senhas.
3. **Settings → API**: copiar `Project URL` e `anon` `public` key.
4. **SQL Editor**: `schema.sql` → `seed.sql` → (Auth user) → `bootstrap_admin.sql` — ver `infra/supabase/README.md`.
5. **Authentication → Users**: criar usuário; atribuir role `admin` em `user_profiles`.

### Env local

```bash
cd web
copy .env.example .env.local
# Editar .env.local com URL e anon key do projeto NOVO
```

---

## 2. Vercel (novo)

1. [vercel.com/new](https://vercel.com/new) → importar repositório **CRM-EXECUTE-SAAS**.
2. **Root Directory:** `web`
3. Framework: Next.js (detectado automaticamente).
4. **Environment Variables** (Production + Preview):

| Variável | Onde pegar |
|----------|------------|
| `NEXT_PUBLIC_SUPABASE_URL` | Supabase → Settings → API |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | idem |
| `SUPABASE_SERVICE_ROLE_KEY` | idem (só servidor; marcar Sensitive) |
| `NEXT_PUBLIC_APP_URL` | `https://seu-projeto.vercel.app` após 1º deploy |

5. Deploy.

### Projeto Vercel antigo

- Renomear para `crm-execute-legacy` **ou** remover Git connection / desativar Production.
- Objetivo: **uma URL de produção** só.

---

## 3. Cron (quando migrar API)

No CRM antigo existia:

```json
{
  "crons": [
    { "path": "/api/cron/deadline-alerts", "schedule": "0 8 * * *" }
  ]
}
```

Colocar em `web/vercel.json` só depois que a rota existir no monorepo. Definir `CRON_SECRET` na Vercel.

---

## 4. Checklist pós-deploy (teste)

- [ ] Login / Auth Supabase com usuário de teste
- [ ] Uma operação básica no app (quando código migrado)
- [ ] Domínio / `NEXT_PUBLIC_APP_URL` apontando para o deploy certo

Não é necessário exportar, importar ou validar dados do CRM antigo.

---

## O que NÃO fazer

- Não apontar o monorepo novo para o Supabase antigo se quiser banco limpo.
- Não manter dois projetos Vercel em produção com o mesmo domínio/produto.
- Não commitar `.env.local` nem service role no Git.
