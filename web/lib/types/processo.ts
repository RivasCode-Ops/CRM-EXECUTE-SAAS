export interface Processo {
  id: string;
  numero: string | null;
  tipo: string;
  status: string;
  cliente_nome: string | null;
  cliente_id?: string | null;
  imovel_descricao?: string | null;
  criado_em?: string;
}

export interface ProcessosResponse {
  processos: Processo[];
}
