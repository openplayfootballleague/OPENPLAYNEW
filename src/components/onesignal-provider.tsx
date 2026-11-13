import { useEffect } from "react";
import type { ReactNode } from "react";
import { getSupabaseClient, isSupabaseConfigured } from "../lib/supabase/client";
import {
  clearOneSignalIdentityLink,
  hasOneSignalIdentityLink,
  isOneSignalConfigured,
  loadOneSignal,
  markOneSignalIdentityLinked,
  type OneSignalSdk,
} from "../lib/onesignal/client";

export function OneSignalProvider({ children }: { children: ReactNode }) {
  useEffect(() => {
    if (!isOneSignalConfigured() || !isSupabaseConfigured()) return;

    let active = true;
    let sdk: OneSignalSdk | null = null;
    let linkedUserId: string | null = null;
    const supabase = getSupabaseClient();

    const unlinkIdentity = async () => {
      const hadLink = Boolean(sdk || window.OneSignal || hasOneSignalIdentityLink());
      if (!hadLink) {
        linkedUserId = null;
        return;
      }
      try {
        const existingSdk = sdk ?? window.OneSignal ?? await loadOneSignal();
        await existingSdk.logout();
        clearOneSignalIdentityLink();
      } catch {
        // Keep the local marker so a later page load can retry identity cleanup.
      }
      linkedUserId = null;
    };

    const syncIdentity = async (userId: string | null) => {
      if (!active) return;
      if (!userId) {
        await unlinkIdentity();
        return;
      }

      const previousUserId = linkedUserId;
      linkedUserId = userId;
      try {
        const [{ data: preferences, error }, { data: profile, error: profileError }] = await Promise.all([
          supabase.rpc("get_my_notification_preferences"),
          supabase.from("profiles").select("account_retention_status").eq("id", userId).maybeSingle(),
        ]);
        if (!active) return;
        if (error || profileError || profile?.account_retention_status !== "active" || preferences?.push_enabled !== true) {
          await unlinkIdentity();
          return;
        }

        sdk ??= await loadOneSignal();
        if (!active) return;
        if (previousUserId && previousUserId !== userId) {
          await sdk.logout();
          clearOneSignalIdentityLink();
        }
        await sdk.login(userId);
        markOneSignalIdentityLinked();
      } catch {
        // Push is optional and must never block account access or app rendering.
      }
    };

    void supabase.auth.getSession()
      .then(({ data: { session } }) => syncIdentity(session?.user.id ?? null))
      .catch(() => syncIdentity(null));

    const { data: { subscription } } = supabase.auth.onAuthStateChange((event, session) => {
      if (!["INITIAL_SESSION", "SIGNED_IN", "SIGNED_OUT", "USER_UPDATED"].includes(event)) return;
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
