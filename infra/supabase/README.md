# Supabase — CRM Execute

## Ordem (projeto novo)

1. **SQL Editor** → colar e executar **`schema.sql`** inteiro (uma vez)
2. **Auth** → Users → criar usuário
3. **`bootstrap_admin.sql`** → trocar `<AUTH_USER_UUID>`
4. *(Opcional)* **`seed.sql`**

Não rode `schema_mvp.sql` nem `migrations/` — são do CRM legado.

## O que o schema inclui

- Multi-tenant: `organizations`, `organization_members`
- Negócio: `clientes`, `processos`, `documentos`, `honorarios`, `pagamentos`
- Event sourcing: `event_store`, `processos_projection`
- Portal: `links_portal`, `token_portal` em clientes
- Planos: `planos`, `assinaturas`
- RLS por organização em todas as tabelas sensíveis

## Organização padrão

- Slug: **`execute`**
- Nome: Execute Construrent
- Plano: `pro`

## Env (web)

```env
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
```

Ver `web/.env.example`.
