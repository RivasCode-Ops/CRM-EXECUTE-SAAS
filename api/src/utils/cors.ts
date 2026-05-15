/** Origens permitidas no CORS (dev + produção). */
export function isCorsOriginAllowed(origin: string): boolean {
  const extras = (process.env.CORS_ORIGINS ?? "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);

  const allowed: (string | RegExp)[] = [
    "http://localhost:3000",
    /^https:\/\/([a-z0-9-]+\.)?crm-execute\.com$/i,
    /^https:\/\/([a-z0-9-]+\.)?vercel\.app$/i,
    /^https:\/\/([a-z0-9-]+\.)?executeconstrurent\.com\.br$/i,
    ...extras,
  ];

  return allowed.some((rule) =>
    typeof rule === "string" ? rule === origin : rule.test(origin),
  );
}
