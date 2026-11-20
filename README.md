# HoldMyWallet (“Wallet, Please Wait”)

Anti-impulse-buying social utility: submit a purchase request, let strangers or a private circle **Approve** / **Reject** with a mandatory reason, then track money saved when you skip rejects.

**Stack:** Flutter (`mobile/`) + Supabase (`supabase/`) + AdMob stubs (ad-supported MVP).  
**Hard constraint:** Never use `webhook.site` in code, mocks, or tests.

## Repo layout

| Path | Contents |
|------|----------|
| [`docs/PRD.md`](docs/PRD.md) | MVP product requirements |
| [`docs/ASO.md`](docs/ASO.md) | Naming, store copy, seed launch plan |
| [`docs/COMPLIANCE.md`](docs/COMPLIANCE.md) | UGC / store review checklist |
| [`supabase/`](supabase/) | Migrations, RLS, RPCs, seed, Edge Functions |
| [`mobile/`](mobile/) | Flutter app (feature-first) |

## Quick start — Flutter (mock data)

```bash
cd mobile
flutter pub get
flutter run --dart-define=USE_MOCK_DATA=true --dart-define=ENABLE_ADS=false
```

Default mode uses in-memory seed cards so UI works without a live backend.

## Quick start — Supabase local

```bash
# Requires Supabase CLI + Docker
supabase start
supabase db reset   # applies migrations + seed.sql

cd mobile
flutter run \
  --dart-define=USE_MOCK_DATA=false \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_ANON_KEY=<anon-key-from-supabase-status> \
  --dart-define=ENABLE_ADS=false
```

Edge function smoke tests (localhost only): see [`supabase/functions/_shared/test_payloads.md`](supabase/functions/_shared/test_payloads.md).

## Deep links (Private Circle)

- App scheme: `walletwait://r/{share_token}`
- HTTPS fallback (documented): `https://holdmywallet.app/r/{share_token}`

## Ads

- Banners on Feed / Savings; interstitial after a successful vote.
- Controlled by `--dart-define=ENABLE_ADS=true|false`.
- Scaffold uses **Google test AdMob unit IDs** only.

## Brand

Store-facing name: **HoldMyWallet**  
Keyword bridge: Wallet, Please Wait (see ASO doc).

## Release checks

Use Flutter 3.50.0 and Supabase CLI 3.2.0 for the checks in
[`release-checks.yml`](.github/workflows/release-checks.yml). The workflow resets a
local database, checks circle access and savings, and submits requests and votes
through the Edge Functions with anonymous user sessions.

Apply migrations and deploy `create-request` and `cast-vote` together in staging
before distributing the updated client. Both functions use the built-in server
environment to verify the session and moderate content. Existing clients must
upgrade to create requests. Circle links grant access when opened. If a previous
deployment exposed invitation tokens, replace affected invitations before launch.
The expiry job runs every minute. The Saved tab can be refreshed after a verdict.

For Android signing, put `storeFile` (absolute or relative to `mobile/android`),
`storePassword`, `keyAlias` and `keyPassword` in the ignored
`mobile/android/key.properties`. Use the Play upload key. Build with
`--dart-define=USE_MOCK_DATA=false`, a hosted HTTPS `SUPABASE_URL` and its public
`SUPABASE_ANON_KEY` supplied through `--dart-define`. Keep ads disabled until
production ad IDs and consent settings are configured. Keep the demo seed local.
