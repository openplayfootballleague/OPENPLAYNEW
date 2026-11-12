import { useEffect, useMemo, useState } from "react";
import { Link, createFileRoute } from "@tanstack/react-router";
import { RefereeBottomNavigation } from "../components/referee-bottom-navigation";
import { getSupabaseClient } from "../lib/supabase/client";

type ReportPlayer = {
  competition_player_id: string | null;
  name: string;
  role: string;
  is_goalkeeper: boolean;
  squad_number: number | null;
  did_appear: boolean;
};
type ReportLineup = { season_team_id: string; team_name: string; players: ReportPlayer[] };
type ReportGoal = {
  season_team_id: string;
  team_name: string;
  competition_player_id: string | null;
  scorer_name: string;
  recorded_at: string;
};
type ReportTeam = { id: string; name: string; badge_path: string | null; instagram_url: string | null };
type MatchReport = {
  fixture: { id: string; gameweek: number; scheduled_at: string | null; status: string };
  home_team: ReportTeam;
  away_team: ReportTeam;
  season_name: string;
  competition_name: string;
  venue: { name: string; address: string | null; town: string | null; region: string | null } | null;
  result: { home_score: number; away_score: number; confirmed_at: string } | null;
  report_available: boolean;
  goals: ReportGoal[];
  lineups: ReportLineup[];
  motm: { player_name: string; team_name: string } | null;
  events: { event_type: string; minute: number | null; description: string | null }[];
  assists_available: boolean;
  match_events_available: boolean;
  motm_available: boolean;
};

export const Route = createFileRoute("/match-report/$fixtureId")({ component: MatchReportPage });

