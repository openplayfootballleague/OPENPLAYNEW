import { useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { Link, createFileRoute, useRouter } from "@tanstack/react-router";
import { ArrowLeft, CalendarDays, Clock, ExternalLink, Medal, MapPin, Shirt, Trophy, Users, type LucideIcon } from "lucide-react";
import { RefereeBottomNavigation } from "../components/referee-bottom-navigation";
import { useOpenPlayAnalytics } from "../components/analytics-provider";
import { EmptyState, ErrorState, LoadingState, MatchCard, SectionHeading, StatusBadge, TeamInitials, type StatusTone } from "../components/ui/op-ui";
import { getSupabaseClient } from "../lib/supabase/client";
import { useRequiredSession } from "../lib/auth/use-required-session";
import { DEFAULT_POINTS, type PointsRules } from "../lib/competition/standings";
import { ordinal, teamSummary, type TeamSummary } from "../lib/competition/team-hub";
import type { MatchFixture, MatchResult, Outcome } from "../lib/competition/player-matches";
import {
  FIXTURE_STATE_LABEL, fixtureState, formBefore, lineupFor, parseMatchReport, publishedResultFor, reportIsConsistent,
  scorersFor, seasonMeetings, venueDirectionsUrl, type FixtureState, type MatchReport, type ReportAppearance, type TeamSide,
} from "../lib/competition/fixture-detail";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export const Route = createFileRoute("/fixtures/$fixtureId")({ component: FixtureDetailPage });

type Team = { id: string; name: string };
type Venue = { name: string; address: string | null };
type Context = { seasonName: string; leagueName: string; points: PointsRules };
type Loaded = { seasonId: string; fixture: MatchFixture; teams: Team[]; fixtures: MatchFixture[]; results: MatchResult[]; venue: Venue | null; context: Context };

const longDate = (value: string | null) => value
  ? new Date(value).toLocaleDateString("en-GB", { weekday: "long", day: "numeric", month: "long", year: "numeric" })
  : "Date to be confirmed";
const kickOffTime = (value: string | null) => value
  ? new Date(value).toLocaleTimeString("en-GB", { hour: "numeric", minute: "2-digit", hour12: true }).toUpperCase()
  : "TBC";
const shortDate = (value: string | null) => value
  ? new Date(value).toLocaleDateString("en-GB", { day: "numeric", month: "short" }).toUpperCase()
  : "DATE TBC";

const STATE_TONE: Record<FixtureState, StatusTone> = {
  upcoming: "upcoming", in_progress: "accent", postponed: "warning", cancelled: "danger", awaiting_result: "neutral", result: "active",
};

/** Fixture detail and match report. Fixture, score, venue and form come from public data via RLS;
 * named match events need an account and come from `get_public_fixture_match_report`. */
function FixtureDetailPage() {
  const { fixtureId } = Route.useParams();
  const router = useRouter();
  const capture = useOpenPlayAnalytics();
  const [data, setData] = useState<Loaded | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [reload, setReload] = useState(0);
  const tracked = useRef("");

  useEffect(() => {
    let alive = true;
    setLoading(true); setError(""); setData(null);
    void (async () => {
      if (!UUID.test(fixtureId)) throw new Error("This fixture link is invalid.");
      const supabase = getSupabaseClient();
      const { data: row, error: fixtureError } = await supabase.from("fixtures")
        .select("id,season_id,gameweek,scheduled_at,status,home_team_id,away_team_id,venue_id,is_title_final")
        .eq("id", fixtureId).maybeSingle();
      if (fixtureError) throw new Error("We couldn't load this fixture. Please try again.");
      if (!row) throw new Error("This fixture is unavailable. It may not be published yet.");
      const [teamsRes, fixturesRes, seasonRes, venueRes] = await Promise.all([
        supabase.from("season_teams").select("id,name").eq("season_id", row.season_id).eq("registration_status", "approved"),
        supabase.from("fixtures").select("id,gameweek,scheduled_at,status,home_team_id,away_team_id,is_title_final").eq("season_id", row.season_id),
        supabase.from("seasons").select("name,league_id,points_for_win,points_for_draw,points_for_loss").eq("id", row.season_id).maybeSingle(),
        row.venue_id ? supabase.from("venues").select("name,address").eq("id", row.venue_id).maybeSingle() : Promise.resolve({ data: null, error: null }),
      ]);
      if (teamsRes.error || fixturesRes.error || seasonRes.error) throw new Error("The fixture is available, but its season data couldn't be loaded.");
      const teams = (teamsRes.data ?? []) as Team[];
      if (!teams.some((t) => t.id === row.home_team_id) || !teams.some((t) => t.id === row.away_team_id)) {
        throw new Error("This fixture is unavailable. It may not be published yet.");
      }
      const fixtures = (fixturesRes.data ?? []) as MatchFixture[];
      const completed = fixtures.filter((f) => f.status === "completed").map((f) => f.id);
      const [resultsRes, leagueRes] = await Promise.all([
        completed.length ? supabase.from("fixture_results").select("fixture_id,home_score,away_score,confirmed_at").in("fixture_id", completed) : Promise.resolve({ data: [], error: null }),
        seasonRes.data ? supabase.from("leagues").select("name").eq("id", seasonRes.data.league_id).maybeSingle() : Promise.resolve({ data: null, error: null }),
      ]);
      if (resultsRes.error) throw new Error("The fixture is available, but its results couldn't be loaded.");
      if (!alive) return;
      const season = seasonRes.data;
      setData({
        seasonId: row.season_id, fixture: row as MatchFixture, teams, fixtures, results: (resultsRes.data ?? []) as MatchResult[],
        // A venue that is no longer active is hidden by RLS; the page then says the venue is to be confirmed.
        venue: (venueRes.data as Venue | null) ?? null,
        context: {
          seasonName: season?.name ?? "", leagueName: leagueRes.data?.name ?? "",
          points: season ? { win: season.points_for_win, draw: season.points_for_draw, loss: season.points_for_loss } : DEFAULT_POINTS,
        },
      });
      setLoading(false);
    })().catch((cause) => {
      if (!alive) return;
      setError(cause instanceof Error ? cause.message : "We couldn't load this fixture.");
      setLoading(false);
      capture("data_load_failed", { feature: "fixtures", error_code: "network_error", outcome: "failure" });
    });
    return () => { alive = false; };
  }, [fixtureId, reload, capture]);

  const result = data ? publishedResultFor(data.fixture, data.results) : null;
  const state = data ? fixtureState(data.fixture, result) : "upcoming";

  useEffect(() => {
    if (!data || tracked.current === data.fixture.id) return;
    if (capture(result ? "result_viewed" : "fixture_viewed", { feature: result ? "results" : "fixtures", season_id: data.seasonId })) tracked.current = data.fixture.id;
  }, [capture, data, result]);

  const back = () => (router.history.length > 1 ? router.history.back() : void router.navigate({ to: "/match-centre" }));

  return (
    <main className="notice-page player-facing">
      <div className="op-page op-fixture-page">
        <button type="button" className="op-back-link" onClick={back}><ArrowLeft aria-hidden="true" /><span>Back</span></button>
        {loading ? <LoadingState label="Loading fixture…" />
          : error || !data ? <>
            <ErrorState message={error || "This fixture is unavailable."} onRetry={() => setReload((n) => n + 1)} />
            <p><Link to="/match-centre" className="op-button op-button-outline"><span>Go to Match Centre</span></Link></p>
          </>
          : <FixtureBody data={data} result={result} state={state} />}
      </div>
      <RefereeBottomNavigation />
    </main>
  );
}

function FixtureBody({ data, result, state }: { data: Loaded; result: MatchResult | null; state: FixtureState }) {
  const { fixture, teams, fixtures, results, venue, context } = data;
  const names = useMemo(() => new Map(teams.map((t) => [t.id, t.name])), [teams]);
  const home = { id: fixture.home_team_id, name: names.get(fixture.home_team_id) ?? "Home" };
  const away = { id: fixture.away_team_id, name: names.get(fixture.away_team_id) ?? "Away" };
  const meetings = useMemo(() => seasonMeetings(fixture, fixtures, results), [fixture, fixtures, results]);
  const summaries = useMemo(() => ({
    home: teamSummary(home.id, teams, fixtures, results, context.points),
    away: teamSummary(away.id, teams, fixtures, results, context.points),
  }), [home.id, away.id, teams, fixtures, results, context.points]);
  const form = useMemo(() => ({
    home: formBefore(home.id, fixture, fixtures, results),
    away: formBefore(away.id, fixture, fixtures, results),
  }), [home.id, away.id, fixture, fixtures, results]);
  const competitionLine = [context.leagueName, context.seasonName].filter(Boolean).join(" · ");

  return <>
    <header className="op-card op-fixture-hero" aria-labelledby="fixture-title">
      <div className="op-fixture-hero-top">
        <span className="op-fixture-meta">{fixture.is_title_final ? <span className="op-accent">Title final</span> : `Gameweek ${fixture.gameweek}`}{competitionLine && ` · ${competitionLine}`}</span>
        <StatusBadge tone={STATE_TONE[state]}>{FIXTURE_STATE_LABEL[state]}</StatusBadge>
      </div>
      <h1 id="fixture-title" className="visually-hidden">{home.name} versus {away.name}</h1>
      <div className="op-fixture-hero-teams">
        <HeroTeam team={home} label="Home" />
        <div className="op-fixture-hero-centre">
          {result
            ? <span className="op-fixture-hero-score" aria-label={`Final score ${home.name} ${result.home_score}, ${away.name} ${result.away_score}`}>{result.home_score}<span aria-hidden="true">–</span>{result.away_score}</span>
            : <span className="op-fixture-hero-time">{state === "cancelled" ? "—" : kickOffTime(fixture.scheduled_at)}</span>}
          <span className="op-fixture-hero-caption">{result ? "Full time" : state === "cancelled" ? "Cancelled" : shortDate(fixture.scheduled_at)}</span>
        </div>
        <HeroTeam team={away} label="Away" />
      </div>
    </header>

    <StateNotice state={state} isTitleFinal={Boolean(fixture.is_title_final)} />

    <section className="op-section" aria-labelledby="details-heading">
      <SectionHeading id="details-heading" title="Match details" />
      <dl className="op-card op-detail-list">
        <DetailRow icon={CalendarDays} label="Date" value={longDate(fixture.scheduled_at)} />
        <DetailRow icon={Clock} label="Kick-off" value={fixture.scheduled_at ? kickOffTime(fixture.scheduled_at) : "To be confirmed"} />
        <DetailRow icon={MapPin} label="Venue" value={venue
          ? <span className="op-detail-venue">
            <span>{venue.name}{venue.address && <small>{venue.address}</small>}</span>
            <a className="op-section-link" href={venueDirectionsUrl(venue)} target="_blank" rel="noopener noreferrer">Directions<ExternalLink aria-hidden="true" /><span className="visually-hidden"> (opens in a new tab)</span></a>
          </span>
          : "To be confirmed"} />
      </dl>
    </section>

    {state === "result" && result && <MatchReportSection fixtureId={fixture.id} home={home} away={away} result={result} />}

    <section className="op-section" aria-labelledby="form-heading">
      <SectionHeading id="form-heading" title="Form and standing" description={fixture.is_title_final ? "League table before the title final" : "Current league table"} />
      <div className="op-card op-form-table" role="table" aria-label="Form and league standing">
        <div role="row" className="op-form-row op-form-head">
          <span role="columnheader">Team · last 5</span>
          <span role="columnheader" className="op-form-num">Pos</span><span role="columnheader" className="op-form-num">Pts</span>
        </div>
        <FormRow team={home} outcomes={form.home} summary={summaries.home} />
        <FormRow team={away} outcomes={form.away} summary={summaries.away} />
      </div>
      <p className="op-footnote">Form shows published results before this fixture, oldest first. Teams level on points share a position.</p>
    </section>

    <section className="op-section" aria-labelledby="meetings-heading">
      <SectionHeading id="meetings-heading" title="Other meetings this season" />
      {meetings.length === 0 ? <EmptyState title="No other meetings this season" icon={Users} />
        : <div className="op-stack">{meetings.map(({ fixture: m, result: r }) => (
          <MatchCard key={m.id} to="/fixtures/$fixtureId" params={{ fixtureId: m.id }}
            meta={m.is_title_final ? "Title final" : `Gameweek ${m.gameweek} · ${shortDate(m.scheduled_at)}`}
            metaTrailing={m.status === "postponed" || m.status === "cancelled" ? <StatusBadge tone={m.status === "cancelled" ? "danger" : "warning"}>{m.status}</StatusBadge> : undefined}
            home={{ name: names.get(m.home_team_id) ?? "Home" }} away={{ name: names.get(m.away_team_id) ?? "Away" }}
            score={r ? { home: r.home_score, away: r.away_score } : null} />
        ))}</div>}
    </section>
  </>;
}

function HeroTeam({ team, label }: { team: { id: string; name: string }; label: string }) {
  return (
    <Link to="/teams/$teamId" params={{ teamId: team.id }} className="op-fixture-hero-team">
      <TeamInitials name={team.name} size="lg" />
      <strong>{team.name}</strong>
      <small>{label}</small>
    </Link>
  );
}

function StateNotice({ state, isTitleFinal }: { state: FixtureState; isTitleFinal: boolean }) {
  const notices: Partial<Record<FixtureState, { title: string; description: string }>> = {
    postponed: { title: "This fixture has been postponed", description: "A new date will appear here once the league confirms it." },
    cancelled: { title: "This fixture has been cancelled", description: "It will not be played and does not count towards the league table." },
    in_progress: { title: "Match in progress", description: "The score is published after the referee's report is confirmed." },
    awaiting_result: { title: "Result pending", description: "The score appears here once the league confirms the result." },
  };
  const notice = notices[state];
  return <>
    {notice && <EmptyState title={notice.title} description={notice.description} icon={CalendarDays} />}
    {isTitleFinal && state !== "cancelled" && <EmptyState title="Title final" description="This match decides first place between teams level on points. It does not add league points." icon={Trophy} />}
  </>;
}

function DetailRow({ icon: Icon, label, value }: { icon: LucideIcon; label: string; value: ReactNode }) {
  return <div className="op-detail-row"><dt><Icon aria-hidden="true" />{label}</dt><dd>{value}</dd></div>;
}

const OUTCOME_LETTER: Record<Outcome, string> = { win: "W", draw: "D", loss: "L" };

function FormRow({ team, outcomes, summary }: { team: { id: string; name: string }; outcomes: Outcome[]; summary: TeamSummary }) {
  return (
    <div role="row" className="op-form-row">
      <span role="cell" className="op-form-team">
        <TeamInitials name={team.name} size="sm" />
        <span className="op-form-team-body">
          <Link to="/teams/$teamId" params={{ teamId: team.id }}>{team.name}</Link>
          {outcomes.length === 0 ? <span className="op-form-none">No earlier results</span>
            : <span className="op-form-pills" role="img" aria-label={`Last ${outcomes.length}: ${outcomes.join(", ")}`}>
              {outcomes.map((o, i) => <span key={i} aria-hidden="true" className={`op-form-pill op-form-${o}`}>{OUTCOME_LETTER[o]}</span>)}
            </span>}
        </span>
      </span>
      <span role="cell" className="op-form-num">{summary.position ? ordinal(summary.position) : "–"}</span>
      <span role="cell" className="op-form-num"><strong>{summary.points}</strong></span>
    </div>
  );
}

type ReportState = { status: "idle" | "loading" | "ready" | "error"; report: MatchReport | null; message: string };

function MatchReportSection({ fixtureId, home, away, result }: {
  fixtureId: string; home: { id: string; name: string }; away: { id: string; name: string }; result: MatchResult;
}) {
  const authStatus = useRequiredSession();
  const [state, setState] = useState<ReportState>({ status: "idle", report: null, message: "" });
  const [reload, setReload] = useState(0);

  useEffect(() => {
    // Clear any report from a previous account before deciding what this session may see.
    setState({ status: authStatus === "authenticated" ? "loading" : "idle", report: null, message: "" });
    if (authStatus !== "authenticated") return;
    let alive = true;
    void getSupabaseClient().rpc("get_public_fixture_match_report", { p_fixture_id: fixtureId }).then(({ data, error }) => {
      if (!alive) return;
      if (error) { setState({ status: "error", report: null, message: "We couldn't load the match report. Please try again." }); return; }
      const report = parseMatchReport(data);
      if (!report) setState({ status: "error", report: null, message: "The match report couldn't be read. Please try again." });
      else setState({ status: "ready", report, message: "" });
    });
    return () => { alive = false; };
  }, [fixtureId, authStatus, reload]);

  let body: ReactNode;
  if (authStatus === "loading" || state.status === "loading" || (authStatus === "authenticated" && state.status === "idle")) body = <LoadingState label="Loading match report…" />;
  else if (authStatus !== "authenticated") body = <EmptyState title="Sign in to view the match report" description="Goal scorers, line-ups and Man of the Match are visible to signed-in Open Play members." icon={Users}
    action={<Link to="/sign-in" className="op-button op-button-outline"><span>Sign in</span></Link>} />;
  else if (state.status === "error" || !state.report) body = <ErrorState message={state.message || "We couldn't load the match report."} onRetry={() => setReload((n) => n + 1)} />;
  else if (!state.report.published) body = <EmptyState title="Match report not yet published" description="Events appear once the league confirms the result." icon={Trophy} />;
  else body = <ReportBody report={state.report} home={home} away={away} result={result} />;

  return <section className="op-section" aria-labelledby="report-heading">
    <SectionHeading id="report-heading" title="Match report" />
    {body}
  </section>;
}

function ReportBody({ report, home, away, result }: { report: MatchReport; home: { name: string }; away: { name: string }; result: MatchResult }) {
  const sides: [TeamSide, { name: string }, number][] = [["home", home, result.home_score], ["away", away, result.away_score]];
  const unrecorded = sides.map(([side, , score]) => score - report.goals.filter((g) => g.team_side === side).length);
  const hasLineups = report.lineups.length > 0;
  return <div className="op-stack">
    <article className="op-card" aria-labelledby="goals-heading">
      <h3 id="goals-heading" className="op-card-title"><Trophy aria-hidden="true" className="op-icon-accent" />Goals</h3>
      {result.home_score + result.away_score === 0 ? <p className="op-muted">Goalless draw.</p>
        : <div className="op-report-columns">{sides.map(([side, team], index) => {
          const lines = scorersFor(report.goals, side);
          return <div key={side} className="op-report-column">
            <p className="op-report-team">{team.name}</p>
            {lines.length === 0 && unrecorded[index] === 0 ? <p className="op-muted">No goals</p>
              : <ul className="op-scorer-list">
                {lines.map((line) => <li key={`${line.isOwnGoal}-${line.name}`}>
                  <span className="op-scorer-name">{line.name}{line.goals > 1 && <span className="op-scorer-count"> ×{line.goals}</span>}{line.isOwnGoal && <span className="op-scorer-tag">OG</span>}</span>
                  {line.assists.length > 0 && <span className="op-scorer-assist">Assist: {line.assists.join(", ")}</span>}
                </li>)}
                {unrecorded[index] > 0 && <li className="op-muted">{unrecorded[index] === 1 ? "1 goal" : `${unrecorded[index]} goals`} without a recorded scorer</li>}
              </ul>}
          </div>;
        })}</div>}
      {!reportIsConsistent(report, result) && <p className="op-footnote" role="note">More goal events are recorded than the confirmed score allows. Please contact the league if this looks wrong.</p>}
    </article>

    <article className="op-card" aria-labelledby="motm-heading">
      <h3 id="motm-heading" className="op-card-title"><Medal aria-hidden="true" className="op-icon-accent" />Man of the Match</h3>
      <div className="op-report-columns">{sides.map(([side, team]) => {
        const award = report.motm.find((m) => m.team_side === side);
        return <div key={side} className="op-report-column">
          <p className="op-report-team">{team.name}</p>
          {award ? <p className="op-motm-name">{award.player_name}</p> : <p className="op-muted">Not nominated</p>}
        </div>;
      })}</div>
    </article>

    <article className="op-card" aria-labelledby="lineups-heading">
      <h3 id="lineups-heading" className="op-card-title"><Shirt aria-hidden="true" className="op-icon-accent" />Line-ups</h3>
      {!hasLineups ? <p className="op-muted">No locked team sheets were recorded for this match.</p>
        : <div className="op-report-columns">{sides.map(([side, team]) => {
          const lineup = lineupFor(report.lineups, side);
          return <div key={side} className="op-report-column">
            <p className="op-report-team">{team.name}</p>
            {lineup.starters.length + lineup.substitutes.length === 0 ? <p className="op-muted">No team sheet recorded</p> : <>
              <LineupList title="Starting" players={lineup.starters} />
              {lineup.substitutes.length > 0 && <LineupList title="Substitutes used" players={lineup.substitutes} />}
            </>}
          </div>;
        })}</div>}
    </article>
  </div>;
}

function LineupList({ title, players }: { title: string; players: ReportAppearance[] }) {
  return <>
    <p className="op-lineup-heading">{title}</p>
    <ul className="op-lineup-list">{players.map((p, i) => (
      <li key={`${p.player_name}-${i}`}>
        <span className="op-lineup-number" aria-hidden={p.squad_number == null}>{p.squad_number ?? "–"}</span>
        <span className="op-lineup-name">{p.player_name}{p.is_goalkeeper && <span className="op-scorer-tag"><abbr title="Goalkeeper">GK</abbr></span>}</span>
      </li>
    ))}</ul>
  </>;
}
