// Exercises the same endpoints as the mobile client against a local CLI stack.
import assert from 'node:assert/strict';

const base = 'http://127.0.0.1:54321';
const apiKey = process.env.ANON_KEY || process.env.PUBLISHABLE_KEY;
assert.ok(apiKey, 'A local Supabase API key is required');

async function post(path, body, token, expected) {
  const response = await fetch(base + path, {
    method: 'POST',
    headers: {
      apikey: apiKey,
      ...(token && { Authorization: 'Bearer ' + token }),
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });
  if (!expected.includes(response.status)) {
    throw new Error(path + ' returned ' + response.status);
  }
  const text = await response.text();
  return text && JSON.parse(text);
}

async function newUser() {
  const { access_token } = await post('/auth/v1/signup', {}, null, [200]);
  assert.ok(access_token);
  await post('/rest/v1/rpc/accept_guidelines', {}, access_token, [200, 204]);
  return access_token;
}

const owner = await newUser();
const voter = await newUser();
const purchase = {
  title: 'Desk lamp', why_want: 'For reading', price_cents: 3900,
  currency: 'USD', visibility: 'circle', duration_hours: 1,
};
const declined = await post('/functions/v1/create-request',
  { ...purchase, product_url: 'https://bit.ly/example' }, owner, [422]);
assert.equal(declined.error, 'moderation_rejected');

const { request } = await post('/functions/v1/create-request', purchase, owner, [201]);
const invitation = { p_token: request.share_token };
await post('/rest/v1/rpc/open_circle', invitation, voter, [200]);
const vote = { request_id: request.id, decision: 'reject', reason: 'Check https://bit.ly/example' };
const rejected = await post('/functions/v1/cast-vote', vote, voter, [422]);
assert.equal(rejected.error, 'moderation_rejected');
const [unchanged] = await post('/rest/v1/rpc/open_circle', invitation, voter, [200]);
assert.equal(unchanged.reject_count, 0);

const counted = await post('/functions/v1/cast-vote',
  { ...vote, reason: 'Your current lamp still works.' }, voter, [200]);
assert.equal(counted.request.reject_count, 1);
console.log('Request moderation, circle invitation, and vote accounting passed.');
