-- Rodar no SQL Editor se o schema já foi aplicado antes de criado_em existir
ALTER TABLE public.processos_projection
  ADD COLUMN IF NOT EXISTS criado_em TIMESTAMPTZ DEFAULT now();
