import { useEffect, useMemo, useState } from "react";
import { AuthenticatedSessionBoundary } from "../components/authenticated-session-boundary";
import { Link, createFileRoute, useNavigate } from "@tanstack/react-router";
import { RefereeBottomNavigation } from "../components/referee-bottom-navigation";
import { getSupabaseClient } from "../lib/supabase/client";
import { useOpenPlayAnalytics } from "../components/analytics-provider";

type RpcClient = {
  rpc(name: string, args?: Record<string, unknown>): Promise<{ data: unknown; error: { message: string } | null }>;
};
type ReportPlayer = {
  competition_player_id: string;
  full_name: string;
  role: "starter" | "substitute";
  is_goalkeeper: boolean;
  disciplinary_inactive: boolean;
};
type CardEvent = {
  season_team_id: string;
  recipient_type: "registered_player" | "bench" | "supporter";
  card_type: "yellow" | "second_yellow_red" | "straight_red";
  competition_player_id: string | null;
  minute: string;
  description: string;
};
type ExistingReport = {
  id: string;
  status: "submitted" | "rejected" | "approved" | "voided";
  version: number;
  home_score: number;
  away_score: number;
  home_scorers: string[];
  away_scorers: string[];
  home_substitute_appearances: string[];
  away_substitute_appearances: string[];
  disciplinary_events: Array<{
    season_team_id: string;
    recipient_type: CardEvent["recipient_type"];
    card_type: CardEvent["card_type"];
    competition_player_id?: string | null;
    minute?: number | null;
    description?: string | null;
  }>;
  match_write_up: string | null;
  review_reason: string | null;
};
type ReportOptions = {
  fixture: {
    id: string;
    gameweek: number;
    fixture_number: number;
    scheduled_at: string;
    home_team_id: string;
    home_team_name: string;
    away_team_id: string;
    away_team_name: string;
  };
  latest_gameweek: number | null;
  report_deadline_at: string | null;
  can_submit: boolean;
  report: ExistingReport | null;
  home_players: ReportPlayer[];
  away_players: ReportPlayer[];
};

export const Route = createFileRoute("/referee_/report/$fixtureId")({ component: RefereeMatchReportPage });

function RefereeMatchReportPage(){
 return <AuthenticatedSessionBoundary label="REFEREE MATCH REPORT"><RefereeMatchReportWorkspace/></AuthenticatedSessionBoundary>;
}

