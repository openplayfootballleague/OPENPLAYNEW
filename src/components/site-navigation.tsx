import { useEffect, useRef, useState } from "react";
import { Link, useNavigate } from "@tanstack/react-router";
import { getSupabaseClient } from "../lib/supabase/client";
import { deriveAccountAccess } from "../lib/account/access";

type Access = {
  signedIn: boolean;
  approvedPlayer: boolean;
  captain: boolean;
  admin: boolean;
  finance: boolean;
  loading: boolean;
};

type AccountSummary = {
  name: string;
  avatarUrl: string | null;
  status: string;
  unread: number | null;
};

const signedOut: Access = {
  signedIn: false,
  approvedPlayer: false,
  captain: false,
  admin: false,
  finance: false,
  loading: false,
};

export function SiteNavigation() {
  const navigate = useNavigate();
  const [access, setAccess] = useState<Access>({ ...signedOut, loading: true });
  const [account, setAccount] = useState<AccountSummary>({ name: "Open Play account", avatarUrl: null, status: "Signed out", unread: 0 });
  const [moreOpen, setMoreOpen] = useState(false);
  const [accountOpen, setAccountOpen] = useState(false);
  const [signingOut, setSigningOut] = useState(false);
  const navigationRef = useRef<HTMLElement>(null);

  useEffect(() => {
    if (!accountOpen && !moreOpen) return;
    function closeOnEscape(event: KeyboardEvent) {
      if (event.key === "Escape") {
        setAccountOpen(false);
        setMoreOpen(false);
      }
    }
    function closeOnOutsidePointer(event: PointerEvent) {
      if (event.target instanceof Node && !navigationRef.current?.contains(event.target)) {
        setAccountOpen(false);
        setMoreOpen(false);
      }
    }
    document.addEventListener("keydown", closeOnEscape);
    document.addEventListener("pointerdown", closeOnOutsidePointer);
    return () => {
      document.removeEventListener("keydown", closeOnEscape);
      document.removeEventListener("pointerdown", closeOnOutsidePointer);
    };
  }, [accountOpen, moreOpen]);

  useEffect(() => {
    let alive = true;
    const supabase = getSupabaseClient();
    let accountChannel: ReturnType<typeof supabase.channel> | null = null;
    let accountChannelUserId: string | null = null;
    let loadSequence = 0;

    async function load() {
      const sequence = ++loadSequence;
      const { data: { session } } = await supabase.auth.getSession();
      if (!alive || sequence !== loadSequence) return;
      if (!session) {
        if (accountChannel) {
          void supabase.removeChannel(accountChannel);
          accountChannel = null;
          accountChannelUserId = null;
        }
        setAccess(signedOut);
        setAccount({ name: "Open Play account", avatarUrl: null, status: "Signed out", unread: 0 });
        return;
      }

      const [{ data: player }, { data: memberships }, { data: roles }, { data: profile }, { count: unreadCount }] = await Promise.all([
        supabase.from("players").select("full_name,registration_status,is_banned").eq("user_id", session.user.id).maybeSingle(),
        supabase.from("team_memberships").select("is_captain").eq("user_id", session.user.id).eq("status", "active").eq("is_captain", true),
        supabase.from("user_roles").select("role").eq("user_id", session.user.id),
        supabase.from("profiles").select("first_name,last_name,avatar_path").eq("id", session.user.id).maybeSingle(),
        supabase.from("notification_events").select("id", { count: "exact", head: true }).eq("user_id", session.user.id).eq("channel", "in_app").eq("status", "sent").is("read_at", null),
      ]);
      if (!alive || sequence !== loadSequence) return;

      const roleNames = (roles ?? []).map((row) => row.role);
      const derivedAccess = deriveAccountAccess(player, (memberships ?? []).length > 0, roleNames);
      const fullName = [profile?.first_name, profile?.last_name].filter(Boolean).join(" ").trim();
      const avatarUrl = profile?.avatar_path
        ? supabase.storage.from("profile-avatars").getPublicUrl(profile.avatar_path).data.publicUrl
        : null;
      setAccess({
        signedIn: true,
        ...derivedAccess,
        loading: false,
      });
      setAccount({
        name: player?.full_name || fullName || session.user.email || "Open Play account",
        avatarUrl,
        status: derivedAccess.approvedPlayer ? "Registered player" : player ? "Player registration pending" : "Account not registered as a player",
        unread: unreadCount ?? null,
      });
      if (accountChannelUserId !== session.user.id) {
        if (accountChannel) void supabase.removeChannel(accountChannel);
        accountChannelUserId = session.user.id;
        accountChannel = supabase.channel("account-indicators-" + session.user.id)
          .on("postgres_changes", { event: "*", schema: "public", table: "notification_events", filter: "user_id=eq." + session.user.id }, async () => {
            const { count } = await supabase.from("notification_events").select("id", { count: "exact", head: true }).eq("user_id", session.user.id).eq("channel", "in_app").eq("status", "sent").is("read_at", null);
            if (alive && accountChannelUserId === session.user.id) setAccount(previous => ({ ...previous, unread: count ?? null }));
          })
          .on("postgres_changes", { event: "UPDATE", schema: "public", table: "profiles", filter: "id=eq." + session.user.id }, async () => {
            const { data: updated } = await supabase.from("profiles").select("avatar_path").eq("id", session.user.id).maybeSingle();
            if (alive && accountChannelUserId === session.user.id) setAccount(previous => ({ ...previous, avatarUrl: updated?.avatar_path ? supabase.storage.from("profile-avatars").getPublicUrl(updated.avatar_path).data.publicUrl : null }));
          })
          .subscribe();
      }
    }

    void load();
    const { data: { subscription } } = supabase.auth.onAuthStateChange(() => {
      queueMicrotask(() => { void load(); });
    });
    return () => {
      alive = false;
      subscription.unsubscribe();
      if (accountChannel) void supabase.removeChannel(accountChannel);
      accountChannel = null;
      accountChannelUserId = null;
    };
  }, []);

  const homeTarget = access.signedIn ? "/player" : "/";
  const showJoin = !access.approvedPlayer;

  async function signOut() {
    if (!window.confirm("Sign out of your Open Play account?")) return;
    setSigningOut(true);
    const { error } = await getSupabaseClient().auth.signOut();
    setSigningOut(false);
    if (error) return;
    setAccountOpen(false);
    setAccess(signedOut);
    await navigate({ to: "/" });
  }

  return (
    <header className="op-site-nav" ref={navigationRef}>
      <Link className="op-nav-brand" to={homeTarget} aria-label="Open Play home">
        <span>OPEN</span><strong>PLAY</strong>
      </Link>
      <nav aria-label="Open Play navigation">
        <Link to={homeTarget}>Home</Link>
        <Link to="/match-centre">Match Centre</Link>
        <Link to="/teams">Teams</Link>
        {showJoin && <Link to="/join">Join Open Play</Link>}
        {access.captain && <Link to="/captain">Matchday</Link>}
        <button
          type="button"
          className="op-nav-more-trigger"
          aria-expanded={moreOpen}
          aria-controls="op-nav-more-menu"
          onClick={() => { setMoreOpen((open) => !open); setAccountOpen(false); }}
        >
          More <span aria-hidden="true">{moreOpen ? "−" : "+"}</span>
        </button>
      </nav>

      <div className="op-nav-account-wrap">
        {access.signedIn ? (
          <>
            <button type="button" className="op-account-trigger" aria-label="Open account menu" aria-expanded={accountOpen} aria-controls="op-account-menu" onClick={() => { setAccountOpen((open) => !open); setMoreOpen(false); }}>
              {account.avatarUrl ? <img src={account.avatarUrl} alt="" /> : <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="8" r="3.5" /><path d="M4.5 20c.5-4 3.2-6 7.5-6s7 2 7.5 6" /></svg>}
              {account.unread > 0 && <span className="op-account-unread" aria-label={account.unread + " unread notifications"} />}
            </button>
            {accountOpen && (
              <div id="op-account-menu" className="op-account-menu">
                <div className="op-account-identity">
                  {account.avatarUrl ? <img src={account.avatarUrl} alt="" /> : <span className="op-account-avatar-fallback" aria-hidden="true">{account.name.slice(0, 1).toUpperCase()}</span>}
                  <div><strong>{account.name}</strong><span>{account.status}</span><small>Signed in</small></div>
                </div>
                <Link to="/account" onClick={() => setAccountOpen(false)}>My Account</Link>
                <a href="/inbox" onClick={() => setAccountOpen(false)}>Inbox {account.unread > 0 && <span className="op-account-count">{account.unread}</span>}</a>
                {access.approvedPlayer && <a href="/player#teams" onClick={() => setAccountOpen(false)}>My Teams</a>}
                <a href="/notifications" onClick={() => setAccountOpen(false)}>Notifications</a>
                <a href="/privacy-security" onClick={() => setAccountOpen(false)}>Privacy &amp; Security</a>
                <a href="/support" onClick={() => setAccountOpen(false)}>Help &amp; Support</a>
                {access.captain && <Link to="/captain" onClick={() => setAccountOpen(false)}>Captain Hub</Link>}
                {access.admin && <Link to="/admin" onClick={() => setAccountOpen(false)}>Admin Dashboard</Link>}
                {access.finance && <Link to="/finance" onClick={() => setAccountOpen(false)}>Finance</Link>}
                <button type="button" onClick={() => void signOut()} disabled={signingOut}>{signingOut ? "Signing out…" : "Sign Out"}</button>
              </div>
            )}
          </>
        ) : (
          <Link className="op-account-trigger" to="/sign-in" aria-label="Sign in to Open Play"><svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="8" r="3.5" /><path d="M4.5 20c.5-4 3.2-6 7.5-6s7 2 7.5 6" /></svg></Link>
        )}
      </div>

      {moreOpen && (
        <div id="op-nav-more-menu" className="op-nav-more-menu" aria-label="More Open Play links">
          {access.signedIn ? (
            <Link to="/account" onClick={() => setMoreOpen(false)}>My account</Link>
          ) : (
            <Link to="/sign-in" onClick={() => setMoreOpen(false)}>Sign in</Link>
          )}
          {access.admin && <Link to="/admin" onClick={() => setMoreOpen(false)}>Admin dashboard</Link>}
          {access.finance && <Link to="/finance" onClick={() => setMoreOpen(false)}>Finance</Link>}
          {access.admin && <Link to="/admin-help" onClick={() => setMoreOpen(false)}>Admin help</Link>}
        </div>
      )}
    </header>
  );
}
