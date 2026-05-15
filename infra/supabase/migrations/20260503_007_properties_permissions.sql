-- 007: permissoes properties.read / properties.write (RECRIADA).
--
-- Reconstruido a partir de:
--   - src/lib/has-permission.ts (Permission type lista "properties.read" e "properties.write")
--   - policies das migrations 005/006 (chamam has_permission('properties.*'))
--
-- Dependencias: 003 (tabela role_permissions, papeis admin/operador).

insert into public.role_permissions (role, permission_key)
values
  ('admin',    'properties.read'),
  ('admin',    'properties.write'),
  ('operador', 'properties.read'),
  ('operador', 'properties.write')
on conflict (role, permission_key) do nothing;

comment on column public.role_permissions.permission_key is
  'Chave de permissao consumida por has_permission(). Convencao: <modulo>.<acao>.';
