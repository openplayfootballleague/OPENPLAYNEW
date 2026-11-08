import { useEffect, useRef, useState } from "react";
import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { SiteNavigation } from "../components/site-navigation";
import { getSupabaseClient } from "../lib/supabase/client";

export const Route = createFileRoute("/edit-profile")({ component: EditProfilePage });

function EditProfilePage() {
  const navigate = useNavigate();
  const imageRef = useRef<HTMLImageElement>(null);
  const [userId, setUserId] = useState("");
  const [oldPath, setOldPath] = useState<string | null>(null);
  const [currentUrl, setCurrentUrl] = useState<string | null>(null);
  const [file, setFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [zoom, setZoom] = useState(1);
  const [horizontal, setHorizontal] = useState(50);
  const [vertical, setVertical] = useState(50);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");

  useEffect(() => {
    let alive = true;
    async function load() {
      const supabase = getSupabaseClient();
      const { data: { session } } = await supabase.auth.getSession();
      if (!session) {
        await navigate({ to: "/sign-in" });
        return;
      }
      const { data, error: profileError } = await supabase.from("profiles").select("avatar_path").eq("id", session.user.id).maybeSingle();
      if (profileError) throw profileError;
      if (!alive) return;
      setUserId(session.user.id);
      setOldPath(data?.avatar_path ?? null);
      setCurrentUrl(data?.avatar_path ? supabase.storage.from("profile-avatars").getPublicUrl(data.avatar_path).data.publicUrl : null);
      setLoading(false);
    }
    void load().catch(cause => { if (alive) { setError(cause instanceof Error ? cause.message : "Unable to load your profile."); setLoading(false); } });
    return () => { alive = false; };
  }, [navigate]);

  useEffect(() => {
    if (!previewUrl) return;
    return () => URL.revokeObjectURL(previewUrl);
  }, [previewUrl]);

  function chooseImage(event: React.ChangeEvent<HTMLInputElement>) {
    setError(""); setMessage("");
    const selected = event.target.files?.[0] ?? null;
    event.target.value = "";
    if (!selected) return;
    if (!["image/jpeg", "image/png", "image/webp"].includes(selected.type)) {
      setError("Choose a JPG, PNG or WebP image.");
      return;
    }
    if (selected.size > 5 * 1024 * 1024) {
      setError("Profile pictures must be 5 MB or smaller.");
      return;
    }
    setFile(selected);
    setPreviewUrl(URL.createObjectURL(selected));
    setZoom(1); setHorizontal(50); setVertical(50);
  }

  async function savePicture() {
    if (!file || !userId || !imageRef.current) return;
    setSaving(true); setError(""); setMessage("");
    const supabase = getSupabaseClient();
    let newPath: string | null = null;
    try {
      const image = imageRef.current;
      if (!image.complete || !image.naturalWidth) throw new Error("The selected image has not finished loading. Try again.");
      const canvas = document.createElement("canvas");
      canvas.width = 512; canvas.height = 512;
      const context = canvas.getContext("2d");
      if (!context) throw new Error("Your browser could not prepare this picture. Try another browser.");
      const scale = Math.max(512 / image.naturalWidth, 512 / image.naturalHeight) * zoom;
      const width = image.naturalWidth * scale;
      const height = image.naturalHeight * scale;
      const left = (512 - width) * (horizontal / 100);
      const top = (512 - height) * (vertical / 100);
      context.drawImage(image, left, top, width, height);
      const blob = await new Promise<Blob>((resolve, reject) => canvas.toBlob(value => value ? resolve(value) : reject(new Error("Could not prepare the cropped image.")), "image/webp", 0.86));
      if (blob.size > 2 * 1024 * 1024) throw new Error("The optimised image is too large. Choose a smaller picture.");
      newPath = userId + "/" + crypto.randomUUID() + ".webp";
      const storage = supabase.storage.from("profile-avatars");
      const { error: uploadError } = await storage.upload(newPath, blob, { contentType: "image/webp", upsert: false });
      if (uploadError) throw uploadError;
      const { error: updateError } = await supabase.from("profiles").update({ avatar_path: newPath }).eq("id", userId);
      if (updateError) throw updateError;
      if (oldPath && oldPath !== newPath) await storage.remove([oldPath]);
      setOldPath(newPath);
      setCurrentUrl(storage.getPublicUrl(newPath).data.publicUrl);
      setFile(null); setPreviewUrl(null);
      setMessage("Your profile picture has been updated.");
    } catch (cause) {
      if (newPath) await supabase.storage.from("profile-avatars").remove([newPath]);
      setError(cause instanceof Error ? cause.message : "Unable to update your profile picture.");
    } finally {
      setSaving(false);
    }
  }

  if (loading) return <main className="notice-page"><SiteNavigation /><section className="notice-panel"><p>Loading your profile…</p></section></main>;

  return <main className="notice-page"><SiteNavigation /><section className="notice-panel edit-profile-page">
    <Link className="account-back-link" to="/account">← MY ACCOUNT</Link>
    <p className="eyebrow eyebrow-dark">ACCOUNT SETTINGS</p>
    <h1>EDIT <em>PROFILE</em></h1>
    <p>Keep your Open Play picture up to date.</p>
    <div className="edit-avatar-preview">
      {previewUrl ? <img ref={imageRef} src={previewUrl} alt="Selected profile picture preview" /> : currentUrl ? <img src={currentUrl} alt="Current profile picture" /> : <span aria-hidden="true">OP</span>}
    </div>
    {previewUrl && <div className="avatar-crop-controls">
      <p>Move and zoom your picture to fit the circle.</p>
      <label>Zoom <input type="range" min="1" max="3" step="0.01" value={zoom} onChange={e=>setZoom(Number(e.target.value))}/></label>
      <label>Horizontal position <input type="range" min="0" max="100" value={horizontal} onChange={e=>setHorizontal(Number(e.target.value))}/></label>
      <label>Vertical position <input type="range" min="0" max="100" value={vertical} onChange={e=>setVertical(Number(e.target.value))}/></label>
      <div className="avatar-crop-preview" aria-hidden="true"><img src={previewUrl} style={{ width: (Math.max(100, 100 * zoom)) + "%", height: (Math.max(100, 100 * zoom)) + "%", objectFit: "cover", objectPosition: horizontal + "% " + vertical + "%" }} alt="" /></div>
    </div>}
    <label className="button edit-avatar-select"> {currentUrl || previewUrl ? "CHANGE PROFILE PHOTO" : "UPLOAD NEW PICTURE"} <input type="file" accept="image/jpeg,image/png,image/webp" onChange={chooseImage} disabled={saving}/></label>
    <p className="form-note">This picture appears across Open Play. JPG, PNG or WebP · Maximum 5 MB.</p>
    {error && <p className="form-error" role="alert">{error}</p>}
    {message && <p className="form-success" role="status">{message}</p>}
    {previewUrl && <div className="edit-avatar-actions"><button type="button" className="button" disabled={saving} onClick={()=>void savePicture()}>{saving?"UPLOADING…":"CONFIRM PICTURE"} <span>↗</span></button><button type="button" className="auth-text-button" disabled={saving} onClick={()=>{setFile(null);setPreviewUrl(null);}}>Cancel</button></div>}
  </section></main>;
}
