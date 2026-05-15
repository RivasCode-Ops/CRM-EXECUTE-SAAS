-- Rodar DEPOIS de criar o usuário em Authentication → Users
-- Substitua <AUTH_USER_UUID> pelo UUID do usuário

INSERT INTO public.organization_members (organization_id, user_id, perfil)
SELECT o.id, '<AUTH_USER_UUID>'::uuid, 'admin'::public.perfil_usuario_t
FROM public.organizations o
WHERE o.slug = 'rivaldo'
ON CONFLICT (organization_id, user_id) DO UPDATE
  SET perfil = EXCLUDED.perfil;
