create schema if not exists private;

-- Invitations are bearer links. Only the token redemption function adds members.
create table private.circle_members (
  request_id uuid not null references public.purchase_requests on delete cascade,
  user_id uuid not null references public.users on delete cascade,
  primary key (request_id, user_id)
);
revoke all on private.circle_members from public, anon, authenticated;

create function private.can_read_request(r public.purchase_requests, viewer uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select viewer is not null and (
    r.owner_id = viewer or (
      r.moderation_status = 'approved'
      and not exists (
        select 1 from public.users u where
          (u.id = viewer and r.owner_id = any(u.blocked_ids)) or
          (u.id = r.owner_id and viewer = any(u.blocked_ids))
      )
      and (r.visibility = 'public' or exists (
        select 1 from private.circle_members m
        where m.request_id = r.id and m.user_id = viewer
      ))
    )
  )
$$;
revoke all on function private.can_read_request from public, anon;
grant execute on function private.can_read_request to authenticated;

create function public.open_circle(p_token text)
returns setof public.purchase_requests
language plpgsql security definer set search_path = '' as $$
declare
  viewer uuid := auth.uid();
  r public.purchase_requests;
begin
  if viewer is null then return; end if;
  select * into r from public.purchase_requests
    where share_token = p_token and visibility = 'circle' and moderation_status = 'approved';
  if not found or exists (
    select 1 from public.users u where
      (u.id = viewer and r.owner_id = any(u.blocked_ids)) or
      (u.id = r.owner_id and viewer = any(u.blocked_ids))
  ) then return; end if;
  insert into private.circle_members values (r.id, viewer) on conflict do nothing;
  return next r;
end;
$$;
revoke all on function public.open_circle from public, anon;
grant execute on function public.open_circle to authenticated;

alter policy users_select_authenticated on public.users using (id = (select auth.uid()));
alter policy requests_select_public on public.purchase_requests
  using (private.can_read_request(purchase_requests, (select auth.uid())));
alter policy votes_select on public.votes using (
  (moderation_status = 'approved' or voter_id = (select auth.uid()))
  and exists (select 1 from public.purchase_requests r where r.id = request_id)
);
alter policy comments_select on public.comments using (
  (moderation_status = 'approved' or author_id = (select auth.uid()))
  and exists (select 1 from public.purchase_requests r where r.id = request_id)
);
alter policy comments_insert on public.comments with check (
  author_id = (select auth.uid()) and moderation_status = 'pending'
  and exists (select 1 from public.purchase_requests r where r.id = request_id)
);

-- Keep decisions, totals, identities, and moderation state under server control.
drop policy requests_insert_own on public.purchase_requests;
drop policy requests_update_own on public.purchase_requests;
drop policy savings_insert_own on public.savings_events;
revoke all on public.purchase_requests, public.savings_events, public.users,
  public.votes, public.comments, public.reports from public, anon, authenticated;
grant select on public.purchase_requests, public.savings_events, public.users,
  public.votes, public.comments, public.reports to authenticated;
grant update (display_name, region, currency, fcm_token) on public.users to authenticated;
grant insert (author_id, request_id, body) on public.comments to authenticated;
grant insert (reporter_id, target_type, target_id, reason) on public.reports to authenticated;
grant select, insert on public.purchase_requests to service_role;

-- Only the Edge Function may supply the verified voter after moderation.
drop function public.cast_vote(uuid, public.vote_decision, text);
create function public.cast_moderated_vote(
  p_voter_id uuid, p_request_id uuid, p_decision public.vote_decision, p_reason text
) returns public.purchase_requests
language plpgsql security definer set search_path = '' as $$
declare
  r public.purchase_requests;
begin
  select * into r from public.purchase_requests where id = p_request_id for update;
  if not found or not private.can_read_request(r, p_voter_id) or r.moderation_status <> 'approved' then
    raise exception 'request unavailable';
  end if;
  if r.owner_id = p_voter_id then raise exception 'cannot vote on own request'; end if;
  if r.status <> 'open' or r.ends_at <= clock_timestamp() then raise exception 'voting is locked'; end if;
  insert into public.votes (voter_id, request_id, decision, reason, moderation_status)
    values (p_voter_id, r.id, p_decision, trim(p_reason), 'approved');
  update public.purchase_requests set
    approve_count = approve_count + (p_decision = 'approve')::integer,
    reject_count = reject_count + (p_decision = 'reject')::integer
    where id = r.id returning * into r;
  return r;
end;
$$;
revoke all on function public.cast_moderated_vote from public, anon, authenticated;
grant execute on function public.cast_moderated_vote to service_role;
revoke all on function public.lock_expired_requests from public, anon, authenticated;
grant execute on function public.lock_expired_requests to service_role;

create extension if not exists pg_cron;
select cron.schedule('finalize-purchase-requests', '* * * * *', 'select public.lock_expired_requests()');
