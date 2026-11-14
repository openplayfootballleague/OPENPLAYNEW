import { useEffect, useMemo, useState } from "react";
import { Link, createFileRoute } from "@tanstack/react-router";
import { BarChart3, CalendarDays, Clock, Footprints, Goal, Medal, ShieldCheck, Trophy, Users } from "lucide-react";
import { RefereeBottomNavigation } from "../components/referee-bottom-navigation";
import { getSupabaseClient } from "../lib/supabase/client";
import { useRequiredSession } from "../lib/auth/use-required-session";
import { EmptyState, ErrorState, LoadingState, Pagination, SearchField, SectionHeading, StatGrid, StatTile, StatusBadge, TeamInitials, Button } from "../components/ui/op-ui";
import { clubLeaders, currentGameweekPage, filterByName, latestResult, nextFixture, ordinal, teamSchedule, teamSummary, type SquadMember } from "../lib/competition/team-hub";
import { completedMatches, paginate, type MatchFixture, type MatchResult } from "../lib/competition/player-matches";
import { DEFAULT_POINTS, type PointsRules } from "../lib/competition/standings";

const VIEWS = ["overview", "squad", "fixtures", "results"] as const;
type View = (typeof VIEWS)[number];
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const FIXTURES_PER_PAGE = 3; // IMG_0540
const RESULTS_PER_PAGE = 4;

export const Route = createFileRoute("/teams_/$teamId")({
  validateSearch: (search: Record<string, unknown>): { view?: View } =>
    VIEWS.includes(search.view as View) && search.view !== "overview" ? { view: search.view as View } : {},
  component: TeamHubPage,
});

type Team = { id: string; name: string; season_id: string };
type Context = { seasonName: string; leagueName: string; locationName: string; points: PointsRules };

const day = (value: string | null) => value ? new Date(value).toLocaleDateString("en-GB", { weekday: "short", day: "numeric", month: "short" }).toUpperCase() : "DATE TBC";
const longDay = (value: string | null) => value ? new Date(value).toLocaleDateString("en-GB", { weekday: "long", day: "numeric", month: "long" }) : "Date to be confirmed";
const time = (value: string | null) => value ? new Date(value).toLocaleTimeString("en-GB", { hour: "numeric", minute: "2-digit", hour12: true }).toUpperCase() : "TBC";

