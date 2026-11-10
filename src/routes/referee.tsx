import { useEffect, useState } from "react";
import { Link, createFileRoute, useNavigate } from "@tanstack/react-router";
import { RefereeBottomNavigation } from "../components/referee-bottom-navigation";
import { getSupabaseClient } from "../lib/supabase/client";

type RpcError = { message: string };
type RpcClient = {
  rpc(name: string, args?: Record<string, unknown>): Promise<{ data: unknown; error: RpcError | null }>;
};
type RefereeLocation = { id: string; name: string; town: string; region: string };
type RefereeApplication = {
  id: string;
  status: "pending" | "approved" | "rejected";
  experience_summary: string;
  qualifications: string[];
  availability: Array<{ weekday: number; start_time: string; end_time: string }>;
  contact_phone: string;
  preferred_location_ids: string[];
  additional_notes: string | null;
  submitted_at: string;
  reviewed_at: string | null;
  review_reason: string | null;
};
type RefereeMembership = {
  status: "active" | "suspended";
  approved_at: string;
  status_changed_at: string;
  status_reason: string;
};
type PortalState = { application: RefereeApplication | null; membership: RefereeMembership | null };
type AvailabilitySlot = { weekday: string; start_time: string; end_time: string };

const weekdays = [
  { value: "1", label: "Monday" },
  { value: "2", label: "Tuesday" },
  { value: "3", label: "Wednesday" },
  { value: "4", label: "Thursday" },
  { value: "5", label: "Friday" },
  { value: "6", label: "Saturday" },
  { value: "7", label: "Sunday" },
];

export const Route = createFileRoute("/referee")({ component: RefereePage });

