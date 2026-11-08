-- Close the profile self-service surface to avatar changes only.
-- The earlier column grant also allowed direct edits to names, phone and
-- preferred position, but the current player UI only updates avatar_path.
-- Trusted admin correction RPCs remain SECURITY DEFINER and are unaffected.
revoke update (
  first_name,
  last_name,
  display_name,
  phone,
  preferred_position
) on table public.profiles from public, anon, authenticated;
