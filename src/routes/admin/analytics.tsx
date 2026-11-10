import { useCallback, useEffect, useMemo, useState } from "react";
import { Link, createFileRoute, useNavigate } from "@tanstack/react-router";
import { useRequiredSession } from "../../lib/auth/use-required-session";
import { aggregateFinanceTotals, buildAnalyticsOverview, buildLocationComparisons, buildSeasonTrends, type AnalyticsDashboardCounts, type AnalyticsFilters, type AnalyticsSetup, type FinanceSummaryRow, type SeasonStatsSnapshot } from "../../lib/analytics/overview";
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
type Tab = "overview" | "usage" | "growth" | "registrations" | "engagement" | "features" | "locations" | "competition" | "business" | "reports";

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
  const [leagueId, setLeagueId] = useState("");
  const [seasonId, setSeasonId] = useState("");
  const [contextSaving, setContextSaving] = useState(false);
  const [setup, setSetup] = useState<AnalyticsSetup>({ locations: [], leagues: [], seasons: [], season_teams: [], fixtures: [] });
  const [dashboard, setDashboard] = useState<Dashboard | null>(null);
  const [fixtures, setFixtures] = useState<Fixture[]>([]);
  const [seasonStats, setSeasonStats] = useState<SeasonStats | null>(null);
  const [seasonError, setSeasonError] = useState("");
  const [seasonTrendSnapshots, setSeasonTrendSnapshots] = useState<SeasonStatsSnapshot[]>([]);
  const [seasonTrendError, setSeasonTrendError] = useState("");
  const [financeAccess, setFinanceAccess] = useState(false);
  const [financeError, setFinanceError] = useState("");
  const [financeOptions, setFinanceOptions] = useState<FinanceOption[]>([]);
  const [financeRows, setFinanceRows] = useState<FinanceSummaryRow[]>([]);
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
      let nextLeague = preference.league_id ?? "";
      let nextSeason = preference.season_id ?? "";
      const assignedLocationIsValid = setupData.locations.some((location) => location.id === nextLocation);
      if (!preference.is_global_admin && (!nextLocation || !assignedLocationIsValid)) {
        nextLocation = setupData.locations[0]?.id ?? "";
        nextLeague = "";
        nextSeason = "";
        if (!nextLocation) {
          setError("No administrator locations are currently assigned to this account.");
          setLoading(false);
          return;
        }
        const { error: saveError } = await getSupabaseClient().rpc("save_admin_context_preference", {
          p_location_id: nextLocation,
          p_league_id: undefined,
          p_season_id: undefined,
        });
        if (!alive) return;
        if (saveError) setError(saveError.message);
      }
      if (nextLeague && !setupData.leagues.some((league) => league.id === nextLeague && (!nextLocation || league.location_id === nextLocation))) nextLeague = "";
      if (nextSeason && !setupData.seasons.some((season) => season.id === nextSeason && (!nextLeague || season.league_id === nextLeague))) nextSeason = "";
      setIsGlobalAdmin(preference.is_global_admin);
      setSetup(setupData);
      setLocationId(nextLocation);
      setLeagueId(nextLeague);
      setSeasonId(nextSeason);
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
      const [dashboardResult, fixtureResult] = await Promise.all([
        getSupabaseClient().rpc("get_admin_dashboard_contextual", args),
        getSupabaseClient().rpc("get_admin_contextual_fixtures", args),
      ]);
      if (dashboardResult.error || fixtureResult.error) {
        throw new Error(dashboardResult.error?.message ?? fixtureResult.error?.message ?? "Unable to load analytics data.");
      }
      setDashboard(dashboardResult.data as Dashboard);
      setFixtures((fixtureResult.data ?? []) as Fixture[]);

      const locationByLeague = new Map(setup.leagues.map((league) => [league.id, league.location_id]));
      const trendSeasons = setup.seasons
        .filter((season) => {
          const seasonLocationId = season.location_id ?? locationByLeague.get(season.league_id);
          return (!locationId || seasonLocationId === locationId) && (!leagueId || season.league_id === leagueId);
        })
        .sort((a, b) => (a.starts_on ?? "").localeCompare(b.starts_on ?? ""))
        .slice(-6);
      const requestedSeasonIds = [...new Set([
        ...trendSeasons.map((season) => season.id),
        ...(seasonId ? [seasonId] : []),
      ])];
      const trendResults = await Promise.all(requestedSeasonIds.map(async (requestedSeasonId) => {
        const { data, error: statsRpcError } = await getSupabaseClient().rpc("get_admin_season_statistics", { p_season_id: requestedSeasonId });
        return { seasonId: requestedSeasonId, data: data as SeasonStats | null, error: statsRpcError };
      }));
      const successfulTrends: SeasonStatsSnapshot[] = trendResults
        .filter((result): result is { seasonId: string; data: SeasonStats; error: null } => !result.error && Boolean(result.data))
        .map((result) => ({ seasonId: result.seasonId, stats: result.data }));
      setSeasonTrendSnapshots(successfulTrends);
      const failedTrendCount = trendResults.filter((result) => result.error).length;
      setSeasonTrendError(failedTrendCount > 0 ? "Some season trend data could not be loaded; the comparison may be partial." : "");
      const selectedSeasonResult = trendResults.find((result) => result.seasonId === seasonId);
      if (seasonId && selectedSeasonResult?.data && !selectedSeasonResult.error) {
        setSeasonStats(selectedSeasonResult.data);
        setSeasonError("");
      } else if (seasonId) {
        setSeasonStats(null);
        setSeasonError(selectedSeasonResult?.error?.message ?? "Selected season statistics are unavailable.");
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
  }, [authStatus, contextReady, leagueId, locationId, seasonId, setup]);

  useEffect(() => {
    if (contextReady) void loadContextData();
  }, [contextReady, loadContextData]);

  const filters: AnalyticsFilters = { locationId, leagueId, seasonId };
  const overview = useMemo(() => dashboard
    ? buildAnalyticsOverview(setup, dashboard.counts, fixtures, filters)
    : null, [dashboard, fixtures, leagueId, locationId, seasonId, setup]);
  const locationComparisons = useMemo(
    () => buildLocationComparisons(setup, { leagueId, seasonId }),
    [leagueId, seasonId, setup],
  );
  const financeTotals = useMemo(() => aggregateFinanceTotals(financeRows), [financeRows]);
  const seasonTrends = useMemo(
    () => buildSeasonTrends(setup.seasons.filter((season) => {
      const seasonLocationId = season.location_id ?? setup.leagues.find((league) => league.id === season.league_id)?.location_id;
      return (!locationId || seasonLocationId === locationId) && (!leagueId || season.league_id === leagueId);
    }).slice(-6).concat(seasonId && !setup.seasons.slice(-6).some((season) => season.id === seasonId) ? setup.seasons.filter((season) => season.id === seasonId) : []), seasonTrendSnapshots),
    [leagueId, locationId, seasonId, seasonTrendSnapshots, setup],
  );
  const latestTrend = seasonTrends[seasonTrends.length - 1] ?? null;


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
        ["Ledger credits (pence)", financeTotals.creditsPence],
        ["Ledger fines (pence)", financeTotals.finesPence],
        ["Outstanding ledger balance (pence)", financeTotals.outstandingPence],
      );
    }
    rows.push([], ["Location", "Seasons", "Approved teams", "Squad memberships", "Fixtures", "Published results", "Goals"]);
    for (const location of locationComparisons) {
      rows.push([location.locationName, location.seasons, location.approvedTeams, location.squadMemberships, location.fixtures, location.publishedResults, location.goals]);
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
          <option value="">All seasons</option>{setup.seasons.filter((season) => {
            const seasonLocationId = season.location_id ?? setup.leagues.find((league) => league.id === season.league_id)?.location_id;
            return (!locationId || seasonLocationId === locationId) && (!leagueId || season.league_id === leagueId);
          }).map((season) => <option key={season.id} value={season.id}>{season.name} · {season.status}</option>)}
        </select></label>
      </div>
      <p className="form-note">Location and league scope all sections. The season filter scopes season detail and finance; Growth and Engagement compare the latest six seasons in the selected location and league. Results are refreshed from permission-checked database records.</p>
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
      </> : tab === "usage" ? <div className="analytics-state"><h2>App usage</h2><p>Page views, sessions, device/browser distribution and navigation trends will appear after consented analytics ingestion is approved and enabled.</p><p className="analytics-state-label">No user-activity figures are being fabricated or inferred from page loads.</p></div> : tab === "growth" ? <>
        <h2>Competition participation growth</h2>
        {seasonTrendError && <p className="form-note" role="status">{seasonTrendError}</p>}
        {seasonTrends.length === 0 ? <p className="form-note">No season statistics are available for this location and league yet.</p> : <>
          <div className="analytics-table-wrap"><table><thead><tr><th>Season</th><th>Approved teams</th><th>Players with appearances</th><th>Fixtures</th><th>Results</th><th>Goals</th></tr></thead><tbody>{seasonTrends.map((trend) => <tr key={trend.seasonId}><td>{trend.seasonName}</td><td>{trend.approvedTeams}</td><td>{trend.playersWithAppearances}</td><td>{trend.fixtures}</td><td>{trend.publishedResults}</td><td>{trend.goals}</td></tr>)}</tbody></table></div>
          <div className="analytics-bars">{seasonTrends.map((trend) => {
            const max = Math.max(1, ...seasonTrends.map((item) => item.playersWithAppearances));
            return <div className="analytics-bar-row" key={trend.seasonId}><span>{trend.seasonName}</span><div className="analytics-bar-track"><span style={{ width: `${trend.playersWithAppearances / max * 100}%` }}/></div><strong>{trend.playersWithAppearances}</strong></div>;
          })}</div>
        </>}
        <p className="form-note">These are competition players with an approved appearance, not total account signups or app users. Only the latest six seasons in the selected location and league are included.</p>
      </> : tab === "registrations" ? <>
        <div className="analytics-stat-grid">
          <article><span>Pending player reviews</span><strong>{overview.pendingPlayerReviews}</strong></article>
          <article><span>Pending team applications</span><strong>{overview.pendingTeamApplications}</strong></article>
          <article><span>Pending join requests</span><strong>{overview.pendingMembershipRequests}</strong></article>
          <article><span>Approved teams</span><strong>{overview.approvedTeams}</strong></article>
          <article><span>Total team applications</span><strong>{overview.totalTeamApplications}</strong></article>
          <article><span>Rejected applications</span><strong>{overview.rejectedTeamApplications}</strong></article>
          <article><span>Withdrawn applications</span><strong>{overview.withdrawnTeamApplications}</strong></article>
          <article><span>Current team approval rate</span><strong>{overview.teamApprovalRate === null ? "—" : `${overview.teamApprovalRate.toFixed(1)}%`}</strong></article>
        </div>
        <p className="form-note">Team approval rate is calculated from the current status of team applications in this context. It is not a time-based signup conversion rate; player-account conversion and historical application outcomes need additional scoped history.</p>
      </> : tab === "engagement" ? <>
        <h2>Competition engagement &amp; return rate</h2>
        {seasonTrendError && <p className="form-note" role="status">{seasonTrendError}</p>}
        {seasonTrends.length === 0 ? <p className="form-note">No verified appearance history is available for this context yet.</p> : <>
          <div className="analytics-stat-grid">
            <article><span>Latest season players</span><strong>{latestTrend?.playersWithAppearances ?? 0}</strong></article>
            <article><span>Returning players</span><strong>{latestTrend?.returningPlayers ?? "—"}</strong></article>
            <article><span>Competition return rate</span><strong>{latestTrend?.returnRate === null || latestTrend?.returnRate === undefined ? "—" : `${latestTrend.returnRate.toFixed(1)}%`}</strong></article>
          </div>
          <div className="analytics-table-wrap"><table><thead><tr><th>Season</th><th>Players with appearances</th><th>Returning from previous season</th><th>Return rate</th><th>Published results</th></tr></thead><tbody>{seasonTrends.map((trend) => <tr key={trend.seasonId}><td>{trend.seasonName}</td><td>{trend.playersWithAppearances}</td><td>{trend.returningPlayers ?? "—"}</td><td>{trend.returnRate === null ? "—" : `${trend.returnRate.toFixed(1)}%`}</td><td>{trend.publishedResults}</td></tr>)}</tbody></table></div>
        </>}
        <p className="form-note">Return rate is the share of players with an appearance in the previous season who also appeared in the next season, using permanent competition identity. It measures competition participation, not app logins or daily active users.</p>
      </> : tab === "features" ? <div className="analytics-state"><h2>Feature performance</h2><p>Feature adoption and repeat interactions will be reported for Player Hub, Match Centre, teams, fixtures, results, registration, team management, gallery and announcements.</p><p className="analytics-state-label">Event coverage is being expanded; incomplete feature history is not displayed as zero.</p></div> : tab === "competition" ? <>
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
        <div className="analytics-table-wrap"><table><thead><tr><th>Location</th><th>Seasons</th><th>Teams</th><th>Squad memberships</th><th>Fixtures</th><th>Results</th><th>Goals</th></tr></thead><tbody>{locationComparisons.map((row) => <tr key={row.locationId}><td>{row.locationName}</td><td>{row.seasons}</td><td>{row.approvedTeams}</td><td>{row.squadMemberships}</td><td>{row.fixtures}</td><td>{row.publishedResults}</td><td>{row.goals}</td></tr>)}</tbody></table></div>
        <p className="form-note">Location rows are limited to the locations returned by your administrator-scoped setup RPC. Squad memberships count current approved-team memberships, not unique people across multiple seasons.</p>
      </> : tab === "business" ? <>
        {!financeAccess ? <div className="analytics-state"><h2>Finance reporting restricted</h2><p>{financeError || "This section is available to authorised finance administrators."}</p><Link className="admin-inline-action" to="/finance">OPEN FINANCE LEDGER ↗</Link></div> : financeError ? <p className="form-error" role="alert">{financeError}</p> : <>
          <h2>Business performance · verified ledger</h2>
          <div className="analytics-stat-grid">
            <article><span>Charges</span><strong>{money(financeTotals.chargesPence)}</strong></article>
            <article><span>Payments</span><strong>{money(financeTotals.paymentsPence)}</strong></article>
            <article><span>Refunds</span><strong>{money(financeTotals.refundsPence)}</strong></article>
            <article><span>Credits</span><strong>{money(financeTotals.creditsPence)}</strong></article>
            <article><span>Fines</span><strong>{money(financeTotals.finesPence)}</strong></article>
            <article><span>Outstanding</span><strong>{money(financeTotals.outstandingPence)}</strong></article>
            <article><span>Finance seasons</span><strong>{new Set(financeOptions.map((option) => option.season_id)).size}</strong></article>
          </div>
          <p className="form-note">This is a verified ledger summary, not a profit statement. It excludes operating costs, sponsorship records and unrecorded costs; Stripe transfers or referee payouts are not treated as revenue.</p>
        </>}
      </> : <>
        <h2>Reports &amp; exports</h2>
        <p>Export the current permission-scoped aggregate snapshot. Player names, contact details, dates of birth, message content and payment references are excluded.</p>
        <div className="analytics-report-actions"><button type="button" className="button" onClick={exportCsv} disabled={!overview}>EXPORT CSV</button><button type="button" className="admin-inline-action" onClick={() => window.print()}>PRINT / SAVE PDF</button></div>
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
      <div className="analytics-table-wrap"><table><thead><tr><th>Location</th><th>Seasons</th><th>Teams</th><th>Squad memberships</th><th>Fixtures</th><th>Results</th><th>Goals</th></tr></thead><tbody>{locationComparisons.map((row) => <tr key={row.locationId}><td>{row.locationName}</td><td>{row.seasons}</td><td>{row.approvedTeams}</td><td>{row.squadMemberships}</td><td>{row.fixtures}</td><td>{row.publishedResults}</td><td>{row.goals}</td></tr>)}</tbody></table></div>
      {financeAccess && !financeError && <p>Ledger charges: {money(financeTotals.chargesPence)} · Payments: {money(financeTotals.paymentsPence)} · Refunds: {money(financeTotals.refundsPence)} · Credits: {money(financeTotals.creditsPence)} · Fines: {money(financeTotals.finesPence)} · Outstanding: {money(financeTotals.outstandingPence)}</p>}
      <p>Generated {new Date().toLocaleString("en-GB")}. Aggregate operational data only; no player personal details included.</p>
    </section>
    <p className="analytics-footnote">Reporting source: permission-checked Supabase RPCs. Reporting window: selected season or all seasons in the accessible context. Date-range cohort reporting and consented app-usage metrics remain gated on the analytics release review.</p>
    <Link className="auth-switch" to="/admin">← BACK TO ADMIN DASHBOARD</Link>
  </section></main>;
}
