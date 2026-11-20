import {
  createClient,
  type SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2.49.1";

const headers = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json",
};

export function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers });
}

export function authenticatedWrite(
  write: (
    body: Record<string, unknown>,
    userId: string,
    db: SupabaseClient,
  ) => Promise<Response>,
) {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response(null, { headers });
    if (req.method !== "POST") {
      return json({ error: "method_not_allowed" }, 405);
    }
    const token = /^Bearer (\S+)$/i.exec(req.headers.get("Authorization") ?? "")
      ?.[1];
    if (!token) return json({ error: "missing_auth" }, 401);

    try {
      const url = Deno.env.get("SUPABASE_URL")!;
      const auth = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!);
      const { data, error } = await auth.auth.getUser(token);
      if (error || !data.user) {
        return json(
          { error: "authentication_failed" },
          error?.status && error.status >= 500 ? 503 : 401,
        );
      }
      const body = await req.json().catch(() => null);
      if (!body || typeof body !== "object" || Array.isArray(body)) {
        return json({ error: "invalid_payload" }, 400);
      }

      const db = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
        auth: { persistSession: false, autoRefreshToken: false },
      });
      const profile = await db.from("users").select("guidelines_accepted_at")
        .eq("id", data.user.id).single();
      if (profile.error) return json({ error: "profile_unavailable" }, 503);
      if (!profile.data.guidelines_accepted_at) {
        return json({ error: "guidelines_required" }, 403);
      }
      return await write(body, data.user.id, db);
    } catch {
      return json({ error: "server_error" }, 500);
    }
  };
}
