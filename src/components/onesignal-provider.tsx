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
      try {
        sdk ??= await loadOneSignal();
        if (!active) return;
        if (userId) {
          if (linkedUserId && linkedUserId !== userId) await sdk.logout();
          if (linkedUserId !== userId) {
            await sdk.login(userId);
            linkedUserId = userId;
          }
        } else if (linkedUserId) {
          await sdk.logout();
          linkedUserId = null;
        }
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
