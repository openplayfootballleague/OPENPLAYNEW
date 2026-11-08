CREATE OR REPLACE FUNCTION public.get_my_team_request_statuses()
RETURNS TABLE (
  membership_id uuid,
  season_team_id uuid,
  team_name text,
  season_id uuid,
  season_name text,
  team_registration_status text,
  membership_status text,
  is_captain boolean,
  is_transfer_request boolean,
  created_at timestamp with time zone
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT
    tm.id,
    tm.season_team_id,
    st.name,
    st.season_id,
    s.name,
    st.registration_status::text,
    tm.status::text,
    tm.is_captain,
    tm.transfer_request_id IS NOT NULL,
    tm.created_at
  FROM public.team_memberships tm
  JOIN public.season_teams st ON st.id = tm.season_team_id
  JOIN public.seasons s ON s.id = st.season_id
  WHERE auth.uid() IS NOT NULL
    AND tm.user_id = auth.uid()
    AND tm.status::text <> 'left'
  ORDER BY tm.created_at DESC, tm.id
  LIMIT 100;
$function$;

REVOKE ALL ON FUNCTION public.get_my_team_request_statuses() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_team_request_statuses() TO authenticated;
