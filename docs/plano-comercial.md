# Plano comercial — Stripe, pricing e white-label

**Pré-requisito:** Deploy em produção ([deploy-producao.md](deploy-producao.md)).

## 1. Planos no Supabase

Rodar no SQL Editor:

```text
infra/supabase/seed_planos_comercial.sql
```

| Plano | Mensal | Usuários | Processos |
|-------|--------|----------|-----------|
| gratuito | R$ 0 | 1 | 20 |
| basico | R$ 49 | 3 | 100 |
| pro | R$ 99 | 10 | 1000 |
| enterprise | R$ 299 | 100 | 10000 |

## 2. Stripe — webhook

**Endpoint:** `POST https://SUA-API/webhooks/stripe`

Código: `api/src/routes/webhooks/stripe.ts` (já registrado no servidor).

**Env na Railway:**

```env
STRIPE_SECRET_KEY=sk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...
```

No Stripe Dashboard → Webhooks → eventos:

- `checkout.session.completed`
- `customer.subscription.deleted`

No Checkout Session, use:

- `client_reference_id` = UUID da `organizations.id`
- `metadata.plano` = `basico` | `pro` | `enterprise`

## 3. Página de pricing + Checkout

- URL: `/pricing` → `web/app/pricing/page.tsx`
- Botão **Começar agora** → `POST /api/v1/create-checkout` (requer login)
- Env na API (Price IDs do Stripe):

```env
STRIPE_PRICE_BASICO_MENSAL=price_...
STRIPE_PRICE_BASICO_ANUAL=price_...
STRIPE_PRICE_PRO_MENSAL=price_...
STRIPE_PRICE_PRO_ANUAL=price_...
STRIPE_PRICE_ENTERPRISE_MENSAL=price_...
STRIPE_PRICE_ENTERPRISE_ANUAL=price_...
```

Teste local com Stripe CLI:

```bash
stripe listen --forward-to localhost:3001/webhooks/stripe
```

## 4. White-label

Middleware: `api/src/middleware/whitelabel.ts`

1. Na org, preencher `custom_domain` (ex. `crm.cliente.com.br`)
2. DNS do cliente: CNAME → Vercel
3. Vercel: domínio adicional no projeto
4. API resolve `Host` → `request.whiteLabel`

Campos em `organizations`: `logo_url`, `primary_color`, `custom_domain`.

## 5. Próximos passos

- [ ] Stripe Checkout Session (API route ou Edge)
- [ ] Portal do cliente
- [ ] Admin SaaS (listar orgs, MRR)
- [ ] E-mail de onboarding (Resend / Supabase Auth)

---

Confirme deploy: **"Deploy concluído – produção funcionando"**.
