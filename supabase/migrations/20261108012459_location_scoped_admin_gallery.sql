insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('open-play-gallery','open-play-gallery',true,10485760,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=true,file_size_limit=10485760,allowed_mime_types=array['image/jpeg','image/png','image/webp'];

create table if not exists public.gallery_items(
 id uuid primary key default gen_random_uuid(),
 location_id uuid not null references public.locations(id) on delete cascade,
 object_path text not null unique,
 caption text not null default '',
 is_published boolean not null default false,
 uploaded_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 published_at timestamptz
);
create index if not exists gallery_items_location_created_idx on public.gallery_items(location_id,created_at desc);
alter table public.gallery_items enable row level security;
revoke all on public.gallery_items from anon,authenticated;

drop policy if exists "Public can view published Open Play gallery images" on storage.objects;
create policy "Public can view published Open Play gallery images" on storage.objects
for select using(bucket_id='open-play-gallery' and exists(select 1 from public.gallery_items gi where gi.object_path=name and gi.is_published=true));
drop policy if exists "Assigned admins can upload Open Play gallery images" on storage.objects;
create policy "Assigned admins can upload Open Play gallery images" on storage.objects
for insert to authenticated with check(bucket_id='open-play-gallery' and split_part(name,'/',1) ~* '^[0-9a-f-]{36}$' and public.can_administer_location(split_part(name,'/',1)::uuid));
drop policy if exists "Assigned admins can delete Open Play gallery images" on storage.objects;
create policy "Assigned admins can delete Open Play gallery images" on storage.objects
for delete to authenticated using(bucket_id='open-play-gallery' and split_part(name,'/',1) ~* '^[0-9a-f-]{36}$' and public.can_administer_location(split_part(name,'/',1)::uuid));

create or replace function public.get_admin_gallery_items(p_location_id uuid default null)
returns table(id uuid,location_id uuid,location_name text,object_path text,caption text,is_published boolean,created_at timestamptz,published_at timestamptz)
language plpgsql stable security definer set search_path=''
as $$
begin
 if auth.uid() is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
 if p_location_id is not null then perform public.assert_admin_location_context(p_location_id); end if;
 return query select gi.id,gi.location_id,l.name,gi.object_path,gi.caption,gi.is_published,gi.created_at,gi.published_at
 from public.gallery_items gi join public.locations l on l.id=gi.location_id
 where (p_location_id is null or gi.location_id=p_location_id) and public.can_administer_location(gi.location_id)
 order by gi.created_at desc;
end;
$$;
create or replace function public.admin_register_gallery_item(p_location_id uuid,p_object_path text,p_caption text default '')
returns uuid language plpgsql security definer set search_path=''
as $$
declare v_id uuid;
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 perform public.assert_admin_location_context(p_location_id);
 if p_object_path is null or split_part(p_object_path,'/',1)<>p_location_id::text or length(p_object_path)>500 then raise exception 'Gallery image path does not match the selected location'; end if;
 if not exists(select 1 from storage.objects where bucket_id='open-play-gallery' and name=p_object_path) then raise exception 'Uploaded image was not found'; end if;
 if length(coalesce(p_caption,''))>240 then raise exception 'Caption must be 240 characters or fewer'; end if;
 insert into public.gallery_items(location_id,object_path,caption,uploaded_by) values(p_location_id,p_object_path,btrim(coalesce(p_caption,'')),auth.uid()) returning id into v_id;
 insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason) values(auth.uid(),'gallery.image.uploaded','gallery_item',v_id::text,nullif(btrim(p_caption),''));
 return v_id;
end;
$$;
create or replace function public.admin_set_gallery_item_published(p_item_id uuid,p_is_published boolean)
returns void language plpgsql security definer set search_path=''
as $$
declare v_location uuid;
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 select location_id into v_location from public.gallery_items where id=p_item_id;
 if v_location is null then raise exception 'Gallery image not found'; end if;
 perform public.assert_admin_location_context(v_location);
 update public.gallery_items set is_published=p_is_published,published_at=case when p_is_published then now() else null end where id=p_item_id;
 insert into public.audit_log(actor_user_id,action,entity_type,entity_id) values(auth.uid(),case when p_is_published then 'gallery.image.published' else 'gallery.image.unpublished' end,'gallery_item',p_item_id::text);
end;
$$;
revoke all on function public.get_admin_gallery_items(uuid) from public,anon;
revoke all on function public.admin_register_gallery_item(uuid,text,text) from public,anon;
revoke all on function public.admin_set_gallery_item_published(uuid,boolean) from public,anon;
grant execute on function public.get_admin_gallery_items(uuid) to authenticated;
grant execute on function public.admin_register_gallery_item(uuid,text,text) to authenticated;
grant execute on function public.admin_set_gallery_item_published(uuid,boolean) to authenticated;
