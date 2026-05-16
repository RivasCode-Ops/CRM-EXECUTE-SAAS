"use client";

import { useEffect, useState } from "react";
import { apiClient } from "@/lib/api-client";
import type { Processo, ProcessosResponse } from "@/lib/types/processo";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";

export default function ProcessosPage() {
  const [processos, setProcessos] = useState<Processo[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    apiClient<ProcessosResponse>("/api/v1/processos")
      .then((data) => setProcessos(data.processos ?? []))
      .catch((err) =>
        setError(err instanceof Error ? err.message : "Erro ao carregar"),
      )
      .finally(() => setLoading(false));
  }, []);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Processos</h1>
        <p className="text-muted-foreground">
          Lista de processos da sua organização
        </p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Todos os processos</CardTitle>
        </CardHeader>
        <CardContent>
          {loading ? (
            <p className="text-muted-foreground">Carregando...</p>
          ) : error ? (
            <p className="text-sm text-red-600">{error}</p>
          ) : processos.length === 0 ? (
            <p className="text-muted-foreground">Nenhum processo encontrado.</p>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Número</TableHead>
                  <TableHead>Cliente</TableHead>
                  <TableHead>Tipo</TableHead>
                  <TableHead>Status</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {processos.map((p) => (
                  <TableRow key={p.id}>
                    <TableCell className="font-medium">
                      {p.numero ?? p.id.slice(0, 8)}
                    </TableCell>
                    <TableCell>{p.cliente_nome ?? "—"}</TableCell>
                    <TableCell>{p.tipo}</TableCell>
                    <TableCell>{p.status}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
