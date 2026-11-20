-- Run with psql -v ON_ERROR_STOP=1 on a migrated local Supabase database.
begin;
insert into auth.users(id, raw_user_meta_data) values
  ('da000000-0000-4000-8000-000000000001', '{}'),
  ('da000000-0000-4000-8000-000000000002', '{}'),
  ('da000000-0000-4000-8000-000000000003', '{}');
insert into public.purchase_requests
  (id, owner_id, title, price_cents, currency, why_want, visibility, share_token,
   duration_hours, ends_at, moderation_status)
values
  ('db000000-0000-4000-8000-000000000001', 'da000000-0000-4000-8000-000000000001',
   'Keyboard', 12000, 'PHP', 'For work', 'circle', 'integration-circle', 1, now() + interval '1 hour', 'approved');
insert into public.comments (request_id, author_id, body, moderation_status)
  values ('db000000-0000-4000-8000-000000000001','da000000-0000-4000-8000-000000000001','For my desk', 'approved');

set local role authenticated;
select set_config('request.jwt.claim.sub', 'da000000-0000-4000-8000-000000000002', true);
do $$
begin
  assert (select count(*) = 1 from public.users);
  assert not exists (select 1 from public.purchase_requests where share_token = 'integration-circle');
  assert not exists (select 1 from public.comments where request_id = 'db000000-0000-4000-8000-000000000001');
  assert not has_table_privilege(current_user, 'public.purchase_requests', 'INSERT');
  assert not has_column_privilege(current_user, 'public.purchase_requests', 'approve_count', 'UPDATE');
  assert not has_table_privilege(current_user, 'public.savings_events', 'INSERT');
  assert not has_function_privilege(current_user, 'public.cast_moderated_vote(uuid,uuid,public.vote_decision,text)', 'EXECUTE');
  assert not exists (select 1 from public.open_circle('missing-invite'));
  assert (select count(*) = 1 from public.open_circle('integration-circle'));
  assert (select count(*) = 1 from public.open_circle('integration-circle'));
  assert exists (select 1 from public.comments where request_id = 'db000000-0000-4000-8000-000000000001');
end;
$$;
set local role service_role;
select public.cast_moderated_vote('da000000-0000-4000-8000-000000000002',
  'db000000-0000-4000-8000-000000000001', 'reject', 'The old one works.');
set local role authenticated;
select set_config('request.jwt.claim.sub', 'da000000-0000-4000-8000-000000000003', true);
do $$
begin
  assert not exists (select 1 from public.votes where request_id = 'db000000-0000-4000-8000-000000000001');
  assert not exists (select 1 from public.purchase_requests where share_token = 'integration-circle');
end;
$$;
reset role;
update public.purchase_requests set ends_at = now() - interval '1 minute'
  where id = 'db000000-0000-4000-8000-000000000001';
select public.lock_expired_requests();
insert into public.purchase_requests
  (id, owner_id, title, price_cents, currency, why_want, duration_hours, ends_at, status, final_verdict)
  values ('db000000-0000-4000-8000-000000000002', 'da000000-0000-4000-8000-000000000001',
    'Mouse', 4500, 'USD', 'For work', 1, now(), 'locked', 'reject');
set local role authenticated;
select set_config('request.jwt.claim.sub', 'da000000-0000-4000-8000-000000000001', true);
do $$
declare
  summary jsonb;
begin
  assert jsonb_array_length(public.savings_summary()->'eligible') = 2;
  perform public.mark_skipped('db000000-0000-4000-8000-000000000001');
  perform public.mark_skipped('db000000-0000-4000-8000-000000000001');
  perform public.mark_skipped('db000000-0000-4000-8000-000000000002');
  summary := public.savings_summary();
  assert summary->'saved_by_currency' = '{"PHP":12000,"USD":4500}'::jsonb;
  assert summary->'eligible' = '[]'::jsonb;
  assert summary->'rejected' = '2'::jsonb;
end;
$$;
rollback;
