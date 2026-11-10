import { useCallback, useEffect, useState } from "react";
import { Link, createFileRoute, useNavigate } from "@tanstack/react-router";
import { useRequiredSession } from "../../lib/auth/use-required-session";
import { getSupabaseClient } from "../../lib/supabase/client";

type RpcError = { message: string };
type RpcClient = {
  rpc(name: string, args?: Record<string, unknown>): Promise<{ data: unknown; error: RpcError | null }>;
};
type RefereeFixtureOption = { fixture_id: string; scheduled_at: string; gameweek: number; fixture_number: number; home_team_name: string; away_team_name: string; location_id: string; location_name: string };
type RefereeCandidate = { referee_user_id: string; referee_name: string; referee_email: string; preferred_location_ids: string[]; availability: Array<{ weekday: number; start_time: string; end_time: string }> };
type RefereeAppointment = { assignment_id: string; fixture_id: string; referee_user_id: string; referee_name: string; referee_email: string; assignment_role: "lead" | "assistant"; assigned_at: string; cancelled_at: string | null; cancellation_reason: string | null; scheduled_at: string; gameweek: number; fixture_number: number; location_id: string; location_name: string; home_team_name: string; away_team_name: string };
type RefereeApplication = {
  application_id: string;
  user_id: string;
  player_name: string;
  email: string;
  contact_phone: string;
  experience_summary: string;
  qualifications: string[];
  availability: Array<{ weekday: number; start_time: string; end_time: string }>;
  preferred_location_ids: string[];
  preferred_location_names: string[];
  additional_notes: string | null;
  status: "pending" | "approved" | "rejected";
  submitted_at: string;
  reviewed_at: string | null;
  review_reason: string | null;
};

const dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];

export const Route = createFileRoute("/admin/referees")({ component: AdminRefereesPage });

