import { authenticatedWrite, json } from "../_shared/authenticated-write.ts";
import { moderateContent } from "../_shared/moderate.ts";

Deno.serve(authenticatedWrite(async (body, voterId, db) => {
  const { request_id, decision, reason } = body;
  if (
    typeof request_id !== "string" ||
    !["approve", "reject"].includes(String(decision)) ||
    typeof reason !== "string" || reason.trim().length < 8 ||
    reason.length > 140
  ) {
    return json({ error: "invalid_payload" }, 400);
  }
  const moderation = moderateContent({ text: reason });
  if (!moderation.allowed) {
    return json({ error: "moderation_rejected", ...moderation }, 422);
  }

  const { data, error } = await db.rpc("cast_moderated_vote", {
    p_voter_id: voterId,
    p_request_id: request_id,
    p_decision: decision,
    p_reason: reason,
  }).single<{ approve_count: number; reject_count: number }>();
  if (error) {
    if (error.code === "23505") return json({ error: "already_voted" }, 409);
    if (error.code === "P0001") return json({ error: error.message }, 400);
    return json(
      { error: "vote_failed" },
      error.code.startsWith("22") ? 400 : 500,
    );
  }
  if (data.approve_count + data.reject_count === 5) {
    console.log(
      JSON.stringify({ event: "first_5_votes", request_id, total: 5 }),
    );
  }
  return json({ request: data });
}));
