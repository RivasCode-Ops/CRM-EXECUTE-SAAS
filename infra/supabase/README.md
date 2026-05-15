# Supabase — CRM Execute

Banco **novo** (sem migrar dados do CRM antigo).

## Ordem de execução (SQL Editor)

1. **`schema.sql`** — tabelas, enums, triggers, RLS
2. **`seed.sql`** — organização inicial (`rivaldo`)
3. **Auth** → criar usuário admin no Dashboard
4. **`bootstrap_admin.sql`** — vincular usuário à org (trocar `<AUTH_USER_UUID>`)

## Legado (não usar em projeto novo)

A pasta `migrations/` e `schema_mvp.sql` vêm do CRM abandonado (`crm - execute`). Use apenas se for portar código antigo. Para o monorepo novo, **`schema.sql` é a fonte da verdade**.

## Modelo

| Tabela | Papel |
|--------|--------|
| `organizations` | Tenant |
| `organization_members` | Usuário × org + perfil |
| `clientes` | Clientes da org |
| `processos` | Número auto `EXE-YYYY-NNNN` |
| `checklist_templates` | Catálogo por tipo de processo |
| `checklist_itens` | Checklist por processo |

## Env

URL e keys em `web/.env.local` — ver `web/.env.example`.
