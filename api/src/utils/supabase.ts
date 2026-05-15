import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { env, requireEnv } from "./env";

const supabaseUrl = () => requireEnv("SUPABASE_URL");
const supabaseServiceKey = () => requireEnv("SUPABASE_SERVICE_ROLE_KEY");
const supabaseAnonKey = () => requireEnv("SUPABASE_ANON_KEY");

/** Admin — ignora RLS; cron, projeções, jobs */
export const supabase = createClient(supabaseUrl(), supabaseServiceKey(), {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
  },
});

/**
 * Operações como o usuário logado (RLS ativo).
 * Usa anon key + JWT do Supabase Auth no header.
 */
export const createAuthenticatedClient = (jwt: string): SupabaseClient => {
  return createClient(supabaseUrl(), supabaseAnonKey(), {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
    global: {
      headers: { Authorization: `Bearer ${jwt}` },
    },
  });
};

/** @deprecated use createAuthenticatedClient */
export const createSupabase = (accessToken?: string) =>
  accessToken ? createAuthenticatedClient(accessToken) : supabase;
