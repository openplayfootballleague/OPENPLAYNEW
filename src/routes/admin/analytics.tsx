import { useCallback, useEffect, useMemo, useState } from "react";
import { Link, createFileRoute, useNavigate } from "@tanstack/react-router";
import { useRequiredSession } from "../../lib/auth/use-required-session";
import { aggregateFinanceTotals, buildAnalyticsOverview, buildLocationComparisons, type AnalyticsDashboardCounts, type AnalyticsFilters, type AnalyticsSetup, type FinanceSummaryRow } from "../../lib/analytics/overview";
import { getSupabaseClient } from "../../lib/supabase/client";

type ContextPreference = { location_id: string | null; league_id: string | null; season_id: string | null; is_global_admin: boolean };
type Dashboard = { counts: AnalyticsDashboardCounts };
type Fixture = { id: string; season_id: string; gameweek: number; status: string; home_score: number | null; away_score: number | null; scheduled_at: string | null; home_team_name: string; away_team_name: string };
type SeasonStats = {
  season: { id: string; name: string; status: string; is_public: boolean };
  summary: { fixtures: number; published_results: number; goals: number; goals_per_match: number; home_wins: number; away_wins: number; draws: number; team_clean_sheets: number };
  teams: Array<{ position: number; team_id: string; name: string; played: number; wins: number; draws: number; losses: number; goals_for: number; goals_against: number; goal_difference: number; points: number; clean_sheets: number }>;
  players: Array<{ competition_player_id: string; full_name: string; apps: number; goals: number }>;
};
type FinanceOption = { season_id: string; season_name: string; team_id: string; team_name: string; league_name: string; season_status: string };
type GrowthRow = {
  bucket_date: string;
  account_signups: number | string | null;
  player_registrations: number | string;
  team_applications: number | string;
  team_approvals: number | string;
};
type RegistrationRow = {
  bucket_date: string;
  player_registered: number | string | null;
  player_pending_review: number | string | null;
  player_rejected: number | string | null;
  team_applications: number | string;
  team_approved: number | string;
  team_rejected: number | string;
  team_pending: number | string;
  membership_requests: number | string;
  membership_accepted: number | string;
  membership_rejected: number | string;
  membership_pending: number | string;
};
type Tab = "overview" | "usage" | "growth" | "registrations" | "engagement" | "features" | "locations" | "competition" | "business" | "reports";
type ProductAnalytics = {
  status: "ready" | "no_data";
  range: { fromDate: string; toDate: string };
  weeklyActivity: Array<{ week_start: string; active_users: number; value_actions: number }>;
  retention: Array<{ cohort_week: string; weeks_since_start: number; cohort_users: number; retained_users: number; retention_rate: number }>;
  features: Array<{ feature: string; unique_users: number; value_actions: number }>;
  definitions: { engagedUser: string; retention: string; featurePerformance: string };
};

const money = (pence: number) => new Intl.NumberFormat("en-GB", { style: "currency", currency: "GBP" }).format(pence / 100);
const csvCell = (value: string | number) => '"' + String(value).replaceAll('"', '""') + '"';

export const Route = createFileRoute("/admin/analytics")({ component: AdminAnalyticsPage });

