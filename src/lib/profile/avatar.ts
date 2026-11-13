import { getSupabaseClient } from "../supabase/client";

/**
 * Profile picture rules (the only self-service profile edit; spec section 6).
 * Storage policy limits writes to the user's own folder in `profile-avatars`
 * (JPEG/PNG/WebP, 5 MB); these checks give immediate feedback and mirror it.
 */
export const AVATAR_TYPES = ["image/jpeg", "image/png", "image/webp"] as const;
export const AVATAR_MAX_BYTES = 5 * 1024 * 1024;

export function validateAvatarFile(file: { type: string; size: number }): string | null {
  if (!(AVATAR_TYPES as readonly string[]).includes(file.type)) return "Choose a JPG, PNG or WebP image.";
  if (file.size > AVATAR_MAX_BYTES) return "Profile pictures must be 5 MB or smaller.";
  return null;
}

export function avatarExtension(type: string): "jpg" | "png" | "webp" {
  return type === "image/jpeg" ? "jpg" : type === "image/png" ? "png" : "webp";
}

export type AvatarProfile = { display_name: string | null; phone: string | null; avatar_path: string | null };

/** Uploads to `<userId>/<uuid>.<ext>` and records the path on the caller's own profile row. */
export async function uploadProfileAvatar(userId: string, file: File): Promise<{ profile: AvatarProfile; publicUrl: string }> {
  const problem = validateAvatarFile(file);
  if (problem) throw new Error(problem);
  const path = `${userId}/${crypto.randomUUID()}.${avatarExtension(file.type)}`;
  const storage = getSupabaseClient().storage.from("profile-avatars");
  const { error: uploadError } = await storage.upload(path, file, { contentType: file.type, upsert: false });
  if (uploadError) throw uploadError;
  const { data, error: updateError } = await getSupabaseClient()
    .from("profiles").update({ avatar_path: path }).eq("id", userId).select("display_name,phone,avatar_path").single();
  if (updateError) throw updateError;
  return { profile: data, publicUrl: storage.getPublicUrl(path).data.publicUrl };
}

export function avatarPublicUrl(path: string | null | undefined): string {
  return path ? getSupabaseClient().storage.from("profile-avatars").getPublicUrl(path).data.publicUrl : "";
}
