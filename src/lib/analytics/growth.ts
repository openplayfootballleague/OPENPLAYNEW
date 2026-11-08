export type AnalyticsRegistration = {
  id: string;
  locationId: string;
  createdAt: string;
  status: "registered" | "withdrawn" | "pending" | "rejected";
};

export type RegistrationGrowthSummary = {
  newRegistrations: number;
  withdrawals: number;
  registrationsByLocation: Array<{ locationId: string; registrations: number }>;
};

/** Counts distinct records created inside a half-open reporting period. */
export function summarizeRegistrationGrowth(
  registrations: readonly AnalyticsRegistration[],
  startInclusive: string,
  endExclusive: string,
): RegistrationGrowthSummary {
  const start = Date.parse(startInclusive);
  const end = Date.parse(endExclusive);
  if (!Number.isFinite(start) || !Number.isFinite(end) || start >= end) {
    throw new RangeError("Analytics reporting period must be a valid increasing date range.");
  }

  const seen = new Set<string>();
  const byLocation = new Map<string, Set<string>>();
  let newRegistrations = 0;
  let withdrawals = 0;

  for (const registration of registrations) {
    const created = Date.parse(registration.createdAt);
    if (!Number.isFinite(created) || created < start || created >= end) continue;
    if (!registration.id || !registration.locationId) {
      throw new RangeError("Analytics registrations require an ID and location.");
    }
    if (seen.has(registration.id)) continue;
    seen.add(registration.id);

    if (registration.status === "registered") {
      newRegistrations += 1;
      const locationIds = byLocation.get(registration.locationId) ?? new Set<string>();
      locationIds.add(registration.id);
      byLocation.set(registration.locationId, locationIds);
    } else if (registration.status === "withdrawn") {
      withdrawals += 1;
    }
  }

  return {
    newRegistrations,
    withdrawals,
    registrationsByLocation: [...byLocation.entries()]
      .map(([locationId, ids]) => ({ locationId, registrations: ids.size }))
      .sort((a, b) => a.locationId.localeCompare(b.locationId)),
  };
}

/** Returning teams are distinct teams present in both comparable cohorts. */
export function countReturningTeams(
  previousSeasonTeamIds: readonly string[],
  currentSeasonTeamIds: readonly string[],
): number {
  const previous = new Set(previousSeasonTeamIds);
  const current = new Set(currentSeasonTeamIds);
  let returning = 0;
  for (const id of previous) if (current.has(id)) returning += 1;
  return returning;
}
