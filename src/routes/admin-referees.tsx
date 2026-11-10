import { useEffect, useMemo, useState } from "react";
import { Link, createFileRoute, useNavigate } from "@tanstack/react-router";
import { useRequiredSession } from "../lib/auth/use-required-session";
import { getSupabaseClient } from "../lib/supabase/client";

type LocationOption = { id: string; name: string; town: string; region: string; is_active: boolean };
type Application = {
  application_id: string; user_id: string; applicant_name: string; applicant_email: string; experience_summary: string; qualifications: string | null;
  availability_notes: string | null; contact_phone: string | null; preferred_location_ids: string[];
  status: string; created_at: string;
};
type RefereeOption = { referee_user_id: string; referee_name: string; approved_at: string; availability_slots: number };
type AvailabilityRow = {
  referee_user_id: string; referee_name: string; available_on: string; starts_at: string;
  ends_at: string; location_id: string; location_name: string; note: string | null;
};
type Assignment = {
  assignment_id: string; fixture_id: string; referee_user_id: string; referee_name: string;
  gameweek: number; scheduled_at: string | null; home_team_name: string; away_team_name: string;
  location_id: string; location_name: string; assigned_at: string;
};
type ReportQueueItem = {
  report_id: string; fixture_id: string; gameweek: number; scheduled_at: string | null;
  home_team_name: string; away_team_name: string; referee_user_id: string | null;
  referee_name: string; status: string; home_score: number; away_score: number;
  submitted_at: string | null; match_summary: string | null;
};
type FixtureOption = {
  id: string; gameweek: number; scheduled_at: string | null;
  home_team_name: string; away_team_name: string; location_id: string; location_name: string;
  status: string;
};

const dateTime = (value: string | null) => value ? new Date(value).toLocaleString("en-GB", { dateStyle: "medium", timeStyle: "short" }) : "To be confirmed";

export const Route = createFileRoute("/admin-referees")({ component: AdminRefereeWorkspace });

