create function public.savings_summary()
returns jsonb language sql stable security invoker set search_path = '' as $$
  with mine as (
    select * from public.purchase_requests where owner_id = (select auth.uid())
  ), saved as (
    select * from public.savings_events where user_id = (select auth.uid())
  )
  select jsonb_build_object(
    'submitted', count(*),
    'approved', count(*) filter (where final_verdict = 'approve'),
    'rejected', count(*) filter (where final_verdict = 'reject'),
    'saved_by_currency', coalesce((
      select jsonb_object_agg(currency, total) from (
        select currency, sum(amount_cents) as total from saved group by currency
      ) amounts
    ), '{}'::jsonb),
    'eligible', coalesce((
      select jsonb_agg(to_jsonb(eligible) order by ends_at desc, id) from (
        select m.* from mine m where status = 'locked' and final_verdict = 'reject'
          and not exists (select 1 from saved where request_id = m.id)
        order by ends_at desc, id limit 50
      ) eligible
    ), '[]'::jsonb)
  ) from mine
$$;
revoke all on function public.savings_summary from public, anon;
grant execute on function public.savings_summary to authenticated;

create or replace function public.mark_skipped(p_request_id uuid)
returns public.savings_events language plpgsql security definer set search_path = '' as $$
declare
  result public.savings_events;
begin
  insert into public.savings_events (request_id, user_id, amount_cents, currency)
    select id, owner_id, price_cents, currency from public.purchase_requests
    where id = p_request_id and owner_id = auth.uid()
      and status = 'locked' and final_verdict = 'reject'
    on conflict (request_id, user_id) do nothing;
  select * into result from public.savings_events
    where request_id = p_request_id and user_id = auth.uid();
  if not found then raise exception 'only a rejected purchase can be marked skipped'; end if;
  return result;
end;
$$;
revoke all on function public.mark_skipped from public, anon;
grant execute on function public.mark_skipped to authenticated;
