import { useEffect, useMemo, useState } from "react";
import { Link } from "@tanstack/react-router";
import { PlayerBottomNavigation } from "./player-bottom-navigation";
import { PlayerCompetitionSelector, usePlayerCompetitionContext } from "../lib/competition/player-context";
import {
  completedMatches,
  paginate,
  upcomingFixtures,
  type MatchFixture,
  type MatchResult,
  type Outcome,
} from "../lib/competition/player-matches";
import { getSupabaseClient } from "../lib/supabase/client";

const PAGE_SIZE = 4;

type ListItem = { fixture: MatchFixture; result?: MatchResult; outcome?: Outcome };
const OUTCOME_LABEL: Record<Outcome, string> = { win: "WIN", draw: "DRAW", loss: "LOSS" };
const STATUS_LABEL: Record<MatchFixture["status"], string> = {
  scheduled: "Scheduled", in_progress: "In progress", completed: "Completed", postponed: "Postponed", cancelled: "Cancelled",
};

type LoadState =
  | { kind: "loading" }
  | { kind: "error"; message: string }
  | { kind: "no-team" }
  | { kind: "ready"; teamId: string; teamName: string; fixtures: MatchFixture[]; results: MatchResult[]; teamNames: Map<string, string>; venueNames: Map<string, string> };

/**
 * Player Hub "My Fixtures" (IMG_0572) and "My Results" (IMG_0573). Data is read under RLS
 * for the signed-in player's own team in the selected season; nothing is client-trusted.
 */
