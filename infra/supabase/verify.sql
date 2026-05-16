-- Verificações rápidas pós-schema / pré-deploy (SQL Editor)

-- Tabelas de processos
SELECT COUNT(*) AS tabelas_processos
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('processos', 'processos_projection');
-- Esperado: 2

-- RLS ativa
SELECT tablename, rowsecurity AS rls_ativa
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('processos', 'processos_projection', 'clientes', 'honorarios', 'event_store')
ORDER BY tablename;

-- Membro admin na org execute
SELECT o.slug, om.user_id, om.perfil, om.ativo
FROM public.organization_members om
JOIN public.organizations o ON o.id = om.organization_id
WHERE o.slug = 'execute';
