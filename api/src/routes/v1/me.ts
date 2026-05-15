import type { FastifyPluginAsync } from "fastify";
import { authMiddleware } from "../../middleware/auth";

const meRoutes: FastifyPluginAsync = async (app) => {
  app.addHook("preHandler", authMiddleware);

  app.get("/me", async (request) => {
    const supabase = request.supabase!;
    const user = request.user!;

    const { data: memberships, error } = await supabase
      .from("organization_members")
      .select(
        `
        perfil,
        ativo,
        organizations ( id, slug, nome, plano, status )
      `,
      )
      .eq("user_id", user.id)
      .eq("ativo", true);

    if (error) {
      request.log.error(error);
      throw app.httpErrors.internalServerError("Erro ao carregar perfil");
    }

    return {
      user,
      organizations: memberships ?? [],
    };
  });
};

export default meRoutes;
