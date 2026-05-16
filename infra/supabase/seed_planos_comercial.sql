-- Atualiza planos com preços e limites comerciais (rodar após schema.sql)
-- Valores em reais (DECIMAL). Anual com ~10% desconto implícito no preco_anual.

INSERT INTO public.planos (
  id,
  nome,
  descricao,
  preco_mensal,
  preco_anual,
  max_usuarios,
  max_processos,
  max_storage_mb,
  tem_portal_cliente,
  tem_relatorios_avancados,
  tem_api,
  suporte_prioritario
) VALUES
  (
    'gratuito',
    'Grátis',
    'Para testar o sistema',
    0,
    0,
    1,
    20,
    100,
    true,
    false,
    false,
    false
  ),
  (
    'basico',
    'Básico',
    'Para pequenos escritórios',
    49,
    529.2,
    3,
    100,
    500,
    true,
    false,
    false,
    false
  ),
  (
    'pro',
    'Profissional',
    'Para escritórios em crescimento',
    99,
    1069.2,
    10,
    1000,
    2000,
    true,
    true,
    false,
    false
  ),
  (
    'enterprise',
    'Enterprise',
    'Para grandes operações',
    299,
    3229.2,
    100,
    10000,
    10000,
    true,
    true,
    true,
    true
  )
ON CONFLICT (id) DO UPDATE SET
  nome = EXCLUDED.nome,
  descricao = EXCLUDED.descricao,
  preco_mensal = EXCLUDED.preco_mensal,
  preco_anual = EXCLUDED.preco_anual,
  max_usuarios = EXCLUDED.max_usuarios,
  max_processos = EXCLUDED.max_processos,
  max_storage_mb = EXCLUDED.max_storage_mb,
  tem_portal_cliente = EXCLUDED.tem_portal_cliente,
  tem_relatorios_avancados = EXCLUDED.tem_relatorios_avancados,
  tem_api = EXCLUDED.tem_api,
  suporte_prioritario = EXCLUDED.suporte_prioritario;
