import { createClient } from "@/lib/supabase/server";

export default async function DashboardPage() {
  const supabase = await createClient();
  const {
    data: { session },
  } = await supabase.auth.getSession();

  if (!session) {
    return (
      <main className="mx-auto max-w-4xl px-4 py-12">
        <p className="text-foreground/70">Não autenticado</p>
      </main>
    );
  }

  return (
    <main className="mx-auto max-w-4xl px-4 py-12">
      <h1 className="text-2xl font-semibold">
        Bem-vindo, {session.user.email}
      </h1>
      <p className="mt-2 text-foreground/70">
        Seu primeiro dashboard do CRM Execute SaaS
      </p>
    </main>
  );
}
