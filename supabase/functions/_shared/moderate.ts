export type ModerateResult = {
  allowed: boolean;
  reasons: string[];
  moderation_status: "approved" | "rejected";
};

const TOXIC_PATTERNS = [
  /\b(kill\s*yourself|kys)\b/i,
  /\b(nazi|rape)\b/i,
  /\b(f+u+c+k\s*you)\b/i,
];

const SCAM_HOST_PATTERNS = [
  /bit\.ly/i,
  /tinyurl\.com/i,
  /t\.me\//i,
  /crypto-?airdrop/i,
  /free-?nitro/i,
  /wallet-?connect.*claim/i,
];

const NSFW_HOST_PATTERNS = [/pornhub/i, /xvideos/i, /onlyfans/i];

export function moderateContent(input: {
  text?: string;
  url?: string;
}): ModerateResult {
  const reasons: string[] = [];
  const text = (input.text ?? "").trim();
  const url = (input.url ?? "").trim();

  for (const re of TOXIC_PATTERNS) {
    if (re.test(text)) reasons.push("toxicity");
  }
  for (const re of SCAM_HOST_PATTERNS) {
    if (re.test(text) || re.test(url)) reasons.push("scam_link");
  }
  for (const re of NSFW_HOST_PATTERNS) {
    if (re.test(text) || re.test(url)) reasons.push("nsfw");
  }

  const linkCount = (text.match(/https?:\/\//gi) ?? []).length;
  if (linkCount >= 3) reasons.push("link_spam");

  const unique = [...new Set(reasons)];
  const allowed = unique.length === 0;
  return {
    allowed,
    reasons: unique,
    moderation_status: allowed ? "approved" : "rejected",
  };
}
