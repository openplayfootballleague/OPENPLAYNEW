update storage.buckets set public=false where id='open-play-gallery';
drop policy if exists "Public can view published Open Play gallery images" on storage.objects;
create policy "Published or assigned Open Play gallery images can be read" on storage.objects
for select using(
 bucket_id='open-play-gallery' and (
  exists(select 1 from public.gallery_items gi where gi.object_path=name and gi.is_published=true)
  or (auth.uid() is not null and split_part(name,'/',1) ~* '^[0-9a-f-]{36}$' and public.can_administer_location(split_part(name,'/',1)::uuid))
 )
);
