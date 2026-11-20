-- Restore the profile for any auth account created before the signup trigger.
insert into public.users (id, display_name)
select id, coalesce(raw_user_meta_data->>'display_name', 'Anonymous') from auth.users
on conflict (id) do nothing;

alter table public.users add column guidelines_accepted_at timestamptz;

create function public.accept_guidelines()
returns void language sql security definer set search_path = '' as $$
  update public.users set guidelines_accepted_at = now()
  where id = auth.uid() and guidelines_accepted_at is null
$$;
create function public.unblock_user(p_blocked uuid)
returns void language sql security definer set search_path = '' as $$
  update public.users set blocked_ids = array_remove(blocked_ids, p_blocked)
  where id = auth.uid()
$$;
revoke all on function public.accept_guidelines(), public.unblock_user(uuid) from public, anon;
grant execute on function public.accept_guidelines(), public.unblock_user(uuid) to authenticated;
