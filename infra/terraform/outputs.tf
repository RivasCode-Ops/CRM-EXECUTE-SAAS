output "supabase_project_id" {
  description = "ID/ref do projeto (usado na URL da API)."
  value       = supabase_project.crm.id
}

output "supabase_url" {
  description = "URL pública da API Supabase."
  value       = local.supabase_url
}

output "vercel_project_id" {
  value = vercel_project.crm.id
}

output "vercel_project_url" {
  value = "https://${vercel_project.crm.name}.vercel.app"
}

output "next_steps" {
  description = "Após o 1º apply, rode SQL em infra/supabase/ e preencha as keys no tfvars."
  value     = <<-EOT
    1. Supabase SQL Editor: infra/supabase/schema.sql → seed.sql → bootstrap_admin.sql
    2. Supabase Settings → API: copiar anon key (e service role se usar)
    3. terraform.tfvars: supabase_anon_key = "..."
    4. terraform apply
    5. Vercel: confirmar GitHub App instalado em ${var.github_repo}
  EOT
}