function RefereePage() {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [state, setState] = useState<PortalState>({ application: null, membership: null });
  const [locations, setLocations] = useState<RefereeLocation[]>([]);
  const [experience, setExperience] = useState("");
  const [qualifications, setQualifications] = useState("");
  const [phone, setPhone] = useState("");
  const [preferredLocations, setPreferredLocations] = useState<string[]>([]);
  const [availability, setAvailability] = useState<AvailabilitySlot[]>([
    { weekday: "5", start_time: "18:00", end_time: "22:00" },
  ]);
  const [notes, setNotes] = useState("");

  useEffect(() => {
    let active = true;
    const supabase = getSupabaseClient();
    const rpc = supabase as unknown as RpcClient;

    async function load() {
      const { data: { session } } = await supabase.auth.getSession();
      if (!active) return;
      if (!session) {
        setLoading(false);
        void navigate({ to: "/sign-in", replace: true });
        return;
      }

      const [portalResult, locationResult] = await Promise.all([
        rpc.rpc("get_my_referee_portal_state"),
        rpc.rpc("get_active_referee_locations"),
      ]);
      if (!active) return;
      if (portalResult.error) setError(portalResult.error.message);
      else if (portalResult.data && typeof portalResult.data === "object") {
        const portal = portalResult.data as PortalState;
        setState({
          application: portal.application ?? null,
          membership: portal.membership ?? null,
        });
        if (portal.application) {
          setExperience(portal.application.experience_summary);
          setQualifications(portal.application.qualifications.join("\n"));
          setPhone(portal.application.contact_phone);
          setPreferredLocations(portal.application.preferred_location_ids);
          setAvailability(portal.application.availability.map((slot) => ({
            weekday: String(slot.weekday),
            start_time: slot.start_time,
            end_time: slot.end_time,
          })));
          setNotes(portal.application.additional_notes ?? "");
        }
      }
      if (locationResult.error) setError((current) => current || locationResult.error!.message);
      else setLocations((locationResult.data ?? []) as RefereeLocation[]);
      setLoading(false);
    }

    void load();
    return () => { active = false; };
  }, [navigate]);

  function updateAvailability(index: number, key: keyof AvailabilitySlot, value: string) {
    setAvailability((current) => current.map((slot, slotIndex) =>
      slotIndex === index ? { ...slot, [key]: value } : slot,
    ));
  }

  function toggleLocation(id: string) {
    setPreferredLocations((current) => current.includes(id)
      ? current.filter((locationId) => locationId !== id)
      : [...current, id]);
  }

  async function submitApplication(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    setNotice("");
    if (preferredLocations.length === 0) {
      setError("Choose at least one preferred location.");
      return;
    }
    if (availability.length === 0 || availability.some((slot) =>
      !slot.weekday || !slot.start_time || !slot.end_time || slot.start_time >= slot.end_time
    )) {
      setError("Check each availability window. The finish time must be after the start time.");
      return;
    }

    setSaving(true);
    const rpc = getSupabaseClient() as unknown as RpcClient;
    const result = await rpc.rpc("submit_referee_application", {
      p_experience_summary: experience,
      p_qualifications: qualifications.split("\n").map((item) => item.trim()).filter(Boolean),
      p_availability: availability.map((slot) => ({
        weekday: Number(slot.weekday),
        start_time: slot.start_time,
        end_time: slot.end_time,
      })),
      p_contact_phone: phone,
      p_preferred_location_ids: preferredLocations,
      p_additional_notes: notes.trim() || null,
    });
    setSaving(false);
    if (result.error) {
      setError(result.error.message);
      return;
    }
    setNotice("Your referee application has been submitted for administrator review.");
    const refreshed = await rpc.rpc("get_my_referee_portal_state");
    if (!refreshed.error && refreshed.data && typeof refreshed.data === "object") {
      const portal = refreshed.data as PortalState;
      setState({ application: portal.application ?? null, membership: portal.membership ?? null });
    }
  }

  const application = state.application;
  const canApply = !application || application.status === "rejected";

  return (
    <main className="notice-page player-facing">
      <section className="notice-panel hub-panel">
        <Link className="notice-brand" to="/">
          <img className="open-play-logo" src="/open-play-logo.png" alt="Open Play" />
        </Link>
        <p className="eyebrow eyebrow-dark">OPEN PLAY · OFFICIALS</p>
        <h1>Referee<br /><em>workspace.</em></h1>
        <p>Apply to officiate Open Play fixtures and manage your referee membership.</p>

        {loading ? <p className="form-note" role="status">Loading your referee workspace…</p> : (
          <>
            {error && <p className="form-note" role="alert">{error}</p>}
            {notice && <p className="form-note" role="status">{notice}</p>}

            {state.membership?.status === "active" ? (
              <section className="hub-memberships">
                <div className="hub-section-heading"><span className="hub-kicker">MEMBERSHIP</span></div>
                <h2>You're an approved Open Play referee.</h2>
                <p>Your referee membership is active. View your appointments, open assigned fixtures and submit official match reports from your matchday workspace.</p>
                <p className="form-note">Approved {new Date(state.membership.approved_at).toLocaleDateString("en-GB")}</p>
                <Link className="admin-inline-action" to="/referee/matchday">OPEN MATCHDAY WORKSPACE <span aria-hidden="true">↗</span></Link>
                <Link className="admin-inline-action" to="/match-centre">MATCH CENTRE <span aria-hidden="true">↗</span></Link>
                <Link className="admin-inline-action" to="/teams">TEAMS <span aria-hidden="true">↗</span></Link>
              </section>
            ) : state.membership?.status === "suspended" ? (
              <section className="hub-memberships">
                <div className="hub-section-heading"><span className="hub-kicker">MEMBERSHIP SUSPENDED</span></div>
                <p>Your referee membership is currently suspended. Contact an Open Play administrator if you need clarification.</p>
                <p className="form-note">Reason: {state.membership.status_reason}</p>
              </section>
            ) : application?.status === "pending" ? (
              <section className="hub-memberships">
                <div className="hub-section-heading"><span className="hub-kicker">APPLICATION RECEIVED</span></div>
                <h2>Waiting for administrator review.</h2>
                <p>Your application was submitted on {new Date(application.submitted_at).toLocaleDateString("en-GB")}. We'll update your workspace when a decision is recorded.</p>
              </section>
            ) : null}

            {canApply && state.membership?.status !== "suspended" && (
              <section className="hub-memberships">
                <div className="hub-section-heading"><span className="hub-kicker">{application?.status === "rejected" ? "REAPPLY" : "REFEREE APPLICATION"}</span></div>
                {application?.status === "rejected" && application.review_reason && (
                  <p className="form-note">Previous decision: {application.review_reason}</p>
                )}
                <form className="admin-setup-form" onSubmit={submitApplication}>
                  <label>
                    Refereeing experience
                    <textarea required minLength={1} maxLength={2000} rows={4} value={experience} onChange={(event) => setExperience(event.target.value)} placeholder="Tell us about your refereeing or relevant football experience." />
                  </label>
                  <label>
                    Qualifications (optional, one per line)
                    <textarea rows={3} value={qualifications} onChange={(event) => setQualifications(event.target.value)} placeholder="e.g. FA Referee Course" />
                  </label>
                  <label>
                    Contact telephone
                    <input required type="tel" minLength={7} maxLength={40} value={phone} onChange={(event) => setPhone(event.target.value)} placeholder="Your contact number" />
                  </label>
                  <div>
                    <strong>Preferred locations</strong>
                    <p className="form-note">Choose the areas where you can referee.</p>
                    {locations.length === 0 ? <p className="form-note">No active locations are currently accepting referee applications.</p> : locations.map((location) => (
                      <label className="admin-appearance-choice" key={location.id}>
                        <input type="checkbox" checked={preferredLocations.includes(location.id)} onChange={() => toggleLocation(location.id)} />
                        {location.name} · {location.town}
                      </label>
                    ))}
                  </div>
                  <div>
                    <strong>Availability</strong>
                    <p className="form-note">Add the days and times you are normally available.</p>
                    {availability.map((slot, index) => (
                      <div className="admin-setup-form" key={index}>
                        <label>Day
                          <select value={slot.weekday} onChange={(event) => updateAvailability(index, "weekday", event.target.value)}>
                            {weekdays.map((day) => <option key={day.value} value={day.value}>{day.label}</option>)}
                          </select>
                        </label>
                        <label>From <input type="time" required value={slot.start_time} onChange={(event) => updateAvailability(index, "start_time", event.target.value)} /></label>
                        <label>Until <input type="time" required value={slot.end_time} onChange={(event) => updateAvailability(index, "end_time", event.target.value)} /></label>
                        {availability.length > 1 && <button type="button" className="reject" onClick={() => setAvailability((current) => current.filter((_, slotIndex) => slotIndex !== index))}>REMOVE AVAILABILITY</button>}
                      </div>
                    ))}
                    {availability.length < 21 && <button type="button" onClick={() => setAvailability((current) => [...current, { weekday: "5", start_time: "18:00", end_time: "22:00" }])}>ADD AVAILABILITY</button>}
                  </div>
                  <label>
                    Additional information (optional)
                    <textarea rows={3} maxLength={2000} value={notes} onChange={(event) => setNotes(event.target.value)} placeholder="Anything else you'd like the referee coordinator to know." />
                  </label>
                  <p className="form-note">Submitting an application does not grant referee access. An administrator must review and approve it first.</p>
                  <button type="submit" disabled={saving || locations.length === 0 || preferredLocations.length === 0}>
                    {saving ? "SUBMITTING…" : "SUBMIT REFEREE APPLICATION"}
                  </button>
                </form>
              </section>
            )}
          </>
        )}
        <Link className="auth-switch" to="/more">Back to More</Link>
      </section>
      <RefereeBottomNavigation />
    </main>
  );
}
