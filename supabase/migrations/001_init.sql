-- HoldMyWallet / Wallet Please Wait — initial schema, RLS, RPCs
-- Currencies: PHP, SGD, MYR, IDR, USD, EUR

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
create type public.currency_code as enum ('PHP', 'SGD', 'MYR', 'IDR', 'USD', 'EUR');
create type public.request_visibility as enum ('public', 'circle');
create type public.request_status as enum ('open', 'locked');
create type public.vote_decision as enum ('approve', 'reject');
create type public.moderation_status as enum ('pending', 'approved', 'rejected');
create type public.final_verdict as enum ('approve', 'reject', 'tie');
create type public.report_target as enum ('request', 'vote', 'comment', 'user');
create type public.report_status as enum ('open', 'reviewed', 'actioned', 'dismissed');

-- ---------------------------------------------------------------------------
-- users (profile row keyed to auth.users)
-- ---------------------------------------------------------------------------
create table public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default 'Anonymous',
  region text not null default 'US',
  currency public.currency_code not null default 'USD',
  blocked_ids uuid[] not null default '{}',
  fcm_token text,
  voice_of_reason boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- purchase_requests
-- ---------------------------------------------------------------------------
create table public.purchase_requests (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.users (id) on delete cascade,
  title text not null check (char_length(title) between 3 and 80),
  price_cents integer not null check (price_cents >= 0),
  currency public.currency_code not null,
  image_url text,
  product_url text,
  why_want text not null check (char_length(why_want) between 1 and 280),
  cheaper_alt text check (cheaper_alt is null or char_length(cheaper_alt) <= 280),
  visibility public.request_visibility not null default 'public',
  share_token text not null unique default encode(gen_random_bytes(12), 'hex'),
  duration_hours integer not null check (duration_hours in (1, 6, 24)),
  ends_at timestamptz not null,
  status public.request_status not null default 'open',
  approve_count integer not null default 0 check (approve_count >= 0),
  reject_count integer not null default 0 check (reject_count >= 0),
  final_verdict public.final_verdict,
  moderation_status public.moderation_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index purchase_requests_public_feed_idx
  on public.purchase_requests (created_at desc)
  where visibility = 'public' and moderation_status = 'approved' and status = 'open';

create index purchase_requests_owner_idx on public.purchase_requests (owner_id);
create index purchase_requests_share_token_idx on public.purchase_requests (share_token);
create index purchase_requests_ends_at_idx on public.purchase_requests (ends_at)
  where status = 'open';

-- ---------------------------------------------------------------------------
-- votes
-- ---------------------------------------------------------------------------
create table public.votes (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.purchase_requests (id) on delete cascade,
  voter_id uuid not null references public.users (id) on delete cascade,
  decision public.vote_decision not null,
  reason text not null check (char_length(reason) between 8 and 140),
  helpful_count integer not null default 0 check (helpful_count >= 0),
  moderation_status public.moderation_status not null default 'pending',
  created_at timestamptz not null default now(),
  unique (request_id, voter_id)
);

create index votes_request_idx on public.votes (request_id);

-- ---------------------------------------------------------------------------
-- comments (optional notes / engagement for notify hooks)
-- ---------------------------------------------------------------------------
create table public.comments (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.purchase_requests (id) on delete cascade,
  author_id uuid not null references public.users (id) on delete cascade,
  body text not null check (char_length(body) between 1 and 280),
  likes_count integer not null default 0 check (likes_count >= 0),
  moderation_status public.moderation_status not null default 'pending',
  created_at timestamptz not null default now()
);

create index comments_request_idx on public.comments (request_id);

-- ---------------------------------------------------------------------------
-- reports
-- ---------------------------------------------------------------------------
create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.users (id) on delete cascade,
  target_type public.report_target not null,
  target_id uuid not null,
  reason text not null check (char_length(reason) between 3 and 280),
  status public.report_status not null default 'open',
  created_at timestamptz not null default now()
);

create index reports_reporter_idx on public.reports (reporter_id);

