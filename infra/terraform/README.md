# Terraform — Supabase + Vercel

Provisiona **projeto Supabase novo** e **projeto Vercel** para o monorepo (`web/` como root).

## Pré-requisitos

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- Token Supabase: [Account → Access Tokens](https://supabase.com/dashboard/account/tokens)
- Organization slug: Organization Settings → **Organization slug**
- Token Vercel: [Account → Tokens](https://vercel.com/account/tokens)
- GitHub App Vercel instalada no org `RivasCode-Ops` com acesso ao repo `CRM-EXECUTE-SAAS`

## Uso (2 applies)

```bash
cd infra/terraform
copy terraform.tfvars.example terraform.tfvars
# Editar terraform.tfvars com tokens e senha do DB

terraform init
terraform plan
terraform apply
```

**1º apply:** cria Supabase + Vercel; define `NEXT_PUBLIC_SUPABASE_URL` na Vercel.

**Depois:**

1. SQL em `../supabase/` (schema + migrations).
2. Supabase → Settings → API → copiar **anon key**.
3. Colocar em `terraform.tfvars`: `supabase_anon_key = "..."`.
4. `terraform apply` de novo → env vars na Vercel.

## Variáveis de ambiente via TF

| Recurso | Key |
|---------|-----|
| auto | `NEXT_PUBLIC_SUPABASE_URL` |
| auto | `NEXT_PUBLIC_APP_URL` |
| manual (2º apply) | `NEXT_PUBLIC_SUPABASE_ANON_KEY` |
| manual (opcional) | `SUPABASE_SERVICE_ROLE_KEY` |

O provider Supabase **não exporta** anon/service role no state — por isso o 2º passo manual.

## Alternativa sem arquivo de secrets

```powershell
$env:TF_VAR_supabase_access_token = "sbp_..."
$env:TF_VAR_supabase_organization_id = "seu-org"
$env:TF_VAR_supabase_db_password = "..."
$env:TF_VAR_vercel_api_token = "..."
terraform apply
```

## Destruir (cuidado)

```bash
terraform destroy
```

Remove projeto Supabase e Vercel gerenciados por este state.
