-- Open Play initial platform schema
-- Apply only to the dedicated "Open Play New" Supabase project.
-- This migration creates the domain model; it does not seed fake production data.

create extension if not exists pgcrypto;

create type public.competition_format as enum ('six_a_side', 'seven_a_side');
create type public.season_status as enum ('draft', 'registration_open', 'active', 'completed', 'archived');
create type public.fixture_status as enum ('scheduled', 'in_progress', 'completed', 'postponed', 'cancelled');
create type public.registration_status as enum ('pending', 'approved', 'rejected', 'withdrawn');
create type public.membership_status as enum ('pending', 'active', 'suspended', 'left');
create type public.payment_status as enum ('pending', 'processing', 'paid', 'failed', 'refunded', 'cancelled');
create type public.lineup_role as enum ('starter', 'substitute');
create type public.transfer_status as enum ('pending', 'approved', 'rejected', 'cancelled');

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  first_name text,
  last_name text,
  display_name text,
  date_of_birth date,
  phone text,
  emergency_contact_name text,
  emergency_contact_phone text,
  preferred_position text,
  avatar_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_first_name_length check (first_name is null or char_length(trim(first_name)) between 1 and 80),
  constraint profiles_last_name_length check (last_name is null or char_length(trim(last_name)) between 1 and 80)
);

create table public.user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('admin', 'super_admin', 'finance_admin', 'league_admin')),
  granted_by uuid references auth.users(id) on delete set null,
  granted_at timestamptz not null default now(),
  unique (user_id, role)
);

