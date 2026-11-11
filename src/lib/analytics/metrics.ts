import type { FinanceEntryType } from "../finance/ledger";

export type AnalyticsFinanceEntry = {
  teamId: string;
  entryType: FinanceEntryType;
  amountPence: number;
  occurredAt: string;
};

export type FinanceAnalyticsSummary = {
  chargesPence: number;
  finesPence: number;
  paymentsPence: number;
  refundsPence: number;
  creditsPence: number;
  expectedIncomePence: number;
  netCashReceivedPence: number;
  outstandingPence: number;
  expenditurePence: null;
  operatingProfitPence: null;
  profitMargin: null;
  completeness: "partial";
};

/**
 * Finance reporting uses ledger entries only. The reporting window is inclusive
 * at start and exclusive at end. Outstanding debt is clamped per team so one
 * team's credit balance cannot conceal another team's debt.
 *
 * Expenditure and profit remain unavailable until the ledger records expenses.
 */
export function summarizeFinanceForAnalytics(
  entries: readonly AnalyticsFinanceEntry[],
  startInclusive: string,
  endExclusive: string,
): FinanceAnalyticsSummary {
  const start = Date.parse(startInclusive);
  const end = Date.parse(endExclusive);
  if (!Number.isFinite(start) || !Number.isFinite(end) || start >= end) {
    throw new RangeError("Analytics date range must be valid and start before end.");
  }

  let chargesPence = 0;
  let finesPence = 0;
  let paymentsPence = 0;
  let refundsPence = 0;
  let creditsPence = 0;
  const teamBalances = new Map<string, number>();

  for (const entry of entries) {
    const occurredAt = Date.parse(entry.occurredAt);
    if (!Number.isFinite(occurredAt) || occurredAt >= end) continue;
    if (!entry.teamId || !Number.isSafeInteger(entry.amountPence) || entry.amountPence <= 0) {
      throw new RangeError("Analytics finance entries require a team and positive integer pence.");
    }

    // Outstanding balance is a point-in-time balance as at the end of the
    // reporting period, so it must include earlier ledger entries too.
    const impact = entry.entryType === "charge" || entry.entryType === "fine"
      ? entry.amountPence
      : -entry.amountPence;
    teamBalances.set(entry.teamId, (teamBalances.get(entry.teamId) ?? 0) + impact);

    // Flow metrics are limited to the selected half-open reporting window.
    if (occurredAt < start) continue;
    switch (entry.entryType) {
      case "charge":
        chargesPence += entry.amountPence;
        break;
      case "fine":
        finesPence += entry.amountPence;
        break;
      case "payment":
        paymentsPence += entry.amountPence;
        break;
      case "refund":
        refundsPence += entry.amountPence;
        break;
      case "credit":
        creditsPence += entry.amountPence;
        break;
    }
  }

  return {
    chargesPence,
    finesPence,
    paymentsPence,
    refundsPence,
    creditsPence,
    expectedIncomePence: chargesPence + finesPence,
    netCashReceivedPence: paymentsPence - refundsPence,
    outstandingPence: [...teamBalances.values()].reduce((sum, balance) => sum + Math.max(balance, 0), 0),
    expenditurePence: null,
    operatingProfitPence: null,
    profitMargin: null,
    completeness: "partial",
  };
}

export function calculateTeamRetention(
  previousSeasonTeamIds: readonly string[],
  currentSeasonTeamIds: readonly string[],
): number | null {
  const previous = new Set(previousSeasonTeamIds);
  if (previous.size === 0) return null;
  const current = new Set(currentSeasonTeamIds);
  let retained = 0;
  for (const id of previous) if (current.has(id)) retained += 1;
  return retained / previous.size;
}

/** Player retention is only meaningful for a stable, comparable player cohort. */
export function calculatePlayerRetention(
  previousPeriodPlayerIds: readonly string[],
  currentPeriodPlayerIds: readonly string[],
): number | null {
  const previous = new Set(previousPeriodPlayerIds);
  if (previous.size === 0) return null;
  const current = new Set(currentPeriodPlayerIds);
  let retained = 0;
  for (const id of previous) if (current.has(id)) retained += 1;
  return retained / previous.size;
}
