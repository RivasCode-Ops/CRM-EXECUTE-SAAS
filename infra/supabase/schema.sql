-- CRM Execute — schema base (multi-tenant)
-- Projeto Supabase NOVO: executar este arquivo no SQL Editor.
-- Depois: seed.sql e bootstrap_admin.sql (após criar usuário no Auth).

-- 1. Extensões
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- 2. ENUMs
DO $$ BEGIN
  CREATE TYPE public.tipo_processo_t AS ENUM (
    'itbi', 'averbacao_obra', 'desmembramento', 'financiamento', 'inventario',
    'reurb', 'retificacao', 'usucapiao', 'cancelamento_hipoteca', 'certidao'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.status_processo_t AS ENUM (
    'captacao', 'ativo', 'aguardando', 'vencido', 'concluido', 'cancelado'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.status_financeiro_t AS ENUM (
    'pendente', 'parcial', 'pago', 'cancelado'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.perfil_usuario_t AS ENUM (
    'admin', 'despachante', 'estagiario'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 3. Organizações (multi-tenant)
CREATE TABLE IF NOT EXISTS public.organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT UNIQUE NOT NULL,
  nome TEXT NOT NULL,
  cnpj TEXT,
  plano TEXT DEFAULT 'gratuito',
  status TEXT DEFAULT 'ativo',
  max_usuarios INT DEFAULT 3,
  max_processos INT DEFAULT 50,
  logo_url TEXT,
  primary_color TEXT DEFAULT '#a78bfa',
  custom_domain TEXT,
  whatsapp TEXT,
  criado_em TIMESTAMPTZ DEFAULT now(),
  expira_em TIMESTAMPTZ
);

-- 4. Membros (usuário × organização)
CREATE TABLE IF NOT EXISTS public.organization_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  perfil public.perfil_usuario_t DEFAULT 'despachante',
  convidado_por UUID REFERENCES auth.users(id),
  convidado_em TIMESTAMPTZ DEFAULT now(),
  UNIQUE (organization_id, user_id)
);

-- 5. Clientes
CREATE TABLE IF NOT EXISTS public.clientes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  nome TEXT NOT NULL,
  cpf_cnpj TEXT,
  rg TEXT,
  email TEXT,
  telefone TEXT,
  whatsapp TEXT,
  endereco TEXT,
  cidade TEXT,
  estado_civil TEXT,
  profissao TEXT,
  observacoes TEXT,
  token_portal UUID DEFAULT gen_random_uuid() UNIQUE,
  criado_por UUID REFERENCES auth.users(id),
  criado_em TIMESTAMPTZ DEFAULT now(),
  atualizado_em TIMESTAMPTZ DEFAULT now()
);

-- 6. Processos
CREATE TABLE IF NOT EXISTS public.processos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  numero TEXT UNIQUE,
  tipo public.tipo_processo_t NOT NULL,
  status public.status_processo_t DEFAULT 'captacao',
  cliente_id UUID NOT NULL REFERENCES public.clientes(id),
  responsavel_id UUID REFERENCES auth.users(id),
  imovel_descricao TEXT,
  imovel_matricula TEXT,
  imovel_endereco TEXT,
  cartorio_id UUID,
  protocolo_cartorio TEXT,
  prazo_conclusao DATE,
  data_entrada DATE DEFAULT CURRENT_DATE,
  observacoes TEXT,
  criado_em TIMESTAMPTZ DEFAULT now(),
  atualizado_em TIMESTAMPTZ DEFAULT now()
);

-- 7. Número do processo EXE-YYYY-NNNN (sequência global na v1)
CREATE SEQUENCE IF NOT EXISTS public.processo_seq START WITH 1;

CREATE OR REPLACE FUNCTION public.gerar_numero_processo()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.numero IS NULL OR NEW.numero = '' THEN
    NEW.numero := 'EXE-' || TO_CHAR(NOW(), 'YYYY') || '-' ||
      LPAD(NEXTVAL('public.processo_seq')::TEXT, 4, '0');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tg_numero_processo ON public.processos;
CREATE TRIGGER tg_numero_processo
  BEFORE INSERT ON public.processos
  FOR EACH ROW
  EXECUTE FUNCTION public.gerar_numero_processo();

