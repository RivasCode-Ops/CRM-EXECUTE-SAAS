-- =====================================================
-- CRM EXECUTE SAAS – SCHEMA COMPLETO
-- Execute este script inteiro de uma vez (SQL Editor)
-- =====================================================

-- 1. HABILITAR EXTENSÕES
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- 2. CRIAR ENUMS
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

DO $$ BEGIN
  CREATE TYPE public.categoria_doc_t AS ENUM (
    'rg_cpf', 'escritura', 'matricula', 'iptu', 'planta', 'certidao', 'guia', 'contrato', 'outros'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.orgao_t AS ENUM (
    'cartorio_rgi', 'cartorio_notas', 'prefeitura', 'receita_federal', 'caixa', 'banco', 'incra', 'spu', 'trf', 'interno'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 3. TABELA: ORGANIZAÇÕES (CORE DO MULTI-TENANT)
CREATE TABLE IF NOT EXISTS public.organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT UNIQUE NOT NULL,
  nome TEXT NOT NULL,
  cnpj TEXT,
  plano TEXT DEFAULT 'gratuito',
  status TEXT DEFAULT 'ativo',
  max_usuarios INT DEFAULT 3,
  max_processos INT DEFAULT 50,
  max_storage_mb INT DEFAULT 500,
  logo_url TEXT,
  primary_color TEXT DEFAULT '#a78bfa',
  secondary_color TEXT DEFAULT '#2dd4bf',
  custom_domain TEXT,
  whatsapp TEXT,
  email_suporte TEXT,
  endereco TEXT,
  cidade TEXT,
  estado TEXT DEFAULT 'PI',
  criado_em TIMESTAMPTZ DEFAULT now(),
  expira_em TIMESTAMPTZ,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 4. TABELA: PLANOS
CREATE TABLE IF NOT EXISTS public.planos (
  id TEXT PRIMARY KEY,
  nome TEXT NOT NULL,
  descricao TEXT,
  preco_mensal DECIMAL(10,2),
  preco_anual DECIMAL(10,2),
  max_usuarios INT,
  max_processos INT,
  max_storage_mb INT,
  tem_portal_cliente BOOLEAN DEFAULT true,
  tem_relatorios_avancados BOOLEAN DEFAULT false,
  tem_api BOOLEAN DEFAULT false,
  suporte_prioritario BOOLEAN DEFAULT false
);

-- 5. TABELA: ASSINATURAS
CREATE TABLE IF NOT EXISTS public.assinaturas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  plano_id TEXT NOT NULL REFERENCES public.planos(id),
  status TEXT DEFAULT 'ativa',
  gateway_id TEXT,
  data_inicio TIMESTAMPTZ DEFAULT now(),
  data_fim TIMESTAMPTZ,
  proxima_cobranca DATE,
  cancelado_em TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 6. TABELA: MEMBROS (USUÁRIOS X ORGANIZAÇÕES)
CREATE TABLE IF NOT EXISTS public.organization_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  perfil public.perfil_usuario_t DEFAULT 'despachante',
  convidado_por UUID REFERENCES auth.users(id),
  convidado_em TIMESTAMPTZ DEFAULT now(),
  ativo BOOLEAN DEFAULT true,
  UNIQUE (organization_id, user_id)
);

-- 7. TABELA: CLIENTES
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
  estado TEXT DEFAULT 'PI',
  cep TEXT,
  estado_civil TEXT,
  profissao TEXT,
  data_nascimento DATE,
  observacoes TEXT,
  token_portal UUID DEFAULT gen_random_uuid() UNIQUE,
  criado_por UUID REFERENCES auth.users(id),
  criado_em TIMESTAMPTZ DEFAULT now(),
  atualizado_em TIMESTAMPTZ DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  UNIQUE (organization_id, cpf_cnpj)
);