function AdminRefereeWorkspace() {
  const authStatus = useRequiredSession();
  const navigate = useNavigate();
  const supabase = getSupabaseClient() as any;
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [locations, setLocations] = useState<LocationOption[]>([]);
  const [selectedLocation, setSelectedLocation] = useState("");
  const [applications, setApplications] = useState<Application[]>([]);
  const [referees, setReferees] = useState<RefereeOption[]>([]);
  const [availability, setAvailability] = useState<AvailabilityRow[]>([]);
  const [assignments, setAssignments] = useState<Assignment[]>([]);
  const [reports, setReports] = useState<ReportQueueItem[]>([]);
  const [fixtures, setFixtures] = useState<FixtureOption[]>([]);
  const [selectedFixture, setSelectedFixture] = useState("");
  const [selectedReferee, setSelectedReferee] = useState("");
  const [assignmentReason, setAssignmentReason] = useState("");
  const [decisionReasons, setDecisionReasons] = useState<Record<string, string>>({});
  const [selectedReport, setSelectedReport] = useState<any>(null);
  const [reportLoading, setReportLoading] = useState(false);

  const openFixtures = useMemo(() => fixtures.filter((fixture) => ["scheduled", "in_progress"].includes(fixture.status)), [fixtures]);

  async function loadWorkspace() {
    setLoading(true); setError("");
    const [{ data: setupRows, error: setupError }, { data: fixtureRows, error: fixtureError }] = await Promise.all([
      supabase.rpc("get_admin_competition_setup"),
      supabase.rpc("get_admin_contextual_fixtures", { p_location_id: selectedLocation || undefined }),
    ]);
    if (setupError || fixtureError) {
      setError(setupError?.message ?? fixtureError?.message ?? "Unable to load referee administration.");
      setLoading(false);
      return;
    }
    const nextLocations = (setupRows?.locations ?? []) as LocationOption[];
    setLocations(nextLocations);
    const [applicationResult, refereeResult, availabilityResult, assignmentResult, reportResult] = await Promise.all([
      supabase.rpc("admin_list_referee_applications", { p_status: "pending" }),
      supabase.rpc("admin_list_active_referees", { p_location_id: selectedLocation || undefined }),
      supabase.rpc("admin_list_referee_availability", { p_location_id: selectedLocation || undefined }),
      supabase.rpc("admin_list_referee_assignments", { p_location_id: selectedLocation || undefined }),
      supabase.rpc("admin_list_referee_report_queue", { p_status: "submitted", p_location_id: selectedLocation || undefined }),
    ]);
    const failure = applicationResult.error ?? refereeResult.error ?? availabilityResult.error ?? assignmentResult.error ?? reportResult.error;
    if (failure) setError(failure.message);
    else {
      setApplications((applicationResult.data ?? []) as Application[]);
      setReferees((refereeResult.data ?? []) as RefereeOption[]);
      setAvailability((availabilityResult.data ?? []) as AvailabilityRow[]);
      setAssignments((assignmentResult.data ?? []) as Assignment[]);
      setReports((reportResult.data ?? []) as ReportQueueItem[]);
      setFixtures((fixtureRows ?? []) as FixtureOption[]);
      if (!selectedFixture && fixtureRows?.length) setSelectedFixture(fixtureRows[0].id);
      if (!selectedReferee && refereeResult.data?.length) setSelectedReferee(refereeResult.data[0].referee_user_id);
    }
    setLoading(false);
  }

  useEffect(() => {
    if (authStatus === "unauthenticated") void navigate({ to: "/sign-in", replace: true });
    if (authStatus === "authenticated") void loadWorkspace();
  }, [authStatus, selectedLocation]);

  async function reviewApplication(application: Application, decision: "approved" | "rejected") {
    const reason = decisionReasons[application.application_id]?.trim() ?? "";
    if (reason.length < 5) { setError("Enter a reason of at least five characters before reviewing an application."); return; }
    setSaving(true); setError(""); setNotice("");
    try {
      const { error: actionError } = await supabase.rpc("admin_review_referee_application", {
        p_application_id: application.application_id, p_decision: decision, p_reason: reason,
      });
      if (actionError) throw actionError;
      setNotice(decision === "approved" ? "Referee membership approved. The applicant can now access the Referee Hub." : "Referee application rejected with an audit reason.");
      setDecisionReasons((current) => ({ ...current, [application.application_id]: "" }));
      await loadWorkspace();
    } catch (cause) { setError(cause instanceof Error ? cause.message : "Unable to review referee application."); }
    finally { setSaving(false); }
  }

  async function assignReferee(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!selectedFixture || !selectedReferee) { setError("Choose both a fixture and an approved referee."); return; }
    setSaving(true); setError(""); setNotice("");
    try {
      const { error: actionError } = await supabase.rpc("admin_assign_referee", {
        p_fixture_id: selectedFixture, p_referee_user_id: selectedReferee, p_reason: assignmentReason.trim() || null,
      });
      if (actionError) throw actionError;
      setNotice("Referee allocated. Any previous active assignment for this fixture has been retained as removed history.");
      setAssignmentReason("");
      await loadWorkspace();
    } catch (cause) { setError(cause instanceof Error ? cause.message : "Unable to assign referee."); }
    finally { setSaving(false); }
  }

  async function removeAssignment(assignment: Assignment) {
    const reason = decisionReasons[assignment.assignment_id]?.trim() ?? "";
    if (reason.length < 5) { setError("Enter a reason of at least five characters before removing an assignment."); return; }
    setSaving(true); setError(""); setNotice("");
    try {
      const { error: actionError } = await supabase.rpc("admin_remove_referee_assignment", { p_assignment_id: assignment.assignment_id, p_reason: reason });
      if (actionError) throw actionError;
      setNotice("Referee assignment removed and audit history retained.");
      await loadWorkspace();
    } catch (cause) { setError(cause instanceof Error ? cause.message : "Unable to remove assignment."); }
    finally { setSaving(false); }
  }

  async function openReport(report: ReportQueueItem) {
    setReportLoading(true); setError("");
    try {
      const { data, error: detailError } = await supabase.rpc("referee_get_match_report", { p_fixture_id: report.fixture_id });
      if (detailError) throw detailError;
      setSelectedReport({ ...report, detail: data });
    } catch (cause) { setError(cause instanceof Error ? cause.message : "Unable to load report details."); }
    finally { setReportLoading(false); }
  }

  async function reviewReport(decision: "approve" | "return" | "reject") {
    if (!selectedReport) return;
    const reason = decisionReasons[selectedReport.report_id]?.trim() ?? "";
    if (decision !== "approve" && reason.length < 5) { setError("Enter a reason of at least five characters for returning or rejecting a report."); return; }
    setSaving(true); setError(""); setNotice("");
    try {
      const { error: actionError } = await supabase.rpc("admin_review_referee_match_report", {
        p_report_id: selectedReport.report_id, p_decision: decision, p_reason: decision === "approve" ? null : reason,
      });
      if (actionError) throw actionError;
      setNotice(decision === "approve" ? "Report approved. Official result, goals, team fines and referee entitlement have been posted." : decision === "return" ? "Report returned to the referee for correction." : "Report rejected with an audit reason.");
      setSelectedReport(null);
      await loadWorkspace();
    } catch (cause) { setError(cause instanceof Error ? cause.message : "Unable to review match report."); }
    finally { setSaving(false); }
  }

  if (authStatus !== "authenticated" || loading) return <main className="admin-referee-page"><section className="admin-referee-panel"><p>{authStatus === "loading" || loading ? "Loading referee administration…" : "Redirecting to sign in…"}</p></section></main>;

  return <main className="admin-referee-page">
    <header className="admin-referee-header"><Link to="/admin" className="admin-referee-back">← Admin workspace</Link><span className="eyebrow">OFFICIALS MANAGEMENT</span><h1>Referee<br/><em>Allocation.</em></h1><p>Approve referee membership, review availability, allocate fixtures and publish match reports.</p></header>
    {error && <p className="referee-alert referee-alert-error">{error}</p>}{notice && <p className="referee-alert referee-alert-success">{notice}</p>}
    <section className="admin-referee-panel">
      <label>Location context<select value={selectedLocation} onChange={(event) => { setSelectedLocation(event.target.value); setSelectedFixture(""); setSelectedReferee(""); }}><option value="">All locations I administer</option>{locations.map((location) => <option key={location.id} value={location.id}>{location.name} · {location.town}</option>)}</select></label>
    </section>
    <section className="admin-referee-panel">
      <div className="admin-referee-section-title"><span className="eyebrow">01 · APPLICATIONS</span><h2>Membership review <b>{applications.length}</b></h2></div>
      {applications.length === 0 ? <p className="admin-referee-muted">No pending referee applications in this location scope.</p> : applications.map((application) => <article className="admin-referee-card" key={application.application_id}>
        <h3>{application.applicant_name}</h3><p className="admin-referee-muted">{application.applicant_email}</p><p>{application.experience_summary}</p>
        {application.qualifications && <p><strong>Qualifications:</strong> {application.qualifications}</p>}
        {application.availability_notes && <p><strong>Availability:</strong> {application.availability_notes}</p>}
        {application.contact_phone && <p><strong>Contact:</strong> {application.contact_phone}</p>}
        <p className="admin-referee-muted">Applied {dateTime(application.created_at)} · Preferred locations: {application.preferred_location_ids.length}</p>
        <label>Decision reason<textarea value={decisionReasons[application.application_id] ?? ""} onChange={(event) => setDecisionReasons((current) => ({ ...current, [application.application_id]: event.target.value }))} placeholder="Required audit reason (minimum five characters)" /></label>
        <div className="admin-referee-actions"><button disabled={saving} onClick={() => void reviewApplication(application, "approved")}>Approve membership</button><button className="is-danger" disabled={saving} onClick={() => void reviewApplication(application, "rejected")}>Reject application</button></div>
      </article>)}
    </section>
    <section className="admin-referee-panel">
      <div className="admin-referee-section-title"><span className="eyebrow">02 · AVAILABILITY</span><h2>Upcoming availability</h2></div>
      {availability.length === 0 ? <p className="admin-referee-muted">No availability submitted for this scope.</p> : <div className="admin-referee-table">{availability.map((slot, index) => <article key={slot.referee_user_id + slot.available_on + slot.starts_at + index}><strong>{slot.referee_name}</strong><span>{new Date(slot.available_on + "T00:00:00").toLocaleDateString("en-GB", { dateStyle: "medium" })}</span><span>{slot.starts_at.slice(0,5)}–{slot.ends_at.slice(0,5)}</span><span>{slot.location_name}</span></article>)}</div>}
    </section>
    <section className="admin-referee-panel">
      <div className="admin-referee-section-title"><span className="eyebrow">03 · FIXTURE ALLOCATION</span><h2>Assign an official</h2></div>
      <form className="admin-referee-form" onSubmit={assignReferee}>
        <label>Fixture<select required value={selectedFixture} onChange={(event) => setSelectedFixture(event.target.value)}><option value="">Choose fixture</option>{openFixtures.map((fixture) => <option key={fixture.id} value={fixture.fixture_id}>GW{fixture.gameweek} · {fixture.home_team_name} v {fixture.away_team_name} · {dateTime(fixture.scheduled_at)}</option>)}</select></label>
        <label>Approved referee<select required value={selectedReferee} onChange={(event) => setSelectedReferee(event.target.value)}><option value="">Choose referee</option>{referees.map((referee) => <option key={referee.referee_user_id} value={referee.referee_user_id}>{referee.referee_name} · {referee.availability_slots} upcoming slots</option>)}</select></label>
        <label>Reason / scheduling note<input value={assignmentReason} onChange={(event) => setAssignmentReason(event.target.value)} placeholder="Optional note" /></label>
        <button disabled={saving || !openFixtures.length || !referees.length}>Allocate referee</button>
      </form>
      <div className="admin-referee-section-title"><h2>Active allocations</h2></div>
      {assignments.length === 0 ? <p className="admin-referee-muted">No active referee allocations in this scope.</p> : assignments.map((assignment) => <article className="admin-referee-card" key={assignment.assignment_id}>
        <h3>{assignment.referee_name}</h3><p>GW{assignment.gameweek} · {assignment.home_team_name} v {assignment.away_team_name}</p><p className="admin-referee-muted">{assignment.location_name} · {dateTime(assignment.scheduled_at)}</p>
        <label>Removal reason<textarea value={decisionReasons[assignment.assignment_id] ?? ""} onChange={(event) => setDecisionReasons((current) => ({ ...current, [assignment.assignment_id]: event.target.value }))} placeholder="Required audit reason" /></label>
        <div className="admin-referee-actions"><button className="is-danger" disabled={saving} onClick={() => void removeAssignment(assignment)}>Remove assignment</button></div>
      </article>)}
    </section>
    <section className="admin-referee-panel">
      <div className="admin-referee-section-title"><span className="eyebrow">04 · REPORT APPROVAL</span><h2>Submitted reports <b>{reports.length}</b></h2></div>
      {reports.length === 0 ? <p className="admin-referee-muted">No match reports awaiting approval.</p> : reports.map((report) => <article className="admin-referee-card" key={report.report_id}>
        <h3>{report.home_team_name} {report.home_score}–{report.away_score} {report.away_team_name}</h3><p>GW{report.gameweek} · {dateTime(report.scheduled_at)} · Official: {report.referee_name}</p>
        {report.match_summary && <p>{report.match_summary}</p>}
        <button onClick={() => void openReport(report)} disabled={reportLoading}>Review report details</button>
      </article>)}
      {selectedReport && <article className="admin-referee-report-detail">
        <div className="admin-referee-section-title"><h2>Report review</h2><button className="admin-referee-close" onClick={() => setSelectedReport(null)}>Close</button></div>
        <p><strong>{selectedReport.home_team_name} {selectedReport.home_score}–{selectedReport.away_score} {selectedReport.away_team_name}</strong></p>
        <p className="admin-referee-muted">Referee: {selectedReport.referee_name} · Submitted {dateTime(selectedReport.submitted_at)}</p>
        <h3>Goals and score record</h3>{(selectedReport.detail?.goals ?? []).map((goal: any) => <p key={goal.id}>{goal.is_own_goal ? "Own goal" : "Goal"} · {goal.credited_team_name} · {goal.scorer_name ?? "Unattributed scorer"}</p>)}
        <h3>Disciplinary incidents</h3>{(selectedReport.detail?.incidents ?? []).map((incident: any) => <p key={incident.id}>{incident.card_outcome.replaceAll("_"," ")} · {incident.team_name} · {incident.player_name ?? incident.recipient_category} · £{(incident.fine_amount_pence / 100).toFixed(2)}</p>)}
        <label>Review reason<textarea value={decisionReasons[selectedReport.report_id] ?? ""} onChange={(event) => setDecisionReasons((current) => ({ ...current, [selectedReport.report_id]: event.target.value }))} placeholder="Required for return or rejection" /></label>
        <div className="admin-referee-actions"><button disabled={saving} onClick={() => void reviewReport("approve")}>Approve and publish</button><button disabled={saving} onClick={() => void reviewReport("return")}>Return for correction</button><button className="is-danger" disabled={saving} onClick={() => void reviewReport("reject")}>Reject report</button></div>
      </article>}
    </section>
    <footer className="admin-referee-footer"><Link to="/admin">Back to admin dashboard</Link><Link to="/finance">Open finance ledger</Link></footer>
  </main>;
}
