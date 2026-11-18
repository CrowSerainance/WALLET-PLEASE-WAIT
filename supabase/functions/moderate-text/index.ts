// HoldMyWallet — lightweight text/URL moderation (Deno Edge Function)
// Local test: see ../_shared/test_payloads.md
// NEVER use webhook.site

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { moderateContent } from "../_shared/moderate.ts";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers":
          "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  try {
    const body = await req.json();
    const result = moderateContent({
      text: body.text,
      url: body.url,
    });
    return new Response(JSON.stringify(result), {
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
      status: result.allowed ? 200 : 422,
    });
  } catch (e) {
    return new Response(
      JSON.stringify({ error: "invalid_payload", detail: String(e) }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }
});