-- 8. TABELA: CARTÓRIOS E ÓRGÃOS
CREATE TABLE IF NOT EXISTS public.cartorios (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
  nome TEXT NOT NULL,
  tipo public.orgao_t NOT NULL,
  cidade TEXT,
  estado TEXT DEFAULT 'PI',
  endereco TEXT,
  telefone TEXT,
  email TEXT,
  responsavel TEXT,
  observacoes TEXT,
  padrao BOOLEAN DEFAULT false
);

-- 9. TABELA: PROCESSOS
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
  cartorio_id UUID REFERENCES public.cartorios(id),
  protocolo_cartorio TEXT,
  prazo_conclusao DATE,
  data_entrada DATE DEFAULT CURRENT_DATE,
  data_conclusao DATE,
  observacoes TEXT,
  valor_total_honorarios DECIMAL(12,2) DEFAULT 0,
  valor_total_pago DECIMAL(12,2) DEFAULT 0,
  criado_em TIMESTAMPTZ DEFAULT now(),
  atualizado_em TIMESTAMPTZ DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- 10. TRIGGER: GERAR NÚMERO DO PROCESSO (EXE-YYYY-NNNN)
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

-- 11. TABELA: EVENT STORE (EVENT SOURCING - IMUTÁVEL)
CREATE TABLE IF NOT EXISTS public.event_store (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  aggregate_type TEXT NOT NULL,
  aggregate_id UUID NOT NULL,
  event_type TEXT NOT NULL,
  event_version INT NOT NULL DEFAULT 1,
  payload JSONB NOT NULL,
  metadata JSONB,
  organization_id UUID NOT NULL,
  user_id UUID,
  correlation_id UUID,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_event_store_aggregate ON public.event_store (aggregate_type, aggregate_id, created_at);
CREATE INDEX IF NOT EXISTS idx_event_store_org ON public.event_store (organization_id, created_at);

-- 12. TABELA: PROJEÇÃO DE PROCESSOS (LEITURA OTIMIZADA)
CREATE TABLE IF NOT EXISTS public.processos_projection (
  id UUID PRIMARY KEY,
  organization_id UUID NOT NULL,
  numero TEXT,
  tipo public.tipo_processo_t,
  status public.status_processo_t,
  cliente_nome TEXT,
  cliente_id UUID,
  responsavel_nome TEXT,
  imovel_descricao TEXT,
  imovel_matricula TEXT,
  prazo_conclusao DATE,
  data_entrada DATE,
  percentual_concluido INT DEFAULT 0,
  ultimo_evento_id UUID,
  ultima_atualizacao TIMESTAMPTZ DEFAULT now(),
  criado_em TIMESTAMPTZ DEFAULT now()
);

-- 13. TABELA: DOCUMENTOS
CREATE TABLE IF NOT EXISTS public.documentos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  processo_id UUID NOT NULL REFERENCES public.processos(id) ON DELETE CASCADE,
  nome_original TEXT NOT NULL,
  nome_armazenado TEXT NOT NULL,
  categoria public.categoria_doc_t NOT NULL,
  storage_path TEXT NOT NULL,
  tamanho_bytes BIGINT,
  mime_type TEXT,
  enviado_cliente BOOLEAN DEFAULT false,
  enviado_em TIMESTAMPTZ,
  upload_por UUID REFERENCES auth.users(id),
  criado_em TIMESTAMPTZ DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- 14. TABELA: CHECKLIST TEMPLATES
CREATE TABLE IF NOT EXISTS public.checklist_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo_processo public.tipo_processo_t NOT NULL,
  descricao TEXT NOT NULL,
  obrigatorio BOOLEAN DEFAULT true,
  ordem INTEGER,
  observacao TEXT,
  prazo_dias_sugerido INT
);

-- 15. TABELA: CHECKLIST ITENS
CREATE TABLE IF NOT EXISTS public.checklist_itens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  processo_id UUID NOT NULL REFERENCES public.processos(id) ON DELETE CASCADE,
  descricao TEXT NOT NULL,
  obrigatorio BOOLEAN DEFAULT true,
  concluido BOOLEAN DEFAULT false,
  concluido_em TIMESTAMPTZ,
  concluido_por UUID REFERENCES auth.users(id),
  ordem INTEGER,
  observacao TEXT
);