-- 8. Checklist templates
CREATE TABLE IF NOT EXISTS public.checklist_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo_processo public.tipo_processo_t NOT NULL,
  descricao TEXT NOT NULL,
  obrigatorio BOOLEAN DEFAULT true,
  ordem INTEGER,
  observacao TEXT
);

-- 9. Checklist por processo
CREATE TABLE IF NOT EXISTS public.checklist_itens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  processo_id UUID NOT NULL REFERENCES public.processos(id) ON DELETE CASCADE,
  descricao TEXT NOT NULL,
  obrigatorio BOOLEAN DEFAULT true,
  concluido BOOLEAN DEFAULT false,
  concluido_em TIMESTAMPTZ,
  concluido_por UUID REFERENCES auth.users(id),
  ordem INTEGER
);

-- 10. Índices
CREATE INDEX IF NOT EXISTS idx_org_members_user ON public.organization_members (user_id);
CREATE INDEX IF NOT EXISTS idx_org_members_org ON public.organization_members (organization_id);
CREATE INDEX IF NOT EXISTS idx_clientes_org ON public.clientes (organization_id);
CREATE INDEX IF NOT EXISTS idx_processos_org ON public.processos (organization_id);
CREATE INDEX IF NOT EXISTS idx_processos_cliente ON public.processos (cliente_id);
CREATE INDEX IF NOT EXISTS idx_checklist_processo ON public.checklist_itens (processo_id);

-- 11. Helper RLS
CREATE OR REPLACE FUNCTION public.user_organization_ids()
RETURNS SETOF UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT organization_id
  FROM public.organization_members
  WHERE user_id = auth.uid();
$$;

-- 12. RLS
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clientes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.processos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checklist_itens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checklist_templates ENABLE ROW LEVEL SECURITY;

-- organizations
DROP POLICY IF EXISTS org_select_member ON public.organizations;
CREATE POLICY org_select_member ON public.organizations
  FOR SELECT TO authenticated
  USING (id IN (SELECT public.user_organization_ids()));

-- organization_members
DROP POLICY IF EXISTS org_members_select ON public.organization_members;
CREATE POLICY org_members_select ON public.organization_members
  FOR SELECT TO authenticated
  USING (organization_id IN (SELECT public.user_organization_ids()));

DROP POLICY IF EXISTS org_members_insert_admin ON public.organization_members;
CREATE POLICY org_members_insert_admin ON public.organization_members
  FOR INSERT TO authenticated
  WITH CHECK (
    organization_id IN (SELECT public.user_organization_ids())
    AND EXISTS (
      SELECT 1 FROM public.organization_members m
      WHERE m.organization_id = organization_members.organization_id
        AND m.user_id = auth.uid()
        AND m.perfil = 'admin'
    )
  );

-- clientes
DROP POLICY IF EXISTS clientes_org_isolation ON public.clientes;
CREATE POLICY clientes_org_isolation ON public.clientes
  FOR ALL TO authenticated
  USING (organization_id IN (SELECT public.user_organization_ids()))
  WITH CHECK (organization_id IN (SELECT public.user_organization_ids()));

-- processos
DROP POLICY IF EXISTS processos_org_isolation ON public.processos;
CREATE POLICY processos_org_isolation ON public.processos
  FOR ALL TO authenticated
  USING (organization_id IN (SELECT public.user_organization_ids()))
  WITH CHECK (organization_id IN (SELECT public.user_organization_ids()));

-- checklist_itens (via processo da mesma org)
DROP POLICY IF EXISTS checklist_itens_org_isolation ON public.checklist_itens;
CREATE POLICY checklist_itens_org_isolation ON public.checklist_itens
  FOR ALL TO authenticated
  USING (
    processo_id IN (
      SELECT p.id FROM public.processos p
      WHERE p.organization_id IN (SELECT public.user_organization_ids())
    )
  )
  WITH CHECK (
    processo_id IN (
      SELECT p.id FROM public.processos p
      WHERE p.organization_id IN (SELECT public.user_organization_ids())
    )
  );

-- templates: leitura para autenticados (catálogo global)
DROP POLICY IF EXISTS checklist_templates_read ON public.checklist_templates;
CREATE POLICY checklist_templates_read ON public.checklist_templates
  FOR SELECT TO authenticated
  USING (true);
