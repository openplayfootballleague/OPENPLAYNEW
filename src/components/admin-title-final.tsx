import { useState, type FormEvent } from "react";
import { getSupabaseClient } from "../lib/supabase/client";

type Leader = { team_id: string; name: string };

/**
 * Owner decision D7: teams level on points in first place play a final. The server
 * (`admin_create_title_final`) re-checks every rule: active season, all league fixtures
 * finished with confirmed results, exactly the two joint leaders, location scope.
 */
export function AdminTitleFinal({ seasonId, seasonStatus, leaders }: { seasonId: string; seasonStatus: string; leaders: Leader[] }) {
  const [homeTeamId, setHomeTeamId] = useState(leaders[0]?.team_id ?? "");
  const [kickOff, setKickOff] = useState("");
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [created, setCreated] = useState("");

  if (leaders.length < 2) return null;
  if (leaders.length > 2) {
    return (
      <p className="form-note" role="status">
        {leaders.length} teams are level on points in first place. The title-decider format for more than two
        teams has not been defined yet, so a final cannot be arranged here.
      </p>
    );
  }
  if (seasonStatus !== "active") {
    return <p className="form-note">A title final can only be arranged while the season is active.</p>;
  }

  const awayTeamId = leaders.find((leader) => leader.team_id !== homeTeamId)?.team_id ?? "";
  const nameOf = (id: string) => leaders.find((leader) => leader.team_id === id)?.name ?? "Team";

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    setCreated("");
    const scheduled = new Date(kickOff);
    if (!kickOff || Number.isNaN(scheduled.getTime())) {
      setError("Choose the date and kick-off time of the final.");
      return;
    }
    setBusy(true);
    const { data, error: rpcError } = await getSupabaseClient().rpc("admin_create_title_final", {
      p_season_id: seasonId,
      p_home_team_id: homeTeamId,
      p_away_team_id: awayTeamId,
      p_scheduled_at: scheduled.toISOString(),
      p_reason: reason,
    });
    setBusy(false);
    if (rpcError) {
      setError(rpcError.message);
      return;
    }
    setCreated(
      `Title final scheduled: ${nameOf(homeTeamId)} v ${nameOf(awayTeamId)}, gameweek ${data?.gameweek ?? "—"}, ` +
        scheduled.toLocaleString("en-GB", { dateStyle: "medium", timeStyle: "short" }) +
        ". Both squads are notified; record its result like any other fixture.",
    );
  }

  if (created) return <p className="form-success" role="status">{created}</p>;

  return (
    <form className="admin-setup-form admin-title-final" onSubmit={submit} aria-labelledby={`title-final-${seasonId}`}>
      <h3 id={`title-final-${seasonId}`}>Arrange the title final</h3>
      <label>
        Home team
        <select value={homeTeamId} onChange={(event) => setHomeTeamId(event.target.value)}>
          {leaders.map((leader) => <option key={leader.team_id} value={leader.team_id}>{leader.name}</option>)}
        </select>
      </label>
      <p className="form-note">Away team: {nameOf(awayTeamId)}</p>
      <label>
        Date and kick-off (UK time)
        <input type="datetime-local" required value={kickOff} onChange={(event) => setKickOff(event.target.value)} />
      </label>
      <label>
        Reason (recorded in the audit history)
        <textarea required minLength={5} rows={2} value={reason} onChange={(event) => setReason(event.target.value)} placeholder="e.g. Level on 31 points after gameweek 14" />
      </label>
      {error && <p className="form-error" role="alert">{error}</p>}
      <button type="submit" disabled={busy}>{busy ? "SCHEDULING…" : "SCHEDULE TITLE FINAL"}</button>
    </form>
  );
}