-- 16. TABELA: HONORÁRIOS
CREATE TABLE IF NOT EXISTS public.honorarios (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  processo_id UUID NOT NULL REFERENCES public.processos(id) ON DELETE CASCADE,
  descricao_servico TEXT NOT NULL,
  valor_total DECIMAL(12,2) NOT NULL CHECK (valor_total > 0),
  valor_pago DECIMAL(12,2) DEFAULT 0,
  status public.status_financeiro_t DEFAULT 'pendente',
  vencimento DATE,
  forma_pagamento TEXT,
  observacoes TEXT,
  criado_em TIMESTAMPTZ DEFAULT now(),
  atualizado_em TIMESTAMPTZ DEFAULT now()
);

-- 17. TABELA: PAGAMENTOS
CREATE TABLE IF NOT EXISTS public.pagamentos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  honorario_id UUID NOT NULL REFERENCES public.honorarios(id) ON DELETE CASCADE,
  valor DECIMAL(12,2) NOT NULL,
  data_pagamento DATE NOT NULL,
  forma TEXT,
  comprovante_path TEXT,
  observacao TEXT,
  registrado_por UUID REFERENCES auth.users(id),
  criado_em TIMESTAMPTZ DEFAULT now()
);

-- 18. TRIGGER: ATUALIZAR STATUS DO HONORÁRIO
CREATE OR REPLACE FUNCTION public.atualizar_status_honorario()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  total_pago DECIMAL;
  total_dever DECIMAL;
BEGIN
  SELECT COALESCE(SUM(valor), 0) INTO total_pago
  FROM public.pagamentos WHERE honorario_id = NEW.honorario_id;

  SELECT valor_total INTO total_dever
  FROM public.honorarios WHERE id = NEW.honorario_id;

  UPDATE public.honorarios SET
    valor_pago = total_pago,
    status = CASE
      WHEN total_pago >= total_dever THEN 'pago'::public.status_financeiro_t
      WHEN total_pago > 0 THEN 'parcial'::public.status_financeiro_t
      ELSE 'pendente'::public.status_financeiro_t
    END,
    atualizado_em = NOW()
  WHERE id = NEW.honorario_id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tg_atualizar_status_honorario ON public.pagamentos;
CREATE TRIGGER tg_atualizar_status_honorario
  AFTER INSERT OR UPDATE ON public.pagamentos
  FOR EACH ROW
  EXECUTE FUNCTION public.atualizar_status_honorario();

-- 19. TABELA: PRAZOS
CREATE TABLE IF NOT EXISTS public.prazos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  processo_id UUID NOT NULL REFERENCES public.processos(id) ON DELETE CASCADE,
  descricao TEXT NOT NULL,
  data_limite DATE NOT NULL,
  orgao public.orgao_t,
  concluido BOOLEAN DEFAULT false,
  concluido_em TIMESTAMPTZ,
  notificar_dias_antes INT DEFAULT 3,
  criado_em TIMESTAMPTZ DEFAULT now()
);

-- 20. TABELA: HISTÓRICO (IMUTÁVEL)
CREATE TABLE IF NOT EXISTS public.historico (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  processo_id UUID NOT NULL REFERENCES public.processos(id) ON DELETE CASCADE,
  descricao TEXT NOT NULL,
  tipo_evento TEXT,
  status_anterior public.status_processo_t,
  status_novo public.status_processo_t,
  usuario_id UUID REFERENCES auth.users(id),
  metadata JSONB,
  criado_em TIMESTAMPTZ DEFAULT now()
);

-- 21. TABELA: LINKS DO PORTAL
CREATE TABLE IF NOT EXISTS public.links_portal (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  processo_id UUID NOT NULL REFERENCES public.processos(id) ON DELETE CASCADE,
  token UUID DEFAULT gen_random_uuid() UNIQUE,
  ativo BOOLEAN DEFAULT true,
  expira_em TIMESTAMPTZ,
  visualizacoes INT DEFAULT 0,
  criado_por UUID REFERENCES auth.users(id),
  criado_em TIMESTAMPTZ DEFAULT now()
);

