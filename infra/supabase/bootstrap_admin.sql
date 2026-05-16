-- Rodar DEPOIS de criar o usuário em Authentication → Users
-- Substitua SEU_UUID_AQUI pelo UUID do usuário (Settings → Users → copiar ID)

-- 1. Garantir organização execute
INSERT INTO public.organizations (slug, nome, plano, status)
VALUES ('execute', 'Execute Construrent', 'pro', 'ativo')
ON CONFLICT (slug) DO NOTHING;

-- 2. Vincular usuário como admin
WITH org AS (SELECT id FROM public.organizations WHERE slug = 'execute')
INSERT INTO public.organization_members (organization_id, user_id, perfil, ativo)
SELECT org.id, 'SEU_UUID_AQUI'::uuid, 'admin'::public.perfil_usuario_t, true
FROM org
ON CONFLICT (organization_id, user_id) DO UPDATE
  SET perfil = EXCLUDED.perfil, ativo = true;

-- 3. Verificar
SELECT
  o.slug,
  om.user_id,
  om.perfil,
  om.ativo
FROM public.organization_members om
JOIN public.organizations o ON o.id = om.organization_id
WHERE o.slug = 'execute';
