import { useEffect, useState } from "react";
import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { SiteNavigation } from "../components/site-navigation";
import { getSupabaseClient } from "../lib/supabase/client";

type AccountData = {
  name: string;
  email: string;
  avatarUrl: string | null;
  registration: string;
  playerLinked: boolean;
  memberships: number;
  unreadMessages: number;
  unreadNotifications: number;
  admin: boolean;
};

export const Route = createFileRoute("/account")({ component: AccountPage });

function AccountPage() {
  const navigate = useNavigate();
  const [data, setData] = useState<AccountData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    let alive = true;
    async function load() {
      try {
        const supabase = getSupabaseClient();
        const { data: { session } } = await supabase.auth.getSession();
        if (!session) {
          await navigate({ to: "/sign-in" });
          return;
        }
        const [{ data: profile, error: profileError }, { data: player, error: playerError }, { data: memberships, error: membershipError }, { count: unreadNotifications, error: notificationError }, { data: roles, error: roleError }] = await Promise.all([
          supabase.from("profiles").select("first_name,last_name,avatar_path").eq("id", session.user.id).maybeSingle(),
          supabase.from("players").select("full_name,registration_status,is_banned").eq("user_id", session.user.id).maybeSingle(),
          supabase.from("team_memberships").select("id,status").eq("user_id", session.user.id),
          supabase.from("notification_events").select("id", { count: "exact", head: true }).eq("user_id", session.user.id).eq("channel", "in_app").eq("status", "sent").is("read_at", null),
          supabase.from("user_roles").select("role").eq("user_id", session.user.id),
        ]);
        const failed = profileError ?? playerError ?? membershipError ?? notificationError ?? roleError;
        if (failed) throw failed;
        if (!alive) return;
        const fullName = [profile?.first_name, profile?.last_name].filter(Boolean).join(" ").trim();
        const avatarUrl = profile?.avatar_path ? supabase.storage.from("profile-avatars").getPublicUrl(profile.avatar_path).data.publicUrl : null;
        const registration = !player ? "Not registered as a player" : player.is_banned ? "Player account restricted" : player.registration_status.replaceAll("_", " ");
        setData({
          name: fullName || player?.full_name || session.user.email || "Open Play account",
          email: session.user.email ?? "",
          avatarUrl,
          registration,
          playerLinked: Boolean(player),
          memberships: (memberships ?? []).filter(row => row.status === "active").length,
          unreadMessages: 0,
          unreadNotifications: unreadNotifications ?? 0,
          admin: (roles ?? []).some(row => ["admin", "super_admin", "league_admin"].includes(row.role)),
        });
      } catch (cause) {
        if (alive) setError(cause instanceof Error ? cause.message : "Unable to load your account.");
      } finally {
        if (alive) setLoading(false);
      }
    }
    void load();
    return () => { alive = false; };
  }, [navigate]);

  if (loading) return <main className="notice-page"><SiteNavigation /><section className="notice-panel"><p>Loading your account…</p></section></main>;
  if (error || !data) return <main className="notice-page"><SiteNavigation /><section className="notice-panel"><p className="form-error" role="alert">{error || "Your account could not be loaded."}</p><Link className="button" to="/sign-in">SIGN IN <span>↗</span></Link></section></main>;

  return <main className="notice-page"><SiteNavigation /><section className="notice-panel account-hub">
    <p className="eyebrow eyebrow-dark">YOUR OPEN PLAY</p>
    <h1>My <em>Account.</em></h1>
    <section className="account-identity-card">
      {data.avatarUrl ? <img src={data.avatarUrl} alt="Your profile" /> : <span className="account-avatar-fallback" aria-hidden="true">{data.name.slice(0,1).toUpperCase()}</span>}
      <div><span className="hub-kicker">ACCOUNT IDENTITY</span><h2>{data.name}</h2><p>{data.email}</p><strong>{data.registration}</strong></div>
    </section>
    {!data.playerLinked && <section className="account-register-callout"><h2>Your player profile isn't registered yet.</h2><p>Your account is separate from player registration. Complete registration if you want to take part as a player.</p><Link className="button button-small" to="/register-player">REGISTER AS A PLAYER <span>↗</span></Link></section>}
    <div className="account-stat-grid">
      <a href="/inbox"><strong>{data.unreadMessages}</strong><span>Unread messages</span></a>
      <a href="/player#teams"><strong>{data.memberships}</strong><span>Current teams</span></a>
      <a href="/player#notifications"><strong>{data.unreadNotifications}</strong><span>Unread alerts</span></a>
    </div>
    <div className="account-section-grid">
      <a href="/edit-profile"><strong>Edit Profile</strong><span>Change your profile picture</span></a>
      <a href="/inbox"><strong>Inbox</strong><span>Messages and announcements</span></a>
      <a href="/player#teams"><strong>My Teams</strong><span>Current and previous memberships</span></a>
      <a href="/player#notifications"><strong>Notifications</strong><span>Alerts and preferences</span></a>
      <a href="/privacy-security"><strong>Privacy &amp; Security</strong><span>Account security and privacy controls</span></a>
      <a href="/support"><strong>Help &amp; Support</strong><span>Get help from Open Play</span></a>
      {data.admin && <Link to="/admin"><strong>Admin Dashboard</strong><span>Authorised administration</span></Link>}
    </div>
  </section></main>;
}