function MatchReportPage() {
  const { fixtureId } = Route.useParams();
  const [report, setReport] = useState<MatchReport | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    let alive = true;
    async function load() {
      setLoading(true);
      setError("");
      const { data, error: queryError } = await getSupabaseClient()
        .rpc("get_public_match_report", { p_fixture_id: fixtureId });
      if (!alive) return;
      if (queryError) {
        setError(queryError.message);
        setReport(null);
      } else if (!data) {
        setError("This match report is not available.");
        setReport(null);
      } else {
        setReport(data as unknown as MatchReport);
      }
      setLoading(false);
    }
    void load();
    return () => { alive = false; };
  }, [fixtureId]);

  const performance = useMemo(() => {
    if (!report) return [];
    return report.lineups.flatMap(lineup => lineup.players.map(player => ({
      ...player,
      team_name: lineup.team_name,
      goals: player.competition_player_id
        ? report.goals.filter(goal => goal.competition_player_id === player.competition_player_id).length
        : 0,
    })));
  }, [report]);

  const crestUrl = (path: string | null) =>
    path ? getSupabaseClient().storage.from("team-crests").getPublicUrl(path).data.publicUrl : null;

  if (loading) return <main className="notice-page player-facing"><section className="notice-panel match-report-panel"><p>Loading match report…</p></section><RefereeBottomNavigation /></main>;

  return (
    <main className="notice-page player-facing">
      <section className="notice-panel match-report-panel">
        <Link className="notice-brand" to="/player"><img className="open-play-logo" src="/open-play-logo.png" alt="Open Play" /></Link>
        <p className="eyebrow eyebrow-dark">MATCH CENTRE / MATCH REPORT</p>
        {error || !report ? (
          <>
            <h1>Match<br /><em>report.</em></h1>
            <p className="form-error" role="alert">{error || "This match report is not available."}</p>
          </>
        ) : (
          <>
            <p className="eyebrow eyebrow-dark">{report.competition_name} · {report.season_name}</p>
            <h1>GAMEWEEK<br /><em>{report.fixture.gameweek}</em></h1>
            <p className="match-report-meta">
              {report.fixture.scheduled_at
                ? new Date(report.fixture.scheduled_at).toLocaleString("en-GB", { dateStyle: "full", timeStyle: "short" })
                : "Date and time to be confirmed"}
              {" · "}{report.venue?.name || "Venue to be confirmed"}
            </p>

            <section className="match-report-scoreboard">
              <div className="match-report-team">
                {crestUrl(report.home_team.badge_path)
                  ? <img src={crestUrl(report.home_team.badge_path) || ""} alt={report.home_team.name + " crest"} />
                  : <span className="match-report-team-mark" />}
                <strong>{report.home_team.name}</strong>
                {report.home_team.instagram_url && <a href={report.home_team.instagram_url} target="_blank" rel="noreferrer">Instagram ↗</a>}
              </div>
              <div className="match-report-score">
                {report.result
                  ? <strong>{report.result.home_score} <span>–</span> {report.result.away_score}</strong>
                  : <strong>VS</strong>}
                <span>{report.report_available ? "FINAL RESULT" : report.fixture.status.replaceAll("_", " ").toUpperCase()}</span>
              </div>
              <div className="match-report-team">
                {crestUrl(report.away_team.badge_path)
                  ? <img src={crestUrl(report.away_team.badge_path) || ""} alt={report.away_team.name + " crest"} />
                  : <span className="match-report-team-mark" />}
                <strong>{report.away_team.name}</strong>
                {report.away_team.instagram_url && <a href={report.away_team.instagram_url} target="_blank" rel="noreferrer">Instagram ↗</a>}
              </div>
            </section>

            {report.venue && (
              <section className="match-report-section">
                <h2>VENUE</h2>
                <p>{[report.venue.address, report.venue.town, report.venue.region].filter(Boolean).join(", ") || report.venue.name}</p>
              </section>
            )}

            {!report.report_available ? (
              <section className="match-report-upcoming">
                <p className="eyebrow eyebrow-dark">FIXTURE DETAILS</p>
                <h2>THE MATCH IS YET TO BE PLAYED</h2>
                <p>The full match report will appear here once the result has been confirmed by an Open Play administrator.</p>
              </section>
            ) : (
              <>
                <section className="match-report-section">
                  <h2>GOALSCORERS</h2>
                  {report.goals.length === 0
                    ? <p>No goalscorers have been recorded for this fixture.</p>
                    : <div className="match-report-goals">{report.goals.map((goal, index) => (
                      <div className="match-report-goal" key={goal.season_team_id + "-" + index}>
                        <span className="match-report-goal-icon">⚽</span>
                        <strong>{goal.scorer_name}</strong>
                        <span>{goal.team_name}</span>
                      </div>
                    ))}</div>}
                </section>

                <section className="match-report-section">
                  <h2>TEAM LINE-UPS</h2>
                  {report.lineups.length === 0
                    ? <p>Locked team sheets are not available for this fixture.</p>
                    : <div className="match-report-lineups">{report.lineups.map(lineup => {
                      const starters = lineup.players.filter(player => player.role === "starter");
                      const substitutes = lineup.players.filter(player => player.role === "substitute");
                      return (
                        <article className="match-report-lineup" key={lineup.season_team_id}>
                          <h3>{lineup.team_name}</h3>
                          <p className="eyebrow eyebrow-dark">STARTING LINE-UP</p>
                          {starters.map((player, index) => (
                            <div className="match-report-player" key={player.competition_player_id || player.name + index}>
                              <span>{player.squad_number ?? "—"}</span><strong>{player.name}{player.is_goalkeeper ? " · GK" : ""}</strong>
                              <small>{player.did_appear ? "Played" : "Did not appear"}</small>
                            </div>
                          ))}
                          <p className="eyebrow eyebrow-dark match-report-sub-heading">SUBSTITUTES</p>
                          {substitutes.length === 0
                            ? <p>No substitutes recorded.</p>
                            : substitutes.map((player, index) => (
                              <div className="match-report-player" key={player.competition_player_id || player.name + index}>
                                <span>{player.squad_number ?? "—"}</span><strong>{player.name}</strong>
                                <small>{player.did_appear ? "Played" : "Did not appear"}</small>
                              </div>
                            ))}
                        </article>
                      );
                    })}</div>}
                </section>

                <section className="match-report-section">
                  <h2>PLAYER PERFORMANCE</h2>
                  {performance.length === 0
                    ? <p>Player appearance details are not available for this fixture.</p>
                    : <div className="table-scroll"><table className="match-report-performance"><thead><tr><th>Player</th><th>Team</th><th>Played</th><th>Goals</th><th>Assists</th></tr></thead><tbody>{performance.map((player, index) => (
                      <tr key={player.competition_player_id || player.name + index}>
                        <td>{player.name}</td><td>{player.team_name}</td><td>{player.did_appear ? "Yes" : "No"}</td><td>{player.goals}</td><td>Not recorded</td>
                      </tr>
                    ))}</tbody></table></div>}
                </section>

                <section className="match-report-section">
                  <h2>MAN OF THE MATCH</h2>
                  {report.motm_available && report.motm
                    ? <p><strong>{report.motm.player_name}</strong> · {report.motm.team_name}</p>
                    : <p>Man of the Match information is not available for this fixture yet.</p>}
                </section>

                <section className="match-report-section">
                  <h2>MATCH EVENTS</h2>
                  {report.match_events_available && report.events.length > 0
                    ? report.events.map((event, index) => <p key={index}>{event.minute ? event.minute + "' · " : ""}{event.description || event.event_type}</p>)
                    : <p>Minute-by-minute events and disciplinary details are not yet captured by the match recording workflow.</p>}
                  {!report.assists_available && <p className="match-report-data-note">Assists are not currently recorded in the result workflow.</p>}
                </section>
              </>
            )}
          </>
        )}
        <div className="match-report-links"><Link className="auth-switch" to="/player">Back to My Fixtures</Link><Link className="auth-switch" to="/match-centre">Back to Match Centre</Link></div>
      </section>
      <RefereeBottomNavigation />
    </main>
  );
}
