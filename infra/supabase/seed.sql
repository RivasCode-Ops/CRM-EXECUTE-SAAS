-- Seed inicial (rodar após schema.sql no SQL Editor)

INSERT INTO public.organizations (slug, nome, plano)
VALUES ('rivaldo', 'Execute Construrent', 'pro')
ON CONFLICT (slug) DO NOTHING;

-- Templates de checklist: adicionar por tipo_processo conforme o produto evoluir.
-- Exemplo:
-- INSERT INTO public.checklist_templates (tipo_processo, descricao, ordem)
-- VALUES ('itbi', 'RG e CPF do comprador', 1);
