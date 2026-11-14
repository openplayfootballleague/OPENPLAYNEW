import { useEffect, useState, type ChangeEvent } from "react";
import { Link, useNavigate } from "@tanstack/react-router";
import { PlayerBottomNavigation } from "./player-bottom-navigation";
import { avatarPublicUrl, uploadProfileAvatar, validateAvatarFile } from "../lib/profile/avatar";
import { getSupabaseClient } from "../lib/supabase/client";

type PlayerRow = { full_name: string; date_of_birth: string | null; phone: string | null; registration_status: string; is_banned: boolean };
type Membership = { teamName: string; competition: string; isCaptain: boolean };
type Loaded = { userId: string; email: string; player: PlayerRow | null; avatarUrl: string; membership: Membership | null };

/** Canonical player status, from the server-held registration and suspension fields. */
function playerStatus(player: PlayerRow | null): { label: string; tone: "ok" | "pending" | "warn" } {
  if (!player) return { label: "Not registered as a player", tone: "pending" };
  if (player.is_banned) return { label: "Suspended", tone: "warn" };
  if (player.registration_status === "registered") return { label: "Registered player", tone: "ok" };
  if (player.registration_status === "pending_review") return { label: "Registration under review", tone: "pending" };
  return { label: "Registration not approved", tone: "warn" };
}

/**
 * Player profile (visual reference IMG_0575, spec section 6). The profile picture is the only
 * editable field; every other value is read-only here and corrected through support/admin.
 */