/** Team hub (references IMG_0535 overview, IMG_0536 squad, IMG_0540 fixtures, IMG_0538 results). */
function TeamHubPage() {
  const { teamId } = Route.useParams();
  const { view = "overview" } = Route.useSearch();
  const authStatus = useRequiredSession();
  const [team, setTeam] = useState<Team | null>(null);
  const [teams, setTeams] = useState<Team[]>([]);
  const [context, setContext] = useState<Context | null>(null);
  const [fixtures, setFixtures] = useState<MatchFixture[]>([]);
  const [results, setResults] = useState<MatchResult[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [reload, setReload] = useState(0);

  useEffect(() => {
    let alive = true;
    setLoading(true); setError(""); setTeam(null);
    void (async () => {
      if (!UUID.test(teamId)) throw new Error("This team link is invalid.");
      const supabase = getSupabaseClient();
      const { data: teamRow, error: teamError } = await supabase.from("season_teams").select("id,name,season_id").eq("id", teamId).eq("registration_status", "approved").maybeSingle();
      if (teamError) throw new Error("We couldn't load this team. Please try again.");
      if (!teamRow) throw new Error("This team is unavailable. It may no longer be published.");
      const [teamsRes, fixturesRes, seasonRes] = await Promise.all([
        supabase.from("season_teams").select("id,name,season_id").eq("season_id", teamRow.season_id).eq("registration_status", "approved"),
        supabase.from("fixtures").select("id,gameweek,scheduled_at,status,home_team_id,away_team_id,venue_id,is_title_final").eq("season_id", teamRow.season_id),
        supabase.from("seasons").select("name,league_id,points_for_win,points_for_draw,points_for_loss").eq("id", teamRow.season_id).maybeSingle(),
      ]);
      if (teamsRes.error || fixturesRes.error || seasonRes.error) throw new Error("The team is available, but its season data couldn't be loaded.");
      const fixtureRows = (fixturesRes.data ?? []) as MatchFixture[];
      const completedIds = fixtureRows.filter((f) => f.status === "completed").map((f) => f.id);
      const [resultsRes, leagueRes] = await Promise.all([
        completedIds.length ? supabase.from("fixture_results").select("fixture_id,home_score,away_score,confirmed_at").in("fixture_id", completedIds) : Promise.resolve({ data: [], error: null }),
        seasonRes.data ? supabase.from("leagues").select("name,location_id").eq("id", seasonRes.data.league_id).maybeSingle() : Promise.resolve({ data: null, error: null }),
      ]);
      if (resultsRes.error) throw new Error("The team is available, but its results couldn't be loaded.");
      const locationRes = leagueRes.data ? await supabase.from("locations").select("name").eq("id", leagueRes.data.location_id).maybeSingle() : { data: null };
      if (!alive) return;
      const season = seasonRes.data;
      setTeam(teamRow as Team);
      setTeams((teamsRes.data ?? []) as Team[]);
      setFixtures(fixtureRows);
      setResults((resultsRes.data ?? []) as MatchResult[]);
      setContext({
        seasonName: season?.name ?? "", leagueName: leagueRes.data?.name ?? "", locationName: locationRes.data?.name ?? "",
        points: season ? { win: season.points_for_win, draw: season.points_for_draw, loss: season.points_for_loss } : DEFAULT_POINTS,
      });
      setLoading(false);
    })().catch((cause) => { if (alive) { setError(cause instanceof Error ? cause.message : "We couldn't load this team."); setLoading(false); } });
    return () => { alive = false; };
  }, [teamId, reload]);

  const names = useMemo(() => new Map(teams.map((t) => [t.id, t.name])), [teams]);
  const summary = team ? teamSummary(team.id, teams, fixtures, results, context?.points) : null;
  const schedule = useMemo(() => team ? teamSchedule(team.id, fixtures, results) : [], [team, fixtures, results]);

  return (
    <main className="notice-page player-facing">
      <div className="op-page">
        {loading ? <LoadingState label="Loading team…" />
          : error || !team || !summary || !context ? <>
            <ErrorState message={error || "This team is unavailable."} onRetry={() => setReload((n) => n + 1)} />
            <p><Link to="/teams" className="op-button op-button-outline"><span>Back to teams</span></Link></p>
          </>
          : <>
            <header className="op-card op-team-hero">
              <TeamInitials name={team.name} size="lg" />
              <div className="op-team-hero-body">
                {context.leagueName && <StatusBadge tone="neutral">{context.leagueName}</StatusBadge>}
                <h1 className="op-page-title">{team.name}</h1>
                <p className="op-page-subtitle">{[context.locationName, "Open Play"].filter(Boolean).join(" · ")}</p>
              </div>
            </header>
            <nav className="op-team-nav" aria-label="Team navigation">
              {([["overview", "Overview", ShieldCheck], ["squad", "Squad", Users], ["fixtures", "Fixtures", CalendarDays], ["results", "Results", Trophy]] as const).map(([key, label, Icon]) => (
                <Link key={key} to="/teams/$teamId" params={{ teamId }} search={key === "overview" ? {} : { view: key }}
                  className={"op-team-nav-link" + (view === key ? " active" : "")} aria-current={view === key ? "page" : undefined}>
                  <Icon aria-hidden="true" /><span>{label}</span>
                </Link>
              ))}
            </nav>
            {view === "overview" && <TeamOverview teamId={team.id} names={names} summary={summary} schedule={schedule} fixtures={fixtures} results={results} />}
            {view === "squad" && <TeamSquad team={team} context={context} authStatus={authStatus} />}
            {view === "fixtures" && <TeamFixtures team={team} context={context} names={names} schedule={schedule} />}
            {view === "results" && <TeamResults team={team} context={context} names={names} summary={summary} fixtures={fixtures} results={results} />}
          </>}
      </div>
      <RefereeBottomNavigation />
    </main>
  );
}

function TeamOverview({ teamId, names, summary, schedule, fixtures, results }: {
  teamId: string; names: Map<string, string>; summary: ReturnType<typeof teamSummary>;
  schedule: ReturnType<typeof teamSchedule>; fixtures: MatchFixture[]; results: MatchResult[];
}) {
  const next = nextFixture(schedule);
  const latest = latestResult(teamId, fixtures, results);
  return <>
    <StatGrid>
      <StatTile accent value={summary.position ? ordinal(summary.position) : "–"} label="Position" />
      <StatTile accent value={summary.points} label="Points" />
      <StatTile accent value={summary.played} label="Played" />
    </StatGrid>
    <SectionHeading title="Upcoming fixture" />
    {next ? <Link to="/fixtures/$fixtureId" params={{ fixtureId: next.fixture.id }} className="op-card op-fixture-card op-match">
      <p className="op-fixture-meta">{longDay(next.fixture.scheduled_at).toUpperCase()} · {time(next.fixture.scheduled_at)}</p>
      <div className="op-fixture-teams"><strong>{names.get(next.fixture.home_team_id) ?? "Home"}</strong><span className="op-vs">VS</span><strong>{names.get(next.fixture.away_team_id) ?? "Away"}</strong></div>
      {next.fixture.status === "postponed" && <StatusBadge tone="warning">Postponed</StatusBadge>}
    </Link> : <EmptyState title="No upcoming fixture" description="The next fixture appears here once it is scheduled." icon={CalendarDays} />}
    <SectionHeading title="Latest result" />
    {latest ? <Link to="/fixtures/$fixtureId" params={{ fixtureId: latest.fixture.id }} className="op-card op-fixture-card op-match">
      <div className="op-fixture-meta-row"><span className="op-fixture-meta">GAMEWEEK {latest.fixture.gameweek}</span><OutcomeBadge outcome={latest.outcome} /></div>
      <div className="op-fixture-teams"><strong>{names.get(latest.fixture.home_team_id)}</strong><span className="op-score">{latest.result.home_score} – {latest.result.away_score}</span><strong>{names.get(latest.fixture.away_team_id)}</strong></div>
    </Link> : <EmptyState title="No results yet" description="Published results appear here after each match." icon={Trophy} />}
  </>;
}

function OutcomeBadge({ outcome }: { outcome: "win" | "draw" | "loss" }) {
  return <StatusBadge tone={outcome === "win" ? "active" : outcome === "draw" ? "warning" : "danger"}>{outcome}</StatusBadge>;
}

function TeamSquad({ team, context, authStatus }: { team: Team; context: Context; authStatus: ReturnType<typeof useRequiredSession> }) {
  const [squad, setSquad] = useState<SquadMember[] | null>(null);
  const [error, setError] = useState("");
  const [query, setQuery] = useState("");
  const [reload, setReload] = useState(0);
  useEffect(() => {
    if (authStatus !== "authenticated") return;
    let alive = true;
    setSquad(null); setError("");
    void getSupabaseClient().rpc("get_public_team_squad", { p_season_team_id: team.id }).then(({ data, error: rpcError }) => {
      if (!alive) return;
      if (rpcError) setError(rpcError.message); else setSquad((data ?? []) as SquadMember[]);
    });
    return () => { alive = false; };
  }, [team.id, authStatus, reload]);

  if (authStatus === "loading") return <LoadingState label="Checking your account…" />;
  if (authStatus !== "authenticated") return <EmptyState title="Sign in to view the squad" description="Squad lists and club leaders are visible to signed-in Open Play members." icon={Users} action={<Link to="/sign-in" className="op-button op-button-outline"><span>Sign in</span></Link>} />;
  if (error) return <ErrorState message={error} onRetry={() => setReload((n) => n + 1)} />;
  if (!squad) return <LoadingState label="Loading squad…" />;
  const visible = filterByName(squad, query, (member) => member.player_name);
  const leaders = clubLeaders(squad);
  const leaderIcon = { "Top scorer": Goal, "Top assists": Footprints, "Clean sheets": ShieldCheck, "Man of the Match": Medal } as const;
  return <>
    <SectionHeading title="Squad" description={[context.leagueName, context.seasonName].filter(Boolean).join(" · ")} meta={<StatusBadge tone="neutral">{squad.length} players</StatusBadge>} />
    <SearchField label="Search players" value={query} onChange={setQuery} placeholder="Search players..." />
    <div className="op-squad-layout">
      <section aria-labelledby="squad-heading">
        <SectionHeading id="squad-heading" title="The squad" description={`${squad.length} registered players`} />
        {squad.length === 0 ? <EmptyState title="No registered players yet" />
          : visible.length === 0 ? <EmptyState title="No players match your search" />
          : <ul className="op-team-list">{visible.map((member) => (
            <li key={member.competition_player_id} className="op-team-row op-team-row-static">
              <span className="op-rank">{member.squad_number != null ? String(member.squad_number).padStart(2, "0") : "–"}</span>
              <span className="op-team-row-body"><strong>{member.player_name}</strong>{member.is_captain && <span className="op-team-row-points">CAPTAIN</span>}</span>
            </li>))}</ul>}
      </section>
      <section aria-labelledby="leaders-heading">
        <SectionHeading id="leaders-heading" title="Club leaders" description="Season totals" />
        {leaders.length === 0 ? <EmptyState title="No statistics recorded yet" description="Leaders appear after published results." icon={BarChart3} />
          : <div className="op-stack">{leaders.map((leader) => {
            const Icon = leaderIcon[leader.label as keyof typeof leaderIcon];
            return <article key={leader.label} className="op-card op-leader-card">
              <Icon aria-hidden="true" className="op-icon-accent" />
              <span className="op-leader-label">{leader.label}</span>
              <strong>{leader.player.player_name}</strong>
              <span className="op-leader-value">{leader.value}</span>
              <span className="op-leader-label">{leader.unit}</span>
            </article>;
          })}</div>}
      </section>
    </div>
  </>;
}

function TeamFixtures({ team, context, names, schedule }: { team: Team; context: Context; names: Map<string, string>; schedule: ReturnType<typeof teamSchedule> }) {
  const [page, setPage] = useState(() => currentGameweekPage(schedule, FIXTURES_PER_PAGE));
  const current = paginate(schedule, page, FIXTURES_PER_PAGE);
  const upcoming = schedule.filter((entry) => entry.fixture.status !== "completed" && entry.fixture.status !== "cancelled").length;
  return <>
    <SectionHeading title="Team fixtures" description={[context.leagueName, context.seasonName].filter(Boolean).join(" · ")} meta={<StatusBadge tone="neutral">{upcoming} upcoming</StatusBadge>} />
    {schedule.length === 0 ? <EmptyState title="No fixtures published yet" icon={CalendarDays} /> : <>
      <div className="op-stack">{current.items.map(({ fixture, result }) => {
        const home = fixture.home_team_id === team.id;
        return <Link key={fixture.id} to="/fixtures/$fixtureId" params={{ fixtureId: fixture.id }} className="op-card op-fixture-card op-match">
          <div className="op-fixture-meta-row"><span className="op-fixture-meta op-accent">GAMEWEEK {fixture.gameweek}</span><span className="op-fixture-meta">{day(fixture.scheduled_at)}</span></div>
          <div className="op-fixture-teams">
            <span><strong>{names.get(fixture.home_team_id)}</strong><small>{home ? "HOME" : "OPPONENT"}</small></span>
            {result ? <span className="op-score">{result.home_score} – {result.away_score}</span> : <span className="op-vs">VS</span>}
            <span className="op-align-end"><strong>{names.get(fixture.away_team_id)}</strong><small>{home ? "OPPONENT" : "AWAY"}</small></span>
          </div>
          <p className="op-fixture-foot"><Clock aria-hidden="true" />{time(fixture.scheduled_at)}{fixture.status !== "scheduled" && <StatusBadge tone={fixture.status === "completed" ? "active" : "warning"}>{fixture.status.replace("_", " ")}</StatusBadge>}</p>
        </Link>;
      })}</div>
      <Pagination from={current.from} to={current.to} total={current.total} hasPrevious={current.hasPrevious} hasNext={current.hasNext} onPrevious={() => setPage(current.page - 1)} onNext={() => setPage(current.page + 1)} />
      <Button variant="light" block icon={CalendarDays} onClick={() => setPage(currentGameweekPage(schedule, FIXTURES_PER_PAGE))}>Current gameweek</Button>
    </>}
  </>;
}

function TeamResults({ team, context, names, summary, fixtures, results }: {
  team: Team; context: Context; names: Map<string, string>; summary: ReturnType<typeof teamSummary>; fixtures: MatchFixture[]; results: MatchResult[];
}) {
  const [page, setPage] = useState(1);
  const matches = completedMatches(fixtures, results, team.id);
  const current = paginate(matches, page, RESULTS_PER_PAGE);
  return <>
    <SectionHeading title="Season record" description={[context.leagueName, context.seasonName].filter(Boolean).join(" · ")} meta={<StatusBadge tone="neutral">{matches.length} matches</StatusBadge>} />
    <StatGrid>
      <StatTile accent value={summary.won} label="Won" />
      <StatTile accent value={summary.drawn} label="Drawn" />
      <StatTile accent value={summary.lost} label="Lost" />
    </StatGrid>
    <SectionHeading title="Match history" />
    {matches.length === 0 ? <EmptyState title="No published results yet" icon={Trophy} /> : <>
      <div className="op-stack">{current.items.map(({ fixture, result, outcome }) => {
        const home = fixture.home_team_id === team.id;
        return <Link key={fixture.id} to="/fixtures/$fixtureId" params={{ fixtureId: fixture.id }} className="op-card op-fixture-card op-match">
          <div className="op-fixture-meta-row"><span className="op-fixture-meta">GAMEWEEK {fixture.gameweek} · {fixture.scheduled_at ? new Date(fixture.scheduled_at).toLocaleDateString("en-GB", { day: "numeric", month: "long" }).toUpperCase() : "DATE TBC"}</span><OutcomeBadge outcome={outcome} /></div>
          <div className="op-fixture-teams">
            <span><strong>{team.name}</strong><small>{home ? "Home" : "Away"}</small></span>
            <span className="op-score">{home ? `${result.home_score} – ${result.away_score}` : `${result.away_score} – ${result.home_score}`}</span>
            <span className="op-align-end"><strong>{names.get(home ? fixture.away_team_id : fixture.home_team_id) ?? "Opponent"}</strong><small>Opponent</small></span>
          </div>
        </Link>;
      })}</div>
      <Pagination from={current.from} to={current.to} total={current.total} hasPrevious={current.hasPrevious} hasNext={current.hasNext} onPrevious={() => setPage(current.page - 1)} onNext={() => setPage(current.page + 1)} />
    </>}
  </>;
}
