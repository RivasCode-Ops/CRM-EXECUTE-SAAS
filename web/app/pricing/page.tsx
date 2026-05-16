"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { apiClient } from "@/lib/api-client";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";

type Plan = {
  id: string;
  nome: string;
  precoMensal: number;
  descricao: string;
  usuarios: string | number;
  processos: string | number;
  storage: string;
  destaque: boolean;
  relatorios?: boolean;
  api?: boolean;
};

const PLANS: Plan[] = [
  {
    id: "basico",
    nome: "Básico",
    precoMensal: 49,
    descricao: "Para pequenos escritórios",
    usuarios: 3,
    processos: 100,
    storage: "500 MB",
    destaque: false,
  },
  {
    id: "pro",
    nome: "Profissional",
    precoMensal: 99,
    descricao: "Para escritórios em crescimento",
    usuarios: 10,
    processos: 1000,
    storage: "2 GB",
    destaque: true,
    relatorios: true,
  },
  {
    id: "enterprise",
    nome: "Enterprise",
    precoMensal: 299,
    descricao: "Para grandes operações",
    usuarios: "Ilimitado",
    processos: "Ilimitado",
    storage: "10 GB",
    destaque: false,
    relatorios: true,
    api: true,
  },
];

function displayPrice(monthly: number, annual: boolean) {
  return annual ? Math.round(monthly * 12 * 0.9) : monthly;
}

export default function PricingPage() {
  const [annual, setAnnual] = useState(false);
  const [loadingPlan, setLoadingPlan] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const router = useRouter();

  const handleCheckout = async (plan: Plan) => {
    setError(null);
    setLoadingPlan(plan.id);

    try {
      const supabase = createClient();
      const {
        data: { session },
      } = await supabase.auth.getSession();

      if (!session) {
        router.push("/login?redirect=/pricing");
        return;
      }

      const origin = window.location.origin;
      const data = await apiClient<{ url: string }>("/api/v1/create-checkout", {
        method: "POST",
        body: JSON.stringify({
          plano_id: plan.id,
          annual,
          success_url: `${origin}/dashboard?checkout=success`,
          cancel_url: `${origin}/pricing`,
        }),
      });

      if (data.url) {
        window.location.href = data.url;
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Erro ao iniciar checkout");
    } finally {
      setLoadingPlan(null);
    }
  };

  return (
    <div className="container mx-auto px-4 py-16">
      <div className="mb-12 text-center">
        <h1 className="mb-4 text-4xl font-bold">Planos e Preços</h1>
        <p className="text-muted-foreground">
          Escolha o plano ideal para o seu escritório
        </p>

        <div className="mt-6 flex items-center justify-center gap-2">
          <Button
            type="button"
            variant={annual ? "outline" : "default"}
            size="sm"
            onClick={() => setAnnual(false)}
          >
            Mensal
          </Button>
          <Button
            type="button"
            variant={annual ? "default" : "outline"}
            size="sm"
            onClick={() => setAnnual(true)}
          >
            Anual <span className="ml-1 text-xs text-green-600">(-10%)</span>
          </Button>
        </div>
      </div>

      {error ? (
        <p className="mb-6 text-center text-sm text-red-600">{error}</p>
      ) : null}

      <div className="mx-auto grid max-w-5xl gap-8 md:grid-cols-3">
        {PLANS.map((plan) => {
          const preco = displayPrice(plan.precoMensal, annual);
          const isLoading = loadingPlan === plan.id;

          return (
            <Card
              key={plan.id}
              className={
                plan.destaque ? "relative border-purple-500 shadow-lg" : ""
              }
            >
              {plan.destaque ? (
                <div className="absolute -top-3 left-1/2 -translate-x-1/2 rounded-full bg-purple-500 px-3 py-1 text-xs text-white">
                  Mais popular
                </div>
              ) : null}
              <CardHeader>
                <CardTitle className="text-2xl">{plan.nome}</CardTitle>
                <CardDescription>{plan.descricao}</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="mb-4">
                  <span className="text-3xl font-bold">R$ {preco}</span>
                  <span className="text-muted-foreground">
                    /{annual ? "ano" : "mês"}
                  </span>
                </div>
                <ul className="space-y-2 text-sm">
                  <li>✓ Até {plan.usuarios} usuários</li>
                  <li>
                    ✓{" "}
                    {plan.processos === "Ilimitado"
                      ? "Processos ilimitados"
                      : `Até ${plan.processos} processos`}
                  </li>
                  <li>✓ {plan.storage} de armazenamento</li>
                  <li>✓ Portal do cliente</li>
                  {plan.relatorios ? <li>✓ Relatórios avançados</li> : null}
                  {plan.api ? <li>✓ API exclusiva</li> : null}
                </ul>
              </CardContent>
              <CardFooter>
                <Button
                  className="w-full"
                  variant={plan.destaque ? "default" : "outline"}
                  disabled={isLoading}
                  onClick={() => void handleCheckout(plan)}
                >
                  {isLoading ? "Redirecionando..." : "Começar agora"}
                </Button>
              </CardFooter>
            </Card>
          );
        })}
      </div>

      <p className="mt-8 text-center text-sm text-muted-foreground">
        Plano Grátis — até 20 processos.{" "}
        <Link href="/login" className="underline">
          Criar conta
        </Link>
      </p>
    </div>
  );
}