function RefereeMatchReportWorkspace() {
  const capture = useOpenPlayAnalytics();
  const { fixtureId } = Route.useParams();
  const navigate = useNavigate();
  const [options, setOptions] = useState<ReportOptions | null>(null);
  const [homeScore, setHomeScore] = useState("0");
  const [awayScore, setAwayScore] = useState("0");
  const [homeScorers, setHomeScorers] = useState<string[]>([]);
  const [awayScorers, setAwayScorers] = useState<string[]>([]);
  const [homeSubs, setHomeSubs] = useState<string[]>([]);
  const [awaySubs, setAwaySubs] = useState<string[]>([]);
  const [cards, setCards] = useState<CardEvent[]>([]);
  const [writeUp, setWriteUp] = useState("");
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");

  useEffect(() => {
    let alive = true;
    async function load() {
      const supabase = getSupabaseClient();
      const { data: { session } } = await supabase.auth.getSession();
      if (!alive) return;
      if (!session) {
        void navigate({ to: "/sign-in", replace: true });
        return;
      }
      const result = await (supabase as unknown as RpcClient).rpc("get_my_referee_fixture_report_options", { p_fixture_id: fixtureId });
      if (!alive) return;
      if (result.error) {
        setError(result.error.message);
        capture("data_load_failed", { feature: "referee_match_report", error_code: "network_error", outcome: "failure" });
      } else {
        const value = result.data as ReportOptions;
        setOptions(value);
        capture("feature_opened", { feature: "referee_match_report", outcome: "success" });
        const report = value.report;
        if (report) {
          setHomeScore(String(report.home_score));
          setAwayScore(String(report.away_score));
          setHomeScorers(report.home_scorers ?? []);
          setAwayScorers(report.away_scorers ?? []);
          setHomeSubs(report.home_substitute_appearances ?? []);
          setAwaySubs(report.away_substitute_appearances ?? []);
          setCards((report.disciplinary_events ?? []).map((event) => ({
            season_team_id: event.season_team_id,
            recipient_type: event.recipient_type,
            card_type: event.card_type,
            competition_player_id: event.competition_player_id ?? null,
            minute: event.minute == null ? "" : String(event.minute),
            description: event.description ?? "",
          })));
          setWriteUp(report.match_write_up ?? "");
        }
      }
      setLoading(false);
    }
    void load();
    return () => { alive = false; };
  }, [capture, fixtureId, navigate]);

  const homeScorerOptions = useMemo(() => options?.home_players.filter((player) =>
    player.role === "starter" || homeSubs.includes(player.competition_player_id)) ?? [], [options, homeSubs]);
  const awayScorerOptions = useMemo(() => options?.away_players.filter((player) =>
    player.role === "starter" || awaySubs.includes(player.competition_player_id)) ?? [], [options, awaySubs]);

  function resizeScorers(value: string, current: string[], setter: (next: string[]) => void) {
    const count = Math.max(0, Math.min(30, Number(value) || 0));
    setter(Array.from({ length: count }, (_, index) => current[index] ?? ""));
  }

  function updateCard(index: number, patch: Partial<CardEvent>) {
    setCards((current) => current.map((card, cardIndex) => cardIndex === index ? { ...card, ...patch } : card));
  }

  async function submitReport(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!options?.can_submit) return;
    const home = Number(homeScore);
    const away = Number(awayScore);
    if (!Number.isInteger(home) || !Number.isInteger(away) || home < 0 || away < 0) {
      setError("Enter a valid whole-number score for both teams.");
      return;
    }
    if (cards.some((card) => card.recipient_type === "registered_player" && !card.competition_player_id)) {
      setError("Choose the registered player for each player card.");
      return;
    }
    setSaving(true);
    setError("");
    setNotice("");
    const rpc = getSupabaseClient() as unknown as RpcClient;
    const result = await rpc.rpc("submit_referee_match_report", {
      p_fixture_id: fixtureId,
      p_home_score: home,
      p_away_score: away,
      p_home_substitute_appearances: homeSubs,
      p_away_substitute_appearances: awaySubs,
      p_home_scorers: homeScorers.filter(Boolean),
      p_away_scorers: awayScorers.filter(Boolean),
      p_disciplinary_events: cards.map((card) => ({
        season_team_id: card.season_team_id,
        recipient_type: card.recipient_type,
        card_type: card.card_type,
        competition_player_id: card.recipient_type === "registered_player" ? card.competition_player_id : null,
        minute: card.minute.trim() ? Number(card.minute) : null,
        description: card.description.trim() || null,
      })),
      p_match_write_up: writeUp.trim() || null,
    });
    setSaving(false);
    if (result.error) {
      setError(result.error.message);
      capture("feature_action_failed", { feature: "referee_match_report", error_code: "unexpected_error", outcome: "failure" });
      return;
    }
    capture("feature_action_completed", { feature: "referee_match_report", outcome: "success" });
    setNotice("Match report submitted. It is now awaiting administrator approval.");
    setOptions((current) => current ? {
      ...current,
      can_submit: false,
      report: {
        id: String(result.data),
        status: "submitted",
        version: (current.report?.version ?? 0) + 1,
        home_score: home,
        away_score: away,
        home_scorers: homeScorers.filter(Boolean),
        away_scorers: awayScorers.filter(Boolean),
        home_substitute_appearances: homeSubs,
        away_substitute_appearances: awaySubs,
        disciplinary_events: cards.map((card) => ({
          season_team_id: card.season_team_id,
          recipient_type: card.recipient_type,
          card_type: card.card_type,
          competition_player_id: card.competition_player_id,
          minute: card.minute.trim() ? Number(card.minute) : null,
          description: card.description,
        })),
        match_write_up: writeUp,
        review_reason: null,
      },
    } : current);
  }

  const fixture = options?.fixture;
  const report = options?.report;
  const canEdit = Boolean(options?.can_submit);

  return (
    <main className="notice-page player-facing">
      <section className="notice-panel hub-panel">
        <Link className="notice-brand" to="/referee"><img className="open-play-logo" src="/open-play-logo.png" alt="Open Play" /></Link>
        <p className="eyebrow eyebrow-dark">OPEN PLAY · OFFICIALS</p>
        <h1>Match<br /><em>report.</em></h1>
        {loading ? <p className="form-note" role="status">Loading fixture and team sheets…</p> : error && !options ? (
          <p className="form-note" role="alert">{error}</p>
        ) : fixture && options ? (
          <>
            <section className="hub-memberships">
              <div className="hub-section-heading"><span className="hub-kicker">GAMEWEEK {fixture.gameweek} · FIXTURE {fixture.fixture_number}</span></div>
              <h2>{fixture.home_team_name} v {fixture.away_team_name}</h2>
              <p>{new Date(fixture.scheduled_at).toLocaleString("en-GB", { dateStyle: "full", timeStyle: "short" })}</p>
              {options.report_deadline_at && <p className="form-note">Initial referee submission closes {new Date(options.report_deadline_at).toLocaleString("en-GB", { dateStyle: "medium", timeStyle: "short" })}. Rejected reports remain available for correction.</p>}
              {report?.status === "rejected" && <p className="form-error" role="alert">Returned by an administrator: {report.review_reason ?? "Please review and correct this report."}</p>}
              {report?.status === "approved" && <p className="form-success" role="status">This report has been approved and the official result has been published.</p>}
              {report?.status === "submitted" && <p className="form-note">Your report is awaiting administrator review.</p>}
              {report?.status === "voided" && <p className="form-error">This report was voided by an administrator and cannot be resubmitted.</p>}
              {!canEdit && !report && <p className="form-note">The reporting window has closed or this is not the latest completed gameweek. Contact an administrator if a report is still required.</p>}
            </section>
            <form className="finance-entry-form" onSubmit={submitReport}>
              <div className="hub-section-heading"><span className="hub-kicker">FINAL SCORE</span></div>
              <div className="finance-filters">
                <label>{fixture.home_team_name}<input type="number" min="0" max="30" required value={homeScore} onChange={(event) => { setHomeScore(event.target.value); resizeScorers(event.target.value, homeScorers, setHomeScorers); }} disabled={!canEdit} /></label>
                <label>{fixture.away_team_name}<input type="number" min="0" max="30" required value={awayScore} onChange={(event) => { setAwayScore(event.target.value); resizeScorers(event.target.value, awayScorers, setAwayScorers); }} disabled={!canEdit} /></label>
              </div>

              <div className="hub-section-heading"><span className="hub-kicker">SUBSTITUTE APPEARANCES</span></div>
              <p className="form-note">Starting players are automatically counted as appearances. Select every substitute who played.</p>
              <div className="finance-filters">
                <div><strong>{fixture.home_team_name}</strong>{options.home_players.filter((player) => player.role === "substitute").map((player) => (
                  <label className="finance-checkbox" key={player.competition_player_id}>
                    <input type="checkbox" checked={homeSubs.includes(player.competition_player_id)} disabled={!canEdit}
                      onChange={(event) => setHomeSubs((current) => event.target.checked ? [...current, player.competition_player_id] : current.filter((id) => id !== player.competition_player_id))} />
                    {player.full_name}{player.disciplinary_inactive ? " · inactive" : ""}
                  </label>
                ))}</div>
                <div><strong>{fixture.away_team_name}</strong>{options.away_players.filter((player) => player.role === "substitute").map((player) => (
                  <label className="finance-checkbox" key={player.competition_player_id}>
                    <input type="checkbox" checked={awaySubs.includes(player.competition_player_id)} disabled={!canEdit}
                      onChange={(event) => setAwaySubs((current) => event.target.checked ? [...current, player.competition_player_id] : current.filter((id) => id !== player.competition_player_id))} />
                    {player.full_name}{player.disciplinary_inactive ? " · inactive" : ""}
                  </label>
                ))}</div>
              </div>

              <div className="hub-section-heading"><span className="hub-kicker">GOALSCORERS · OPTIONAL</span></div>
              <p className="form-note">Record only confirmed scorers who appeared. Leave a goal unassigned when the scorer is unknown; the final score can still be submitted.</p>
              {Array.from({ length: Math.max(0, Math.min(30, Number(homeScore) || 0)) }, (_, index) => (
                <label key={"home-goal-"+index}>{fixture.home_team_name} · Goal {index + 1}
                  <select value={homeScorers[index] ?? ""} disabled={!canEdit} onChange={(event) => setHomeScorers((current) => current.map((id, i) => i === index ? event.target.value : id))}>
                    <option value="">Not recorded</option>{homeScorerOptions.map((player) => <option key={player.competition_player_id} value={player.competition_player_id}>{player.full_name}</option>)}
                  </select>
                </label>
              ))}
              {Array.from({ length: Math.max(0, Math.min(30, Number(awayScore) || 0)) }, (_, index) => (
                <label key={"away-goal-"+index}>{fixture.away_team_name} · Goal {index + 1}
                  <select value={awayScorers[index] ?? ""} disabled={!canEdit} onChange={(event) => setAwayScorers((current) => current.map((id, i) => i === index ? event.target.value : id))}>
                    <option value="">Not recorded</option>{awayScorerOptions.map((player) => <option key={player.competition_player_id} value={player.competition_player_id}>{player.full_name}</option>)}
                  </select>
                </label>
              ))}

              <div className="hub-section-heading"><span className="hub-kicker">DISCIPLINARY EVENTS</span></div>
              <p className="form-note">Cards are retained on the disciplinary record. Fines are charged to the team.</p>
              {cards.map((card, index) => {
                const teamPlayers = card.season_team_id === fixture.home_team_id ? options.home_players : options.away_players;
                return <div className="admin-sheet-editor" key={"card-"+index}>
                  <label>Team<select value={card.season_team_id} disabled={!canEdit} onChange={(event) => updateCard(index, { season_team_id: event.target.value, competition_player_id: null })}>
                    <option value={fixture.home_team_id}>{fixture.home_team_name}</option>
                    <option value={fixture.away_team_id}>{fixture.away_team_name}</option>
                  </select></label>
                  <label>Recipient<select value={card.recipient_type} disabled={!canEdit} onChange={(event) => updateCard(index, { recipient_type: event.target.value as CardEvent["recipient_type"], competition_player_id: null })}>
                    <option value="registered_player">Registered player</option><option value="bench">Bench / substitute</option><option value="supporter">Supporter</option>
                  </select></label>
                  <label>Card<select value={card.card_type} disabled={!canEdit} onChange={(event) => updateCard(index, { card_type: event.target.value as CardEvent["card_type"] })}>
                    <option value="yellow">Yellow card · £5</option><option value="second_yellow_red">Second yellow / red · £15</option><option value="straight_red">Straight red · £30</option>
                  </select></label>
                  {card.recipient_type === "registered_player" && <label>Player<select required value={card.competition_player_id ?? ""} disabled={!canEdit} onChange={(event) => updateCard(index, { competition_player_id: event.target.value || null })}>
                    <option value="">Choose player</option>{teamPlayers.map((player) => <option key={player.competition_player_id} value={player.competition_player_id}>{player.full_name}</option>)}
                  </select></label>}
                  <label>Match minute<input type="number" min="0" max="120" value={card.minute} disabled={!canEdit} onChange={(event) => updateCard(index, { minute: event.target.value })} placeholder="Optional" /></label>
                  <label>Notes<textarea rows={2} maxLength={500} value={card.description} disabled={!canEdit} onChange={(event) => updateCard(index, { description: event.target.value })} placeholder="Optional incident details" /></label>
                  <button type="button" className="reject" disabled={!canEdit} onClick={() => setCards((current) => current.filter((_, i) => i !== index))}>REMOVE CARD</button>
                </div>;
              })}
              <button type="button" className="button secondary" disabled={!canEdit || cards.length >= 50}
                onClick={() => setCards((current) => [...current, { season_team_id: fixture.home_team_id, recipient_type: "registered_player", card_type: "yellow", competition_player_id: null, minute: "", description: "" }])}>
                ADD CARD EVENT
              </button>

              <div className="hub-section-heading"><span className="hub-kicker">MATCH WRITE-UP</span></div>
              <label>Optional match notes<textarea rows={4} maxLength={2000} value={writeUp} disabled={!canEdit} onChange={(event) => setWriteUp(event.target.value)} placeholder="Add any important match notes for the administrator." /></label>
              {error && <p className="form-error" role="alert">{error}</p>}
              {notice && <p className="form-success" role="status">{notice}</p>}
              <button className="button" type="submit" disabled={!canEdit || saving}>{saving ? "SUBMITTING…" : report?.status === "rejected" ? "RESUBMIT CORRECTED REPORT" : "SUBMIT MATCH REPORT"}</button>
            </form>
          </>
        ) : <p className="form-note">Unable to load this fixture report.</p>}
        <Link className="auth-switch" to="/referee/matchday">Back to Matchday</Link>
      </section>
      <RefereeBottomNavigation />
    </main>
  );
}
