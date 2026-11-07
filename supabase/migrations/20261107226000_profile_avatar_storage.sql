-- Private account profile data remains protected by profiles RLS.
-- Avatar objects are publicly readable images, but each signed-in user can
-- upload, replace and delete objects only inside their own UUID folder.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('profile-avatars','profile-avatars',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=true,file_size_limit=5242880,allowed_mime_types=array['image/jpeg','image/png','image/webp'];

create policy profile_avatars_public_read on storage.objects
for select to anon,authenticated using(bucket_id='profile-avatars');

create policy profile_avatars_owner_insert on storage.objects
for insert to authenticated with check(
  bucket_id='profile-avatars' and (storage.foldername(name))[1]=(select auth.uid())::text
);

create policy profile_avatars_owner_update on storage.objects
for update to authenticated using(
  bucket_id='profile-avatars' and (storage.foldername(name))[1]=(select auth.uid())::text
) with check(
  bucket_id='profile-avatars' and (storage.foldername(name))[1]=(select auth.uid())::text
);

create policy profile_avatars_owner_delete on storage.objects
for delete to authenticated using(
  bucket_id='profile-avatars' and (storage.foldername(name))[1]=(select auth.uid())::text
);
