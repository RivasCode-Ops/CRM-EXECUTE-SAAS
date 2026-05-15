export function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Variável de ambiente ausente: ${name}`);
  }
  return value;
}

export const env = {
  nodeEnv: process.env.NODE_ENV ?? "development",
  isProd: process.env.NODE_ENV === "production",
  port: Number(process.env.PORT) || 3001,
  host: process.env.HOST ?? "0.0.0.0",
  supabaseUrl: process.env.SUPABASE_URL ?? "",
  supabaseAnonKey: process.env.SUPABASE_ANON_KEY ?? "",
  supabaseServiceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY ?? "",
  redisUrl: process.env.REDIS_URL ?? "",
  redisToken: process.env.REDIS_TOKEN ?? "",
  jwtSecret: process.env.JWT_SECRET ?? "dev-secret-change-me",
};

export function assertSupabaseEnv(): void {
  requireEnv("SUPABASE_URL");
  requireEnv("SUPABASE_ANON_KEY");
  requireEnv("SUPABASE_SERVICE_ROLE_KEY");
}

export function hasRedis(): boolean {
  return Boolean(env.redisUrl && env.redisToken);
}