-- 22. TABELA: LOGS DE ACESSO (AUDITORIA)
CREATE TABLE IF NOT EXISTS public.logs_acesso (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL,
  usuario_id UUID,
  recurso_tipo TEXT NOT NULL,
  recurso_id UUID NOT NULL,
  acao TEXT NOT NULL,
  justificativa TEXT,
  ip TEXT,
  user_agent TEXT,
  criado_em TIMESTAMPTZ DEFAULT now()
);

-- Índices auxiliares
CREATE INDEX IF NOT EXISTS idx_org_members_user ON public.organization_members (user_id);
CREATE INDEX IF NOT EXISTS idx_clientes_org ON public.clientes (organization_id);
CREATE INDEX IF NOT EXISTS idx_processos_org ON public.processos (organization_id);

-- 23. HELPER RLS
CREATE OR REPLACE FUNCTION public.user_organization_ids()
RETURNS SETOF UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT organization_id
  FROM public.organization_members
  WHERE user_id = auth.uid() AND ativo = true;
$$;

-- 24. ATIVAR RLS
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clientes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.processos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.processos_projection ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documentos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.honorarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pagamentos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.historico ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.logs_acesso ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_store ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checklist_itens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prazos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.links_portal ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assinaturas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checklist_templates ENABLE ROW LEVEL SECURITY;

-- 25. POLÍTICAS RLS
DROP POLICY IF EXISTS org_select_member ON public.organizations;
CREATE POLICY org_select_member ON public.organizations
  FOR SELECT TO authenticated
  USING (id IN (SELECT public.user_organization_ids()));

DROP POLICY IF EXISTS org_members_select ON public.organization_members;
CREATE POLICY org_members_select ON public.organization_members
  FOR SELECT TO authenticated
  USING (organization_id IN (SELECT public.user_organization_ids()));

DROP POLICY IF EXISTS processos_org_isolation ON public.processos;
CREATE POLICY processos_org_isolation ON public.processos
  FOR ALL TO authenticated
  USING (organization_id IN (SELECT public.user_organization_ids()))
  WITH CHECK (organization_id IN (SELECT public.user_organization_ids()));

DROP POLICY IF EXISTS clientes_org_isolation ON public.clientes;
CREATE POLICY clientes_org_isolation ON public.clientes
  FOR ALL TO authenticated
  USING (organization_id IN (SELECT public.user_organization_ids()))
  WITH CHECK (organization_id IN (SELECT public.user_organization_ids()));

DROP POLICY IF EXISTS documentos_org_isolation ON public.documentos;
CREATE POLICY documentos_org_isolation ON public.documentos
  FOR ALL TO authenticated
  USING (organization_id IN (SELECT public.user_organization_ids()))
  WITH CHECK (organization_id IN (SELECT public.user_organization_ids()));

DROP POLICY IF EXISTS processos_projection_org ON public.processos_projection;
CREATE POLICY processos_projection_org ON public.processos_projection
  FOR ALL TO authenticated
  USING (organization_id IN (SELECT public.user_organization_ids()))
  WITH CHECK (organization_id IN (SELECT public.user_organization_ids()));

DROP POLICY IF EXISTS honorarios_org ON public.honorarios;
CREATE POLICY honorarios_org ON public.honorarios
  FOR ALL TO authenticated
  USING (organization_id IN (SELECT public.user_organization_ids()))
  WITH CHECK (organization_id IN (SELECT public.user_organization_ids()));

DROP POLICY IF EXISTS pagamentos_org ON public.pagamentos;
CREATE POLICY pagamentos_org ON public.pagamentos
  FOR ALL TO authenticated
  USING (
    honorario_id IN (
      SELECT h.id FROM public.honorarios h
      WHERE h.organization_id IN (SELECT public.user_organization_ids())
    )
  )
  WITH CHECK (
    honorario_id IN (
      SELECT h.id FROM public.honorarios h
      WHERE h.organization_id IN (SELECT public.user_organization_ids())
    )
  );

