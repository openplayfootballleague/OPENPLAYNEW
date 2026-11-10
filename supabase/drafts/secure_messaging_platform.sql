-- Secure Open Play messaging: authorised direct/team/support conversations,
-- captain announcements, targeted admin broadcasts, moderation and read receipts.
-- CI creates the canonical migration filename with `supabase migration new`.

create table public.message_conversations (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('direct','team','support','announcement')),
  title text not null check (length(btrim(title)) between 1 and 120),
  created_by uuid references auth.users(id) on delete set null,
  season_team_id uuid references public.season_teams(id) on delete restrict,
  location_id uuid references public.locations(id) on delete set null,
  season_id uuid references public.seasons(id) on delete set null,
  target_type text check (target_type is null or target_type in ('everyone','players','captains','admins','location','season','team','individual')),
  target_id uuid,
  direct_pair_key text,
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint message_conversation_kind_scope_check check (
    (kind='direct' and direct_pair_key is not null and season_team_id is null and target_type is null)
    or (kind='team' and season_team_id is not null and direct_pair_key is null and target_type is null)
    or (kind='support' and direct_pair_key is null and target_type is null)
    or (kind='announcement' and target_type is not null and direct_pair_key is null)
  )
);

create unique index message_conversations_direct_pair_active_idx
  on public.message_conversations(direct_pair_key)
  where kind='direct' and closed_at is null;
create unique index message_conversations_team_active_idx
  on public.message_conversations(season_team_id)
  where kind='team' and closed_at is null;
create index message_conversations_updated_idx
  on public.message_conversations(updated_at desc);
create index message_conversations_location_idx
  on public.message_conversations(location_id,created_at desc);

create table public.message_conversation_participants (
  conversation_id uuid not null references public.message_conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  last_read_at timestamptz not null default now(),
  primary key(conversation_id,user_id)
);
create index message_conversation_participants_user_idx
  on public.message_conversation_participants(user_id,left_at,conversation_id);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.message_conversations(id) on delete cascade,
  sender_id uuid references auth.users(id) on delete set null,
  body text not null check (length(btrim(body)) between 1 and 2000),
  message_type text not null default 'message'
    check (message_type in ('message','announcement')),
  is_hidden boolean not null default false,
  hidden_by uuid references auth.users(id) on delete set null,
  hidden_at timestamptz,
  hidden_reason text,
  created_at timestamptz not null default now(),
  constraint message_hidden_state_check check (
    (is_hidden=false and hidden_by is null and hidden_at is null and hidden_reason is null)
    or (is_hidden=true and hidden_by is not null and hidden_at is not null and length(btrim(coalesce(hidden_reason,'')))>=5)
  )
);
create index messages_conversation_created_idx
  on public.messages(conversation_id,created_at desc,id desc);
create index messages_sender_created_idx
  on public.messages(sender_id,created_at desc);

create table public.message_user_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(blocker_id,blocked_user_id),
  constraint message_user_blocks_not_self check (blocker_id<>blocked_user_id)
);
create index message_user_blocks_blocked_idx
  on public.message_user_blocks(blocked_user_id,blocker_id);

create table public.message_reports (
  id uuid primary key default gen_random_uuid(),
  message_id uuid references public.messages(id) on delete set null,
  conversation_id uuid references public.message_conversations(id) on delete set null,
  reporter_id uuid references auth.users(id) on delete set null,
  reported_user_id uuid references auth.users(id) on delete set null,
  reason text not null check (length(btrim(reason)) between 5 and 1000),
  status text not null default 'open' check (status in ('open','resolved','dismissed')),
  resolution_action text check (resolution_action is null or resolution_action in ('hide_message','dismiss')),
  resolution_reason text,
  resolved_by uuid references auth.users(id) on delete set null,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  constraint message_report_resolution_state_check check (
    (status='open' and resolved_by is null and resolved_at is null and resolution_action is null)
    or (status<>'open' and resolved_by is not null and resolved_at is not null and resolution_action is not null)
  )
);
create unique index message_reports_one_open_per_reporter_idx
  on public.message_reports(message_id,reporter_id)
  where status='open' and message_id is not null;
create index message_reports_status_created_idx
  on public.message_reports(status,created_at desc);

alter table public.message_conversations enable row level security;
alter table public.message_conversation_participants enable row level security;
alter table public.messages enable row level security;
alter table public.message_user_blocks enable row level security;
alter table public.message_reports enable row level security;

revoke all on public.message_conversations,public.message_conversation_participants,
  public.messages,public.message_user_blocks,public.message_reports from public,anon,authenticated;
grant select on public.message_conversations,public.message_conversation_participants,public.messages to authenticated;

