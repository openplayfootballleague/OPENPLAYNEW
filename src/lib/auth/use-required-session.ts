import { useEffect, useState } from "react";
import { getSupabaseClient } from "../supabase/client";

export type RequiredSessionStatus = "loading" | "authenticated" | "unauthenticated";

/** Shared client-side session boundary for protected workspaces.
 * Database RPC/RLS checks remain the source of truth for permissions.
 */
export function useRequiredSession(): RequiredSessionStatus {
  const [authenticated, setAuthenticated] = useState<boolean | null>(null);

  useEffect(() => {
    let active = true;
    let authEventSeen = false;
    const supabase = getSupabaseClient();
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      authEventSeen = true;
      if (active) setAuthenticated(Boolean(session));
    });

    void supabase.auth.getSession().then(({ data, error }) => {
      if (active && !authEventSeen) setAuthenticated(!error && Boolean(data.session));
    }).catch(() => {
      if (active && !authEventSeen) setAuthenticated(false);
    });

    return () => {
      active = false;
      subscription.unsubscribe();
    };
  }, []);

  if (authenticated === null) return "loading";
  return authenticated ? "authenticated" : "unauthenticated";
}