export function PlayerMatchesPage({ mode }: { mode: "fixtures" | "results" }) {
  const competition = usePlayerCompetitionContext();
  const [state, setState] = useState<LoadState>({ kind: "loading" });
  const [page, setPage] = useState(1);
  const [openId, setOpenId] = useState("");

  useEffect(() => {
    if (competition.loading) return;
    let alive = true;
    setState({ kind: "loading" });
    setPage(1);
    void (async () => {
      try {
        const supabase = getSupabaseClient();
        const { data: sessionData } = await supabase.auth.getSession();
        const userId = sessionData.session?.user.id;
        const seasonId = competition.selectedSeasonId;
        if (!userId || !seasonId) {
          if (alive) setState({ kind: "no-team" });
          return;
        }
        const { data: memberships, error: membershipError } = await supabase
          .from("team_memberships").select("season_team_id,status").eq("user_id", userId).in("status", ["active", "left"]);
        if (membershipError) throw membershipError;
        const { data: seasonTeams, error: teamsError } = await supabase
          .from("season_teams").select("id,name").eq("season_id", seasonId).eq("registration_status", "approved");
        if (teamsError) throw teamsError;
        const teamIds = new Set((seasonTeams ?? []).map((t) => t.id));
        // Prefer the active membership in this season; fall back to a historical one.
        const mine = (memberships ?? []).filter((m) => teamIds.has(m.season_team_id))
          .sort((a, b) => (a.status === "active" ? -1 : 0) - (b.status === "active" ? -1 : 0))[0];
        if (!mine) {
          if (alive) setState({ kind: "no-team" });
          return;
        }
        const teamId = mine.season_team_id;
        const { data: fixtureRows, error: fixtureError } = await supabase
          .from("fixtures").select("id,gameweek,scheduled_at,status,home_team_id,away_team_id,venue_id,is_title_final")
          .eq("season_id", seasonId).or(`home_team_id.eq.${teamId},away_team_id.eq.${teamId}`);
        if (fixtureError) throw fixtureError;
        const fixtures = (fixtureRows ?? []) as MatchFixture[];
        const completedIds = fixtures.filter((f) => f.status === "completed").map((f) => f.id);
        const venueIds = [...new Set(fixtures.map((f) => f.venue_id).filter((id): id is string => Boolean(id)))];
        const [resultResponse, venueResponse] = await Promise.all([
          completedIds.length
            ? supabase.from("fixture_results").select("fixture_id,home_score,away_score,confirmed_at").in("fixture_id", completedIds)
            : Promise.resolve({ data: [], error: null }),
          venueIds.length
            ? (supabase as unknown as { from: (t: string) => { select: (c: string) => { in: (c: string, v: string[]) => Promise<{ data: Array<{ id: string; name: string }> | null; error: { message: string } | null }> } } })
                .from("venues").select("id,name").in("id", venueIds)
            : Promise.resolve({ data: [], error: null }),
        ]);
        if (resultResponse.error) throw resultResponse.error;
        if (!alive) return;
        setState({
          kind: "ready",
          teamId,
          teamName: (seasonTeams ?? []).find((t) => t.id === teamId)?.name ?? "Your team",
          fixtures,
          results: (resultResponse.data ?? []) as MatchResult[],
          teamNames: new Map((seasonTeams ?? []).map((t) => [t.id, t.name])),
          // Venue names are optional context; a failed lookup must not hide fixtures.
          venueNames: new Map((venueResponse.error ? [] : venueResponse.data ?? []).map((v) => [v.id, v.name])),
        });
      } catch (cause) {
        if (alive) setState({ kind: "error", message: cause instanceof Error ? cause.message : "Unable to load your matches." });
      }
    })();
    return () => {
      alive = false;
    };
  }, [competition.loading, competition.selectedSeasonId]);

  const season = competition.seasons.find((s) => s.id === competition.selectedSeasonId);
  const seasonName = season ? `${season.league_name} · ${season.name}` : "";
  const listing = useMemo(() => {
    if (state.kind !== "ready") return null;
    const items: ListItem[] = mode === "fixtures"
      ? upcomingFixtures(state.fixtures, state.teamId).map((fixture) => ({ fixture }))
      : completedMatches(state.fixtures, state.results, state.teamId);
    return paginate(items, page, PAGE_SIZE);
  }, [state, mode, page]);

  const title = mode === "fixtures" ? "Your Fixtures." : "Your Results.";
  const sectionLabel = mode === "fixtures" ? "UPCOMING FIXTURES" : "COMPLETED MATCHES";

  return (
    <main className="notice-page player-facing">
      <section className="notice-panel player-matches-panel">
        <p className="eyebrow eyebrow-dark">PLAYER HUB / {mode === "fixtures" ? "MY FIXTURES" : "MY RESULTS"}</p>
        <h1>{title}</h1>
        {state.kind === "ready" && <p className="form-note">{state.teamName}{seasonName ? ` · ${seasonName}` : ""}</p>}
        <PlayerCompetitionSelector context={competition} />

        {state.kind === "loading" && <p className="form-note" role="status">Loading your {mode}…</p>}
        {state.kind === "error" && (
          <p className="form-error" role="alert">
            {mode === "fixtures" ? "Fixtures" : "Results"} could not be loaded: {state.message}
          </p>
        )}
        {state.kind === "no-team" && (
          <section className="hub-empty">
            <p className="form-note">You are not in an approved team for this season yet.</p>
            <Link className="button" to="/join">FIND A TEAM <span aria-hidden="true">↗</span></Link>
          </section>
        )}

        {state.kind === "ready" && listing && (
          <section aria-labelledby="matches-heading" className="player-matches-list">
            <div className="hub-section-heading">
              <span className="hub-kicker" id="matches-heading">{sectionLabel}</span>
              <span>{listing.total}</span>
            </div>
            {listing.total === 0 ? (
              <p className="form-note">
                {mode === "fixtures" ? "No upcoming fixtures for your team this season." : "No published results for your team yet."}
              </p>
            ) : (
              listing.items.map((item) => {
                const fixture = item.fixture;
                const completed = item.result && item.outcome ? { result: item.result, outcome: item.outcome } : null;
                const home = state.teamNames.get(fixture.home_team_id) ?? "Home team";
                const away = state.teamNames.get(fixture.away_team_id) ?? "Away team";
                const when = fixture.scheduled_at ? new Date(fixture.scheduled_at) : null;
                const venue = fixture.venue_id ? state.venueNames.get(fixture.venue_id) : undefined;
                const open = openId === fixture.id;
                return (
                  <article key={fixture.id} className={`player-match-card status-${fixture.status}`}>
                    <div className="player-match-meta">
                      <span>{fixture.is_title_final ? "TITLE FINAL" : `GAMEWEEK ${fixture.gameweek}`}</span>
                      <span>{when ? when.toLocaleDateString("en-GB", { weekday: "short", day: "numeric", month: "short" }) : "Date to be confirmed"}</span>
                    </div>
                    <div className="player-match-teams">
                      <div className={fixture.home_team_id === state.teamId ? "is-own-team" : undefined}><small>HOME</small><strong>{home}</strong></div>
                      <b aria-label={completed ? `Score ${completed.result.home_score} to ${completed.result.away_score}` : "versus"}>
                        {completed ? `${completed.result.home_score} – ${completed.result.away_score}` : "VS"}
                      </b>
                      <div className={fixture.away_team_id === state.teamId ? "is-own-team" : undefined}><small>AWAY</small><strong>{away}</strong></div>
                    </div>
                    <div className="player-match-foot">
                      {completed ? (
                        <span className={`outcome outcome-${completed.outcome}`}>{OUTCOME_LABEL[completed.outcome]}</span>
                      ) : (
                        <span className={`match-status match-status-${fixture.status}`}>
                          {fixture.status === "scheduled" && when ? when.toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" }) : STATUS_LABEL[fixture.status]}
                        </span>
                      )}
                      <span>{venue ?? "Venue to be confirmed"}</span>
                      <button type="button" aria-expanded={open} aria-controls={`match-detail-${fixture.id}`} onClick={() => setOpenId(open ? "" : fixture.id)}>
                        {open ? "HIDE DETAILS" : mode === "fixtures" ? "FIXTURE DETAILS" : "RESULT DETAILS"}
                      </button>
                    </div>
                    {open && (
                      <dl className="player-match-detail" id={`match-detail-${fixture.id}`}>
                        <div><dt>Status</dt><dd>{STATUS_LABEL[fixture.status]}</dd></div>
                        <div><dt>Kick-off</dt><dd>{when ? when.toLocaleString("en-GB", { dateStyle: "full", timeStyle: "short" }) : "To be confirmed"}</dd></div>
                        <div><dt>Venue</dt><dd>{venue ?? "To be confirmed"}</dd></div>
                        {completed && <div><dt>Published result</dt><dd>{home} {completed.result.home_score} – {completed.result.away_score} {away}</dd></div>}
                      </dl>
                    )}
                  </article>
                );
              })
            )}
            {listing.total > 0 && (
              <nav className="player-matches-pagination" aria-label={`${mode === "fixtures" ? "Fixtures" : "Results"} pages`}>
                <button type="button" disabled={!listing.hasPrevious} onClick={() => setPage(listing.page - 1)}>PREVIOUS</button>
                <span aria-live="polite">{listing.from}–{listing.to} of {listing.total}</span>
                <button type="button" disabled={!listing.hasNext} onClick={() => setPage(listing.page + 1)}>NEXT</button>
              </nav>
            )}
          </section>
        )}
        <Link className="auth-switch" to="/player">Back to Player Hub</Link>
      </section>
      <PlayerBottomNavigation />
    </main>
  );
}
