-- Seed adicional (opcional após schema.sql)
-- A organização e planos já são criados no schema.sql

-- Exemplo: assinatura da org execute
INSERT INTO public.assinaturas (organization_id, plano_id, status)
SELECT o.id, 'pro', 'ativa'
FROM public.organizations o
WHERE o.slug = 'execute'
  AND NOT EXISTS (
    SELECT 1 FROM public.assinaturas a
    WHERE a.organization_id = o.id AND a.plano_id = 'pro' AND a.status = 'ativa'
  );
