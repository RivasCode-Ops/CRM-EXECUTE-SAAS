"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useAuth } from "@/contexts/AuthContext";
import { apiClient } from "@/lib/api-client";
import type { Processo, ProcessosResponse } from "@/lib/types/processo";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";

function statusBadgeClass(status: string) {
  switch (status) {
    case "ativo":
      return "bg-green-100 text-green-800";
    case "concluido":
      return "bg-blue-100 text-blue-800";
    case "cancelado":
      return "bg-red-100 text-red-800";
    default:
      return "bg-yellow-100 text-yellow-800";
  }
}

function formatNumero(processo: Processo) {
  return processo.numero ?? processo.id.slice(0, 8).toUpperCase();
}

export default function DashboardPage() {
  const { user } = useAuth();
  const [processos, setProcessos] = useState<Processo[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchProcessos = async () => {
      try {
        const data = await apiClient<ProcessosResponse>("/api/v1/processos");
        setProcessos(data.processos ?? []);
      } catch (err) {
        console.error("Erro ao buscar processos:", err);
        setError(
          err instanceof Error ? err.message : "Erro ao carregar processos",
        );
      } finally {
        setLoading(false);
      }
    };

    void fetchProcessos();
  }, []);

  const ativos = processos.filter((p) => p.status === "ativo").length;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Dashboard</h1>
        <p className="text-muted-foreground">Bem-vindo, {user?.email}</p>
      </div>

      {error ? (
        <p className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </p>
      ) : null}

      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Processos ativos</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{ativos}</div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Total de processos</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{processos.length}</div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Ações rápidas</CardTitle>
          </CardHeader>
          <CardContent>
            <Link href="/dashboard/processos">
              <Button size="sm" className="w-full">
                Ver processos
              </Button>
            </Link>
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Últimos processos</CardTitle>
        </CardHeader>
        <CardContent>
          {loading ? (
            <p className="text-muted-foreground">Carregando...</p>
          ) : processos.length === 0 ? (
            <p className="text-muted-foreground">Nenhum processo encontrado.</p>
          ) : (
            <div className="space-y-2">
              {processos.slice(0, 5).map((processo) => (
                <div
                  key={processo.id}
                  className="flex items-center justify-between rounded-lg border p-3"
                >
                  <div>
                    <p className="font-medium">{formatNumero(processo)}</p>
                    <p className="text-sm text-muted-foreground">
                      {processo.cliente_nome ?? "Cliente não informado"} •{" "}
                      {processo.tipo}
                    </p>
                  </div>
                  <span
                    className={`rounded-full px-2 py-1 text-xs ${statusBadgeClass(processo.status)}`}
                  >
                    {processo.status}
                  </span>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