create table public.locations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  town text not null,
  region text not null default 'North Devon',
  address text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.leagues (
  id uuid primary key default gen_random_uuid(),
  location_id uuid not null references public.locations(id) on delete restrict,
  name text not null,
  slug text not null unique,
  format public.competition_format not null default 'six_a_side',
  description text,
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.seasons (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null references public.leagues(id) on delete restrict,
  name text not null,
  season_number integer,
  starts_on date,
  ends_on date,
  registration_opens_at timestamptz,
  registration_closes_at timestamptz,
  status public.season_status not null default 'draft',
  is_public boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (league_id, name),
  constraint seasons_dates_valid check (ends_on is null or starts_on is null or ends_on >= starts_on)
);

create table public.teams (
  id uuid primary key default gen_random_uuid(),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

-- A team's identity and presentation are frozen per season so historical seasons
-- are not rewritten when a team changes name, badge or colours.
create table public.season_teams (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete restrict,
  season_id uuid not null references public.seasons(id) on delete restrict,
  name text not null,
  slug text not null,
  badge_path text,
  primary_colour text,
  secondary_colour text,
  registration_status public.registration_status not null default 'pending',
  approved_at timestamptz,
  approved_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (season_id, slug),
  unique (team_id, season_id)
);

create table public.season_registrations (
  id uuid primary key default gen_random_uuid(),
  season_id uuid not null references public.seasons(id) on delete restrict,
  user_id uuid not null references public.profiles(id) on delete cascade,
  status public.registration_status not null default 'pending',
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id) on delete set null,
  unique (season_id, user_id)
);

create table public.team_memberships (
  id uuid primary key default gen_random_uuid(),
  season_team_id uuid not null references public.season_teams(id) on delete restrict,
  user_id uuid not null references public.profiles(id) on delete cascade,
  status public.membership_status not null default 'pending',
  is_captain boolean not null default false,
  squad_number smallint,
  joined_at timestamptz,
  left_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (season_team_id, user_id),
  constraint team_memberships_squad_number_valid check (squad_number is null or squad_number between 1 and 99)
);

create unique index team_memberships_one_active_captain
  on public.team_memberships(season_team_id)
  where is_captain and status = 'active';

create table public.fixtures (
  id uuid primary key default gen_random_uuid(),
  season_id uuid not null references public.seasons(id) on delete restrict,
  gameweek integer not null check (gameweek > 0),
  fixture_number integer not null default 1 check (fixture_number > 0),
  home_team_id uuid not null references public.season_teams(id) on delete restrict,
  away_team_id uuid not null references public.season_teams(id) on delete restrict,
  venue_id uuid references public.locations(id) on delete set null,
  scheduled_at timestamptz,
  status public.fixture_status not null default 'scheduled',
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fixtures_different_teams check (home_team_id <> away_team_id),
  unique (season_id, gameweek, fixture_number)
);

create table public.fixture_results (
  fixture_id uuid primary key references public.fixtures(id) on delete cascade,
  home_score smallint not null check (home_score >= 0),
  away_score smallint not null check (away_score >= 0),
  confirmed_at timestamptz,
  confirmed_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

create table public.fixture_team_sheets (
  id uuid primary key default gen_random_uuid(),
  fixture_id uuid not null references public.fixtures(id) on delete cascade,
  season_team_id uuid not null references public.season_teams(id) on delete restrict,
  submitted_by uuid not null references auth.users(id) on delete restrict,
  submitted_at timestamptz not null default now(),
  is_locked boolean not null default false,
  unique (fixture_id, season_team_id)
);

create table public.fixture_team_sheet_players (
  id uuid primary key default gen_random_uuid(),
  team_sheet_id uuid not null references public.fixture_team_sheets(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete restrict,
  role public.lineup_role not null,
  squad_number_snapshot smallint,
  created_at timestamptz not null default now(),
  unique (team_sheet_id, user_id),
  constraint fixture_squad_number_valid check (squad_number_snapshot is null or squad_number_snapshot between 1 and 99)
);

create table public.fixture_availability (
  id uuid primary key default gen_random_uuid(),
  fixture_id uuid not null references public.fixtures(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  is_available boolean not null,
  response_note text,
  responded_at timestamptz not null default now(),
  unique (fixture_id, user_id)
);

create table public.transfer_requests (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.profiles(id) on delete cascade,
  from_membership_id uuid references public.team_memberships(id) on delete set null,
  target_season_team_id uuid not null references public.season_teams(id) on delete restrict,
  status public.transfer_status not null default 'pending',
  message text,
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.season_fee_configs (
  id uuid primary key default gen_random_uuid(),
  season_id uuid not null references public.seasons(id) on delete restrict,
  team_fee_pence integer not null check (team_fee_pence >= 0),
  effective_from_gameweek integer not null default 1 check (effective_from_gameweek > 0),
  reason text,
  changed_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (season_id, effective_from_gameweek)
);

create table public.payment_records (
  id uuid primary key default gen_random_uuid(),
  season_team_id uuid not null references public.season_teams(id) on delete restrict,
  fixture_id uuid references public.fixtures(id) on delete restrict,
  amount_pence integer not null check (amount_pence >= 0),
  currency text not null default 'gbp' check (currency = lower(currency) and char_length(currency) = 3),
  status public.payment_status not null default 'pending',
  fee_snapshot jsonb not null,
  stripe_checkout_session_id text unique,
  stripe_payment_intent_id text unique,
  paid_at timestamptz,
  refunded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.notification_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  channel text not null check (channel in ('email', 'sms', 'in_app')),
  event_type text not null,
  status text not null default 'queued' check (status in ('queued', 'sent', 'failed', 'cancelled')),
  provider_reference text,
  payload jsonb not null default '{}'::jsonb,
  sent_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.audit_log (
  id bigint generated always as identity primary key,
  actor_user_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id text,
  before_data jsonb,
  after_data jsonb,
  reason text,
  created_at timestamptz not null default now()
);

create index seasons_league_status_idx on public.seasons(league_id, status);
create index season_teams_season_idx on public.season_teams(season_id);
create index memberships_user_status_idx on public.team_memberships(user_id, status);
create index fixtures_season_gameweek_idx on public.fixtures(season_id, gameweek);
create index fixtures_scheduled_at_idx on public.fixtures(scheduled_at);
create index payment_records_team_status_idx on public.payment_records(season_team_id, status);
create index audit_log_entity_idx on public.audit_log(entity_type, entity_id, created_at desc);

create trigger profiles_set_updated_at before update on public.profiles
for each row execute function public.set_updated_at();
create trigger locations_set_updated_at before update on public.locations
for each row execute function public.set_updated_at();
create trigger leagues_set_updated_at before update on public.leagues
for each row execute function public.set_updated_at();
create trigger seasons_set_updated_at before update on public.seasons
for each row execute function public.set_updated_at();
create trigger season_teams_set_updated_at before update on public.season_teams
for each row execute function public.set_updated_at();
create trigger team_memberships_set_updated_at before update on public.team_memberships
for each row execute function public.set_updated_at();
create trigger fixtures_set_updated_at before update on public.fixtures
for each row execute function public.set_updated_at();
create trigger payment_records_set_updated_at before update on public.payment_records
for each row execute function public.set_updated_at();

-- All application tables are protected by RLS. Policies are added in the next migration.
alter table public.profiles enable row level security;
alter table public.user_roles enable row level security;
alter table public.locations enable row level security;
alter table public.leagues enable row level security;
alter table public.seasons enable row level security;
alter table public.teams enable row level security;
alter table public.season_teams enable row level security;
alter table public.season_registrations enable row level security;
alter table public.team_memberships enable row level security;
alter table public.fixtures enable row level security;
alter table public.fixture_results enable row level security;
alter table public.fixture_team_sheets enable row level security;
alter table public.fixture_team_sheet_players enable row level security;
alter table public.fixture_availability enable row level security;
alter table public.transfer_requests enable row level security;
alter table public.season_fee_configs enable row level security;
alter table public.payment_records enable row level security;
alter table public.notification_events enable row level security;
alter table public.audit_log enable row level security;


-- Account creation is separate from player registration. Create an empty profile
-- automatically so an unregistered account can still browse and complete onboarding later.
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, first_name, last_name, display_name)
  values (
    new.id,
    nullif(trim(new.raw_user_meta_data ->> 'first_name'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'last_name'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'display_name'), '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_auth_user();
