import { useEffect, useState, type FormEvent } from "react";
import { getSupabaseClient } from "../lib/supabase/client";
import {
  eligibleAssisters,
  eligibleScorers,
  toGoalEventPayload,
  validateGoalEvents,
  type FixtureSheets,
  type GoalEvent,
  type TeamSide,
} from "../lib/competition/goal-events";

type CompletedFixture = {
  id: string;
  gameweek: number;
  home_team_name: string;
  away_team_name: string;
  status: string;
  home_score: number | null;
  away_score: number | null;
};

type ScorerOptions = {
  home_players: FixtureSheets["home"];
  away_players: FixtureSheets["away"];
  home_sheet_submitted: boolean;
  away_sheet_submitted: boolean;
};

const emptyEvent = (teamSide: TeamSide): GoalEvent => ({ teamSide, scorerId: "", isOwnGoal: false, assistId: null });

/**
 * Records scorers, assists and own goals for a published result. The official score stays
 * authoritative: goals may be left unattributed. The server re-validates every event.
 */
export function AdminGoalEvents({ fixtures }: { fixtures: CompletedFixture[] }) {
  const eligible = fixtures.filter((f) => f.status === "completed" && f.home_score !== null && f.away_score !== null);
  const [fixtureId, setFixtureId] = useState("");
  const [sheets, setSheets] = useState<FixtureSheets | null>(null);
  const [events, setEvents] = useState<GoalEvent[]>([]);
  const [reason, setReason] = useState("");
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const fixture = eligible.find((f) => f.id === fixtureId) ?? null;

  useEffect(() => {
    if (!fixtureId) {
      setSheets(null);
      return;
    }
    let alive = true;
    setLoading(true);
    setError("");
    setNotice("");
    setEvents([]);
    void getSupabaseClient()
      .rpc("get_admin_fixture_scorer_options", { p_fixture_id: fixtureId })
      .then(({ data, error: rpcError }) => {
        if (!alive) return;
        setLoading(false);
        if (rpcError) {
          setError(rpcError.message);
          setSheets(null);
          return;
        }
        const options = data as unknown as ScorerOptions;
        if (!options.home_sheet_submitted || !options.away_sheet_submitted) {
          setError("Both team sheets must be locked before goal events can be recorded.");
          setSheets(null);
          return;
        }
        setSheets({ home: options.home_players, away: options.away_players });
      });
    return () => {
      alive = false;
    };
  }, [fixtureId]);

  function update(index: number, patch: Partial<GoalEvent>) {
    setEvents((current) =>
      current.map((event, i) => {
        if (i !== index) return event;
        const next = { ...event, ...patch };
        // Changing side or own-goal invalidates the chosen players.
        if (patch.teamSide !== undefined || patch.isOwnGoal !== undefined) {
          next.scorerId = "";
          next.assistId = null;
        }
        if (next.isOwnGoal) next.assistId = null;
        if (next.assistId === next.scorerId) next.assistId = null;
        return next;
      }),
    );
  }

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!fixture || !sheets) return;
    const problems = validateGoalEvents(events, sheets, { home: fixture.home_score ?? 0, away: fixture.away_score ?? 0 });
    if (problems.length) {
      setError(problems.join(" "));
      return;
    }
    setSaving(true);
    setError("");
    const { data, error: rpcError } = await getSupabaseClient().rpc("admin_record_fixture_goal_events", {
      p_fixture_id: fixture.id,
      p_events: toGoalEventPayload(events),
      p_reason: reason,
    });
    setSaving(false);
    if (rpcError) {
      setError(rpcError.message);
      return;
    }
    const result = data as { recorded: number; unattributed_home: number; unattributed_away: number };
    setNotice(
      `Recorded ${result.recorded} goal event${result.recorded === 1 ? "" : "s"}. ` +
        `Unattributed: ${result.unattributed_home} home, ${result.unattributed_away} away. Statistics update immediately.`,
    );
    setReason("");
  }

  const nameOf = (side: TeamSide) => (side === "home" ? fixture?.home_team_name : fixture?.away_team_name) ?? side;

  return (
    <form className="admin-setup-form admin-goal-events" onSubmit={submit} aria-labelledby="goal-events-heading">
      <h3 id="goal-events-heading">Scorers, assists and own goals</h3>
      <p className="form-note">Replaces this fixture's goal attribution; earlier entries are kept in history.</p>
      <label>
        Completed fixture
        <select value={fixtureId} onChange={(e) => setFixtureId(e.target.value)}>
          <option value="">Choose a fixture with a published result</option>
          {eligible.map((f) => (
            <option key={f.id} value={f.id}>
              GW{f.gameweek}: {f.home_team_name} {f.home_score}–{f.away_score} {f.away_team_name}
            </option>
          ))}
        </select>
      </label>
      {eligible.length === 0 && <p className="form-note">No completed fixtures with published results in this view.</p>}
      {loading && <p className="form-note" role="status">Loading team sheets…</p>}
      {fixture && sheets && (
        <>
          {events.map((goal, index) => {
            const scorers = eligibleScorers(sheets, goal.teamSide, goal.isOwnGoal);
            const assisters = eligibleAssisters(sheets, goal);
            return (
              <fieldset className="admin-goal-event" key={index}>
                <legend>Goal {index + 1}</legend>
                <label>
                  Credited to
                  <select value={goal.teamSide} onChange={(e) => update(index, { teamSide: e.target.value as TeamSide })}>
                    <option value="home">{nameOf("home")}</option>
                    <option value="away">{nameOf("away")}</option>
                  </select>
                </label>
                <label className="admin-goal-own">
                  <input type="checkbox" checked={goal.isOwnGoal} onChange={(e) => update(index, { isOwnGoal: e.target.checked })} />
                  Own goal (scored by {nameOf(goal.teamSide === "home" ? "away" : "home")})
                </label>
                <label>
                  Scorer
                  <select required value={goal.scorerId} onChange={(e) => update(index, { scorerId: e.target.value })}>
                    <option value="">Choose scorer</option>
                    {scorers.map((p) => <option key={p.competition_player_id} value={p.competition_player_id}>{p.full_name}</option>)}
                  </select>
                </label>
                {!goal.isOwnGoal && (
                  <label>
                    Assist (optional)
                    <select value={goal.assistId ?? ""} onChange={(e) => update(index, { assistId: e.target.value || null })}>
                      <option value="">No assist</option>
                      {assisters.map((p) => <option key={p.competition_player_id} value={p.competition_player_id}>{p.full_name}</option>)}
                    </select>
                  </label>
                )}
                <button type="button" className="reject" onClick={() => setEvents((current) => current.filter((_, i) => i !== index))}>
                  REMOVE GOAL {index + 1}
                </button>
              </fieldset>
            );
          })}
          <div className="captain-actions">
            <button type="button" onClick={() => setEvents((c) => [...c, emptyEvent("home")])} disabled={events.filter((e) => e.teamSide === "home").length >= (fixture.home_score ?? 0)}>
              + {nameOf("home")} GOAL
            </button>
            <button type="button" onClick={() => setEvents((c) => [...c, emptyEvent("away")])} disabled={events.filter((e) => e.teamSide === "away").length >= (fixture.away_score ?? 0)}>
              + {nameOf("away")} GOAL
            </button>
          </div>
          <label>
            Reason (recorded in the audit history)
            <input required minLength={5} value={reason} onChange={(e) => setReason(e.target.value)} placeholder="e.g. Scorers confirmed from referee report" />
          </label>
          <button type="submit" disabled={saving}>{saving ? "SAVING…" : "SAVE GOAL EVENTS"}</button>
        </>
      )}
      {error && <p className="form-error" role="alert">{error}</p>}
      {notice && <p className="form-success" role="status">{notice}</p>}
    </form>
  );
}
