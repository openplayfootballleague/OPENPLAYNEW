import { useCallback, useEffect, useState } from "react";
import { getSupabaseClient } from "../lib/supabase/client";

type DisciplinarySuspension = {
  competition_player_id: string;
  player_name: string;
  disciplinary_strikes: number;
  last_straight_red_at: string;
  last_fixture_id: string;
  last_gameweek: number;
  last_team_name: string;
};

type RpcClient = {
  rpc(name: string, args?: Record<string, unknown>): Promise<{ data: unknown; error: { message: string } | null }>;
};

export function AdminDisciplinarySuspensions() {
  const [rows, setRows] = useState<DisciplinarySuspension[]>([]);
  const [reasons, setReasons] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState("");
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const client = getSupabaseClient() as unknown as RpcClient;
      const { data, error: rpcError } = await client.rpc("admin_list_disciplinary_suspensions", {
        p_location_id: null,
      });
      if (rpcError) throw new Error(rpcError.message);
      setRows((data ?? []) as DisciplinarySuspension[]);
    } catch (cause) {
      setRows([]);
      setError(cause instanceof Error ? cause.message : "Unable to load disciplinary records.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { void load(); }, [load]);

  async function approveReturn(row: DisciplinarySuspension) {
    const reason = (reasons[row.competition_player_id] ?? "").trim();
    if (reason.length < 5) {
      setError("Enter a reason of at least 5 characters before approving a return.");
      return;
    }
    setBusy(row.competition_player_id);
    setError("");
    setNotice("");
    try {
      const client = getSupabaseClient() as unknown as RpcClient;
      const { error: rpcError } = await client.rpc("admin_reactivate_disciplined_player", {
        p_competition_player_id: row.competition_player_id,
        p_reason: reason,
      });
      if (rpcError) throw new Error(rpcError.message);
      setNotice(row.player_name + " has been approved to return. Their permanent disciplinary strike count has not been reset.");
      setReasons((current) => ({ ...current, [row.competition_player_id]: "" }));
      await load();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Unable to approve this return.");
    } finally {
      setBusy("");
    }
  }

  return (
    <section className="hub-memberships">
      <div className="hub-section-heading">
        <span className="hub-kicker">DISCIPLINARY RETURN REVIEW</span>
        <span>{rows.length} awaiting review</span>
      </div>
      <p className="form-note">Three approved straight-red incidents make a player ineligible for future team sheets until an authorised administrator reviews their return. Their strike count remains on the permanent competition record.</p>
      {error && <p className="form-error" role="alert">{error}</p>}
      {notice && <p className="form-success" role="status">{notice}</p>}
      {loading ? <p className="form-note">Loading disciplinary records…</p> : rows.length === 0 ? (
        <p className="form-note">No players are currently awaiting disciplinary return review in your permitted locations.</p>
      ) : rows.map((row) => (
        <article className="admin-queue-row" key={row.competition_player_id}>
          <div>
            <strong>{row.player_name}</strong>
            <span>{row.disciplinary_strikes} approved straight-red strikes</span>
            <small>Most recent incident: {new Date(row.last_straight_red_at).toLocaleString("en-GB", { dateStyle: "medium", timeStyle: "short" })}</small>
            <small>Gameweek {row.last_gameweek} · {row.last_team_name}</small>
          </div>
          <div className="admin-sheet-editor">
            <label>
              Reason for approving return (required)
              <textarea rows={2} minLength={5} maxLength={500} value={reasons[row.competition_player_id] ?? ""} onChange={(event) => setReasons((current) => ({ ...current, [row.competition_player_id]: event.target.value }))} placeholder="Record the reason for allowing this player to return." />
            </label>
            <button type="button" disabled={busy === row.competition_player_id || (reasons[row.competition_player_id] ?? "").trim().length < 5} onClick={() => void approveReturn(row)}>
              {busy === row.competition_player_id ? "SAVING…" : "APPROVE RETURN TO PLAY"}
            </button>
          </div>
        </article>
      ))}
      <button type="button" disabled={loading} onClick={() => void load()}>REFRESH DISCIPLINARY QUEUE</button>
    </section>
  );
}
