-- 008: app_current_tenant_id / has_permission — JWT (request.jwt.claims / auth.jwt) + compatibilidade 003
--
-- O projeto ja usa has_permission via tabela role_permissions + app_current_role() (user_profiles).
-- Esta migration:
--   - Le tenant_id de auth.jwt() ou, em fallback, de current_setting('request.jwt.claims') (PostgREST).
--   - OR com claims JWT: formato plano, array de strings, objeto plano, ou aninhado (ver abaixo).
--
-- Formato aninhado (exemplo):
--   {"tenant_id":"...","permissions":{"properties":["read","write"]}}
--   => has_permission('properties.read') olha permissions.properties e verifica se contem "read".
--
-- ---------------------------------------------------------------------------
-- Testes manuais (psql / SQL editor), ajuste <seu_tenant_id>:
--
-- 1) Fallback JWT (sem linha em role_permissions para esse perm)
--    SET LOCAL request.jwt.claims = '{"tenant_id":"<uuid>","permissions":{"properties":["read","write"]}}';
--    SELECT has_permission('properties.read');   -- true via JWT
--    SELECT has_permission('admin.delete');       -- false (nao esta no claim nem em role)
--
-- 2) Fallback role (003): JWT sem permissao para a chave, mas papel concede em role_permissions
--    -- Limpe ou omita permissions no claim; garanta user_profiles + role_permissions.
--    SELECT has_permission('properties.read');   -- true via role_permissions
--
-- 3) Negacao: claim sem a permissao solicitada (e papel sem acesso)
--    SET LOCAL request.jwt.claims = '{"tenant_id":"00000000-0000-0000-0000-000000000001"}';
--    SELECT has_permission('properties.read');   -- false se nem JWT nem role concedem
--
-- Nota: has_permission nao compara tenant do JWT com tabelas de negocio; isolamento de dados
-- continua em RLS (tenant_id = app_current_tenant_id()). Use tenant_id correto nos claims em producao.
-- ---------------------------------------------------------------------------

create or replace function app_current_tenant_id()
returns uuid
language sql
stable
security invoker
set search_path = public
as $$
  select coalesce(
    nullif((auth.jwt() ->> 'tenant_id'), '')::uuid,
    nullif((current_setting('request.jwt.claims', true)::json ->> 'tenant_id'), '')::uuid
  );
$$;

create or replace function has_permission(p_permission text)
returns boolean
language plpgsql
stable
security invoker
set search_path = public
as $$
declare
  from_role boolean;
  jwt_raw jsonb;
  jwt_perms jsonb;
  mod text;
  act text;
  mod_actions jsonb;
begin
  select exists (
    select 1
    from role_permissions rp
    where rp.role = app_current_role()
      and rp.permission_key = p_permission
  )
  into from_role;

  if from_role then
    return true;
  end if;

  jwt_raw := coalesce(
    (auth.jwt())::jsonb,
    (current_setting('request.jwt.claims', true)::json::jsonb)
  );

  if jwt_raw is null then
    return false;
  end if;

  jwt_perms := jwt_raw -> 'permissions';
  if jwt_perms is null then
    jwt_perms := jwt_raw -> 'app_metadata' -> 'permissions';
  end if;
  if jwt_perms is null then
    jwt_perms := jwt_raw -> 'user_metadata' -> 'permissions';
  end if;

  if jwt_perms is null then
    return false;
  end if;

  if jsonb_typeof(jwt_perms) = 'array' then
    return exists (
      select 1
      from jsonb_array_elements_text(jwt_perms) as elem(v)
      where elem.v = p_permission
    );
  end if;

  if jsonb_typeof(jwt_perms) = 'object' then
    if jwt_perms ? p_permission then
      return coalesce((jwt_perms -> p_permission)::boolean, false);
    end if;

    if strpos(p_permission, '.') > 0 then
      mod := split_part(p_permission, '.', 1);
      act := split_part(p_permission, '.', 2);
      mod_actions := jwt_perms -> mod;
      if mod_actions is not null and jsonb_typeof(mod_actions) = 'array' then
        return exists (
          select 1
          from jsonb_array_elements_text(mod_actions) as elem(v)
          where elem.v = act
        );
      end if;
    end if;

    return false;
  end if;

  return false;
end;
$$;

comment on function app_current_tenant_id() is
  'Tenant atual: auth.jwt()->>tenant_id ou request.jwt.claims.tenant_id (UUID).';

comment on function has_permission(text) is
  'Permissao: role_permissions + app_current_role(); ou JWT em permissions (plano, array, objeto, ou modulo.acao com arrays aninhados).';
