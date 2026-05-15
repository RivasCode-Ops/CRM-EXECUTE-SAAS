export const apiUrl = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:3001";

export function apiPath(path: string): string {
  const base = apiUrl.replace(/\/$/, "");
  const suffix = path.startsWith("/") ? path : `/${path}`;
  return `${base}${suffix}`;
}
