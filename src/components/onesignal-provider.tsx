import { useEffect } from "react";
import type { ReactNode } from "react";
import { getSupabaseClient, isSupabaseConfigured } from "../lib/supabase/client";
import { isOneSignalConfigured, loadOneSignal, type OneSignalSdk } from "../lib/onesignal/client";

export function OneSignalProvider({ children }: { children: ReactNode }) {
  useEffect(() => {
    if (!isOneSignalConfigured() || !isSupabaseConfigured()) return;

    let active = true;
    let sdk: OneSignalSdk | null = null;
    let linkedUserId: string | null = null;
    const supabase = getSupabaseClient();

    const syncIdentity = async (userId: string | null) => {
      if (!active) return;
      if (!userId) {
        const existingSdk = sdk ?? window.OneSignal ?? null;
        if (existingSdk && linkedUserId) {
          try { await existingSdk.logout(); } catch { /* optional push cleanup */ }
        }
        linkedUserId = null;
        return;
      }

      const previousUserId = linkedUserId;
      linkedUserId = userId;
      try {
        const { data: preferences, error } = await supabase.rpc("get_my_notification_preferences");
        if (!active) return;
        if (error || preferences?.push_enabled !== true) {
          const existingSdk = sdk ?? window.OneSignal ?? null;
          if (existingSdk && previousUserId && previousUserId !== userId) {
            try { await existingSdk.logout(); } catch { /* optional push cleanup */ }
          }
          return;
        }

        sdk ??= await loadOneSignal();
        if (!active) return;
        if (previousUserId && previousUserId !== userId) await sdk.logout();
        await sdk.login(userId);
      } catch {
        // Push is optional and must never block account access or app rendering.
      }
    };

    void supabase.auth.getSession()
      .then(({ data: { session } }) => syncIdentity(session?.user.id ?? null))
      .catch(() => syncIdentity(null));

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      queueMicrotask(() => {
        if (active) void syncIdentity(session?.user.id ?? null);
      });
    });

    return () => {
      active = false;
      subscription.unsubscribe();
    };
  }, []);

  return <>{children}</>;
}
