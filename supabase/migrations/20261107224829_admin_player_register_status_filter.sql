create or replace function public.get_admin_player_register(p_search text default null,p_status text default null,p_limit integer default 50,p_offset integer default 0)
returns table(user_id uuid,full_name text,email text,phone text,registration_status text,is_banned boolean,created_at timestamptz,preferred_position text,team_names text[])
language plpgsql stable security definer set search_path = '' as $$
declare v_actor uuid:=auth.uid(); v_search text:=nullif(btrim(p_search),'');
begin
if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
if p_status is not null and p_status not in ('all','pending_review','registered','rejected') then raise exception 'Invalid player registration filter'; end if;
return query
select p.user_id,p.full_name,p.email,p.phone,p.registration_status::text,p.is_banned,p.created_at,pr.preferred_position,coalesce(array_agg(distinct st.name) filter(where tm.status='active' and st.id is not null),'{}'::text[])
from public.players p left join public.profiles pr on pr.id=p.user_id left join public.team_memberships tm on tm.user_id=p.user_id and tm.status='active' left join public.season_teams st on st.id=tm.season_team_id
where (v_search is null or p.full_name ilike '%'||v_search||'%' or p.email ilike '%'||v_search||'%' or p.phone ilike '%'||v_search||'%') and (p_status is null or p_status='all' or p.registration_status::text=p_status)
group by p.user_id,p.full_name,p.email,p.phone,p.registration_status,p.is_banned,p.created_at,pr.preferred_position
order by p.full_name limit least(greatest(coalesce(p_limit,50),1),100) offset greatest(coalesce(p_offset,0),0);
end; $$;
revoke all on function public.get_admin_player_register(text,text,integer,integer) from public,anon;
grant execute on function public.get_admin_player_register(text,text,integer,integer) to authenticated;