DROP POLICY IF EXISTS historico_org ON public.historico;
CREATE POLICY historico_org ON public.historico
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

DROP POLICY IF EXISTS logs_acesso_org ON public.logs_acesso;
CREATE POLICY logs_acesso_org ON public.logs_acesso
  FOR ALL TO authenticated
  USING (organization_id IN (SELECT public.user_organization_ids()))
  WITH CHECK (organization_id IN (SELECT public.user_organization_ids()));

DROP POLICY IF EXISTS event_store_org ON public.event_store;
CREATE POLICY event_store_org ON public.event_store
  FOR ALL TO authenticated
  USING (organization_id IN (SELECT public.user_organization_ids()))
  WITH CHECK (organization_id IN (SELECT public.user_organization_ids()));

DROP POLICY IF EXISTS checklist_itens_org ON public.checklist_itens;
CREATE POLICY checklist_itens_org ON public.checklist_itens
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

DROP POLICY IF EXISTS prazos_org ON public.prazos;
CREATE POLICY prazos_org ON public.prazos
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

DROP POLICY IF EXISTS links_portal_org ON public.links_portal;
CREATE POLICY links_portal_org ON public.links_portal
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

DROP POLICY IF EXISTS assinaturas_org ON public.assinaturas;
CREATE POLICY assinaturas_org ON public.assinaturas
  FOR ALL TO authenticated
  USING (organization_id IN (SELECT public.user_organization_ids()))
  WITH CHECK (organization_id IN (SELECT public.user_organization_ids()));

DROP POLICY IF EXISTS checklist_templates_read ON public.checklist_templates;
CREATE POLICY checklist_templates_read ON public.checklist_templates
  FOR SELECT TO authenticated
  USING (true);

-- 26. SEED (planos, cartórios globais, organização)
INSERT INTO public.planos (id, nome, descricao, preco_mensal, max_usuarios, max_processos, max_storage_mb)
VALUES
  ('gratuito', 'Gratuito', 'Para testar o sistema', 0, 1, 20, 100),
  ('basico', 'Básico', 'Para pequenos escritórios', 49, 3, 100, 500),
  ('pro', 'Profissional', 'Para escritórios em crescimento', 99, 10, 500, 2000),
  ('enterprise', 'Enterprise', 'Sob consulta', 299, 100, 10000, 10000)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.cartorios (nome, tipo, cidade, estado, padrao)
SELECT v.nome, v.tipo, v.cidade, v.estado, v.padrao
FROM (VALUES
  ('Cartório de Registro de Imóveis de Picos', 'cartorio_rgi'::public.orgao_t, 'Picos', 'PI', true),
  ('Cartório de Notas de Picos', 'cartorio_notas'::public.orgao_t, 'Picos', 'PI', true),
  ('Prefeitura Municipal de Picos', 'prefeitura'::public.orgao_t, 'Picos', 'PI', true)
) AS v(nome, tipo, cidade, estado, padrao)
WHERE NOT EXISTS (SELECT 1 FROM public.cartorios c WHERE c.nome = v.nome AND c.cidade = v.cidade);

INSERT INTO public.organizations (slug, nome, plano, status)
VALUES ('execute', 'Execute Construrent', 'pro', 'ativo')
ON CONFLICT (slug) DO NOTHING;

-- 27. VERIFICAR SE TUDO FUNCIONOU
SELECT
  'Extensões' AS check,
  CASE WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'uuid-ossp') THEN 'OK' ELSE 'FALTA' END AS status
UNION ALL
SELECT 'ENUMs', CASE WHEN EXISTS (SELECT 1 FROM pg_type WHERE typname = 'tipo_processo_t') THEN 'OK' ELSE 'FALTA' END
UNION ALL
SELECT 'Tabelas', CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'organizations') THEN 'OK' ELSE 'FALTA' END
UNION ALL
SELECT 'RLS processos', CASE WHEN EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'processos' AND rowsecurity = true) THEN 'OK' ELSE 'FALTA' END;
