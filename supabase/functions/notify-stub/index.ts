// HoldMyWallet — FCM push notification stub (no live FCM keys in MVP)
// Events: first_5_votes | countdown_expired | comment_likes_gt_10
// Local: http://127.0.0.1:54321/functions/v1/notify-stub
// NEVER use webhook.site — log / queue only

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

type NotifyEvent =
  | "first_5_votes"
  | "countdown_expired"
  | "comment_likes_gt_10";

type NotifyPayload = {
  event: NotifyEvent;
  user_id?: string;
  request_id?: string;
  comment_id?: string;
  fcm_token?: string;
  title?: string;
  body?: string;
};

const TEMPLATES: Record<NotifyEvent, { title: string; body: string }> = {
  first_5_votes: {
    title: "Your request is heating up",
    body: "You just hit 5 votes — strangers are weighing in.",
  },
  countdown_expired: {
    title: "Final verdict ready",
    body: "The timer ended. See if the crowd said Approve or Reject.",
  },
  comment_likes_gt_10: {
    title: "Voice of Reason",
    body: "A comment you left just passed 10 likes.",
  },
};

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
    const payload = (await req.json()) as NotifyPayload;
    if (!payload.event || !(payload.event in TEMPLATES)) {
      return new Response(JSON.stringify({ error: "invalid_event" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const tpl = TEMPLATES[payload.event];
    const queued = {
      ...payload,
      title: payload.title ?? tpl.title,
      body: payload.body ?? tpl.body,
      queued_at: new Date().toISOString(),
      delivery: "stub_log_only",
      // Production: send via Firebase Cloud Messaging using fcm_token
    };

    console.log(JSON.stringify({ notify_stub: queued }));

    return new Response(JSON.stringify({ ok: true, queued }), {
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    });
  } catch (e) {
    return new Response(
      JSON.stringify({ error: "invalid_payload", detail: String(e) }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }
});
