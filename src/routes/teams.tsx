import { useEffect, useMemo, useRef, useState } from "react";
import { Link, createFileRoute } from "@tanstack/react-router";
import { ChevronRight, Users } from "lucide-react";
import { RefereeBottomNavigation } from "../components/referee-bottom-navigation";
import { PlayerCompetitionSelector, usePlayerCompetitionContext } from "../lib/competition/player-context";
import { getSupabaseClient } from "../lib/supabase/client";
import { useOpenPlayAnalytics } from "../components/analytics-provider";
import { useRequiredSession } from "../lib/auth/use-required-session";
import { EmptyState, ErrorState, LoadingState, PageHeader, SearchField, SectionHeading, StatusBadge, TeamInitials } from "../components/ui/op-ui";
import { filterByName, teamSummary } from "../lib/competition/team-hub";
import type { MatchFixture, MatchResult } from "../lib/competition/player-matches";
import { DEFAULT_POINTS, type PointsRules } from "../lib/competition/standings";

type TeamRow = { id: string; name: string; season_id: string };
type ClubLeader = { competition_player_id: string; player_name: string; season_team_id: string; team_name: string; motm_awards: number; appearances: number };

export const Route = createFileRoute("/teams")({ component: TeamsPage });

/** Teams directory (reference IMG_0533). Public data only; squad counts for signed-in members. */
function TeamsPage() {
  const competition = usePlayerCompetitionContext();
  const capture = useOpenPlayAnalytics();
  const authStatus = useRequiredSession();
  const [teams, setTeams] = useState<TeamRow[]>([]);
  const [fixtures, setFixtures] = useState<MatchFixture[]>([]);
  const [results, setResults] = useState<MatchResult[]>([]);
  const [points, setPoints] = useState<PointsRules>(DEFAULT_POINTS);
  const [squadCounts, setSquadCounts] = useState<Map<string, number>>(new Map());
  const [query, setQuery] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [reload, setReload] = useState(0);
  const lastTrackedSeason = useRef("");
  const [leaders, setLeaders] = useState<ClubLeader[]>([]);
  const [leadersLoading, setLeadersLoading] = useState(false);
  const [leadersError, setLeadersError] = useState("");
  const seasonId = competition.selectedSeasonId;

  useEffect(() => {
    if (competition.loading) return;
    if (!seasonId) { setTeams([]); setFixtures([]); setResults([]); setLoading(false); return; }
    let alive = true;
    setLoading(true); setError("");
    void (async () => {
      const supabase = getSupabaseClient();
      const [teamRes, fixtureRes, seasonRes] = await Promise.all([
        supabase.from("season_teams").select("id,name,season_id").eq("season_id", seasonId).eq("registration_status", "approved").order("name"),
        supabase.from("fixtures").select("id,gameweek,scheduled_at,status,home_team_id,away_team_id,is_title_final").eq("season_id", seasonId),
        supabase.from("seasons").select("points_for_win,points_for_draw,points_for_loss").eq("id", seasonId).maybeSingle(),
      ]);
      if (!alive) return;
      if (teamRes.error || fixtureRes.error) {
        setError((teamRes.error ?? fixtureRes.error)!.message);
        capture("data_load_failed", { feature: "team_directory", error_code: "network_error", outcome: "failure" });
        setLoading(false);
        return;
      }
      const fixtureRows = (fixtureRes.data ?? []) as MatchFixture[];
      const completedIds = fixtureRows.filter((f) => f.status === "completed").map((f) => f.id);
      const resultRes = completedIds.length
        ? await supabase.from("fixture_results").select("fixture_id,home_score,away_score,confirmed_at").in("fixture_id", completedIds)
        : { data: [], error: null };
      if (!alive) return;
      if (resultRes.error) { setError(resultRes.error.message); setLoading(false); return; }
      const season = seasonRes.data;
      setPoints(season ? { win: season.points_for_win, draw: season.points_for_draw, loss: season.points_for_loss } : DEFAULT_POINTS);
      setTeams((teamRes.data ?? []) as TeamRow[]);
      setFixtures(fixtureRows);
      setResults((resultRes.data ?? []) as MatchResult[]);
      setLoading(false);
    })().catch(() => { if (alive) { setError("Teams could not be loaded."); setLoading(false); } });
    return () => { alive = false; };
  }, [competition.loading, seasonId, capture, reload]);

  // Squad sizes come from a signed-in-only RPC (no anonymous SECURITY DEFINER access).
  useEffect(() => {
    if (!seasonId || authStatus !== "authenticated") { setSquadCounts(new Map()); return; }
    let alive = true;
    void getSupabaseClient().rpc("get_public_season_team_squad_counts", { p_season_id: seasonId }).then(({ data }) => {
      if (alive) setSquadCounts(new Map((data ?? []).map((row) => [row.season_team_id, row.registered_players])));
    });
    return () => { alive = false; };
  }, [seasonId, authStatus]);

  useEffect(() => {
    if (loading || error || !seasonId || teams.length === 0 || lastTrackedSeason.current === seasonId) return;
    if (capture("core_value_action", { feature: "team_directory", season_id: seasonId })) lastTrackedSeason.current = seasonId;
  }, [capture, seasonId, error, loading, teams.length]);

  useEffect(() => {
    if (competition.loading || authStatus === "loading") return;
    if (authStatus !== "authenticated" || !seasonId) { setLeaders([]); setLeadersLoading(false); setLeadersError(""); return; }
    let alive = true;
    setLeadersLoading(true); setLeadersError("");
    void (async () => {
      try {
        const { data, error: rpcError } = await getSupabaseClient().rpc("get_public_season_club_leaders", { p_season_id: seasonId });
        if (!alive) return;
        if (rpcError) throw new Error(rpcError.message);
        setLeaders((data ?? []) as ClubLeader[]);
      } catch (cause) {
        if (alive) { setLeaders([]); setLeadersError(cause instanceof Error ? cause.message : "Unable to load Club Leaders."); }
      } finally { if (alive) setLeadersLoading(false); }
    })();
    return () => { alive = false; };
  }, [competition.loading, seasonId, authStatus]);

  const selectedSeason = competition.seasons.find((season) => season.id === seasonId);
  const rows = useMemo(() => filterByName(teams, query, (team) => team.name)
    .map((team) => ({ team, summary: teamSummary(team.id, teams, fixtures, results, points) }))
    .sort((a, b) => b.summary.points - a.summary.points || a.team.name.localeCompare(b.team.name)), [teams, query, fixtures, results, points]);

  return (
    <main className="notice-page player-facing">
      <div className="op-page">
        <PageHeader eyebrow="Teams" title="All teams in your league" subtitle="View team profiles, squads, stats and season information." />
        <PlayerCompetitionSelector context={competition} />
        {competition.error && <ErrorState message={competition.error} />}
        {loading || competition.loading ? <LoadingState label="Loading teams…" />
          : error ? <ErrorState message={error} onRetry={() => setReload((n) => n + 1)} />
          : !seasonId ? <EmptyState title="No public season available yet" description="Published teams appear here when a location and season are active." action={<Link to="/join" className="op-button op-button-outline"><span>Join Open Play</span></Link>} />
          : teams.length === 0 ? <EmptyState title="No teams published yet" description="Approved teams appear here once an administrator approves them." />
          : <>
            <SearchField label="Search teams" value={query} onChange={setQuery} placeholder="Search teams..." />
            <SectionHeading title={selectedSeason?.league_name ?? "Teams"} meta={<StatusBadge tone="neutral">{teams.length} teams</StatusBadge>} />
            {rows.length === 0 ? <EmptyState title="No teams match your search" />
              : <ul className="op-team-list">
                {rows.map(({ team, summary }) => (
                  <li key={team.id}>
                    <Link className="op-team-row" to="/teams/$teamId" params={{ teamId: team.id }} aria-label={`View ${team.name}`}>
                      <TeamInitials name={team.name} size="sm" />
                      <span className="op-team-row-body">
                        <strong>{team.name}</strong>
                        <span className="op-team-row-meta">
                          {squadCounts.has(team.id) && <><Users aria-hidden="true" /><span aria-label={`${squadCounts.get(team.id)} registered players`}>{squadCounts.get(team.id)}</span><span aria-hidden="true">|</span></>}
                          <span>P: {summary.played}</span><span aria-hidden="true">|</span><span className="op-team-row-points">Pts: {summary.points}</span>
                        </span>
                      </span>
                      <ChevronRight aria-hidden="true" className="op-icon-accent" />
                    </Link>
                  </li>
                ))}
              </ul>}
          </>}
        {seasonId && (
          <section aria-labelledby="club-leaders-heading">
            <SectionHeading id="club-leaders-heading" title="Club Leaders" description="Man of the Match awards this season" />
            {authStatus === "unauthenticated" ? <EmptyState title="Sign in to see Club Leaders" description="Player names are visible to signed-in Open Play members." action={<Link to="/sign-in" className="op-button op-button-outline"><span>Sign in</span></Link>} />
              : authStatus === "loading" || leadersLoading ? <LoadingState label="Loading Club Leaders…" />
              : leadersError ? <ErrorState message={`Club Leaders are temporarily unavailable: ${leadersError}`} />
              : leaders.length === 0 ? <EmptyState title="No Man of the Match awards yet" />
              : <ol className="op-team-list">{leaders.map((leader, index) => (
                <li key={leader.competition_player_id + leader.season_team_id} className="op-team-row op-team-row-static">
                  <span className="op-rank">{index + 1}</span>
                  <span className="op-team-row-body"><strong>{leader.player_name}</strong><span className="op-team-row-meta">{leader.team_name} · {leader.motm_awards} MOTM · {leader.appearances} apps</span></span>
                </li>))}</ol>}
          </section>
        )}
      </div>
      <RefereeBottomNavigation />
    </main>
  );
}
