import { useEffect, useState } from "react";
import { Link } from "@tanstack/react-router";
import { Bell, MapPin, User } from "lucide-react";
import { getSupabaseClient } from "../lib/supabase/client";
import { isApprovedPlayer } from "../lib/navigation/account-navigation";
import { formatUnreadCount, LOCATION_CHANGE_EVENT, COMPETITION_STORAGE_KEY, readStoredLocationId } from "../lib/navigation/global-header";

type Location = { id: string; name: string };

/**
 * Global player-facing header (references IMG_0577 signed in, IMG_0578 signed out): Open Play brand,
 * notifications, Sign In or account, and the location selector. Locations come only from published,
 * active locations; the unread count is read under the caller's own RLS.
 */
export function GlobalHeader() {
  const [signedIn, setSignedIn] = useState<boolean | null>(null);
  const [home, setHome] = useState<"/" | "/player">("/");
  const [unread, setUnread] = useState(0);
  const [locations, setLocations] = useState<Location[]>([]);
  const [locationId, setLocationId] = useState("");

  useEffect(() => {
    const supabase = getSupabaseClient();
    let alive = true;
    async function loadAccount(userId: string | null) {
      setSignedIn(Boolean(userId));
      if (!userId) { setUnread(0); setHome("/"); return; }
      const [{ count, error }, { data: player }] = await Promise.all([
        supabase.from("notification_events").select("id", { count: "exact", head: true }).eq("user_id", userId).is("read_at", null),
        supabase.from("players").select("registration_status,is_banned").eq("user_id", userId).maybeSingle(),
      ]);
      if (!alive) return;
      setUnread(error ? 0 : count ?? 0);
      // The logo returns approved players to their Player Hub (owner spec 4); others to public Home.
      setHome(isApprovedPlayer(player ?? null) ? "/player" : "/");
    }
    void supabase.auth.getSession().then(({ data }) => { if (alive) void loadAccount(data.session?.user.id ?? null); }).catch(() => { if (alive) setSignedIn(false); });
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => { if (alive) void loadAccount(session?.user.id ?? null); });
    void supabase.from("locations").select("id,name").eq("is_active", true).order("name").then(({ data }) => {
      if (!alive) return;
      const rows = (data ?? []) as Location[];
      setLocations(rows);
      const stored = readStoredLocationId();
      setLocationId(rows.some((row) => row.id === stored) ? stored : rows[0]?.id ?? "");
    });
    return () => { alive = false; subscription.unsubscribe(); };
  }, []);

  function changeLocation(next: string) {
    setLocationId(next);
    try {
      window.localStorage.setItem(COMPETITION_STORAGE_KEY, JSON.stringify({ locationId: next }));
    } catch {
      // Storage may be unavailable; open pages still receive the event below.
    }
    window.dispatchEvent(new CustomEvent(LOCATION_CHANGE_EVENT, { detail: { locationId: next } }));
  }

  return (
    <header className={"global-header" + (signedIn === false ? " global-header--signed-out" : "")}>
      <Link to={home} className="global-header-brand" aria-label={home === "/player" ? "Open Play — Player Hub" : "Open Play home"}>
        <img src="/open-play-logo.png" alt="" /><span>OPEN PLAY</span>
      </Link>
      <div className="global-header-actions">
        <Link to={signedIn ? "/inbox" : "/sign-in"} className="global-header-bell" aria-label={unread > 0 ? `Notifications, ${unread} unread` : "Notifications"}>
          <Bell aria-hidden="true" />
          {unread > 0 && <span className="global-header-badge" aria-hidden="true">{formatUnreadCount(unread)}</span>}
        </Link>
        {signedIn === false && <Link to="/sign-in" className="global-header-signin">SIGN IN</Link>}
        {signedIn && (
          <Link to="/player/profile" className="global-header-avatar" aria-label="Your profile">
            <User aria-hidden="true" />
          </Link>
        )}
        {locations.length > 0 && (
          <label className="global-header-location">
            <MapPin aria-hidden="true" />
            <span className="visually-hidden">Location</span>
            <select value={locationId} onChange={(event) => changeLocation(event.target.value)}>
              {locations.map((location) => <option key={location.id} value={location.id}>{location.name}</option>)}
            </select>
          </label>
        )}
      </div>
    </header>
  );
}
