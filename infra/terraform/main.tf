resource "supabase_project" "crm" {
  organization_id   = var.supabase_organization_id
  name              = var.supabase_project_name
  region            = var.supabase_region
  database_password = var.supabase_db_password

  lifecycle {
    ignore_changes = [database_password]
  }
}

resource "vercel_project" "crm" {
  name           = var.vercel_project_name
  framework      = "nextjs"
  root_directory = "web"

  git_repository = {
    type = "github"
    repo = var.github_repo
  }
}

locals {
  supabase_url = "https://${supabase_project.crm.id}.supabase.co"
}

resource "vercel_project_environment_variable" "supabase_url" {
  project_id = vercel_project.crm.id
  key        = "NEXT_PUBLIC_SUPABASE_URL"
  value      = local.supabase_url
  target     = ["production", "preview", "development"]
  sensitive  = false
}

resource "vercel_project_environment_variable" "supabase_anon_key" {
  count = var.supabase_anon_key != "" ? 1 : 0

  project_id = vercel_project.crm.id
  key        = "NEXT_PUBLIC_SUPABASE_ANON_KEY"
  value      = var.supabase_anon_key
  target     = ["production", "preview", "development"]
  sensitive  = true
}

resource "vercel_project_environment_variable" "supabase_service_role_key" {
  count = var.supabase_service_role_key != "" ? 1 : 0

  project_id = vercel_project.crm.id
  key        = "SUPABASE_SERVICE_ROLE_KEY"
  value      = var.supabase_service_role_key
  target     = ["production", "preview"]
  sensitive  = true
}

resource "vercel_project_environment_variable" "app_url" {
  project_id = vercel_project.crm.id
  key        = "NEXT_PUBLIC_APP_URL"
  value      = "https://${vercel_project.crm.name}.vercel.app"
  target     = ["production", "preview"]
  sensitive  = false
}
