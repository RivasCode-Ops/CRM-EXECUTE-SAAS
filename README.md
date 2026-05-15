# CRM Execute SaaS

Monorepo do CRM Execute: frontend Next.js, API, infraestrutura e documentação.

## Estrutura

```
CRM-EXECUTE-SAAS/
├── web/       # Frontend (Next.js, TypeScript, Tailwind, App Router)
├── api/       # Backend (a implementar)
├── infra/     # IaC, Docker, deploy
├── docs/      # Documentação do produto
└── .github/   # CI/CD (GitHub Actions)
```

## Pré-requisitos

- Node.js 20+
- npm 10+

## Comandos (raiz)

| Comando        | Descrição                          |
|----------------|------------------------------------|
| `npm install`  | Instala dependências de todos os workspaces |
| `npm run dev`  | Sobe o frontend em modo desenvolvimento |
| `npm run build`| Build de todos os workspaces       |
| `npm run lint` | Lint em todos os workspaces        |

## Desenvolvimento

```bash
# Na raiz do monorepo
npm install
npm run dev
```

O app web fica em [http://localhost:3000](http://localhost:3000).

### Apenas o frontend

```bash
npm run dev:web
# ou
cd web && npm run dev
```

## Workspaces

Este repositório usa [npm workspaces](https://docs.npmjs.com/cli/using-npm/workspaces). Pacotes:

- `web` — aplicação Next.js
- `api` — API (placeholder; implementação futura)

## Supabase e Vercel

- **Supabase:** projeto **novo** (só havia teste no antigo; banco zerado). Schema em `infra/supabase/`.
- **Vercel:** projeto **novo**, root directory `web`.
- Passo a passo: [docs/deploy-vercel-supabase.md](docs/deploy-vercel-supabase.md).
- IaC: [infra/terraform/](infra/terraform/) (Supabase + Vercel).
