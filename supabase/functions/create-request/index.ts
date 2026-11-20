import { authenticatedWrite, json } from "../_shared/authenticated-write.ts";
import { moderateContent } from "../_shared/moderate.ts";

Deno.serve(authenticatedWrite(async (body, ownerId, db) => {
  const {
    title,
    why_want,
    cheaper_alt,
    product_url,
    image_url,
    duration_hours,
    currency,
    price_cents,
    visibility,
  } = body;
  if (
    typeof title !== "string" || typeof why_want !== "string" ||
    (cheaper_alt != null && typeof cheaper_alt !== "string") ||
    typeof duration_hours !== "number" ||
    ![1, 6, 24].includes(duration_hours) ||
    typeof price_cents !== "number" || !Number.isSafeInteger(price_cents) ||
    price_cents < 0 ||
    typeof currency !== "string" ||
    !["PHP", "SGD", "MYR", "IDR", "USD", "EUR"].includes(currency) ||
    (visibility !== "public" && visibility !== "circle")
  ) {
    return json({ error: "invalid_payload" }, 400);
  }
  for (const url of [product_url, image_url]) {
    if (
      url != null && (typeof url !== "string" || !URL.canParse(url) ||
        !["http:", "https:"].includes(new URL(url).protocol))
    ) {
      return json({ error: "invalid_url" }, 400);
    }
  }
  const moderation = moderateContent({
    text: [title, why_want, cheaper_alt, product_url, image_url].filter(Boolean)
      .join("\n"),
  });
  if (!moderation.allowed) {
    return json({ error: "moderation_rejected", ...moderation }, 422);
  }
  const { data, error } = await db.from("purchase_requests").insert({
    owner_id: ownerId,
    title: title.trim(),
    why_want: why_want.trim(),
    cheaper_alt,
    product_url,
    image_url,
    price_cents,
    currency,
    visibility,
    duration_hours,
    ends_at: new Date(Date.now() + duration_hours * 3600000).toISOString(),
    moderation_status: moderation.moderation_status,
  }).select().single();
  if (error) {
    return json(
      { error: "request_failed" },
      error.code.startsWith("22") || error.code === "23514" ? 400 : 500,
    );
  }
  return json({ request: data }, 201);
}));
