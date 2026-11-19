# Local / mock test payloads

Base URL (local Supabase): `http://127.0.0.1:54321/functions/v1`  
Replace `$ANON_KEY` and `$ACCESS_TOKEN` from `supabase status`.  
**Never use `webhook.site`.**

## moderate-text — allow

```bash
curl -s http://127.0.0.1:54321/functions/v1/moderate-text \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"text":"Too expensive for how often you would use it.","url":"https://www.amazon.com/dp/example"}'
```

## moderate-text — block scam

```bash
curl -s http://127.0.0.1:54321/functions/v1/moderate-text \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"text":"Claim free nitro here http://bit.ly/totally-legit"}'
```

## cast-vote

```bash
curl -s http://127.0.0.1:54321/functions/v1/cast-vote \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "apikey: $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"request_id":"22222222-2222-2222-2222-222222222201","decision":"reject","reason":"You already own a keyboard that works fine."}'
```

## notify-stub — countdown expired

```bash
curl -s http://127.0.0.1:54321/functions/v1/notify-stub \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"event":"countdown_expired","user_id":"11111111-1111-1111-1111-111111111101","request_id":"22222222-2222-2222-2222-222222222201"}'
```

## notify-stub — first 5 votes

```bash
curl -s http://127.0.0.1:54321/functions/v1/notify-stub \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"event":"first_5_votes","request_id":"22222222-2222-2222-2222-222222222216"}'
```

## notify-stub — comment likes > 10

```bash
curl -s http://127.0.0.1:54321/functions/v1/notify-stub \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"event":"comment_likes_gt_10","comment_id":"00000000-0000-0000-0000-000000000001","user_id":"11111111-1111-1111-1111-111111111103"}'
```

## lock expired requests (SQL)

```bash
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" \
  -c "select public.lock_expired_requests();"
```