-- ---------------------------------------------------------------------------
-- savings_events (owner marked rejected/locked item as Skipped)
-- ---------------------------------------------------------------------------
create table public.savings_events (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.purchase_requests (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  amount_cents integer not null check (amount_cents >= 0),
  currency public.currency_code not null,
  created_at timestamptz not null default now(),
  unique (request_id, user_id)
);

-- ---------------------------------------------------------------------------
-- updated_at helper
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger users_set_updated_at
  before update on public.users
  for each row execute function public.set_updated_at();

create trigger purchase_requests_set_updated_at
  before update on public.purchase_requests
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Auto-create public.users on auth signup / anonymous sign-in
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', 'Anonymous')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- cast_vote RPC — atomic, no double-vote, respects timer lock
-- ---------------------------------------------------------------------------
create or replace function public.cast_vote(
  p_request_id uuid,
  p_decision public.vote_decision,
  p_reason text
)
returns public.purchase_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_req public.purchase_requests;
  v_mod public.moderation_status := 'approved';
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if char_length(trim(p_reason)) < 8 or char_length(p_reason) > 140 then
    raise exception 'reason must be 8–140 characters';
  end if;

  select * into v_req
  from public.purchase_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'request not found';
  end if;

  if v_req.owner_id = v_uid then
    raise exception 'cannot vote on own request';
  end if;

  if v_req.status <> 'open' or v_req.ends_at <= now() then
    raise exception 'voting is locked';
  end if;

  if v_req.moderation_status = 'rejected' then
    raise exception 'request not available';
  end if;

  -- Insert vote; unique constraint blocks doubles
  insert into public.votes (request_id, voter_id, decision, reason, moderation_status)
  values (p_request_id, v_uid, p_decision, trim(p_reason), v_mod);

  if p_decision = 'approve' then
    update public.purchase_requests
    set approve_count = approve_count + 1
    where id = p_request_id
    returning * into v_req;
  else
    update public.purchase_requests
    set reject_count = reject_count + 1
    where id = p_request_id
    returning * into v_req;
  end if;

  return v_req;
end;
$$;

-- ---------------------------------------------------------------------------
-- lock_expired_requests — call from cron / edge schedule
-- ---------------------------------------------------------------------------
create or replace function public.lock_expired_requests()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  with locked as (
    update public.purchase_requests
    set
      status = 'locked',
      final_verdict = case
        when approve_count > reject_count then 'approve'::public.final_verdict
        when reject_count > approve_count then 'reject'::public.final_verdict
        else 'tie'::public.final_verdict
      end,
      updated_at = now()
    where status = 'open' and ends_at <= now()
    returning id
  )
  select count(*) into v_count from locked;

  return v_count;
end;
$$;

-- ---------------------------------------------------------------------------
-- mark_skipped — owner records savings after reject/tie lock
-- ---------------------------------------------------------------------------
create or replace function public.mark_skipped(p_request_id uuid)
returns public.savings_events
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_req public.purchase_requests;
  v_event public.savings_events;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select * into v_req from public.purchase_requests where id = p_request_id;
  if not found then
    raise exception 'request not found';
  end if;
  if v_req.owner_id <> v_uid then
    raise exception 'only owner can mark skipped';
  end if;
  if v_req.status <> 'locked' then
    raise exception 'request still open';
  end if;
  if v_req.final_verdict = 'approve' then
    raise exception 'approved items cannot be marked skipped for savings';
  end if;

  insert into public.savings_events (request_id, user_id, amount_cents, currency)
  values (v_req.id, v_uid, v_req.price_cents, v_req.currency)
  on conflict (request_id, user_id) do update
    set amount_cents = excluded.amount_cents
  returning * into v_event;

  return v_event;
end;
$$;

-- ---------------------------------------------------------------------------
-- block_user
-- ---------------------------------------------------------------------------
create or replace function public.block_user(p_blocked uuid)
returns public.users
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_user public.users;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;
  if p_blocked = v_uid then
    raise exception 'cannot block yourself';
  end if;

  update public.users
  set blocked_ids = (
    select array_agg(distinct x)
    from unnest(blocked_ids || p_blocked) as x
  )
  where id = v_uid
  returning * into v_user;

  return v_user;
end;
$$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.users enable row level security;
alter table public.purchase_requests enable row level security;
alter table public.votes enable row level security;
alter table public.comments enable row level security;
alter table public.reports enable row level security;
alter table public.savings_events enable row level security;

-- users
create policy users_select_authenticated on public.users
  for select to authenticated using (true);

create policy users_update_own on public.users
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- purchase_requests select: public approved (not blocked), own, or circle via share (client filters token)
create policy requests_select_public on public.purchase_requests
  for select to authenticated
  using (
    owner_id = auth.uid()
    or (
      visibility = 'public'
      and moderation_status = 'approved'
      and owner_id <> all (
        coalesce((select blocked_ids from public.users where id = auth.uid()), '{}')
      )
    )
    or visibility = 'circle'
  );

create policy requests_insert_own on public.purchase_requests
  for insert to authenticated
  with check (owner_id = auth.uid());

create policy requests_update_own on public.purchase_requests
  for update to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

-- votes: readable on visible requests; insert via RPC (security definer) — still allow select
create policy votes_select on public.votes
  for select to authenticated
  using (
    moderation_status = 'approved'
    or voter_id = auth.uid()
  );

-- Direct inserts disabled for clients; use cast_vote RPC
create policy votes_no_direct_insert on public.votes
  for insert to authenticated
  with check (false);

-- comments
create policy comments_select on public.comments
  for select to authenticated
  using (moderation_status = 'approved' or author_id = auth.uid());

create policy comments_insert on public.comments
  for insert to authenticated
  with check (author_id = auth.uid());

-- reports: insert own; no public read of others' reports
create policy reports_insert_own on public.reports
  for insert to authenticated
  with check (reporter_id = auth.uid());

create policy reports_select_own on public.reports
  for select to authenticated
  using (reporter_id = auth.uid());

-- savings
create policy savings_select_own on public.savings_events
  for select to authenticated
  using (user_id = auth.uid());

create policy savings_insert_own on public.savings_events
  for insert to authenticated
  with check (user_id = auth.uid());

-- Grants for RPC
grant usage on schema public to authenticated;
grant select, update on public.users to authenticated;
grant select, insert, update on public.purchase_requests to authenticated;
grant select on public.votes to authenticated;
grant select, insert on public.comments to authenticated;
grant select, insert on public.reports to authenticated;
grant select, insert on public.savings_events to authenticated;
grant execute on function public.cast_vote(uuid, public.vote_decision, text) to authenticated;
grant execute on function public.lock_expired_requests() to authenticated;
grant execute on function public.mark_skipped(uuid) to authenticated;
grant execute on function public.block_user(uuid) to authenticated;

-- Storage bucket (run after storage schema exists in hosted/local supabase)
insert into storage.buckets (id, name, public)
values ('request-images', 'request-images', true)
on conflict (id) do nothing;

create policy request_images_public_read on storage.objects
  for select using (bucket_id = 'request-images');

create policy request_images_auth_upload on storage.objects
  for insert to authenticated
  with check (bucket_id = 'request-images' and auth.uid()::text = (storage.foldername(name))[1]);
