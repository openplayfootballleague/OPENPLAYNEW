import { useEffect, useState } from "react";
import { getSupabaseClient } from "../supabase/client";

/**
 * Owner decision D6: online card payments are frozen unless the owner enables the audited
 * `online_card_payments` platform flag. Returns `null` while loading; any read failure is
 * treated as disabled so no payment action is offered on uncertain state. The checkout Edge
 * Functions enforce the same flag server-side.
 */
export function useOnlineCardPaymentsEnabled(): boolean | null {
  const [enabled, setEnabled] = useState<boolean | null>(null);
  useEffect(() => {
    let alive = true;
    void getSupabaseClient().from("platform_feature_flags").select("enabled").eq("feature_key", "online_card_payments").maybeSingle()
      .then(({ data, error }) => { if (alive) setEnabled(onlinePaymentsEnabled(data, error)); }, () => { if (alive) setEnabled(false); });
    return () => { alive = false; };
  }, []);
  return enabled;
}

export function onlinePaymentsEnabled(row: { enabled: boolean } | null | undefined, error: unknown): boolean {
  return !error && row?.enabled === true;
}

export const ONLINE_PAYMENTS_UNAVAILABLE =
  "Online card payment is not available. Fees and payments are recorded by Open Play administrators.";
