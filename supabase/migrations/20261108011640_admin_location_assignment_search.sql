create or replace function public.admin_search_location_admin_candidates(p_query text)
returns table(user_id uuid,email text,display_name text)
language plpgsql stable security definer set search_path=''
as $$
declare v_query text:=nullif(btrim(p_query),'');
begin
 if auth.uid() is null or not exists(select 1 from public.user_roles where user_id=auth.uid() and role in ('admin','super_admin')) then raise exception 'Global administrator permission required'; end if;
 if length(coalesce(v_query,''))<2 then raise exception 'Enter at least two characters to search'; end if;
 return query
 select u.id,u.email,coalesce(nullif(u.raw_user_meta_data->>'full_name',''),nullif(u.raw_user_meta_data->>'name',''),u.email)
 from auth.users u join public.user_roles r on r.user_id=u.id and r.role='league_admin'
 where u.email ilike '%'||v_query||'%' or coalesce(u.raw_user_meta_data->>'full_name',u.raw_user_meta_data->>'name','') ilike '%'||v_query||'%'
 order by u.email limit 25;
end;
$$;
revoke all on function public.admin_search_location_admin_candidates(text) from public,anon;
grant execute on function public.admin_search_location_admin_candidates(text) to authenticated;
