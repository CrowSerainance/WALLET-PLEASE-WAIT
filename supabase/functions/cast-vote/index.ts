// HoldMyWallet — cast-vote Edge Function wrapping Postgres RPC
// Local: http://127.0.0.1:54321/functions/v1/cast-vote
// NEVER use webhook.site

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { moderateContent } from "../_shared/moderate.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: cors });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "missing_auth" }), {
        status: 401,
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }

    const { request_id, decision, reason } = await req.json();
    if (!request_id || !decision || !reason) {
      return new Response(JSON.stringify({ error: "invalid_payload" }), {
        status: 400,
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }

    if (decision !== "approve" && decision !== "reject") {
      return new Response(JSON.stringify({ error: "invalid_decision" }), {
        status: 400,
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }

    const mod = moderateContent({ text: reason });
    if (!mod.allowed) {
      return new Response(
        JSON.stringify({ error: "moderation_rejected", ...mod }),
        {
          status: 422,
          headers: { ...cors, "Content-Type": "application/json" },
        },
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "http://127.0.0.1:54321";
    const supabaseAnon = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

    const supabase = createClient(supabaseUrl, supabaseAnon, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data, error } = await supabase.rpc("cast_vote", {
      p_request_id: request_id,
      p_decision: decision,
      p_reason: reason,
    });

    if (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 400,
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }

    const total = (data?.approve_count ?? 0) + (data?.reject_count ?? 0);
    if (total === 5) {
      console.log(
        JSON.stringify({
          event: "first_5_votes",
          request_id,
          total,
        }),
      );
    }

    return new Response(JSON.stringify({ request: data }), {
      headers: { ...cors, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(
      JSON.stringify({ error: "server_error", detail: String(e) }),
      { status: 500, headers: { ...cors, "Content-Type": "application/json" } },
    );
  }
});