create or replace function public.message_actor_is_active(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select p_user_id is not null
    and exists (
      select 1 from public.profiles p
      where p.id=p_user_id
        and coalesce(p.account_retention_status,'active')='active'
    )
    and (
      exists (
        select 1 from public.players pl
        where pl.user_id=p_user_id
          and pl.registration_status='registered'
          and pl.is_banned=false
      )
      or exists (
        select 1 from public.referee_memberships rm
        where rm.user_id=p_user_id and rm.status='active'
      )
      or exists (
        select 1 from public.user_roles ur
        where ur.user_id=p_user_id
          and ur.role in ('admin','super_admin','league_admin','finance_admin')
      )
    );
$$;
revoke all on function public.message_actor_is_active(uuid) from public,anon;
grant execute on function public.message_actor_is_active(uuid) to authenticated;

create or replace function public.can_access_message_conversation(p_conversation_id uuid)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select auth.uid() is not null
    and public.message_actor_is_active(auth.uid())
    and exists (
      select 1
      from public.message_conversations c
      join public.message_conversation_participants cp on cp.conversation_id=c.id
      where c.id=p_conversation_id
        and c.closed_at is null
        and cp.user_id=auth.uid()
        and cp.left_at is null
        and (
          c.kind<>'team'
          or exists (
            select 1 from public.team_memberships tm
            where tm.season_team_id=c.season_team_id
              and tm.user_id=auth.uid()
              and tm.status='active'
          )
        )
    );
$$;
revoke all on function public.can_access_message_conversation(uuid) from public,anon;
grant execute on function public.can_access_message_conversation(uuid) to authenticated;

drop policy if exists message_conversations_select_participant on public.message_conversations;
create policy message_conversations_select_participant
  on public.message_conversations for select to authenticated
  using (public.can_access_message_conversation(id));

drop policy if exists message_participants_select_self on public.message_conversation_participants;
create policy message_participants_select_self
  on public.message_conversation_participants for select to authenticated
  using (user_id=(select auth.uid()));

drop policy if exists messages_select_participant on public.messages;
create policy messages_select_participant
  on public.messages for select to authenticated
  using (public.can_access_message_conversation(conversation_id));

create or replace function public.enqueue_notification_event(
  p_user_id uuid,
  p_event_type text,
  p_payload jsonb
)
returns void
language plpgsql
security definer
set search_path=''
as $$
declare
  v_preferences public.notification_preferences;
  v_dedupe text;
begin
  if p_user_id is null or p_event_type is null or length(btrim(p_event_type))<3 then return; end if;
  insert into public.notification_preferences(user_id) values(p_user_id)
  on conflict(user_id) do nothing;
  select * into v_preferences from public.notification_preferences where user_id=p_user_id;
  v_dedupe:=p_event_type||':'||coalesce(
    p_payload->>'message_id',
    p_payload->>'fixture_id',
    p_payload->>'membership_id',
    p_payload->>'season_team_id',
    p_payload->>'conversation_id',
    'event'
  )||':'||p_user_id::text;

  if v_preferences.email_enabled then
    insert into public.notification_events(user_id,channel,event_type,status,payload,dedupe_key)
    values(p_user_id,'email',p_event_type,'queued',coalesce(p_payload,'{}'::jsonb),v_dedupe||':email')
    on conflict(dedupe_key) where dedupe_key is not null do nothing;
  end if;
  if v_preferences.sms_enabled then
    insert into public.notification_events(user_id,channel,event_type,status,payload,dedupe_key)
    values(p_user_id,'sms',p_event_type,'queued',coalesce(p_payload,'{}'::jsonb),v_dedupe||':sms')
    on conflict(dedupe_key) where dedupe_key is not null do nothing;
  end if;
  if v_preferences.in_app_enabled then
    insert into public.notification_events(user_id,channel,event_type,status,payload,dedupe_key,sent_at)
    values(p_user_id,'in_app',p_event_type,'sent',coalesce(p_payload,'{}'::jsonb),v_dedupe||':in_app',now())
    on conflict(dedupe_key) where dedupe_key is not null do nothing;
  end if;
end;
$$;
revoke all on function public.enqueue_notification_event(uuid,text,jsonb) from public,anon,authenticated;

create or replace function public.get_my_message_conversations(p_limit integer default 50)
returns table(
  conversation_id uuid,
  kind text,
  title text,
  season_team_id uuid,
  created_at timestamptz,
  updated_at timestamptz,
  last_message_id uuid,
  last_message_body text,
  last_message_at timestamptz,
  last_message_sender_id uuid,
  unread_count bigint,
  participant_count bigint,
  other_participant_user_id uuid,
  other_participant_name text
)
language plpgsql
stable
security definer
set search_path=''
as $$
begin
  if auth.uid() is null or not public.message_actor_is_active(auth.uid()) then
    raise exception 'Active Open Play account required';
  end if;
  return query
  select c.id,c.kind,c.title,c.season_team_id,c.created_at,c.updated_at,
    lm.id,
    case when lm.is_hidden then '[Message hidden by moderation]' else lm.body end,
    lm.created_at,lm.sender_id,
    (select count(*) from public.messages um
      where um.conversation_id=c.id
        and um.sender_id is distinct from auth.uid()
        and um.created_at>cp.last_read_at),
    (select count(*) from public.message_conversation_participants allcp
      where allcp.conversation_id=c.id and allcp.left_at is null),
    op.user_id,
    coalesce(nullif(oprof.display_name,''),opl.full_name,'Open Play member')
  from public.message_conversations c
  join public.message_conversation_participants cp
    on cp.conversation_id=c.id and cp.user_id=auth.uid() and cp.left_at is null
  left join lateral (
    select m.id,m.body,m.is_hidden,m.created_at,m.sender_id
    from public.messages m where m.conversation_id=c.id
    order by m.created_at desc,m.id desc limit 1
  ) lm on true
  left join lateral (
    select othercp.user_id
    from public.message_conversation_participants othercp
    where othercp.conversation_id=c.id
      and othercp.user_id<>auth.uid()
      and othercp.left_at is null
    order by othercp.joined_at limit 1
  ) op on c.kind='direct'
  left join public.profiles oprof on oprof.id=op.user_id
  left join public.players opl on opl.user_id=op.user_id
  where c.closed_at is null
    and public.can_access_message_conversation(c.id)
  order by coalesce(lm.created_at,c.updated_at) desc
  limit greatest(1,least(coalesce(p_limit,50),100));
end;
$$;
revoke all on function public.get_my_message_conversations(integer) from public,anon;
grant execute on function public.get_my_message_conversations(integer) to authenticated;

create or replace function public.get_message_history(
  p_conversation_id uuid,
  p_limit integer default 50,
  p_before timestamptz default null
)
returns table(
  message_id uuid,
  conversation_id uuid,
  sender_id uuid,
  sender_name text,
  body text,
  message_type text,
  is_hidden boolean,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path=''
as $$
begin
  if not public.can_access_message_conversation(p_conversation_id) then
    raise exception 'Conversation not found or access denied';
  end if;
  return query
  select m.id,m.conversation_id,m.sender_id,
    case when m.sender_id is null then 'Former member'
      else coalesce(nullif(p.display_name,''),pl.full_name,'Open Play member') end,
    case when m.is_hidden then '[Message hidden by moderation]' else m.body end,
    m.message_type,m.is_hidden,m.created_at
  from public.messages m
  left join public.profiles p on p.id=m.sender_id
  left join public.players pl on pl.user_id=m.sender_id
  where m.conversation_id=p_conversation_id
    and (p_before is null or m.created_at<p_before)
  order by m.created_at desc,m.id desc
  limit greatest(1,least(coalesce(p_limit,50),100));
end;
$$;
revoke all on function public.get_message_history(uuid,integer,timestamptz) from public,anon;
grant execute on function public.get_message_history(uuid,integer,timestamptz) to authenticated;

create or replace function public.mark_message_conversation_read(p_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path=''
as $$
begin
  if not public.can_access_message_conversation(p_conversation_id) then
    raise exception 'Conversation not found or access denied';
  end if;
  update public.message_conversation_participants
  set last_read_at=now()
  where conversation_id=p_conversation_id and user_id=auth.uid() and left_at is null;
end;
$$;
revoke all on function public.mark_message_conversation_read(uuid) from public,anon;
grant execute on function public.mark_message_conversation_read(uuid) to authenticated;

create or replace function public.search_message_recipients(p_query text,p_limit integer default 20)
returns table(user_id uuid,display_name text,shared_team_name text)
language plpgsql
stable
security definer
set search_path=''
as $$
begin
  if auth.uid() is null or not public.message_actor_is_active(auth.uid()) then
    raise exception 'Active Open Play account required';
  end if;
  if length(btrim(coalesce(p_query,'')))<2 then return; end if;
  return query
  select distinct on (pl.user_id)
    pl.user_id,
    coalesce(nullif(pr.display_name,''),pl.full_name),
    st.name
  from public.team_memberships mine
  join public.team_memberships theirs
    on theirs.season_team_id=mine.season_team_id
   and theirs.status='active'
  join public.season_teams st on st.id=mine.season_team_id
  join public.players pl on pl.user_id=theirs.user_id
  join public.profiles pr on pr.id=pl.user_id
  where mine.user_id=auth.uid() and mine.status='active'
    and pl.user_id<>auth.uid()
    and pl.registration_status='registered' and pl.is_banned=false
    and public.message_actor_is_active(pl.user_id)
    and coalesce(nullif(pr.display_name,''),pl.full_name) ilike '%'||btrim(p_query)||'%'
    and not exists (
      select 1 from public.message_user_blocks b
      where (b.blocker_id=auth.uid() and b.blocked_user_id=pl.user_id)
         or (b.blocker_id=pl.user_id and b.blocked_user_id=auth.uid())
    )
  order by pl.user_id,st.name
  limit greatest(1,least(coalesce(p_limit,20),50));
end;
$$;
revoke all on function public.search_message_recipients(text,integer) from public,anon;
grant execute on function public.search_message_recipients(text,integer) to authenticated;

create or replace function public.send_message(
  p_conversation_id uuid,
  p_body text,
  p_message_type text default 'message'
)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare
  v_user uuid:=auth.uid();
  v_conversation public.message_conversations;
  v_message_id uuid;
  v_recent_minute integer;
  v_recent_day integer;
  v_sender_name text;
  v_recipient record;
begin
  if v_user is null or not public.message_actor_is_active(v_user) then
    raise exception 'Active Open Play account required';
  end if;
  if length(btrim(coalesce(p_body,''))) not between 1 and 2000 then
    raise exception 'Messages must contain between 1 and 2000 characters';
  end if;
  if p_message_type not in ('message','announcement') then
    raise exception 'Unsupported message type';
  end if;
  select * into v_conversation
  from public.message_conversations
  where id=p_conversation_id and closed_at is null
  for update;
  if not found or not public.can_access_message_conversation(p_conversation_id) then
    raise exception 'Conversation not found or access denied';
  end if;
  if v_conversation.kind='announcement' then
    raise exception 'Admin broadcasts are read-only for recipients';
  end if;
  if p_message_type='announcement' then
    if v_conversation.kind<>'team' then
      raise exception 'Announcements can only be posted in team conversations';
    end if;
    if not public.is_active_team_captain(v_conversation.season_team_id)
       and not exists (
         select 1 from public.user_roles ur
         where ur.user_id=v_user and ur.role in ('admin','super_admin','league_admin')
       ) then
      raise exception 'Only the team captain or an authorised administrator can post team announcements';
    end if;
    if exists (select 1 from public.user_roles ur where ur.user_id=v_user and ur.role='league_admin')
       and not exists (select 1 from public.user_roles ur where ur.user_id=v_user and ur.role in ('admin','super_admin')) then
      perform public.assert_admin_location_context(v_conversation.location_id);
    end if;
  end if;
  if v_conversation.kind='direct' and exists (
    select 1 from public.message_conversation_participants cp
    join public.message_user_blocks b
      on (b.blocker_id=v_user and b.blocked_user_id=cp.user_id)
      or (b.blocker_id=cp.user_id and b.blocked_user_id=v_user)
    where cp.conversation_id=p_conversation_id
      and cp.user_id<>v_user
      and cp.left_at is null
  ) then
    raise exception 'This direct conversation is unavailable because a participant has blocked the other';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_user::text,0));
  select count(*) into v_recent_minute from public.messages
    where sender_id=v_user and created_at>now()-interval '1 minute';
  select count(*) into v_recent_day from public.messages
    where sender_id=v_user and created_at>now()-interval '1 day';
  if v_recent_minute>=10 then raise exception 'Message rate limit reached. Please wait before sending again'; end if;
  if v_recent_day>=100 then raise exception 'Daily message limit reached'; end if;

  insert into public.messages(conversation_id,sender_id,body,message_type)
  values(p_conversation_id,v_user,btrim(p_body),p_message_type)
  returning id into v_message_id;
  update public.message_conversations set updated_at=now() where id=p_conversation_id;
  update public.message_conversation_participants
  set last_read_at=now()
  where conversation_id=p_conversation_id and user_id=v_user and left_at is null;

  select coalesce(nullif(p.display_name,''),pl.full_name,'Open Play member')
    into v_sender_name
  from public.profiles p left join public.players pl on pl.user_id=p.id
  where p.id=v_user;
  for v_recipient in
    select cp.user_id
    from public.message_conversation_participants cp
    where cp.conversation_id=p_conversation_id
      and cp.user_id<>v_user and cp.left_at is null
      and public.message_actor_is_active(cp.user_id)
  loop
    perform public.enqueue_notification_event(
      v_recipient.user_id,
      'message.new',
      jsonb_build_object(
        'conversation_id',p_conversation_id,
        'message_id',v_message_id,
        'conversation_title',v_conversation.title,
        'sender_name',coalesce(v_sender_name,'Open Play member')
      )
    );
  end loop;
  return v_message_id;
end;
$$;
revoke all on function public.send_message(uuid,text,text) from public,anon;
grant execute on function public.send_message(uuid,text,text) to authenticated;

create or replace function public.create_direct_message_conversation(p_recipient_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare
  v_user uuid:=auth.uid();
  v_key text;
  v_conversation_id uuid;
  v_shared_team_id uuid;
  v_season_id uuid;
  v_location_id uuid;
begin
  if v_user is null or p_recipient_user_id is null or p_recipient_user_id=v_user then
    raise exception 'Choose another eligible Open Play member';
  end if;
  if not public.message_actor_is_active(v_user)
     or not public.message_actor_is_active(p_recipient_user_id) then
    raise exception 'Both accounts must be active Open Play members';
  end if;
  select st.id,s.id,l.location_id
    into v_shared_team_id,v_season_id,v_location_id
  from public.team_memberships a
  join public.team_memberships b on b.season_team_id=a.season_team_id
  join public.season_teams st on st.id=a.season_team_id
  join public.seasons s on s.id=st.season_id
  join public.leagues l on l.id=s.league_id
  where a.user_id=v_user and a.status='active'
    and b.user_id=p_recipient_user_id and b.status='active'
  order by a.joined_at desc nulls last
  limit 1;
  if v_shared_team_id is null then
    raise exception 'Direct messages are limited to members of the same active team';
  end if;
  if exists (
    select 1 from public.message_user_blocks b
    where (b.blocker_id=v_user and b.blocked_user_id=p_recipient_user_id)
       or (b.blocker_id=p_recipient_user_id and b.blocked_user_id=v_user)
  ) then
    raise exception 'This member is unavailable for direct messaging';
  end if;
  v_key:=least(v_user::text,p_recipient_user_id::text)||':'||greatest(v_user::text,p_recipient_user_id::text);
  insert into public.message_conversations(kind,title,created_by,location_id,season_id,direct_pair_key)
  values('direct','Direct conversation',v_user,v_location_id,v_season_id,v_key)
  on conflict(direct_pair_key) where kind='direct' and closed_at is null do nothing;
  select id into v_conversation_id from public.message_conversations
  where kind='direct' and direct_pair_key=v_key and closed_at is null;
  insert into public.message_conversation_participants(conversation_id,user_id)
  values(v_conversation_id,v_user),(v_conversation_id,p_recipient_user_id)
  on conflict(conversation_id,user_id) do update
    set left_at=null,joined_at=coalesce(public.message_conversation_participants.joined_at,now());
  return v_conversation_id;
end;
$$;
revoke all on function public.create_direct_message_conversation(uuid) from public,anon;
grant execute on function public.create_direct_message_conversation(uuid) to authenticated;

create or replace function public.create_support_message_conversation(p_subject text,p_initial_message text)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare
  v_user uuid:=auth.uid();
  v_conversation_id uuid;
  v_count integer;
begin
  if v_user is null or not public.message_actor_is_active(v_user) then
    raise exception 'Active Open Play account required';
  end if;
  if length(btrim(coalesce(p_subject,''))) not between 3 and 120
     or length(btrim(coalesce(p_initial_message,''))) not between 1 and 2000 then
    raise exception 'Enter a subject and a message';
  end if;
  select count(*) into v_count from public.message_conversations
  where kind='support' and created_by=v_user and created_at>now()-interval '1 day';
  if v_count>=5 then raise exception 'Support request limit reached. Please wait before opening another conversation'; end if;
  insert into public.message_conversations(kind,title,created_by)
  values('support',btrim(p_subject),v_user)
  returning id into v_conversation_id;
  insert into public.message_conversation_participants(conversation_id,user_id)
  values(v_conversation_id,v_user)
  on conflict do nothing;
  insert into public.message_conversation_participants(conversation_id,user_id)
  select v_conversation_id,ur.user_id
  from public.user_roles ur
  where ur.role in ('admin','super_admin','league_admin','finance_admin')
    and public.message_actor_is_active(ur.user_id)
  on conflict do nothing;
  perform public.send_message(v_conversation_id,p_initial_message,'message');
  return v_conversation_id;
end;
$$;
revoke all on function public.create_support_message_conversation(text,text) from public,anon;
grant execute on function public.create_support_message_conversation(text,text) to authenticated;

create or replace function public.admin_create_message_broadcast(
  p_title text,
  p_body text,
  p_target_type text,
  p_target_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare
  v_user uuid:=auth.uid();
  v_global boolean;
  v_location_id uuid;
  v_conversation_id uuid;
  v_message_id uuid;
  v_recipient_count integer;
  v_recent_broadcasts integer;
  v_sender_name text;
  v_recipient record;
begin
  if v_user is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;
  if length(btrim(coalesce(p_title,''))) not between 3 and 120
     or length(btrim(coalesce(p_body,''))) not between 1 and 2000 then
    raise exception 'Enter a title and message';
  end if;
  if p_target_type not in ('everyone','players','captains','admins','location','season','team','individual') then
    raise exception 'Unsupported broadcast audience';
  end if;
  select exists(select 1 from public.user_roles ur where ur.user_id=v_user and ur.role in ('admin','super_admin'))
    into v_global;
  if p_target_type in ('everyone','players','admins','individual') and not v_global then
    raise exception 'Only global administrators can send a platform-wide broadcast';
  end if;
  if p_target_type='location' then
    v_location_id:=p_target_id;
  elsif p_target_type='season' then
    select l.location_id into v_location_id
    from public.seasons s join public.leagues l on l.id=s.league_id
    where s.id=p_target_id;
  elsif p_target_type='team' then
    select l.location_id into v_location_id
    from public.season_teams st join public.seasons s on s.id=st.season_id
    join public.leagues l on l.id=s.league_id where st.id=p_target_id;
  elsif p_target_type='captains' then
    v_location_id:=p_target_id;
  end if;
  if p_target_type in ('location','season','team') and v_location_id is null then
    raise exception 'The selected broadcast target does not exist';
  end if;
  if v_location_id is not null then
    perform public.assert_admin_location_context(v_location_id);
  elsif not v_global then
    raise exception 'Location administrators must choose an assigned location, season, team or captain audience';
  end if;
  select count(*) into v_recent_broadcasts
  from public.message_conversations
  where kind='announcement' and created_by=v_user and created_at>now()-interval '1 hour';
  if v_recent_broadcasts>=10 then raise exception 'Broadcast rate limit reached'; end if;

  insert into public.message_conversations(
    kind,title,created_by,location_id,season_id,season_team_id,target_type,target_id
  )
  values(
    'announcement',btrim(p_title),v_user,
    case when p_target_type='location' then p_target_id else v_location_id end,
    case when p_target_type='season' then p_target_id else null end,
    case when p_target_type='team' then p_target_id else null end,
    p_target_type,p_target_id
  )
  returning id into v_conversation_id;

  insert into public.message_conversation_participants(conversation_id,user_id)
  select v_conversation_id,pr.id
  from public.profiles pr
  where public.message_actor_is_active(pr.id)
    and (
      p_target_type='everyone'
      or (p_target_type='players' and exists(
        select 1 from public.players pl where pl.user_id=pr.id and pl.registration_status='registered' and pl.is_banned=false
      ))
      or (p_target_type='admins' and exists(
        select 1 from public.user_roles ur where ur.user_id=pr.id and ur.role in ('admin','super_admin','league_admin','finance_admin')
      ))
      or (p_target_type='individual' and pr.id=p_target_id)
      or (p_target_type='captains' and exists(
        select 1 from public.team_memberships tm
        join public.season_teams st on st.id=tm.season_team_id
        join public.seasons s on s.id=st.season_id
        join public.leagues l on l.id=s.league_id
        where tm.user_id=pr.id and tm.status='active' and tm.is_captain=true
          and (p_target_id is null or l.location_id=p_target_id)
      ))
      or (p_target_type='location' and exists(
        select 1 from public.team_memberships tm
        join public.season_teams st on st.id=tm.season_team_id
        join public.seasons s on s.id=st.season_id
        join public.leagues l on l.id=s.league_id
        where tm.user_id=pr.id and tm.status='active' and l.location_id=p_target_id
      ))
      or (p_target_type='season' and exists(
        select 1 from public.team_memberships tm
        join public.season_teams st on st.id=tm.season_team_id
        where tm.user_id=pr.id and tm.status='active' and st.season_id=p_target_id
      ))
      or (p_target_type='team' and exists(
        select 1 from public.team_memberships tm
        where tm.user_id=pr.id and tm.status='active' and tm.season_team_id=p_target_id
      ))
    )
  on conflict(conversation_id,user_id) do nothing;
  select count(*) into v_recipient_count from public.message_conversation_participants
  where conversation_id=v_conversation_id;
  if v_recipient_count=0 then
    delete from public.message_conversations where id=v_conversation_id;
    raise exception 'No active recipients matched this audience';
  end if;
  insert into public.messages(conversation_id,sender_id,body,message_type)
  values(v_conversation_id,v_user,btrim(p_body),'announcement')
  returning id into v_message_id;
  update public.message_conversations set updated_at=now() where id=v_conversation_id;
  select coalesce(nullif(p.display_name,''),pl.full_name,'Open Play admin')
    into v_sender_name
  from public.profiles p left join public.players pl on pl.user_id=p.id where p.id=v_user;
  for v_recipient in
    select cp.user_id from public.message_conversation_participants cp
    where cp.conversation_id=v_conversation_id and cp.user_id<>v_user and cp.left_at is null
  loop
    perform public.enqueue_notification_event(
      v_recipient.user_id,'message.new',
      jsonb_build_object('conversation_id',v_conversation_id,'message_id',v_message_id,
        'conversation_title',btrim(p_title),'sender_name',coalesce(v_sender_name,'Open Play admin'))
    );
  end loop;
  return v_conversation_id;
end;
$$;
revoke all on function public.admin_create_message_broadcast(text,text,text,uuid) from public,anon;
grant execute on function public.admin_create_message_broadcast(text,text,text,uuid) to authenticated;

create or replace function public.admin_get_message_target_options()
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $
declare
  v_user uuid:=auth.uid();
  v_global boolean;
begin
  if v_user is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;
  select exists(select 1 from public.user_roles ur where ur.user_id=v_user and ur.role in ('admin','super_admin'))
    into v_global;
  return jsonb_build_object(
    'locations',coalesce((
      select jsonb_agg(jsonb_build_object('id',l.id,'name',l.name,'town',l.town) order by l.name)
      from public.locations l
      where l.is_active and (v_global or public.can_administer_location(l.id))
    ),'[]'::jsonb),
    'seasons',coalesce((
      select jsonb_agg(jsonb_build_object('id',s.id,'name',s.name,'league_name',l.name,'location_name',loc.name) order by loc.name,l.name,s.created_at desc)
      from public.seasons s
      join public.leagues l on l.id=s.league_id
      join public.locations loc on loc.id=l.location_id
      where v_global or public.can_administer_location(loc.id)
    ),'[]'::jsonb),
    'teams',coalesce((
      select jsonb_agg(jsonb_build_object('id',st.id,'name',st.name,'season_name',s.name,'location_name',loc.name) order by loc.name,s.name,st.name)
      from public.season_teams st
      join public.seasons s on s.id=st.season_id
      join public.leagues l on l.id=s.league_id
      join public.locations loc on loc.id=l.location_id
      where v_global or public.can_administer_location(loc.id)
    ),'[]'::jsonb),
    'players',case when v_global then coalesce((
      select jsonb_agg(jsonb_build_object('user_id',pl.user_id,'full_name',pl.full_name) order by pl.full_name)
      from public.players pl
      where pl.registration_status='registered' and pl.is_banned=false
        and public.message_actor_is_active(pl.user_id)
    ),'[]'::jsonb) else '[]'::jsonb end
  );
end;
$;
revoke all on function public.admin_get_message_target_options() from public,anon;
grant execute on function public.admin_get_message_target_options() to authenticated;

create or replace function public.report_message(p_message_id uuid,p_reason text)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare
  v_user uuid:=auth.uid();
  v_message public.messages;
  v_report_id uuid;
begin
  if v_user is null or length(btrim(coalesce(p_reason,''))) not between 5 and 1000 then
    raise exception 'Enter a report reason of at least 5 characters';
  end if;
  select * into v_message from public.messages where id=p_message_id;
  if not found or not public.can_access_message_conversation(v_message.conversation_id) then
    raise exception 'Message not found or access denied';
  end if;
  if v_message.sender_id=v_user then
    raise exception 'You cannot report your own message';
  end if;
  insert into public.message_reports(message_id,conversation_id,reporter_id,reported_user_id,reason)
  values(p_message_id,v_message.conversation_id,v_user,v_message.sender_id,btrim(p_reason))
  on conflict(message_id,reporter_id) where status='open' and message_id is not null do nothing
  returning id into v_report_id;
  if v_report_id is null then
    select id into v_report_id from public.message_reports
    where message_id=p_message_id and reporter_id=v_user and status='open';
  end if;
  return v_report_id;
end;
$$;
revoke all on function public.report_message(uuid,text) from public,anon;
grant execute on function public.report_message(uuid,text) to authenticated;

create or replace function public.block_message_user(p_blocked_user_id uuid)
returns void
language plpgsql
security definer
set search_path=''
as $$
declare v_user uuid:=auth.uid();
begin
  if v_user is null or not public.message_actor_is_active(v_user)
     or p_blocked_user_id is null or p_blocked_user_id=v_user then
    raise exception 'Choose another active member to block';
  end if;
  if not exists (
    select 1 from public.message_conversations c
    join public.message_conversation_participants a on a.conversation_id=c.id and a.user_id=v_user
    join public.message_conversation_participants b on b.conversation_id=c.id and b.user_id=p_blocked_user_id
    where c.kind='direct' and c.closed_at is null and a.left_at is null and b.left_at is null
  ) then
    raise exception 'You can block a member only after a direct conversation exists';
  end if;
  insert into public.message_user_blocks(blocker_id,blocked_user_id)
  values(v_user,p_blocked_user_id) on conflict do nothing;
end;
$$;
revoke all on function public.block_message_user(uuid) from public,anon;
grant execute on function public.block_message_user(uuid) to authenticated;

create or replace function public.unblock_message_user(p_blocked_user_id uuid)
returns void
language plpgsql
security definer
set search_path=''
as $
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  delete from public.message_user_blocks
  where blocker_id=auth.uid() and blocked_user_id=p_blocked_user_id;
end;
$;
revoke all on function public.unblock_message_user(uuid) from public,anon;
grant execute on function public.unblock_message_user(uuid) to authenticated;

create or replace function public.get_my_blocked_message_users()
returns table(user_id uuid,display_name text,blocked_at timestamptz)
language plpgsql
stable
security definer
set search_path=''
as $
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  return query
  select b.blocked_user_id,
    coalesce(nullif(p.display_name,''),pl.full_name,'Open Play member'),
    b.created_at
  from public.message_user_blocks b
  left join public.profiles p on p.id=b.blocked_user_id
  left join public.players pl on pl.user_id=b.blocked_user_id
  where b.blocker_id=auth.uid()
  order by b.created_at desc;
end;
$;
revoke all on function public.get_my_blocked_message_users() from public,anon;
grant execute on function public.get_my_blocked_message_users() to authenticated;

create or replace function public.admin_get_message_reports(p_status text default 'open',p_limit integer default 50)
returns table(
  report_id uuid,
  message_id uuid,
  conversation_id uuid,
  conversation_title text,
  reporter_name text,
  reported_user_name text,
  message_body text,
  reason text,
  status text,
  created_at timestamptz,
  location_id uuid
)
language plpgsql
stable
security definer
set search_path=''
as $$
declare v_user uuid:=auth.uid(); v_global boolean;
begin
  if v_user is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;
  select exists(select 1 from public.user_roles ur where ur.user_id=v_user and ur.role in ('admin','super_admin'))
    into v_global;
  return query
  select r.id,r.message_id,r.conversation_id,c.title,
    coalesce(rp.display_name,rpl.full_name,'Former member'),
    coalesce(up.display_name,upl.full_name,'Former member'),
    case when m.is_hidden then '[Message hidden by moderation]' else m.body end,
    r.reason,r.status,r.created_at,c.location_id
  from public.message_reports r
  left join public.message_conversations c on c.id=r.conversation_id
  left join public.messages m on m.id=r.message_id
  left join public.profiles rp on rp.id=r.reporter_id
  left join public.players rpl on rpl.user_id=r.reporter_id
  left join public.profiles up on up.id=r.reported_user_id
  left join public.players upl on upl.user_id=r.reported_user_id
  where (p_status='all' or r.status=p_status)
    and (v_global or public.can_administer_location(c.location_id))
  order by r.created_at desc
  limit greatest(1,least(coalesce(p_limit,50),100));
end;
$$;
revoke all on function public.admin_get_message_reports(text,integer) from public,anon;
grant execute on function public.admin_get_message_reports(text,integer) to authenticated;

create or replace function public.admin_resolve_message_report(
  p_report_id uuid,
  p_action text,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path=''
as $$
declare
  v_user uuid:=auth.uid();
  v_report public.message_reports;
  v_conversation public.message_conversations;
  v_global boolean;
  v_before jsonb;
begin
  if v_user is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;
  if p_action not in ('hide_message','dismiss') or length(btrim(coalesce(p_reason,'')))<5 then
    raise exception 'Choose a moderation action and enter a reason of at least 5 characters';
  end if;
  select * into v_report from public.message_reports where id=p_report_id for update;
  if not found or v_report.status<>'open' then raise exception 'Open message report not found'; end if;
  select * into v_conversation from public.message_conversations where id=v_report.conversation_id;
  select exists(select 1 from public.user_roles ur where ur.user_id=v_user and ur.role in ('admin','super_admin'))
    into v_global;
  if not v_global and (v_conversation.location_id is null or not public.can_administer_location(v_conversation.location_id)) then
    raise exception 'You are not assigned to this conversation location';
  end if;
  v_before:=jsonb_build_object('status',v_report.status,'message_id',v_report.message_id);
  if p_action='hide_message' and v_report.message_id is not null then
    update public.messages
    set is_hidden=true,hidden_by=v_user,hidden_at=now(),hidden_reason=btrim(p_reason)
    where id=v_report.message_id;
  end if;
  update public.message_reports
  set status=case when p_action='dismiss' then 'dismissed' else 'resolved' end,
      resolution_action=p_action,resolution_reason=btrim(p_reason),
      resolved_by=v_user,resolved_at=now()
  where id=p_report_id;
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(v_user,'message.report.resolved','message_report',p_report_id::text,btrim(p_reason),
    v_before,jsonb_build_object('status',case when p_action='dismiss' then 'dismissed' else 'resolved' end,'action',p_action));
end;
$$;
revoke all on function public.admin_resolve_message_report(uuid,text,text) from public,anon;
grant execute on function public.admin_resolve_message_report(uuid,text,text) to authenticated;

create or replace function public.sync_team_message_conversation()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare v_conversation_id uuid; v_team_name text;
begin
  if new.status='active' then
    select name into v_team_name from public.season_teams where id=new.season_team_id;
    insert into public.message_conversations(kind,title,created_by,season_team_id,season_id,location_id)
    select 'team',st.name,new.user_id,st.id,st.season_id,l.location_id
    from public.season_teams st
    join public.seasons s on s.id=st.season_id
    join public.leagues l on l.id=s.league_id
    where st.id=new.season_team_id
    on conflict(season_team_id) where kind='team' and closed_at is null do nothing;
    select id into v_conversation_id from public.message_conversations
    where kind='team' and season_team_id=new.season_team_id and closed_at is null;
    insert into public.message_conversation_participants(conversation_id,user_id)
    select v_conversation_id,tm.user_id
    from public.team_memberships tm
    where tm.season_team_id=new.season_team_id and tm.status='active'
      and public.message_actor_is_active(tm.user_id)
    on conflict(conversation_id,user_id) do update
      set left_at=null,last_read_at=now();
  else
    update public.message_conversation_participants cp
    set left_at=coalesce(cp.left_at,now())
    where cp.user_id=new.user_id
      and cp.conversation_id in (
        select c.id from public.message_conversations c
        where c.kind='team' and c.season_team_id=new.season_team_id
      );
  end if;
  return new;
end;
$$;
revoke all on function public.sync_team_message_conversation() from public,anon,authenticated;
drop trigger if exists sync_team_message_conversation_trigger on public.team_memberships;
create trigger sync_team_message_conversation_trigger
after insert or update of status on public.team_memberships
for each row execute function public.sync_team_message_conversation();

do $$
begin
  if exists(select 1 from pg_publication where pubname='supabase_realtime') then
    if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='messages') then
      execute 'alter publication supabase_realtime add table public.messages';
    end if;
    if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='message_conversation_participants') then
      execute 'alter publication supabase_realtime add table public.message_conversation_participants';
    end if;
  end if;
end;
$$;
