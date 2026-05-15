# Primeiro passo — checklist

Tudo que precisa existir **antes** de testar login e dashboard.

## 1. Repositório (feito)

- [x] Código em [github.com/RivasCode-Ops/CRM-EXECUTE-SAAS](https://github.com/RivasCode-Ops/CRM-EXECUTE-SAAS)
- [x] Monorepo: `web/`, `api/`, `infra/`

## 2. Supabase (você faz no painel)

- [ ] Criar projeto novo (`crm-execute-prod` ou similar)
- [ ] SQL Editor → colar e executar **`infra/supabase/schema.sql`** (script completo, uma vez)
- [ ] *(Opcional)* `infra/supabase/seed.sql`
- [ ] Auth → Users → criar usuário (e-mail + senha)
- [ ] SQL Editor → `infra/supabase/bootstrap_admin.sql` (UUID do usuário)

## 3. Variáveis locais (`web/.env.local`)

Copie de `web/.env.example`:

```env
NEXT_PUBLIC_SUPABASE_URL=https://SEU-PROJETO.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=sua_anon_key
NEXT_PUBLIC_API_URL=http://localhost:3001
```

Sem as duas primeiras, `/login` mostra *Supabase não configurado*.

## 4. Rodar em dev

```bash
# Terminal 1 — API
cd api && npm run dev

# Terminal 2 — Web
cd web && npm run dev
```

- http://localhost:3000/login
- http://localhost:3001/health

## 5. Vercel (depois do Git)

- [ ] Importar repo → Root Directory: **`web`**
- [ ] Env: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `NEXT_PUBLIC_API_URL`

## 6. Terraform (opcional)

```bash
cd infra/terraform
copy terraform.tfvars.example terraform.tfvars
terraform init && terraform apply
```

Requer tokens Supabase + Vercel no `terraform.tfvars`.