function AdminRefereesPage() {
  const authStatus = useRequiredSession();
  const navigate = useNavigate();
  const [applications, setApplications] = useState<RefereeApplication[]>([]);
  const [statusFilter, setStatusFilter] = useState("pending");
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState("");
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [reasons, setReasons] = useState<Record<string, string>>({});
  const [fixtures, setFixtures] = useState<RefereeFixtureOption[]>([]);
  const [candidates, setCandidates] = useState<RefereeCandidate[]>([]);
  const [appointments, setAppointments] = useState<RefereeAppointment[]>([]);
  const [selectedFixtureId, setSelectedFixtureId] = useState("");
  const [selectedRefereeId, setSelectedRefereeId] = useState("");
  const [assignmentRole, setAssignmentRole] = useState<"lead" | "assistant">("lead");
  const [allocationLoading, setAllocationLoading] = useState(true);
  const [allocationReason, setAllocationReason] = useState<Record<string, string>>({});

  useEffect(() => {
    if (authStatus === "unauthenticated") void navigate({ to: "/sign-in", replace: true });
  }, [authStatus, navigate]);

  const loadApplications = useCallback(async () => {
    setLoading(true);
    setError("");
    const rpc = getSupabaseClient() as unknown as RpcClient;
    const result = await rpc.rpc("admin_list_referee_applications", { p_status: statusFilter });
    if (result.error) {
      setError(result.error.message);
      setApplications([]);
    } else {
      setApplications((result.data ?? []) as RefereeApplication[]);
    }
    setLoading(false);
  }, [statusFilter]);

  useEffect(() => { void loadApplications(); }, [loadApplications]);

  const loadAllocationData = useCallback(async () => {
    setAllocationLoading(true);
    const rpc = getSupabaseClient() as unknown as RpcClient;
    const [fixtureResult, candidateResult, appointmentResult] = await Promise.all([
      rpc.rpc("admin_list_referee_assignment_fixtures"),
      rpc.rpc("admin_list_referee_assignment_candidates", { p_location_id: null }),
      rpc.rpc("admin_list_referee_appointments", { p_location_id: null, p_include_cancelled: false }),
    ]);
    if (!fixtureResult.error) setFixtures((fixtureResult.data ?? []) as RefereeFixtureOption[]);
    if (!candidateResult.error) setCandidates((candidateResult.data ?? []) as RefereeCandidate[]);
    if (!appointmentResult.error) setAppointments((appointmentResult.data ?? []) as RefereeAppointment[]);
    const firstError = fixtureResult.error ?? candidateResult.error ?? appointmentResult.error;
    if (firstError) setError(firstError.message);
    setAllocationLoading(false);
  }, []);

  useEffect(() => { void loadAllocationData(); }, [loadAllocationData]);

  const selectedFixture = fixtures.find((fixture) => fixture.fixture_id === selectedFixtureId);
  const eligibleCandidates = selectedFixture
    ? candidates.filter((candidate) => candidate.preferred_location_ids.includes(selectedFixture.location_id))
    : [];

  async function assignReferee() {
    if (!selectedFixtureId || !selectedRefereeId) {
      setError("Choose a fixture and an active referee before allocating.");
      return;
    }
    setBusy("allocation");
    setError("");
    setNotice("");
    const rpc = getSupabaseClient() as unknown as RpcClient;
    const result = await rpc.rpc("admin_assign_referee_to_fixture", {
      p_fixture_id: selectedFixtureId,
      p_referee_user_id: selectedRefereeId,
      p_assignment_role: assignmentRole,
    });
    setBusy("");
    if (result.error) {
      setError(result.error.message);
      return;
    }
    setNotice("Referee appointment saved and notification queued.");
    setSelectedRefereeId("");
    await loadAllocationData();
  }

  async function cancelAppointment(appointment: RefereeAppointment) {
    const reason = (allocationReason[appointment.assignment_id] ?? "").trim();
    if (reason.length < 5) {
      setError("Enter a cancellation reason of at least five characters.");
      return;
    }
    setBusy(appointment.assignment_id);
    setError("");
    const rpc = getSupabaseClient() as unknown as RpcClient;
    const result = await rpc.rpc("admin_cancel_referee_fixture_assignment", {
      p_assignment_id: appointment.assignment_id,
      p_reason: reason,
    });
    setBusy("");
    if (result.error) {
      setError(result.error.message);
      return;
    }
    setNotice("Appointment cancelled, with the history retained and referee notified.");
    await loadAllocationData();
  }

  async function decide(application: RefereeApplication, decision: "approved" | "rejected") {
    const reason = (reasons[application.application_id] ?? "").trim();
    if (reason.length < 5) {
      setError("Enter a review reason of at least five characters before making a decision.");
      return;
    }
    setBusy(application.application_id);
    setError("");
    setNotice("");
    const rpc = getSupabaseClient() as unknown as RpcClient;
    const result = await rpc.rpc("review_referee_application", {
      p_application_id: application.application_id,
      p_decision: decision,
      p_reason: reason,
    });
    setBusy("");
    if (result.error) {
      setError(result.error.message);
      return;
    }
    setNotice(decision === "approved"
      ? `${application.player_name} has been approved as an Open Play referee.`
      : `${application.player_name}'s application has been rejected.`);
    await loadApplications();
  }

  return (
    <main className="notice-page player-facing">
      <section className="notice-panel hub-panel">
        <Link className="notice-brand" to="/admin">
          <img className="open-play-logo" src="/open-play-logo.png" alt="Open Play" />
        </Link>
        <p className="eyebrow eyebrow-dark">ADMINISTRATION · OFFICIALS</p>
        <h1>Referee<br /><em>applications.</em></h1>
        <p>Review referee applicants for the locations you administer. Approval grants a separate referee membership; it does not rely on user-editable account metadata.</p>

        <section className="hub-memberships">
          <div className="hub-section-heading">
            <span className="hub-kicker">APPLICATION QUEUE</span>
            <select aria-label="Filter applications" value={statusFilter} onChange={(event) => setStatusFilter(event.target.value)}>
              <option value="pending">Pending</option>
              <option value="approved">Approved</option>
              <option value="rejected">Rejected</option>
              <option value="all">All applications</option>
            </select>
          </div>
          {error && <p className="form-note" role="alert">{error}</p>}
          {notice && <p className="form-note" role="status">{notice}</p>}
          {loading ? <p className="form-note">Loading referee applications…</p> : applications.length === 0 ? (
            <p className="form-note">No applications match this filter for your permitted locations.</p>
          ) : applications.map((application) => (
            <article className="admin-queue-row" key={application.application_id}>
              <div>
                <strong>{application.player_name}</strong>
                <span>{application.email} · {application.contact_phone}</span>
                <small>{application.preferred_location_names.join(", ")}</small>
                <small>Submitted {new Date(application.submitted_at).toLocaleString("en-GB", { dateStyle: "medium", timeStyle: "short" })} · {application.status.toUpperCase()}</small>
                <p><strong>Experience</strong><br />{application.experience_summary}</p>
                <p><strong>Qualifications</strong><br />{application.qualifications.length ? application.qualifications.join(", ") : "None supplied"}</p>
                <p><strong>Availability</strong><br />{application.availability.map((slot) => `${dayNames[slot.weekday - 1]} ${slot.start_time}–${slot.end_time}`).join(" · ")}</p>
                {application.additional_notes && <p><strong>Additional information</strong><br />{application.additional_notes}</p>}
                {application.review_reason && <p className="form-note"><strong>Previous review:</strong> {application.review_reason}</p>}
              </div>
              {application.status === "pending" && (
                <div className="admin-sheet-editor">
                  <label>
                    Review reason (required)
                    <textarea rows={2} minLength={5} maxLength={500} value={reasons[application.application_id] ?? ""} onChange={(event) => setReasons((current) => ({ ...current, [application.application_id]: event.target.value }))} placeholder="Record why this application is approved or rejected." />
                  </label>
                  <div className="captain-actions">
                    <button type="button" className="reject" disabled={busy === application.application_id} onClick={() => void decide(application, "rejected")}>REJECT</button>
                    <button type="button" disabled={busy === application.application_id} onClick={() => void decide(application, "approved")}>{busy === application.application_id ? "SAVING…" : "APPROVE REFEREE"}</button>
                  </div>
                </div>
              )}
            </article>
          ))}
          <button type="button" disabled={loading} onClick={() => void loadApplications()}>REFRESH QUEUE</button>
        </section>
        <section className="hub-memberships">
          <div className="hub-section-heading"><span className="hub-kicker">FIXTURE ALLOCATION</span></div>
          <p>Appoint active referees to fixtures at locations you administer. The database checks membership, preferred location, declared availability and conflicting kickoff appointments.</p>
          {allocationLoading ? <p className="form-note">Loading fixtures and referee availability…</p> : (
            <div className="admin-sheet-editor">
              <label>
                Fixture
                <select value={selectedFixtureId} onChange={(event) => { setSelectedFixtureId(event.target.value); setSelectedRefereeId(""); }}>
                  <option value="">Choose a future fixture</option>
                  {fixtures.map((fixture) => <option key={fixture.fixture_id} value={fixture.fixture_id}>
                    {fixture.location_name} · GW {fixture.gameweek} · {fixture.home_team_name} v {fixture.away_team_name} · {new Date(fixture.scheduled_at).toLocaleString("en-GB", { dateStyle: "medium", timeStyle: "short" })}
                  </option>)}
                </select>
              </label>
              <label>
                Active referee
                <select value={selectedRefereeId} onChange={(event) => setSelectedRefereeId(event.target.value)} disabled={!selectedFixtureId}>
                  <option value="">Choose a referee</option>
                  {eligibleCandidates.map((candidate) => <option key={candidate.referee_user_id} value={candidate.referee_user_id}>
                    {candidate.referee_name} · {candidate.referee_email}
                  </option>)}
                </select>
              </label>
              <label>
                Appointment role
                <select value={assignmentRole} onChange={(event) => setAssignmentRole(event.target.value as "lead" | "assistant")}>
                  <option value="lead">Lead referee</option>
                  <option value="assistant">Assistant referee</option>
                </select>
              </label>
              <button type="button" disabled={busy === "allocation" || !selectedFixtureId || !selectedRefereeId} onClick={() => void assignReferee()}>
                {busy === "allocation" ? "SAVING…" : "ALLOCATE REFEREE"}
              </button>
              {selectedFixture && <p className="form-note">{eligibleCandidates.length} active referee(s) have selected {selectedFixture.location_name}. Exact time availability is checked again when saving.</p>}
              {fixtures.length === 0 && <p className="form-note">No future scheduled fixtures are available for your locations.</p>}
            </div>
          )}
          <div className="hub-section-heading"><span className="hub-kicker">ACTIVE APPOINTMENTS</span></div>
          {appointments.length === 0 ? <p className="form-note">No active referee appointments.</p> : appointments.map((appointment) => (
            <article className="admin-queue-row" key={appointment.assignment_id}>
              <div>
                <strong>{appointment.referee_name} · {appointment.assignment_role.toUpperCase()}</strong>
                <span>{appointment.referee_email}</span>
                <small>{appointment.location_name} · GW {appointment.gameweek} · {appointment.home_team_name} v {appointment.away_team_name}</small>
                <small>{new Date(appointment.scheduled_at).toLocaleString("en-GB", { dateStyle: "medium", timeStyle: "short" })}</small>
              </div>
              <div className="admin-sheet-editor">
                <label>
                  Cancellation / reassignment reason
                  <textarea rows={2} minLength={5} maxLength={500} value={allocationReason[appointment.assignment_id] ?? ""} onChange={(event) => setAllocationReason((current) => ({ ...current, [appointment.assignment_id]: event.target.value }))} placeholder="Explain why this appointment is being changed." />
                </label>
                <button type="button" className="reject" disabled={busy === appointment.assignment_id} onClick={() => void cancelAppointment(appointment)}>
                  {busy === appointment.assignment_id ? "SAVING…" : "CANCEL APPOINTMENT"}
                </button>
              </div>
            </article>
          ))}
          <button type="button" disabled={allocationLoading} onClick={() => void loadAllocationData()}>REFRESH ALLOCATIONS</button>
        </section>
        <Link className="auth-switch" to="/admin">Back to Admin Dashboard</Link>
      </section>
    </main>
  );
}
