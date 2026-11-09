-- Canonicalise player phone numbers before they are stored or matched.
-- UK national numbers are interpreted using the documented UK default.
-- Explicit + and 00 international prefixes are preserved and normalised to E.164.
create or replace function public.normalize_player_phone(p_phone text)
returns text
language plpgsql
immutable
strict
set search_path = ''
as $$
declare
  v_value text;
begin
  if length(btrim(p_phone)) = 0 or length(p_phone) > 30 then
    raise exception 'Enter a valid mobile or contact number';
  end if;

  -- Only common visual separators are accepted; letters and extensions are rejected.
  if p_phone !~ '^[+0-9() .-]+$' then
    raise exception 'Enter a valid phone number using digits and standard separators';
  end if;

  v_value := regexp_replace(btrim(p_phone), '[() .-]', '', 'g');

  if left(v_value, 2) = '00' then
    v_value := '+' || substr(v_value, 3);
  elsif left(v_value, 1) <> '+' then
    -- UK national format is the default for numbers without an international prefix.
    if left(v_value, 1) = '0' then
      v_value := '+44' || substr(v_value, 2);
    else
      raise exception 'Use a UK national number or an international number beginning with + or 00';
    end if;
  end if;

  -- Validate the complete E.164 form, not just its digits. This rejects
  -- embedded or repeated plus signs as well as invalid country-code prefixes.
  if v_value !~ '^\\+[1-9][0-9]{7,14}
end;
$$;

revoke all on function public.normalize_player_phone(text) from public, anon, authenticated;

create or replace function public.canonicalize_player_phone()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.phone := public.normalize_player_phone(new.phone);
  return new;
end;
$$;

drop trigger if exists players_canonicalize_phone on public.players;
create trigger players_canonicalize_phone
before insert or update of phone on public.players
for each row execute function public.canonicalize_player_phone();

-- Refuse ambiguous historical collisions rather than silently merging identities.
do $$
begin
  if exists (
    select public.normalize_player_phone(phone)
    from public.players
    group by public.normalize_player_phone(phone)
    having count(*) > 1
  ) then
    raise exception 'Phone normalisation found duplicate canonical numbers; resolve identity collisions before applying this migration';
  end if;
end;
$$;

update public.players
set phone = public.normalize_player_phone(phone)
where phone is distinct from public.normalize_player_phone(phone);

comment on function public.normalize_player_phone(text) is
  'Canonicalises a player phone number to E.164; UK national format is the default when no international prefix is supplied.';
 then
    raise exception 'Enter a valid international phone number';
  end if;

  return v_value;
end;
$$;

revoke all on function public.normalize_player_phone(text) from public, anon, authenticated;

create or replace function public.canonicalize_player_phone()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.phone := public.normalize_player_phone(new.phone);
  return new;
end;
$$;

drop trigger if exists players_canonicalize_phone on public.players;
create trigger players_canonicalize_phone
before insert or update of phone on public.players
for each row execute function public.canonicalize_player_phone();

-- Refuse ambiguous historical collisions rather than silently merging identities.
do $$
begin
  if exists (
    select public.normalize_player_phone(phone)
    from public.players
    group by public.normalize_player_phone(phone)
    having count(*) > 1
  ) then
    raise exception 'Phone normalisation found duplicate canonical numbers; resolve identity collisions before applying this migration';
  end if;
end;
$$;

update public.players
set phone = public.normalize_player_phone(phone)
where phone is distinct from public.normalize_player_phone(phone);

comment on function public.normalize_player_phone(text) is
  'Canonicalises a player phone number to E.164; UK national format is the default when no international prefix is supplied.';
