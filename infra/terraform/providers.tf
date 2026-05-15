provider "supabase" {
  access_token = var.supabase_access_token
}

provider "vercel" {
  api_token = var.vercel_api_token
  team_id   = var.vercel_team_id
}