function AdminAnalyticsPage() {
  const authStatus = useRequiredSession();
  const navigate = useNavigate();
  const [contextReady, setContextReady] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [isGlobalAdmin, setIsGlobalAdmin] = useState(false);
  const [locationId, setLocationId] = useState("");
  const [fromDate, setFromDate] = useState("");
  const [toDate, setToDate] = useState("");
  const [leagueId, setLeagueId] = useState("");
  const [seasonId, setSeasonId] = useState("");
  const [contextSaving, setContextSaving] = useState(false);
  const [setup, setSetup] = useState<AnalyticsSetup>({ locations: [], leagues: [], seasons: [], season_teams: [], fixtures: [] });
  const [dashboard, setDashboard] = useState<Dashboard | null>(null);
  const [fixtures, setFixtures] = useState<Fixture[]>([]);
  const [seasonStats, setSeasonStats] = useState<SeasonStats | null>(null);
  const [seasonError, setSeasonError] = useState("");
  const [financeAccess, setFinanceAccess] = useState(false);
  const [financeError, setFinanceError] = useState("");
  const [financeOptions, setFinanceOptions] = useState<FinanceOption[]>([]);
  const [financeRows, setFinanceRows] = useState<FinanceSummaryRow[]>([]);
  const [growthRows, setGrowthRows] = useState<GrowthRow[]>([]);
  const [growthError, setGrowthError] = useState("");
  const [registrationRows, setRegistrationRows] = useState<RegistrationRow[]>([]);
  const [registrationError, setRegistrationError] = useState("");
  const [productAnalytics, setProductAnalytics] = useState<ProductAnalytics | null>(null);
  const [productAnalyticsLoading, setProductAnalyticsLoading] = useState(false);
  const [productAnalyticsError, setProductAnalyticsError] = useState("");
  const [refreshedAt, setRefreshedAt] = useState<Date | null>(null);
  const [tab, setTab] = useState<Tab>("overview");

  useEffect(() => {
    if (authStatus === "unauthenticated") void navigate({ to: "/sign-in", replace: true });
  }, [authStatus, navigate]);

  useEffect(() => {
    if (authStatus !== "authenticated") return;
    let alive = true;
    void (async () => {
      setLoading(true);
      const [preferenceResult, setupResult] = await Promise.all([
        getSupabaseClient().rpc("get_admin_context_preference"),
        getSupabaseClient().rpc("get_admin_competition_setup"),
      ]);
      if (!alive) return;
      if (preferenceResult.error || setupResult.error) {
        setError(preferenceResult.error?.message ?? setupResult.error?.message ?? "Administrator access is required.");
        setLoading(false);
        return;
      }
      const preference = preferenceResult.data as ContextPreference;
      const setupData = (setupResult.data ?? { locations: [], leagues: [], seasons: [], season_teams: [], fixtures: [] }) as AnalyticsSetup;
      let nextLocation = preference.location_id ?? "";
      if (!preference.is_global_admin && !nextLocation && setupData.locations.length > 0) {
        const { error: saveError } = await getSupabaseClient().rpc("save_admin_context_preference", {
          p_location_id: setupData.locations[0].id,
          p_league_id: undefined,
          p_season_id: undefined,
        });
        if (!alive) return;
        if (saveError) setError(saveError.message);
        nextLocation = setupData.locations[0].id;
      }
      setIsGlobalAdmin(preference.is_global_admin);
      setSetup(setupData);
      setLocationId(nextLocation);
      setLeagueId(preference.league_id ?? "");
      setSeasonId(preference.season_id ?? "");
      setContextReady(true);
      setLoading(false);
    })().catch((cause: unknown) => {
      if (alive) {
        setError(cause instanceof Error ? cause.message : "Unable to load analytics workspace.");
        setLoading(false);
      }
    });
    return () => { alive = false; };
  }, [authStatus]);

  const loadContextData = useCallback(async () => {
    if (!contextReady || authStatus !== "authenticated") return;
    setLoading(true);
    setError("");
    try {
      const args = {
        p_location_id: locationId || undefined,
        p_league_id: leagueId || undefined,
        p_season_id: seasonId || undefined,
      };
      const [dashboardResult, fixtureResult, growthResult, registrationResult] = await Promise.all([
        getSupabaseClient().rpc("get_admin_dashboard_contextual", args),
        getSupabaseClient().rpc("get_admin_contextual_fixtures", args),
        getSupabaseClient().rpc("get_admin_user_growth", {
          p_from_date: fromDate || undefined,
          p_to_date: toDate || undefined,
          ...args,
        }),
        getSupabaseClient().rpc("get_admin_registration_conversion", {
          p_from_date: fromDate || undefined,
          p_to_date: toDate || undefined,
          ...args,
        }),
      ]);
      if (dashboardResult.error || fixtureResult.error) {
        throw new Error(dashboardResult.error?.message ?? fixtureResult.error?.message ?? "Unable to load analytics data.");
      }
      setDashboard(dashboardResult.data as Dashboard);
      setFixtures((fixtureResult.data ?? []) as Fixture[]);
      if (growthResult.error) {
        setGrowthRows([]);
        setGrowthError("User growth reporting is unavailable for this context.");
      } else {
        setGrowthRows((growthResult.data ?? []) as GrowthRow[]);
        setGrowthError("");
      }
      if (registrationResult.error) {
        setRegistrationRows([]);
        setRegistrationError("Registration conversion reporting is unavailable for this context.");
      } else {
        setRegistrationRows((registrationResult.data ?? []) as RegistrationRow[]);
        setRegistrationError("");
      }

      if (seasonId) {
        const { data, error: statsRpcError } = await getSupabaseClient().rpc("get_admin_season_statistics", { p_season_id: seasonId });
        if (statsRpcError) {
          setSeasonStats(null);
          setSeasonError(statsRpcError.message);
        } else {
          setSeasonStats(data as SeasonStats);
          setSeasonError("");
        }
      } else {
        setSeasonStats(null);
        setSeasonError("");
      }

      const { data: financeOptionRows, error: financeOptionError } = await getSupabaseClient().rpc("get_finance_options");
      if (financeOptionError) {
        setFinanceAccess(false);
        setFinanceOptions([]);
        setFinanceRows([]);
        setFinanceError("Finance reporting is restricted to authorised finance administrators.");
      } else {
        setFinanceAccess(true);
        setFinanceOptions((financeOptionRows ?? []) as FinanceOption[]);
        if (!seasonId && (locationId || leagueId)) {
          setFinanceRows([]);
          setFinanceError("Choose a season to view finance totals scoped to this location or league.");
        } else {
          const { data: summaryRows, error: financeSummaryError } = await getSupabaseClient().rpc("get_finance_summary", { p_season_id: seasonId || undefined });
          if (financeSummaryError) {
            setFinanceRows([]);
            setFinanceError("Finance summary could not be loaded for this context.");
          } else {
            setFinanceRows((summaryRows ?? []) as FinanceSummaryRow[]);
            setFinanceError("");
          }
        }
      }
      setRefreshedAt(new Date());
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Unable to load analytics workspace.");
      setDashboard(null);
      setFixtures([]);
    } finally {
      setLoading(false);
    }
  }, [authStatus, contextReady, fromDate, leagueId, locationId, seasonId, toDate]);

  useEffect(() => {
    if (contextReady) void loadContextData();
  }, [contextReady, loadContextData]);

  useEffect(() => {
    if (!contextReady || authStatus !== "authenticated" || (tab !== "engagement" && tab !== "features")) return;
    let alive = true;
    setProductAnalyticsLoading(true);
    setProductAnalyticsError("");
    void (async () => {
      const { data, error: invokeError } = await getSupabaseClient().functions.invoke("admin-product-analytics", {
        body: {
          fromDate: fromDate || undefined,
          toDate: toDate || undefined,
          locationId: locationId || undefined,
          leagueId: leagueId || undefined,
          seasonId: seasonId || undefined,
        },
      });
      if (!alive) return;
      if (invokeError) {
        let message = "Product analytics could not be loaded. Check the server-side PostHog query credential.";
        const response = (invokeError as Error & { context?: Response }).context;
        if (response) {
          try {
            const body = await response.clone().json() as { error?: string };
            if (typeof body.error === "string") message = body.error;
          } catch {
            // Keep the generic fail-closed message when an error body is unavailable.
          }
        }
        setProductAnalytics(null);
        setProductAnalyticsError(message);
        return;
      }
      const payload = data as ProductAnalytics | { error?: string } | null;
      if (!payload || !("status" in payload)) {
        setProductAnalytics(null);
        setProductAnalyticsError(payload && "error" in payload && typeof payload.error === "string" && payload.error
          ? payload.error
          : "Product analytics returned an invalid response.");
        return;
      }
      setProductAnalytics(payload);
      setProductAnalyticsError("");
    })().catch((cause: unknown) => {
      if (alive) {
        setProductAnalytics(null);
        setProductAnalyticsError(cause instanceof Error ? cause.message : "Product analytics could not be loaded.");
      }
    }).finally(() => {
      if (alive) setProductAnalyticsLoading(false);
    });
    return () => { alive = false; };
  }, [authStatus, contextReady, fromDate, leagueId, locationId, seasonId, tab, toDate]);

  const dateRangeInvalid = Boolean(fromDate && toDate && fromDate > toDate);
  const filters: AnalyticsFilters = { locationId, leagueId, seasonId, fromDate, toDate };
  const overview = useMemo(() => dashboard && !dateRangeInvalid
    ? buildAnalyticsOverview(setup, dashboard.counts, fixtures, filters)
    : null, [dashboard, dateRangeInvalid, fixtures, fromDate, leagueId, locationId, seasonId, setup, toDate]);
  const locationComparisons = useMemo(
    () => buildLocationComparisons(setup, { locationId, leagueId, seasonId, fromDate, toDate }),
    [fromDate, leagueId, locationId, seasonId, setup, toDate],
  );
  const financeTotals = useMemo(() => aggregateFinanceTotals(financeRows), [financeRows]);
  const growthTotals = useMemo(() => ({
    accountSignups: growthRows.some((row) => row.account_signups !== null)
      ? growthRows.reduce((total, row) => total + Number(row.account_signups ?? 0), 0)
      : null,
    playerRegistrations: growthRows.reduce((total, row) => total + Number(row.player_registrations ?? 0), 0),
    teamApplications: growthRows.reduce((total, row) => total + Number(row.team_applications ?? 0), 0),
    teamApprovals: growthRows.reduce((total, row) => total + Number(row.team_approvals ?? 0), 0),
  }), [growthRows]);
  const registrationTotals = useMemo(() => registrationRows.reduce((totals, row) => ({
    playerRegistered: totals.playerRegistered === null || row.player_registered === null ? null : totals.playerRegistered + Number(row.player_registered),
    playerPending: totals.playerPending === null || row.player_pending_review === null ? null : totals.playerPending + Number(row.player_pending_review),
    playerRejected: totals.playerRejected === null || row.player_rejected === null ? null : totals.playerRejected + Number(row.player_rejected),
    teamApplications: totals.teamApplications + Number(row.team_applications),
    teamApproved: totals.teamApproved + Number(row.team_approved),
    teamRejected: totals.teamRejected + Number(row.team_rejected),
    teamPending: totals.teamPending + Number(row.team_pending),
    membershipRequests: totals.membershipRequests + Number(row.membership_requests),
    membershipAccepted: totals.membershipAccepted + Number(row.membership_accepted),
    membershipRejected: totals.membershipRejected + Number(row.membership_rejected),
    membershipPending: totals.membershipPending + Number(row.membership_pending),
  }), {
    playerRegistered: registrationRows.length > 0 && registrationRows[0].player_registered !== null ? 0 : null,
    playerPending: registrationRows.length > 0 && registrationRows[0].player_pending_review !== null ? 0 : null,
    playerRejected: registrationRows.length > 0 && registrationRows[0].player_rejected !== null ? 0 : null,
    teamApplications: 0, teamApproved: 0, teamRejected: 0, teamPending: 0,
    membershipRequests: 0, membershipAccepted: 0, membershipRejected: 0, membershipPending: 0,
  }), [registrationRows]);
  const teamResolved = registrationTotals.teamApproved + registrationTotals.teamRejected;
  const membershipResolved = registrationTotals.membershipAccepted + registrationTotals.membershipRejected;
  const teamApprovalRate = teamResolved > 0 ? registrationTotals.teamApproved / teamResolved * 100 : null;
  const membershipAcceptanceRate = membershipResolved > 0 ? registrationTotals.membershipAccepted / membershipResolved * 100 : null;

  async function saveContext(nextLocation: string, nextLeague: string, nextSeason: string) {
    setContextSaving(true);
    setError("");
    setNotice("");
    try {
      const { data, error: rpcError } = await getSupabaseClient().rpc("save_admin_context_preference", {
        p_location_id: nextLocation || undefined,
        p_league_id: nextLeague || undefined,
        p_season_id: nextSeason || undefined,
      });
      if (rpcError) throw rpcError;
      const saved = data as { location_id: string | null; league_id: string | null; season_id: string | null };
      setLocationId(saved.location_id ?? "");
      setLeagueId(saved.league_id ?? "");
      setSeasonId(saved.season_id ?? "");
      setNotice("Reporting context saved.");
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Unable to save reporting context.");
    } finally {
      setContextSaving(false);
    }
  }

  function exportCsv() {
    if (!overview) return;
    const rows: Array<Array<string | number>> = [
      ["Metric", "Value"],
      ["Accessible locations", overview.locations],
      ["Leagues in context", overview.leagues],
      ["Seasons in context", overview.seasons],
      ["Open seasons", overview.openSeasons],
      ["Approved teams", overview.approvedTeams],
      ["Current squad memberships", overview.squadMemberships],
      ["Fixtures in context", overview.fixtures],
      ["Published results", overview.publishedResults],
      ["Goals in published results", overview.goals],
      ["Pending player reviews", overview.pendingPlayerReviews],
      ["Pending team applications", overview.pendingTeamApplications],
      ["Pending join requests", overview.pendingMembershipRequests],
    ];
    if (financeAccess && !financeError) {
      rows.push(
        ["Ledger charges (pence)", financeTotals.chargesPence],
        ["Ledger payments (pence)", financeTotals.paymentsPence],
        ["Ledger refunds (pence)", financeTotals.refundsPence],
        ["Ledger fines (pence)", financeTotals.finesPence],
        ["Outstanding ledger balance (pence)", financeTotals.outstandingPence],
      );
    }
    rows.push([], ["Location", "Seasons", "Approved teams", "Squad memberships", "Fixtures", "Completed fixtures", "Published results", "Result coverage (%)", "Goals", "Goals per result"]);
    for (const location of locationComparisons) {
      rows.push([
        location.locationName, location.seasons, location.approvedTeams, location.squadMemberships,
        location.fixtures, location.completedFixtures, location.publishedResults,
        location.resultsCoveragePercent ?? "", location.goals, location.goalsPerResult ?? "",
      ]);
    }
    if (growthRows.length > 0) {
      rows.push(
        [],
        ["Daily user growth", "Account signups", "Player registrations", "Team applications", "Team approvals"],
      );
      for (const row of growthRows) {
        rows.push([
          row.bucket_date,
          row.account_signups === null ? "" : Number(row.account_signups),
          Number(row.player_registrations),
          Number(row.team_applications),
          Number(row.team_approvals),
        ]);
      }
    }
    if (productAnalytics?.weeklyActivity.length) {
      rows.push([], ["Weekly engagement", "Active users", "Meaningful content views"]);
      for (const row of productAnalytics.weeklyActivity) {
        rows.push([row.week_start, row.active_users, row.value_actions]);
      }
    }
    if (productAnalytics?.features.length) {
      rows.push([], ["Feature performance", "Unique users", "Meaningful content views"]);
      for (const row of productAnalytics.features) {
        rows.push([row.feature, row.unique_users, row.value_actions]);
      }
    }
    if (productAnalytics?.retention.length) {
      rows.push([], ["Weekly retention", "Weeks since first observed", "Cohort users", "Retained users", "Retention rate (%)"]);
      for (const row of productAnalytics.retention) {
        rows.push([row.cohort_week, row.weeks_since_start, row.cohort_users, row.retained_users, row.retention_rate]);
      }
    }
    const csv = rows.map((row) => row.map((cell) => csvCell(cell)).join(",")).join("\r\n");
    const blob = new Blob(["\uFEFF", csv], { type: "text/csv;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = `open-play-analytics-${new Date().toISOString().slice(0, 10)}.csv`;
    anchor.click();
    URL.revokeObjectURL(url);
  }

  const tabs: Array<{ id: Tab; label: string }> = [
    { id: "overview", label: "Overview" },
    { id: "usage", label: "App usage" },
    { id: "growth", label: "User growth" },
    { id: "registrations", label: "Registration" },
    { id: "engagement", label: "Engagement" },
    { id: "features", label: "Feature performance" },
    { id: "locations", label: "Locations" },
    { id: "competition", label: "Competition" },
    { id: "business", label: "Business" },
    { id: "reports", label: "Reports & exports" },
  ];

  if (authStatus !== "authenticated" || loading && !contextReady) {
    return <main className="notice-page analytics-page"><section className="notice-panel analytics-panel"><p>{authStatus === "loading" ? "Checking your account…" : authStatus === "unauthenticated" ? "Redirecting to sign in…" : "Loading analytics workspace…"}</p></section></main>;
  }

  if (error && !dashboard) {
    return <main className="notice-page analytics-page"><section className="notice-panel analytics-panel"><Link className="notice-brand" to="/admin">OPEN PLAY ADMIN</Link><p className="eyebrow eyebrow-dark">ADMIN ANALYTICS</p><h1>Analytics<br/><em>unavailable.</em></h1><p className="form-error" role="alert">{error}</p><Link className="auth-switch" to="/admin">Back to Admin Dashboard</Link></section></main>;
  }

  return <main className="notice-page analytics-page"><section className="notice-panel analytics-panel">
    <Link className="notice-brand" to="/admin"><img className="open-play-logo" src="/open-play-logo.png" alt="Open Play"/></Link>
    <p className="eyebrow eyebrow-dark">ADMINISTRATION · REPORTING</p>
    <h1>Numbers<br/><em>that matter.</em></h1>
    <p className="analytics-intro">Operational reporting is drawn from permission-checked Open Play records. No player names, contact details, dates of birth or private messages are included in these summaries.</p>
    {error && <p className="form-error" role="alert">{error}</p>}
    {notice && <p className="form-success" role="status">{notice}</p>}
    <section className="analytics-context" aria-label="Reporting context">
      <div className="analytics-context-grid">
        <label>Location<select value={locationId} disabled={contextSaving} onChange={(event) => void saveContext(event.target.value, "", "")}>
          {isGlobalAdmin && <option value="">All accessible locations</option>}
          {setup.locations.map((location) => <option key={location.id} value={location.id}>{location.name} · {location.town}</option>)}
        </select></label>
        <label>League<select value={leagueId} disabled={contextSaving || (!locationId && !isGlobalAdmin)} onChange={(event) => void saveContext(locationId, event.target.value, "")}>
          <option value="">All leagues</option>{setup.leagues.filter((league) => !locationId || league.location_id === locationId).map((league) => <option key={league.id} value={league.id}>{league.name}</option>)}
        </select></label>
        <label>Season<select value={seasonId} disabled={contextSaving} onChange={(event) => void saveContext(locationId, leagueId, event.target.value)}>
          <option value="">All seasons</option>{setup.seasons.filter((season) => (!locationId || season.location_id === locationId) && (!leagueId || season.league_id === leagueId)).map((season) => <option key={season.id} value={season.id}>{season.name} · {season.status}</option>)}
        </select></label>
        <label>Activity date from<input type="date" value={fromDate} max={toDate || undefined} disabled={contextSaving} onChange={(event) => setFromDate(event.target.value)} /></label>
        <label>Activity date to<input type="date" value={toDate} disabled={contextSaving} min={fromDate || undefined} onChange={(event) => setToDate(event.target.value)} /></label>
      </div>
      <p className="form-note">The selected location, league and season define this report. Activity dates filter fixture/result and daily growth counts; team and queue figures remain current snapshots, and finance figures remain ledger totals for the selected season.</p>
    </section>
    <div className="analytics-toolbar"><span>{refreshedAt ? `Last refreshed ${refreshedAt.toLocaleString("en-GB", { dateStyle: "medium", timeStyle: "short" })}` : "Waiting for data"}</span><button type="button" className="admin-inline-action" onClick={() => void loadContextData()} disabled={loading || contextSaving}>{loading ? "REFRESHING…" : "REFRESH"}</button></div>
    <nav className="analytics-tab-list" role="tablist" aria-label="Analytics reports">
      {tabs.map((item) => <button key={item.id} type="button" role="tab" aria-selected={tab === item.id} aria-controls={`analytics-tab-${item.id}`} onClick={() => setTab(item.id)}>{item.label}</button>)}
    </nav>
    <section id={`analytics-tab-${tab}`} role="tabpanel" className="analytics-tab-content">
      {!overview ? <p className="form-note">Analytics data is not available for this context.</p> : tab === "overview" ? <>
        <div className="analytics-stat-grid">
          <article><span>Approved teams</span><strong>{overview.approvedTeams}</strong></article>
          <article><span>Squad memberships</span><strong>{overview.squadMemberships}</strong></article>
          <article><span>Fixtures</span><strong>{overview.fixtures}</strong></article>
          <article><span>Published results</span><strong>{overview.publishedResults}</strong></article>
          <article><span>Goals</span><strong>{overview.goals}</strong></article>
          <article><span>Open seasons</span><strong>{overview.openSeasons}</strong></article>
        </div>
        <div className="analytics-section"><h2>Needs attention</h2><div className="analytics-stat-grid analytics-stat-grid-compact">
          <article><span>Player reviews</span><strong>{overview.pendingPlayerReviews}</strong></article>
          <article><span>Team applications</span><strong>{overview.pendingTeamApplications}</strong></article>
          <article><span>Join requests</span><strong>{overview.pendingMembershipRequests}</strong></article>
        </div><Link className="admin-inline-action" to="/admin">OPEN ADMIN QUEUES ↗</Link></div>
        <div className="analytics-section"><h2>Verified competition activity</h2>
          <div className="analytics-bars">
            {[["Fixtures", overview.fixtures], ["Published results", overview.publishedResults], ["Goals", overview.goals]].map(([label, value]) => {
              const numeric = Number(value);
              const max = Math.max(overview.fixtures, overview.publishedResults, overview.goals, 1);
              return <div className="analytics-bar-row" key={String(label)}><span>{label}</span><div className="analytics-bar-track"><span style={{ width: `${Math.max(0, Math.min(100, numeric / max * 100))}%` }}/></div><strong>{numeric}</strong></div>;
            })}
          </div>
          <p className="form-note">Only fixtures marked completed with a published score contribute to result and goal totals.</p>
        </div>
      </> : tab === "usage" ? <div className="analytics-state"><h2>App usage</h2><p>Page views, sessions, device/browser distribution and navigation trends will appear after consented analytics ingestion is approved and enabled.</p><p className="analytics-state-label">No user-activity figures are being fabricated or inferred from page loads.</p></div>  : tab === "growth" ? <>
        <h2>User growth · daily activity</h2>
        <p className="form-note">Daily totals use Supabase account profiles, player registrations and season-team application records. In scoped views, player registrations include only players associated with the selected competition through membership history. Account signups appear only in the global all-locations view.</p>
        {growthError ? <p className="form-error" role="alert">{growthError}</p> : <>
          <div className="analytics-stat-grid">
            <article><span>Account signups</span><strong>{growthTotals.accountSignups === null ? "—" : growthTotals.accountSignups}</strong></article>
            <article><span>Player registrations</span><strong>{growthTotals.playerRegistrations}</strong></article>
            <article><span>Team applications</span><strong>{growthTotals.teamApplications}</strong></article>
            <article><span>Team approvals</span><strong>{growthTotals.teamApprovals}</strong></article>
          </div>
          {growthTotals.accountSignups === null && <p className="analytics-state-label">Platform-wide account signup totals are hidden in location, league and season views.</p>}
          {growthRows.length === 0 ? <p className="form-note">No growth data is available for this date range.</p> : <>
            <div className="analytics-table-wrap"><table><thead><tr><th>Date</th><th>Account signups</th><th>Player registrations</th><th>Team applications</th><th>Team approvals</th></tr></thead><tbody>
              {growthRows.map((row) => <tr key={row.bucket_date}>
                <td>{new Date(row.bucket_date + "T12:00:00Z").toLocaleDateString("en-GB", { timeZone: "Europe/London", dateStyle: "medium" })}</td>
                <td>{row.account_signups === null ? "—" : Number(row.account_signups)}</td>
                <td>{Number(row.player_registrations)}</td>
                <td>{Number(row.team_applications)}</td>
                <td>{Number(row.team_approvals)}</td>
              </tr>)}
            </tbody></table></div>
            {growthTotals.accountSignups === 0 && growthTotals.playerRegistrations === 0 && growthTotals.teamApplications === 0 && growthTotals.teamApprovals === 0
              ? <p className="form-note">No account or registration activity was recorded in the selected date range.</p>
              : null}
          </>}
        </>}
      </> : tab === "registrations" ? <>
        <h2>Registration &amp; conversion · created-date cohorts</h2>
        {registrationError ? <p className="form-error" role="alert">{registrationError}</p> : <>
          <p className="form-note">Records are grouped by their original creation date and classified by their current outcome. Pending records remain unresolved and are excluded from resolved conversion-rate denominators.</p>
          <div className="analytics-stat-grid">
            <article><span>Player registrations approved</span><strong>{registrationTotals.playerRegistered === null ? "—" : registrationTotals.playerRegistered}</strong></article>
            <article><span>Player reviews pending</span><strong>{registrationTotals.playerPending === null ? "—" : registrationTotals.playerPending}</strong></article>
            <article><span>Player registrations rejected</span><strong>{registrationTotals.playerRejected === null ? "—" : registrationTotals.playerRejected}</strong></article>
            <article><span>Team applications</span><strong>{registrationTotals.teamApplications}</strong></article>
            <article><span>Team approval · resolved</span><strong>{teamApprovalRate === null ? "—" : teamApprovalRate.toFixed(1) + "%"}</strong></article>
            <article><span>Membership acceptance · resolved</span><strong>{membershipAcceptanceRate === null ? "—" : membershipAcceptanceRate.toFixed(1) + "%"}</strong></article>
          </div>
          {registrationTotals.playerRegistered === null && <p className="analytics-state-label">Player registration review totals are restricted to the global administrator's all-location view. They are not inferred from team membership records.</p>}
          <div className="analytics-section"><h3>Team application outcomes</h3>
            <p className="form-note">Approval rate = approved / (approved + rejected). Pending applications are excluded from the resolved denominator.</p>
            <div className="analytics-stat-grid analytics-stat-grid-compact">
              <article><span>Approved</span><strong>{registrationTotals.teamApproved}</strong></article>
              <article><span>Rejected</span><strong>{registrationTotals.teamRejected}</strong></article>
              <article><span>Pending</span><strong>{registrationTotals.teamPending}</strong></article>
            </div>
          </div>
          <div className="analytics-section"><h3>Club membership outcomes</h3>
            <p className="form-note">Acceptance rate = accepted / (accepted + rejected). Previously accepted memberships remain accepted in this cohort if the player later leaves; pending requests are excluded.</p>
            <div className="analytics-stat-grid analytics-stat-grid-compact">
              <article><span>Accepted</span><strong>{registrationTotals.membershipAccepted}</strong></article>
              <article><span>Rejected</span><strong>{registrationTotals.membershipRejected}</strong></article>
              <article><span>Pending</span><strong>{registrationTotals.membershipPending}</strong></article>
            </div>
          </div>
          {registrationRows.length === 0 ? <p className="form-note">No registration activity was recorded in the selected date range.</p> : <div className="analytics-table-wrap"><table><thead><tr><th>Created</th><th>Team applications</th><th>Approved</th><th>Rejected</th><th>Pending</th><th>Join requests</th><th>Accepted</th><th>Rejected</th><th>Pending</th></tr></thead><tbody>
            {registrationRows.map((row) => <tr key={row.bucket_date}><td>{new Date(row.bucket_date + "T12:00:00Z").toLocaleDateString("en-GB", { timeZone: "Europe/London", dateStyle: "medium" })}</td><td>{Number(row.team_applications)}</td><td>{Number(row.team_approved)}</td><td>{Number(row.team_rejected)}</td><td>{Number(row.team_pending)}</td><td>{Number(row.membership_requests)}</td><td>{Number(row.membership_accepted)}</td><td>{Number(row.membership_rejected)}</td><td>{Number(row.membership_pending)}</td></tr>)}
          </tbody></table></div>}
        </>}
      </> : tab === "engagement" ? <>
        <h2>Engagement &amp; retention</h2>
        <p className="form-note">Meaningful activity is a consented player viewing published fixtures, results, league standings, player statistics or the approved team directory. Admin and finance activity is excluded. Retention cohorts use first observed meaningful activity in this reporting window. Only full Monday–Sunday weeks wholly contained in the selected date range are included; partial first/last weeks and the current incomplete week are excluded.</p>
        {productAnalyticsLoading ? <p className="form-note">Loading consented engagement data…</p> : productAnalyticsError ? <div className="analytics-state"><h3>Product analytics unavailable</h3><p>{productAnalyticsError}</p><p className="analytics-state-label">The PostHog query credential is held server-side. No user-level event records are returned to this page.</p></div> : !productAnalytics || productAnalytics.status === "no_data" ? <div className="analytics-state"><h3>No consented engagement data yet</h3><p>There are no meaningful content-view events for the selected competition and reporting period. Figures will appear as players who have opted into optional analytics view available competition content.</p><p className="analytics-state-label">An app open or a generic page render is not counted as engagement.</p></div> : <>
          <div className="analytics-stat-grid">
            <article><span>Latest completed week · active players</span><strong>{productAnalytics.weeklyActivity.length ? productAnalytics.weeklyActivity.at(-1)!.active_users : "—"}</strong></article>
            <article><span>Meaningful content views</span><strong>{productAnalytics.weeklyActivity.reduce((sum, row) => sum + row.value_actions, 0)}</strong></article>
            <article><span>Retention cohorts</span><strong>{new Set(productAnalytics.retention.map((row) => row.cohort_week)).size}</strong></article>
          </div>
          <div className="analytics-section"><h3>Weekly active players</h3>
            {productAnalytics.weeklyActivity.length === 0 ? <p className="form-note">No completed week has recorded meaningful activity.</p> : <div className="analytics-table-wrap"><table><thead><tr><th>Week commencing</th><th>Active players</th><th>Meaningful views</th></tr></thead><tbody>{productAnalytics.weeklyActivity.map((row) => <tr key={row.week_start}><td>{row.week_start}</td><td>{row.active_users}</td><td>{row.value_actions}</td></tr>)}</tbody></table></div>}
          </div>
          <div className="analytics-section"><h3>Weekly retention cohorts</h3>
            <p className="form-note">Each cohort is players whose first observed meaningful action fell in that week. Percentages show how many returned in each subsequent week.</p>
            {productAnalytics.retention.length === 0 ? <p className="form-note">There is not yet enough completed weekly activity to calculate retention.</p> : <div className="analytics-table-wrap"><table><thead><tr><th>Cohort week</th><th>Weeks later</th><th>Cohort size</th><th>Returned</th><th>Retention</th></tr></thead><tbody>{productAnalytics.retention.map((row) => <tr key={row.cohort_week + "-" + row.weeks_since_start}><td>{row.cohort_week}</td><td>{row.weeks_since_start}</td><td>{row.cohort_users}</td><td>{row.retained_users}</td><td>{row.retention_rate.toFixed(1)}%</td></tr>)}</tbody></table></div>}
          </div>
          <p className="form-note">Reporting period: {productAnalytics.range.fromDate} to {productAnalytics.range.toDate}. Source: consented PostHog events; results are aggregate-only.</p>
        </>}
      </> : tab === "features" ? <>
        <h2>Feature performance</h2>
        <p className="form-note">Counts are based on meaningful content views, not raw page loads. Only the current allowlisted competition features are shown, and only for seasons visible to the signed-in administrator.</p>
        {productAnalyticsLoading ? <p className="form-note">Loading feature performance…</p> : productAnalyticsError ? <p className="form-error" role="alert">{productAnalyticsError}</p> : !productAnalytics || productAnalytics.status === "no_data" ? <div className="analytics-state"><h3>No feature activity yet</h3><p>Feature usage will appear once a player who has opted into optional analytics views fixtures, results, league standings, player statistics or the approved team directory.</p><p className="analytics-state-label">No missing event coverage is reported as zero usage.</p></div> : productAnalytics.features.length === 0 ? <p className="form-note">No feature activity was recorded in this reporting window.</p> : <>
          <div className="analytics-stat-grid">
            <article><span>Features used</span><strong>{productAnalytics.features.length}</strong></article>
            <article><span>Unique player-feature pairs</span><strong>{productAnalytics.features.reduce((sum, row) => sum + row.unique_users, 0)}</strong></article>
            <article><span>Meaningful views</span><strong>{productAnalytics.features.reduce((sum, row) => sum + row.value_actions, 0)}</strong></article>
          </div>
          <div className="analytics-table-wrap"><table><thead><tr><th>Feature</th><th>Unique players</th><th>Meaningful views</th></tr></thead><tbody>{productAnalytics.features.map((row) => <tr key={row.feature}><td>{row.feature.replaceAll("_", " ")}</td><td>{row.unique_users}</td><td>{row.value_actions}</td></tr>)}</tbody></table></div>
          <p className="form-note">Reporting period: {productAnalytics.range.fromDate} to {productAnalytics.range.toDate}. A player may appear in more than one feature row.</p>
        </>}
      </> : tab === "competition" ? <>
        {!seasonId ? <p className="form-note">Choose a season above to load its verified competition statistics.</p> : seasonError ? <p className="form-error" role="alert">{seasonError}</p> : !seasonStats ? <p className="form-note">Loading season statistics…</p> : <>
          <h2>{seasonStats.season.name} · {seasonStats.season.status}</h2>
          <div className="analytics-stat-grid">
            <article><span>Fixtures</span><strong>{seasonStats.summary.fixtures}</strong></article>
            <article><span>Published results</span><strong>{seasonStats.summary.published_results}</strong></article>
            <article><span>Goals</span><strong>{seasonStats.summary.goals}</strong></article>
            <article><span>Goals / match</span><strong>{seasonStats.summary.goals_per_match}</strong></article>
            <article><span>Players with appearances</span><strong>{seasonStats.players.length}</strong></article>
            <article><span>Team clean sheets</span><strong>{seasonStats.summary.team_clean_sheets}</strong></article>
          </div>
          <div className="analytics-table-wrap"><table><thead><tr><th>Position</th><th>Team</th><th>Played</th><th>Won</th><th>Drawn</th><th>Lost</th><th>Goals</th><th>Points</th></tr></thead><tbody>{seasonStats.teams.map((team) => <tr key={team.team_id}><td>{team.position}</td><td>{team.name}</td><td>{team.played}</td><td>{team.wins}</td><td>{team.draws}</td><td>{team.losses}</td><td>{team.goals_for}–{team.goals_against}</td><td>{team.points}</td></tr>)}</tbody></table></div>
          <p className="form-note">Player identities are counted for this summary but not listed here. The player leaderboard remains available in the season statistics section of the main Admin Dashboard.</p>
        </>}
      </> : tab === "locations" ? <>
        <h2>Location comparison</h2>
        <div className="analytics-table-wrap"><table><thead><tr><th>Location</th><th>Seasons</th><th>Teams</th><th>Squad memberships</th><th>Fixtures</th><th>Completed</th><th>Results</th><th>Result coverage</th><th>Goals</th><th>Goals / result</th></tr></thead><tbody>{locationComparisons.map((row) => <tr key={row.locationId}><td>{row.locationName}</td><td>{row.seasons}</td><td>{row.approvedTeams}</td><td>{row.squadMemberships}</td><td>{row.fixtures}</td><td>{row.completedFixtures}</td><td>{row.publishedResults}</td><td>{row.resultsCoveragePercent === null ? "—" : row.resultsCoveragePercent.toFixed(1) + "%"}</td><td>{row.goals}</td><td>{row.goalsPerResult === null ? "—" : row.goalsPerResult.toFixed(2)}</td></tr>)}</tbody></table></div>
        <p className="form-note">Location rows are limited to the locations returned by your administrator-scoped setup RPC. Squad memberships count current approved-team memberships, not unique people across multiple seasons.</p>
      </> : tab === "business" ? <>
        {!financeAccess ? <div className="analytics-state"><h2>Finance reporting restricted</h2><p>{financeError || "This section is available to authorised finance administrators."}</p><Link className="admin-inline-action" to="/finance">OPEN FINANCE LEDGER ↗</Link></div> : financeError ? <p className="form-error" role="alert">{financeError}</p> : <>
          <h2>Business performance · verified ledger</h2>
          <div className="analytics-stat-grid">
            <article><span>Charges</span><strong>{money(financeTotals.chargesPence)}</strong></article>
            <article><span>Payments</span><strong>{money(financeTotals.paymentsPence)}</strong></article>
            <article><span>Refunds</span><strong>{money(financeTotals.refundsPence)}</strong></article>
            <article><span>Fines</span><strong>{money(financeTotals.finesPence)}</strong></article>
            <article><span>Outstanding</span><strong>{money(financeTotals.outstandingPence)}</strong></article>
            <article><span>Finance seasons</span><strong>{new Set(financeOptions.map((option) => option.season_id)).size}</strong></article>
          </div>
          <p className="form-note">This is a verified ledger summary, not a profit statement. It excludes operating costs, sponsorship records and unrecorded costs; Stripe transfers or referee payouts are not treated as revenue.</p>
        </>}
      </> : <>
        <h2>Reports &amp; exports</h2>
        <p>Export the current permission-scoped aggregate snapshot. Player names, contact details, dates of birth, message content and payment references are excluded.</p>
        <div className="analytics-report-actions"><button type="button" className="button" onClick={exportCsv} disabled={!overview || dateRangeInvalid}>EXPORT CSV</button><button type="button" className="admin-inline-action" onClick={() => window.print()} disabled={!overview || dateRangeInvalid}>PRINT / SAVE PDF</button></div>
        <p className="form-note">CSV values are in integer pence for financial totals. Use the Finance Ledger for itemised financial records.</p>
      </>}
    </section>
    <section className="analytics-print-report" data-print-report aria-label="Printable analytics summary">
      <h2>Open Play reporting summary</h2>
      <p>Reporting context: {locationId ? setup.locations.find((item) => item.id === locationId)?.name ?? "Selected location" : "All accessible locations"} · {leagueId ? setup.leagues.find((item) => item.id === leagueId)?.name ?? "Selected league" : "All accessible leagues"} · {seasonId ? setup.seasons.find((item) => item.id === seasonId)?.name ?? "Selected season" : "All accessible seasons"}</p>
      {overview && <div className="analytics-print-metrics">
        <p>Approved teams: {overview.approvedTeams} · Squad memberships: {overview.squadMemberships}</p>
        <p>Fixtures: {overview.fixtures} · Published results: {overview.publishedResults} · Goals: {overview.goals}</p>
        <p>Open seasons: {overview.openSeasons} · Pending player reviews: {overview.pendingPlayerReviews} · Pending team applications: {overview.pendingTeamApplications} · Pending join requests: {overview.pendingMembershipRequests}</p>
      </div>}
      <h3>Location comparison</h3>
      <div className="analytics-table-wrap"><table><thead><tr><th>Location</th><th>Seasons</th><th>Teams</th><th>Squad memberships</th><th>Fixtures</th><th>Completed</th><th>Results</th><th>Result coverage</th><th>Goals</th><th>Goals / result</th></tr></thead><tbody>{locationComparisons.map((row) => <tr key={row.locationId}><td>{row.locationName}</td><td>{row.seasons}</td><td>{row.approvedTeams}</td><td>{row.squadMemberships}</td><td>{row.fixtures}</td><td>{row.completedFixtures}</td><td>{row.publishedResults}</td><td>{row.resultsCoveragePercent === null ? "—" : row.resultsCoveragePercent.toFixed(1) + "%"}</td><td>{row.goals}</td><td>{row.goalsPerResult === null ? "—" : row.goalsPerResult.toFixed(2)}</td></tr>)}</tbody></table></div>
      <h3>Daily user growth</h3>
      <div className="analytics-table-wrap"><table><thead><tr><th>Date</th><th>Account signups</th><th>Player registrations</th><th>Team applications</th><th>Team approvals</th></tr></thead><tbody>{growthRows.map((row) => <tr key={row.bucket_date}><td>{row.bucket_date}</td><td>{row.account_signups === null ? "—" : Number(row.account_signups)}</td><td>{Number(row.player_registrations)}</td><td>{Number(row.team_applications)}</td><td>{Number(row.team_approvals)}</td></tr>)}</tbody></table></div>
      {productAnalytics && productAnalytics.weeklyActivity.length > 0 && <>
        <h3>Weekly engagement</h3>
        <div className="analytics-table-wrap"><table><thead><tr><th>Week commencing</th><th>Active players</th><th>Meaningful views</th></tr></thead><tbody>{productAnalytics.weeklyActivity.map((row) => <tr key={row.week_start}><td>{row.week_start}</td><td>{row.active_users}</td><td>{row.value_actions}</td></tr>)}</tbody></table></div>
      </>}
      {productAnalytics && productAnalytics.features.length > 0 && <>
        <h3>Feature performance</h3>
        <div className="analytics-table-wrap"><table><thead><tr><th>Feature</th><th>Unique players</th><th>Meaningful views</th></tr></thead><tbody>{productAnalytics.features.map((row) => <tr key={row.feature}><td>{row.feature}</td><td>{row.unique_users}</td><td>{row.value_actions}</td></tr>)}</tbody></table></div>
      </>}
      {productAnalytics && productAnalytics.retention.length > 0 && <>
        <h3>Weekly retention</h3>
        <div className="analytics-table-wrap"><table><thead><tr><th>Cohort week</th><th>Weeks later</th><th>Cohort size</th><th>Returned</th><th>Retention</th></tr></thead><tbody>{productAnalytics.retention.map((row) => <tr key={row.cohort_week + "-" + row.weeks_since_start}><td>{row.cohort_week}</td><td>{row.weeks_since_start}</td><td>{row.cohort_users}</td><td>{row.retained_users}</td><td>{row.retention_rate.toFixed(1)}%</td></tr>)}</tbody></table></div>
      </>}
      {financeAccess && !financeError && <p>Ledger charges: {money(financeTotals.chargesPence)} · Payments: {money(financeTotals.paymentsPence)} · Refunds: {money(financeTotals.refundsPence)} · Fines: {money(financeTotals.finesPence)} · Outstanding: {money(financeTotals.outstandingPence)}</p>}
      <p>Generated {new Date().toLocaleString("en-GB")}. Aggregate operational data only; no player personal details included.</p>
    </section>
    <p className="analytics-footnote">Reporting source: permission-checked Supabase RPCs for operational and financial truth; consented PostHog aggregates for product engagement and feature performance. Fixture reporting window: {fromDate || toDate ? `${fromDate || "Any date"} to ${toDate || "Any date"}` : "all dates"} within the selected season or accessible context. Team and queue figures are current snapshots; finance figures are ledger totals for the selected season. PostHog reporting requires the server-side project query credential and sufficient consented activity.</p>
    <Link className="auth-switch" to="/admin">← BACK TO ADMIN DASHBOARD</Link>
  </section></main>;
}
