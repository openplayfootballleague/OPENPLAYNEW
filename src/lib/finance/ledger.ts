export type FinanceEntryType = "charge" | "payment" | "refund" | "credit" | "fine";

/** Convert a pounds input to integer pence without floating-point rounding. */
export function poundsToPence(value: string): number | null {
  const trimmed = value.trim();
  if (!/^\d+(\.\d{1,2})?$/.test(trimmed)) return null;
  const [whole, fraction = ""] = trimmed.split(".");
  const amount = Number(whole) * 100 + Number((fraction + "00").slice(0, 2));
  return Number.isSafeInteger(amount) ? amount : null;
}

/** Positive impacts increase the team's debt; negative impacts reduce it. */
export function financeEntryImpactPence(type: FinanceEntryType, amountPence: number): number {
  if (!Number.isSafeInteger(amountPence) || amountPence <= 0) {
    throw new RangeError("Finance amounts must be positive integer pence.");
  }
  return type === "charge" || type === "fine"
    ? amountPence
    : -amountPence;
}

/** Overpayments stay visible as a negative team balance but never offset another team's debt. */
export function outstandingPenceByTeam(
  entries: readonly { teamId: string; type: FinanceEntryType; amountPence: number }[],
): number {
  const balances = new Map<string, number>();
  for (const entry of entries) {
    balances.set(
      entry.teamId,
      (balances.get(entry.teamId) ?? 0) + financeEntryImpactPence(entry.type, entry.amountPence),
    );
  }
  return [...balances.values()].reduce((total, balance) => total + Math.max(balance, 0), 0);
}
