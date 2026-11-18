# UGC Safety & Store Compliance Checklist

Required so the first iOS / Android build can pass review for user-generated content.

## Apple App Store (Guideline 1.2)

| Requirement | MVP implementation |
|-------------|-------------------|
| Filter objectionable content | `moderate-text` Edge Function + `moderation_status` on requests/votes; public feed only shows `approved` |
| Mechanism to report | In-app Report → `reports` table |
| Block abusive users | Profile / overflow → `users.blocked_ids`; feed excludes blocked authors |
| Published contact info | Store listing + in-app About email placeholder |
| Timely moderation | Pending items hidden; rejected never published |

## Google Play (UGC / Impersonation)

| Requirement | MVP implementation |
|-------------|-------------------|
| User reporting | Same `reports` flow |
| Block / restrict | Block user + hide content |
| In-app terms | Onboarding acceptance of community guidelines |
| Underage / NSFW | No adult content; image policy rejects known NSFW host patterns in moderator |

## In-app surfaces to ship

1. **Report sheet** — reasons: spam, harassment, scam link, NSFW, other.
2. **Block confirmation** — irreversible from that device account until unblock (MVP: unblock in Profile).
3. **Guidelines screen** — short rules: no scams, no hate, no NSFW, reasons required.
4. **Profanity client hint** — soft warn before submit; server is source of truth.

## Privacy

- Anonymous auth allowed; display name editable.
- No selling of vote data in MVP docs.
- Product URLs may leave the app; show external-link disclosure when opening.
