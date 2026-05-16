# Primeiro passo — checklist

Tudo que precisa existir **antes** de testar login e dashboard.

## 1. Repositório (feito)

- [x] Código em [github.com/RivasCode-Ops/CRM-EXECUTE-SAAS](https://github.com/RivasCode-Ops/CRM-EXECUTE-SAAS)
- [x] Monorepo: `web/`, `api/`, `infra/`

## 2. Supabase — Passo 2 (schema)

- [x] SQL Editor → `infra/supabase/schema.sql` (verificação OK)
- [ ] Auth → Users → criar usuário (e-mail + senha)
- [ ] `infra/supabase/bootstrap_admin.sql` (UUID do usuário, slug `execute`)

## 3. Variáveis locais (`web/.env.local`)

Copie de `web/.env.example`:

```env
NEXT_PUBLIC_SUPABASE_URL=https://SEU-PROJETO.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=sua_anon_key
NEXT_PUBLIC_API_URL=http://localhost:3001
```

Sem as duas primeiras, `/login` mostra *Supabase não configurado*.

## 4. API — Passo 3

Ver [passo-3-api.md](passo-3-api.md): `api/.env` + `npm run dev` + `npm run worker`.

## 5. Web — Passo 4

Login, dashboard e listagem de processos. Ver código em `web/app/dashboard/`.

## 6. Rodar em dev

```bash
# Terminal 1 — API
cd api && npm run dev

# Terminal 2 — Worker
cd api && npm run worker

# Terminal 3 — Web
cd web && npm run dev
```

- http://localhost:3000/login
- http://localhost:3001/health

## 7. Passo 5 — Bootstrap e deploy

Ver [passo-5-checklist.md](passo-5-checklist.md).

## 8. Vercel (depois do Git)

- [ ] Importar repo → Root Directory: **`web`**
- [ ] Env: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `NEXT_PUBLIC_API_URL`

## 9. Terraform (opcional)

```bash
cd infra/terraform
copy terraform.tfvars.example terraform.tfvars
terraform init && terraform apply
```

Requer tokens Supabase + Vercel no `terraform.tfvars`.
