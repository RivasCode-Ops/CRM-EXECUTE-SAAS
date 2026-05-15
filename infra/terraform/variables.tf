variable "supabase_access_token" {
  type        = string
  sensitive   = true
  description = "Personal Access Token: Supabase Dashboard → Account → Access Tokens."
}

variable "supabase_organization_id" {
  type        = string
  description = "Organization slug: Dashboard → Organization Settings → Organization slug."
}

variable "supabase_db_password" {
  type        = string
  sensitive   = true
  description = "Senha do Postgres do projeto novo (guarde em cofre de senhas)."
}

variable "supabase_project_name" {
  type        = string
  default     = "crm-execute"
  description = "Nome do projeto no Supabase."
}

variable "supabase_region" {
  type        = string
  default     = "sa-east-1"
  description = "Região do projeto Supabase."
}

variable "vercel_api_token" {
  type        = string
  sensitive   = true
  description = "Vercel API token: Account Settings → Tokens."
}

variable "vercel_team_id" {
  type        = string
  default     = null
  description = "Opcional. Team ID se o projeto for criado sob um time Vercel."
}

variable "vercel_project_name" {
  type        = string
  default     = "crm-execute"
  description = "Nome do projeto na Vercel."
}

variable "github_repo" {
  type        = string
  default     = "RivasCode-Ops/CRM-EXECUTE-SAAS"
  description = "Repositório GitHub no formato owner/repo."
}

# Preencha após criar o projeto Supabase (Settings → API).
# O provider Supabase ainda não expõe anon/service_role no state.
variable "supabase_anon_key" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Anon key do projeto novo. Deixe vazio no 1º apply; preencha e aplique de novo."
}

variable "supabase_service_role_key" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Service role key (opcional). Apenas servidor."
}