export function PlayerProfilePage() {
  const navigate = useNavigate();
  const [data, setData] = useState<Loaded | null>(null);
  const [loadError, setLoadError] = useState("");
  const [uploading, setUploading] = useState(false);
  const [uploadError, setUploadError] = useState("");
  const [uploadNotice, setUploadNotice] = useState("");
  const [signingOut, setSigningOut] = useState(false);
  const [signOutError, setSignOutError] = useState("");

  useEffect(() => {
    let alive = true;
    void (async () => {
      try {
        const supabase = getSupabaseClient();
        const { data: sessionData } = await supabase.auth.getSession();
        const user = sessionData.session?.user;
        if (!user) throw new Error("Your session has ended. Sign in again.");
        const [playerRes, profileRes, membershipRes] = await Promise.all([
          supabase.from("players").select("full_name,date_of_birth,phone,registration_status,is_banned").eq("user_id", user.id).maybeSingle(),
          supabase.from("profiles").select("avatar_path").eq("id", user.id).maybeSingle(),
          supabase.from("team_memberships").select("season_team_id,is_captain").eq("user_id", user.id).eq("status", "active"),
        ]);
        if (playerRes.error) throw playerRes.error;
        if (profileRes.error) throw profileRes.error;
        if (membershipRes.error) throw membershipRes.error;
        let membership: Membership | null = null;
        const active = membershipRes.data?.[0];
        if (active) {
          const { data: team } = await supabase.from("season_teams").select("name,season_id").eq("id", active.season_team_id).maybeSingle();
          const { data: season } = team
            ? await supabase.from("seasons").select("name,league_id").eq("id", team.season_id).maybeSingle()
            : { data: null };
          const { data: league } = season
            ? await supabase.from("leagues").select("name").eq("id", season.league_id).maybeSingle()
            : { data: null };
          membership = {
            teamName: team?.name ?? "Your team",
            competition: [league?.name, season?.name].filter(Boolean).join(" · ") || "Competition details unavailable",
            isCaptain: active.is_captain,
          };
        }
        if (!alive) return;
        setData({
          userId: user.id,
          email: user.email ?? "",
          player: (playerRes.data as PlayerRow | null) ?? null,
          avatarUrl: avatarPublicUrl(profileRes.data?.avatar_path),
          membership,
        });
      } catch (cause) {
        if (alive) setLoadError(cause instanceof Error ? cause.message : "Your profile could not be loaded.");
      }
    })();
    return () => {
      alive = false;
    };
  }, []);

  async function changePicture(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (!file || !data) return;
    setUploadError("");
    setUploadNotice("");
    const problem = validateAvatarFile(file);
    if (problem) {
      setUploadError(problem);
      return;
    }
    setUploading(true);
    try {
      const { publicUrl } = await uploadProfileAvatar(data.userId, file);
      setData({ ...data, avatarUrl: publicUrl });
      setUploadNotice("Profile picture updated.");
    } catch (cause) {
      setUploadError(cause instanceof Error ? cause.message : "Unable to upload your profile picture.");
    } finally {
      setUploading(false);
    }
  }

  async function signOut() {
    setSigningOut(true);
    setSignOutError("");
    const { error } = await getSupabaseClient().auth.signOut();
    if (error) {
      setSignOutError(error.message);
      setSigningOut(false);
      return;
    }
    await navigate({ to: "/sign-in" });
  }

  const status = playerStatus(data?.player ?? null);
  const name = data?.player?.full_name ?? "Open Play member";
  const initials = name.split(/\s+/).filter(Boolean).slice(0, 2).map((part) => part[0]?.toUpperCase()).join("") || "OP";
  const dob = data?.player?.date_of_birth
    ? new Date(`${data.player.date_of_birth}T00:00:00`).toLocaleDateString("en-GB", { day: "numeric", month: "long", year: "numeric" })
    : "Not provided";

  return (
    <main className="notice-page player-facing">
      <section className="notice-panel player-profile-panel">
        <p className="eyebrow eyebrow-dark">PLAYER HUB / MY PROFILE</p>
        <h1>Your Profile.</h1>
        {loadError && <p className="form-error" role="alert">{loadError}</p>}
        {!data && !loadError && <p className="form-note" role="status">Loading your profile…</p>}
        {data && (
          <>
            <section className="profile-summary" aria-label="Profile summary">
              {data.avatarUrl
                ? <img className="profile-avatar" src={data.avatarUrl} alt="Your profile picture" />
                : <span className="profile-avatar profile-avatar-default" aria-hidden="true">{initials}</span>}
              <div>
                <strong className="profile-name">{name}</strong>
                <span className="profile-role">
                  {data.membership ? `${data.membership.teamName} · ${data.membership.isCaptain ? "Captain" : "Player"}` : "Not in a team yet"}
                </span>
                <span className={`profile-status profile-status-${status.tone}`}>{status.label}</span>
              </div>
              <label className="profile-change-picture">
                {uploading ? "UPLOADING…" : "CHANGE PROFILE PICTURE"}
                <input type="file" accept="image/jpeg,image/png,image/webp" onChange={changePicture} disabled={uploading} />
              </label>
              {uploadError && <p className="form-error" role="alert">{uploadError}</p>}
              {uploadNotice && <p className="form-success" role="status">{uploadNotice}</p>}
            </section>

            <section className="profile-section" aria-labelledby="personal-info-heading">
              <div className="hub-section-heading"><span className="hub-kicker" id="personal-info-heading">PERSONAL INFORMATION</span></div>
              <dl className="profile-readonly">
                {[
                  ["Full name", data.player?.full_name ?? "Not registered"],
                  ["Date of birth", dob],
                  ["Email", data.email || "Not provided"],
                  ["Mobile number", data.player?.phone ?? "Not provided"],
                ].map(([label, value]) => (
                  <div key={label}>
                    <dt>{label}</dt>
                    <dd>{value}<span className="profile-lock" aria-label="Read-only" title="Read-only">🔒</span></dd>
                  </div>
                ))}
              </dl>
              <p className="form-note">
                These details are read-only. To correct them, <Link to="/inbox" search={{ tab: "messages" }}>contact Open Play support</Link>.
              </p>
            </section>

            <section className="profile-section" aria-labelledby="football-info-heading">
              <div className="hub-section-heading"><span className="hub-kicker" id="football-info-heading">FOOTBALL INFORMATION</span></div>
              <dl className="profile-readonly">
                <div><dt>Current team</dt><dd>{data.membership?.teamName ?? "None"}</dd></div>
                <div><dt>Competition</dt><dd>{data.membership?.competition ?? "None"}</dd></div>
                <div><dt>Player status</dt><dd>{status.label}</dd></div>
              </dl>
            </section>

            <nav className="profile-section profile-settings" aria-labelledby="account-settings-heading">
              <div className="hub-section-heading"><span className="hub-kicker" id="account-settings-heading">ACCOUNT SETTINGS</span></div>
              <Link to="/reset-password">Change Password<span aria-hidden="true">›</span></Link>
              <Link to="/player" hash="notification-preferences">Notification Preferences<span aria-hidden="true">›</span></Link>
              <Link to="/privacy-security">Privacy and Permissions<span aria-hidden="true">›</span></Link>
              <span className="profile-settings-pending" aria-disabled="true">
                Terms and Conditions<small>Awaiting publication by Open Play</small>
              </span>
            </nav>

            {signOutError && <p className="form-error" role="alert">{signOutError}</p>}
            <button type="button" className="button profile-logout" onClick={() => void signOut()} disabled={signingOut}>
              {signingOut ? "LOGGING OUT…" : "LOG OUT"}
            </button>
          </>
        )}
      </section>
      <PlayerBottomNavigation />
    </main>
  );
}
