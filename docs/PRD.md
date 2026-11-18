# HoldMyWallet ("Wallet, Please Wait") — MVP PRD

**Product name (store):** HoldMyWallet  
**Working title / keyword:** Wallet, Please Wait  
**Platforms:** iOS + Android (Flutter)  
**Backend:** Supabase (Auth, Postgres, RLS, Realtime, Edge Functions, Storage)  
**Monetization (MVP):** Ad-supported (AdMob banners + interstitial after vote)  
**Hard constraint:** Never use `webhook.site` in code, mocks, or tests.

---

## 1. Problem & opportunity

Impulse checkout is common among Gen-Z / Millennial shoppers on Shopee, Lazada, Amazon, and TikTok Shop. The viral Chinese mini-program “钱包请等等” proved demand for a social pause before purchase. There is no standalone native app for SEA / US / EU storefronts.

**Core loop:** Shopper submits a purchase request → strangers or a private circle vote Approve / Reject with a mandatory short reason → countdown ends → verdict + optional “I skipped it” savings tracking.

---

## 2. Target users

| Segment | Markets | Habits |
|--------|---------|--------|
| SEA shoppers | PH, SG, MY, ID | Shopee / Lazada, flash sales |
| US / EU shoppers | US, EU | Amazon / TikTok Shop, de-influencing |

Currencies (MVP): `PHP`, `SGD`, `MYR`, `IDR`, `USD`, `EUR`.

---

## 3. MVP user flows

### 3.1 Onboarding

1. Launch → anonymous Supabase Auth (optional later: Google / Apple).
2. Auto-detect region / currency from device locale (editable).
3. Show short value prop + UGC safety notice; accept community guidelines.

### 3.2 Create purchase request

Fields:

| Field | Rules |
|-------|--------|
| Item name | required, 3–80 chars |
| Price + currency | required; stored as `price_cents` + `currency` |
| Product link | optional URL |
| Image | camera / gallery / URL → Storage `request-images` |
| Why I want it | required, ≤280 chars |
| Cheaper alternative | optional, ≤280 chars |
| Timer | `1h` \| `6h` \| `24h` → `ends_at` |
| Visibility | `public` (Public Square) \| `circle` (share token) |

### 3.3 Public Square (feed)

- Vertical card feed (Tinder-style swipe optional; MVP: Approve / Reject buttons).
- Card shows image, formatted price, “why”, live approve/reject progress.
- Tapping Approve or Reject opens a bottom sheet: **1-sentence reason required** (max 140 chars) before the vote counts.
- Votes call server RPC / Edge Function (no client-side counter mutation).

### 3.4 Private Circle

- Request created with `visibility = circle` and `share_token`.
- Deep link: `walletwait://r/{share_token}` + HTTPS fallback documented in README.
- Recipients open link → vote without browsing the public feed.

### 3.5 Savings dashboard

- Requests submitted count.
- Approved vs rejected ratio (locked requests).
- Estimated money saved = sum of `savings_events` when owner marks a rejected/locked item as **Skipped**.

---

## 4. Retention & gamification

| Mechanic | Behavior |
|----------|----------|
| Total Money Saved | Persistent profile stat from skipped rejected items |
| Approve / Reject ratio | Personal insight on impulse patterns |
| Voice of Reason badge | Awarded when a user’s vote reason receives high “helpful” engagement (MVP: comment likes ≥ 10) |
| Push (stubbed) | First 5 votes; countdown expired / verdict; helpful comment threshold |

---

## 5. Anti-troll & moderation

- Mandatory reason on every vote (min length 8, max 140).
- Server moderation on request + vote text (toxicity / scam URL heuristics).
- `moderation_status`: `pending` \| `approved` \| `rejected`.
- Block user (adds to `users.blocked_ids`); blocked authors hidden from feed.
- Report post / user → `reports` table.
- Double-vote prevented by `UNIQUE (request_id, voter_id)` + RPC checks.
- Voting locked when `ends_at` passed or `status = locked`.

---

## 6. Data model (summary)

See `supabase/migrations/001_init.sql` for authoritative SQL.

- `users`, `purchase_requests`, `votes`, `comments`, `reports`, `savings_events`

---

## 7. App Store / Play compliance (UGC)

Required for first review pass:

1. **Block user** — Profile / overflow menu.
2. **Report content** — Report reason picker → persisted.
3. **Filter / hide** — Profanity / toxicity gate before publish; pending moderation not shown in public feed.
4. **EULA / guidelines** — Linked in onboarding and store metadata.
5. **Publisher contact** — In store listing + in-app About.
6. **Age rating** — Content may include user text; no NSFW images allowed (image URL / upload policy).

Details: [COMPLIANCE.md](./COMPLIANCE.md).

---

## 8. Ads (MVP)

- Banner on Feed and Savings.
- Interstitial after successful vote (feature flag `ENABLE_ADS`; Google **test** unit IDs only in scaffold).
- No IAP / remove-ads in MVP.

---

## 9. Non-goals (this MVP)

- Live production Supabase / FCM credentials in repo
- Real AdMob unit IDs
- Store binary submission
- Subscriptions
- Multi-language UI (English copy; SEA currencies only)
