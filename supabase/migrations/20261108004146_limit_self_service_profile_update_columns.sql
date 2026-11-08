-- Keep profile self-service writes limited to the fields exposed by the
-- Player Hub. DOB and emergency-contact details remain admin-managed.
-- SECURITY DEFINER admin RPCs continue to perform privileged corrections.
revoke update on table public.profiles from authenticated;
grant update (
  first_name,
  last_name,
  display_name,
  phone,
  preferred_position,
  avatar_path
) on table public.profiles to authenticated;
