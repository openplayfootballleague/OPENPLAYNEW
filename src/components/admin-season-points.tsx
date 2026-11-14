import { useEffect, useState, type FormEvent } from "react";
import { getSupabaseClient } from "../lib/supabase/client";

/**
 * Season points rules (competition spec: configurable win/draw/loss points).
 * `admin_set_season_points` enforces location scope, ordering (win >= draw >= loss >= 0),
 * an audit reason, and locks the rules once the season has a published result.
 */
export function AdminSeasonPoints({ seasonId }: { seasonId: string }) {
  const [current, setCurrent] = useState<{ win: number; draw: number; loss: number } | null>(null);
  const [form, setForm] = useState({ win: 3, draw: 1, loss: 0 });
  const [reason, setReason] = useState("");
  const [loadError, setLoadError] = useState("");
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    let alive = true;
    setLoadError("");
    void getSupabaseClient().from("seasons").select("points_for_win,points_for_draw,points_for_loss").eq("id", seasonId).maybeSingle()
      .then(({ data, error: queryError }) => {
        if (!alive) return;
        if (queryError || !data) {
          setLoadError(queryError?.message ?? "Season points could not be loaded.");
          return;
        }
        const value = { win: data.points_for_win, draw: data.points_for_draw, loss: data.points_for_loss };
        setCurrent(value);
        setForm(value);
      });
    return () => {
      alive = false;
    };
  }, [seasonId]);

  async function save(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    setNotice("");
    if (!(form.win >= form.draw && form.draw >= form.loss && form.loss >= 0)) {
      setError("Points must satisfy win ≥ draw ≥ loss ≥ 0.");
      return;
    }
    setSaving(true);
    const { data, error: rpcError } = await getSupabaseClient().rpc("admin_set_season_points", {
      p_season_id: seasonId, p_points_for_win: form.win, p_points_for_draw: form.draw, p_points_for_loss: form.loss, p_reason: reason,
    });
    setSaving(false);
    if (rpcError) {
      setError(rpcError.message);
      return;
    }
    const saved = { win: data.points_for_win, draw: data.points_for_draw, loss: data.points_for_loss };
    setCurrent(saved);
    setReason("");
    setNotice(`Points saved: ${saved.win} for a win, ${saved.draw} for a draw, ${saved.loss} for a loss. Reload the statistics to see the table.`);
  }

  if (loadError) return <p className="form-error" role="alert">{loadError}</p>;
  if (!current) return <p className="form-note" role="status">Loading season points…</p>;

  return (
    <form className="admin-setup-form admin-season-points" onSubmit={save} aria-labelledby={`season-points-${seasonId}`}>
      <h3 id={`season-points-${seasonId}`}>League points for this season</h3>
      <p className="form-note">Currently {current.win}/{current.draw}/{current.loss}. Teams level on points share a position; a shared first place is decided by a final. Points lock once a result is published.</p>
      <div className="admin-season-points-grid">
        {(["win", "draw", "loss"] as const).map((key) => (
          <label key={key}>
            Points for a {key}
            <input type="number" min={0} max={10} required value={form[key]} onChange={(e) => setForm({ ...form, [key]: Number(e.target.value) })} />
          </label>
        ))}
      </div>
      <label>
        Reason (recorded in the audit history)
        <input required minLength={5} value={reason} onChange={(e) => setReason(e.target.value)} placeholder="e.g. Two points for a win agreed for this season" />
      </label>
      {error && <p className="form-error" role="alert">{error}</p>}
      {notice && <p className="form-success" role="status">{notice}</p>}
      <button type="submit" disabled={saving}>{saving ? "SAVING…" : "SAVE POINTS"}</button>
    </form>
  );
}
