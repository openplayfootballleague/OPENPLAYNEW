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
type RefereeMatchReport = {
  report_id: string;
  fixture_id: string;
  referee_user_id: string | null;
  referee_name: string;
  referee_email: string | null;
  report_source: "referee" | "admin";
  status: "submitted" | "rejected" | "approved" | "voided";
  version: number;
  submitted_at: string;
  scheduled_at: string;
  gameweek: number;
  fixture_number: number;
  location_name: string;
  home_team_name: string;
  away_team_name: string;
  home_score: number;
  away_score: number;
  disciplinary_events: Array<{ recipient_type: string; card_type: string; season_team_id: string }>;
  match_write_up: string | null;
  review_reason: string | null;
};
type AdminReportableFixture = {
  fixture_id: string;
  scheduled_at: string;
  gameweek: number;
  fixture_number: number;
  home_team_id: string;
  home_team_name: string;
  away_team_id: string;
  away_team_name: string;
  location_id: string;
  location_name: string;
  existing_report_id: string | null;
  existing_report_status: "submitted" | "rejected" | null;
};
type AdminReportPlayer = {
  competition_player_id: string;
  full_name: string;
  role: "starter" | "substitute";
  is_goalkeeper: boolean;
  disciplinary_inactive: boolean;
};
type AdminDisciplinaryEvent = {
  season_team_id: string;
  recipient_type: "registered_player" | "bench" | "supporter";
  card_type: "yellow" | "second_yellow_red" | "straight_red";
  competition_player_id: string | null;
  minute: number | null;
  description: string | null;
};
type AdminReportOptions = {
  fixture: {
    id: string;
    scheduled_at: string;
    gameweek: number;
    fixture_number: number;
    home_team_id: string;
    home_team_name: string;
    away_team_id: string;
    away_team_name: string;
  };
  report: null | {
    id: string;
    status: "submitted" | "rejected" | "approved" | "voided";
    version: number;
    home_score: number;
    away_score: number;
    home_scorers: string[];
    away_scorers: string[];
    home_substitute_appearances: string[];
    away_substitute_appearances: string[];
    disciplinary_events: AdminDisciplinaryEvent[];
    match_write_up: string | null;
    review_reason: string | null;
  };
  home_players: AdminReportPlayer[];
  away_players: AdminReportPlayer[];
};
type RefereePayoutTransferHistory = {
  attempt_number:number;status:string;amount_pence:number;stripe_transfer_id:string|null;
  failure_reason:string|null;created_at:string;
};
type RefereeMilestoneReward = {
  reward_id:string;referee_user_id:string|null;referee_name:string;milestone_number:number;
  approved_games:number;amount_pence:number;
  status:"pending_connect"|"processing"|"transferred"|"failed"|"cancelled";
  stripe_transfer_id:string|null;failure_reason:string|null;transfer_attempts:number;
  connect_status:"onboarding_required"|"verification_pending"|"enabled"|"restricted";
  transfers_enabled:boolean;payouts_enabled:boolean;created_at:string;transferred_at:string|null;
};
type RefereePayoutObligation = {
  payout_id: string;
  report_id: string;
  referee_user_id: string | null;
  referee_name: string;
  referee_email: string | null;
  fixture_id: string;
  gameweek: number;
  fixture_number: number;
  scheduled_at: string;
  location_id: string;
  location_name: string;
  gross_allocation_pence: number;
  deductions_pence: number;
  referee_net_pence: number;
  open_play_top_up_pence: number;
  status: "pending_connect" | "processing" | "transferred" | "failed" | "cancelled";
  stripe_transfer_id: string | null;
  failure_reason: string | null;
  transfer_attempts: number;
  connect_status: "onboarding_required" | "verification_pending" | "enabled" | "restricted";
  transfers_enabled: boolean;
  payouts_enabled: boolean;
  created_at: string;
  transferred_at: string | null;
};

const dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
const formatPence = (value: number) => new Intl.NumberFormat("en-GB", {
  style: "currency",
  currency: "GBP",
}).format(value / 100);

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
  const [reports, setReports] = useState<RefereeMatchReport[]>([]);
  const [approvedReports, setApprovedReports] = useState<RefereeMatchReport[]>([]);
  const [approvedReportsLoading, setApprovedReportsLoading] = useState(false);
  const [reportsLoading, setReportsLoading] = useState(false);
  const [reportReasons, setReportReasons] = useState<Record<string, string>>({});
  const [payouts, setPayouts] = useState<RefereePayoutObligation[]>([]);
  const [milestoneRewards, setMilestoneRewards] = useState<RefereeMilestoneReward[]>([]);
  const [milestoneRewardsLoading, setMilestoneRewardsLoading] = useState(false);
  const [payoutHistoryOpen, setPayoutHistoryOpen] = useState("");
  const [payoutHistory, setPayoutHistory] = useState<Record<string,RefereePayoutTransferHistory[]>>({});
  const [payoutsLoading, setPayoutsLoading] = useState(false);
  const [payoutStatusFilter, setPayoutStatusFilter] = useState("all");
  const [reportableFixtures, setReportableFixtures] = useState<AdminReportableFixture[]>([]);
  const [reportableFixturesLoading, setReportableFixturesLoading] = useState(false);
  const [selectedAdminReportFixtureId, setSelectedAdminReportFixtureId] = useState("");
  const [adminReportOptions, setAdminReportOptions] = useState<AdminReportOptions | null>(null);
  const [adminReportOptionsLoading, setAdminReportOptionsLoading] = useState(false);
  const [correctionMode, setCorrectionMode] = useState(false);
  const [adminReportHomeScore, setAdminReportHomeScore] = useState("0");
  const [adminReportAwayScore, setAdminReportAwayScore] = useState("0");
  const [adminReportHomeSubs, setAdminReportHomeSubs] = useState<string[]>([]);
  const [adminReportAwaySubs, setAdminReportAwaySubs] = useState<string[]>([]);
  const [adminReportHomeScorers, setAdminReportHomeScorers] = useState<string[]>([]);
  const [adminReportAwayScorers, setAdminReportAwayScorers] = useState<string[]>([]);
  const [adminReportDisciplinaryEvents, setAdminReportDisciplinaryEvents] = useState<AdminDisciplinaryEvent[]>([]);
  const [adminReportWriteUp, setAdminReportWriteUp] = useState("");
  const [adminReportReason, setAdminReportReason] = useState("");

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

  const loadReports = useCallback(async () => {
    setReportsLoading(true);
    const rpc = getSupabaseClient() as unknown as RpcClient;
    const result = await rpc.rpc("admin_list_referee_match_reports", { p_status: "submitted", p_location_id: null });
    if (result.error) {
      setError(result.error.message);
      setReports([]);
    } else {
      setReports((result.data ?? []) as RefereeMatchReport[]);
    }
    setReportsLoading(false);
  }, []);

  useEffect(() => { void loadReports(); }, [loadReports]);

  const loadApprovedReports = useCallback(async () => {
    setApprovedReportsLoading(true);
    const rpc = getSupabaseClient() as unknown as RpcClient;
    const result = await rpc.rpc("admin_list_referee_match_reports", {
      p_status: "approved",
      p_location_id: null,
    });
    if (result.error) {
      setError(result.error.message);
      setApprovedReports([]);
    } else {
      setApprovedReports((result.data ?? []) as RefereeMatchReport[]);
    }
    setApprovedReportsLoading(false);
  }, []);

  useEffect(() => { void loadApprovedReports(); }, [loadApprovedReports]);

  const loadPayouts = useCallback(async () => {
    setPayoutsLoading(true);
    const rpc = getSupabaseClient() as unknown as RpcClient;
    const result = await rpc.rpc("admin_list_referee_report_payouts_connect", {
      p_status: payoutStatusFilter,
    });
    if (result.error) {
      setError(result.error.message);
      setPayouts([]);
    } else {
      setPayouts((result.data ?? []) as RefereePayoutObligation[]);
    }
    setPayoutsLoading(false);
  }, [payoutStatusFilter]);

  useEffect(() => { void loadPayouts(); }, [loadPayouts]);

  const loadMilestoneRewards = useCallback(async () => {
    setMilestoneRewardsLoading(true);
    const rpc = getSupabaseClient() as unknown as RpcClient;
    const result = await rpc.rpc("admin_list_referee_milestone_rewards_connect", { p_status: "all" });
    if (result.error) {
      setError(result.error.message);
      setMilestoneRewards([]);
    } else {
      setMilestoneRewards((result.data ?? []) as RefereeMilestoneReward[]);
    }
    setMilestoneRewardsLoading(false);
  }, []);

  useEffect(() => { void loadMilestoneRewards(); }, [loadMilestoneRewards]);

  async function togglePayoutHistory(payoutType:"match_report"|"milestone",payoutId:string){
    const key=`${payoutType}:${payoutId}`;
    if(payoutHistoryOpen===key){setPayoutHistoryOpen("");return;}
    const rpc=getSupabaseClient() as unknown as RpcClient;
    const {data,error:historyError}=await rpc.rpc("admin_get_referee_payout_transfer_history",{
      p_payout_type:payoutType,p_payout_id:payoutId,
    });
    if(historyError){setError(historyError.message);return;}
    setPayoutHistory((current)=>({...current,[key]:(data??[]) as RefereePayoutTransferHistory[]}));
    setPayoutHistoryOpen(key);
  }

  async function sendRefereePayout(payoutType: "match_report" | "milestone", payoutId: string) {
    setBusy(`referee-payout:${payoutId}`);
    setError("");
    setNotice("");
    const supabase = getSupabaseClient() as unknown as {
      functions: { invoke(name: string, options?: Record<string, unknown>): Promise<{data: any; error: {message: string} | null}> };
    };
    const {data,error:transferError}=await supabase.functions.invoke("pay-referee-payout",{
      body:{payout_type:payoutType,payout_id:payoutId},
    });
    setBusy("");
    if(transferError){
      setError(data?.error ?? transferError.message);
      await Promise.all([loadPayouts(),loadMilestoneRewards()]);
      return;
    }
    if(data?.status==="processing"){
      setNotice("Stripe created the transfer. The payout is awaiting signed webhook reconciliation; do not retry it.");
    }else{
      setNotice("Stripe confirmed the referee transfer successfully.");
    }
    await Promise.all([loadPayouts(),loadMilestoneRewards()]);
  }

  const loadReportableFixtures = useCallback(async () => {
    setReportableFixturesLoading(true);
    const rpc = getSupabaseClient() as unknown as RpcClient;
    const result = await rpc.rpc("admin_list_referee_reportable_fixtures", { p_location_id: null });
    if (result.error) {
      setError(result.error.message);
      setReportableFixtures([]);
    } else {
      setReportableFixtures((result.data ?? []) as AdminReportableFixture[]);
    }
    setReportableFixturesLoading(false);
  }, []);

  useEffect(() => { void loadReportableFixtures(); }, [loadReportableFixtures]);

  const applyAdminReportOptions = useCallback((options: AdminReportOptions) => {
    setAdminReportOptions(options);
    const report = options.report;
    setAdminReportHomeScore(String(report?.home_score ?? 0));
    setAdminReportAwayScore(String(report?.away_score ?? 0));
    setAdminReportHomeSubs(report?.home_substitute_appearances ?? []);
    setAdminReportAwaySubs(report?.away_substitute_appearances ?? []);
    setAdminReportHomeScorers(report?.home_scorers ?? []);
    setAdminReportAwayScorers(report?.away_scorers ?? []);
    setAdminReportDisciplinaryEvents(report?.disciplinary_events ?? []);
    setAdminReportWriteUp(report?.match_write_up ?? "");
    setAdminReportReason("");
  }, []);

  const loadAdminReportOptions = useCallback(async (fixtureId: string) => {
    setCorrectionMode(false);
    setAdminReportOptionsLoading(true);
    setAdminReportOptions(null);
    const rpc = getSupabaseClient() as unknown as RpcClient;
    const result = await rpc.rpc("admin_get_referee_fixture_report_options", { p_fixture_id: fixtureId });
    if (result.error) {
      setError(result.error.message);
      setAdminReportOptions(null);
    } else {
      applyAdminReportOptions(result.data as AdminReportOptions);
    }
    setAdminReportOptionsLoading(false);
  }, [applyAdminReportOptions]);

  const loadApprovedReportCorrectionOptions = useCallback(async (reportId: string) => {
    setCorrectionMode(true);
    setAdminReportOptionsLoading(true);
    setAdminReportOptions(null);
    const rpc = getSupabaseClient() as unknown as RpcClient;
    const result = await rpc.rpc("admin_get_approved_referee_report_correction_options", {
      p_report_id: reportId,
    });
    if (result.error) {
      setError(result.error.message);
      setCorrectionMode(false);
      setAdminReportOptions(null);
    } else {
      applyAdminReportOptions(result.data as AdminReportOptions);
    }
    setAdminReportOptionsLoading(false);
  }, [applyAdminReportOptions]);

  useEffect(() => {
    if (selectedAdminReportFixtureId) void loadAdminReportOptions(selectedAdminReportFixtureId);
    else {
      setCorrectionMode(false);
      setAdminReportOptions(null);
      setAdminReportDisciplinaryEvents([]);
    }
  }, [selectedAdminReportFixtureId, loadAdminReportOptions]);

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

  async function submitAdminMatchReport() {
    if (!adminReportOptions) return;
    const homeScore = Number(adminReportHomeScore);
    const awayScore = Number(adminReportAwayScore);
    if (!Number.isInteger(homeScore) || homeScore < 0 || homeScore > 32767 ||
        !Number.isInteger(awayScore) || awayScore < 0 || awayScore > 32767) {
      setError("Enter whole-number scores between 0 and 32767.");
      return;
    }
    if (adminReportHomeScorers.length !== homeScore || adminReportAwayScorers.length !== awayScore) {
      setError("Select exactly one goalscorer for every goal.");
      return;
    }
    if (adminReportReason.trim().length < 5) {
      setError(correctionMode
        ? "Enter a correction reason of at least five characters."
        : "Enter an administrator submission reason of at least five characters.");
      return;
    }
    setBusy("admin-report");
    setError("");
    setNotice("");
    const rpc = getSupabaseClient() as unknown as RpcClient;
    const payload = {
      p_home_score: homeScore,
      p_away_score: awayScore,
      p_home_substitute_appearances: adminReportHomeSubs,
      p_away_substitute_appearances: adminReportAwaySubs,
      p_home_scorers: adminReportHomeScorers,
      p_away_scorers: adminReportAwayScorers,
      p_disciplinary_events: adminReportDisciplinaryEvents.map((event) => ({
        ...event,
        competition_player_id: event.recipient_type === "registered_player" ? event.competition_player_id : null,
      })),
      p_match_write_up: adminReportWriteUp.trim() || null,
      p_reason: adminReportReason.trim(),
    };
    const result = correctionMode && adminReportOptions.report?.status === "approved"
      ? await rpc.rpc("admin_correct_approved_referee_match_report", {
          p_report_id: adminReportOptions.report.id,
          p_expected_version: adminReportOptions.report.version,
          ...payload,
        })
      : await rpc.rpc("admin_submit_referee_match_report", {
          p_fixture_id: adminReportOptions.fixture.id,
          ...payload,
        });
    setBusy("");
    if (result.error) {
      setError(result.error.message);
      return;
    }
    const wasCorrection = correctionMode && adminReportOptions.report?.status === "approved";
    setNotice(wasCorrection
      ? "Approved match report corrected. The previous version and reason are retained in the audit history."
      : "Administrator match report saved. It is now awaiting review before the result is published.");
    setCorrectionMode(false);
    setSelectedAdminReportFixtureId("");
    setAdminReportOptions(null);
    await Promise.all([loadReportableFixtures(), loadReports(), loadApprovedReports()]);
  }

  async function reviewReport(report: RefereeMatchReport, decision: "approved" | "rejected") {
    const reason = (reportReasons[report.report_id] ?? "").trim();
    if (reason.length < 5) {
      setError("Enter a review reason of at least five characters.");
      return;
    }
    setBusy(report.report_id);
    setError("");
    setNotice("");
    const rpc = getSupabaseClient() as unknown as RpcClient;
    const result = await rpc.rpc("admin_review_referee_match_report", {
      p_report_id: report.report_id,
      p_decision: decision,
      p_reason: reason,
    });
    setBusy("");
    if (result.error) {
      setError(result.error.message);
      return;
    }
    if(decision==="approved"){
      // Trigger the report's one-time Stripe transfer immediately after the
      // approval transaction succeeds. The payout claim is locked/idempotent;
      // ambiguous Stripe outcomes stay processing for webhook reconciliation.
      const supabase=getSupabaseClient() as unknown as {
        functions:{invoke(name:string,options?:Record<string,unknown>):Promise<{data:any;error:{message:string}|null}>};
      };
      const {data:transferData,error:transferError}=await supabase.functions.invoke("pay-referee-payout",{
        body:{payout_type:"match_report",report_id:report.report_id},
      });
      if(transferError){
        setNotice("Match report approved and result published. The automatic referee transfer could not be confirmed ("+
          (transferData?.error??transferError.message)+"). Check the payout queue before any retry.");
      }else if(transferData?.status==="processing"){
        setNotice("Match report approved and result published. The referee transfer is still processing and must be reconciled before any retry. Do not retry yet.");
      }else if(transferData?.success===true&&transferData?.status==="transferred"){
        setNotice("Match report approved and result published. The referee's approved payment transfer was confirmed by Stripe.");
      }else{
        setNotice("Match report approved and result published. The referee payment requires attention: "+
          (transferData?.error??"Stripe did not confirm a transfer.")+" Check Connect readiness and the payout queue.");
      }
    }else{
      setNotice("Match report returned to the referee with your review reason.");
    }
    await Promise.all([loadReports(),loadApprovedReports(),loadPayouts()]);
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
        <section className="hub-memberships">
          <div className="hub-section-heading"><span className="hub-kicker">{correctionMode ? "CORRECT APPROVED MATCH REPORT" : "ADMIN MATCH REPORT ENTRY"}</span></div>
          <p>{correctionMode ? "You are amending an already approved result. Saving applies the corrected score, appearances, goalscorers and disciplinary events immediately, with a versioned audit trail." : "Submit or amend a report for a completed fixture with both team sheets locked. The result remains unpublished until a separate administrator review approves it."}</p>
          {reportableFixturesLoading && !correctionMode ? <p className="form-note">Loading completed fixtures…</p> : (
            <div className="admin-sheet-editor admin-report-entry">
              {!correctionMode && <label>
                Completed fixture
                <select value={selectedAdminReportFixtureId} disabled={adminReportOptionsLoading} onChange={(event) => setSelectedAdminReportFixtureId(event.target.value)}>
                  <option value="">Choose a completed fixture</option>
                  {reportableFixtures.map((fixture) => <option key={fixture.fixture_id} value={fixture.fixture_id}>
                    {fixture.location_name} · GW {fixture.gameweek} · {fixture.home_team_name} v {fixture.away_team_name}
                    {fixture.existing_report_status ? ` · ${fixture.existing_report_status.toUpperCase()} REPORT` : ""}
                  </option>)}
                </select>
              </label>}
              {!correctionMode && reportableFixtures.length === 0 && <p className="form-note">No completed fixtures with locked team sheets need an administrator report.</p>}
              {adminReportOptionsLoading && <p className="form-note">Loading team-sheet players…</p>}
              {adminReportOptions && (correctionMode || adminReportOptions.fixture.id === selectedAdminReportFixtureId) && <>
                <p className="form-note">{correctionMode ? `Correcting approved report version ${adminReportOptions.report?.version ?? "?"}. This updates the official result and disciplinary records; the previous version and your reason remain in the audit history.` : `GW ${adminReportOptions.fixture.gameweek} · ${adminReportOptions.fixture.home_team_name} v ${adminReportOptions.fixture.away_team_name}. Starters count as appearances automatically; select substitutes who appeared before selecting goalscorers.`}</p>
                {adminReportOptions.report?.review_reason && <p className="form-note"><strong>Previous review:</strong> {adminReportOptions.report.review_reason}</p>}
                <div className="admin-report-score-grid">
                  <label>{adminReportOptions.fixture.home_team_name} score
                    <input type="number" min={0} max={32767} value={adminReportHomeScore} onChange={(event) => setAdminReportHomeScore(event.target.value)} />
                  </label>
                  <label>{adminReportOptions.fixture.away_team_name} score
                    <input type="number" min={0} max={32767} value={adminReportAwayScore} onChange={(event) => setAdminReportAwayScore(event.target.value)} />
                  </label>
                </div>
                <label>{adminReportOptions.fixture.home_team_name} substitute appearances
                  <select multiple size={Math.min(5, Math.max(2, adminReportOptions.home_players.filter((player) => player.role === "substitute").length))}
                    value={adminReportHomeSubs} onChange={(event) => setAdminReportHomeSubs(Array.from(event.target.selectedOptions, (option) => option.value))}>
                    {adminReportOptions.home_players.filter((player) => player.role === "substitute").map((player) =>
                      <option key={player.competition_player_id} value={player.competition_player_id}>{player.full_name}</option>)}
                  </select>
                </label>
                <label>{adminReportOptions.fixture.away_team_name} substitute appearances
                  <select multiple size={Math.min(5, Math.max(2, adminReportOptions.away_players.filter((player) => player.role === "substitute").length))}
                    value={adminReportAwaySubs} onChange={(event) => setAdminReportAwaySubs(Array.from(event.target.selectedOptions, (option) => option.value))}>
                    {adminReportOptions.away_players.filter((player) => player.role === "substitute").map((player) =>
                      <option key={player.competition_player_id} value={player.competition_player_id}>{player.full_name}</option>)}
                  </select>
                </label>
                <label>{adminReportOptions.fixture.home_team_name} goalscorers
                  <select multiple size={Math.min(6, Math.max(2, adminReportOptions.home_players.length))}
                    value={adminReportHomeScorers} onChange={(event) => setAdminReportHomeScorers(Array.from(event.target.selectedOptions, (option) => option.value))}>
                    {adminReportOptions.home_players.filter((player) => player.role === "starter" || adminReportHomeSubs.includes(player.competition_player_id)).map((player) =>
                      <option key={player.competition_player_id} value={player.competition_player_id}>{player.full_name}{player.is_goalkeeper ? " · GK" : ""}</option>)}
                  </select>
                </label>
                <label>{adminReportOptions.fixture.away_team_name} goalscorers
                  <select multiple size={Math.min(6, Math.max(2, adminReportOptions.away_players.length))}
                    value={adminReportAwayScorers} onChange={(event) => setAdminReportAwayScorers(Array.from(event.target.selectedOptions, (option) => option.value))}>
                    {adminReportOptions.away_players.filter((player) => player.role === "starter" || adminReportAwaySubs.includes(player.competition_player_id)).map((player) =>
                      <option key={player.competition_player_id} value={player.competition_player_id}>{player.full_name}{player.is_goalkeeper ? " · GK" : ""}</option>)}
                  </select>
                </label>
                <div className="hub-section-heading"><span className="hub-kicker">DISCIPLINARY EVENTS</span></div>
                {adminReportDisciplinaryEvents.map((event, index) => {
                  const teamPlayers = event.season_team_id === adminReportOptions.fixture.home_team_id
                    ? adminReportOptions.home_players : adminReportOptions.away_players;
                  return <article className="admin-queue-row" key={index}>
                    <div className="admin-sheet-editor">
                      <label>Team
                        <select value={event.season_team_id} onChange={(change) => setAdminReportDisciplinaryEvents((current) => current.map((item, i) => i === index ? { ...item, season_team_id: change.target.value, competition_player_id: null } : item))}>
                          <option value={adminReportOptions.fixture.home_team_id}>{adminReportOptions.fixture.home_team_name}</option>
                          <option value={adminReportOptions.fixture.away_team_id}>{adminReportOptions.fixture.away_team_name}</option>
                        </select>
                      </label>
                      <label>Recipient
                        <select value={event.recipient_type} onChange={(change) => setAdminReportDisciplinaryEvents((current) => current.map((item, i) => i === index ? { ...item, recipient_type: change.target.value as AdminDisciplinaryEvent["recipient_type"], competition_player_id: null } : item))}>
                          <option value="registered_player">Registered player</option>
                          <option value="bench">Bench</option>
                          <option value="supporter">Supporter</option>
                        </select>
                      </label>
                      {event.recipient_type === "registered_player" && <label>Player
                        <select value={event.competition_player_id ?? ""} onChange={(change) => setAdminReportDisciplinaryEvents((current) => current.map((item, i) => i === index ? { ...item, competition_player_id: change.target.value || null } : item))}>
                          <option value="">Choose player</option>
                          {teamPlayers.map((player) => <option key={player.competition_player_id} value={player.competition_player_id}>{player.full_name}</option>)}
                        </select>
                      </label>}
                      <label>Card
                        <select value={event.card_type} onChange={(change) => setAdminReportDisciplinaryEvents((current) => current.map((item, i) => i === index ? { ...item, card_type: change.target.value as AdminDisciplinaryEvent["card_type"] } : item))}>
                          <option value="yellow">Yellow</option><option value="second_yellow_red">Second yellow / red</option><option value="straight_red">Straight red</option>
                        </select>
                      </label>
                      <label>Minute
                        <input type="number" min={0} max={120} value={event.minute ?? ""} onChange={(change) => setAdminReportDisciplinaryEvents((current) => current.map((item, i) => i === index ? { ...item, minute: change.target.value ? Number(change.target.value) : null } : item))} />
                      </label>
                      <label>Notes
                        <textarea rows={2} maxLength={500} value={event.description ?? ""} onChange={(change) => setAdminReportDisciplinaryEvents((current) => current.map((item, i) => i === index ? { ...item, description: change.target.value || null } : item))} />
                      </label>
                      <button type="button" className="reject" onClick={() => setAdminReportDisciplinaryEvents((current) => current.filter((_, i) => i !== index))}>REMOVE EVENT</button>
                    </div>
                  </article>;
                })}
                <button type="button" onClick={() => setAdminReportDisciplinaryEvents((current) => [...current, {
                  season_team_id: adminReportOptions.fixture.home_team_id,
                  recipient_type: "bench", card_type: "yellow", competition_player_id: null, minute: null, description: null,
                }])} disabled={adminReportDisciplinaryEvents.length >= 50}>ADD DISCIPLINARY EVENT</button>
                <label>Match write-up
                  <textarea rows={3} maxLength={2000} value={adminReportWriteUp} onChange={(event) => setAdminReportWriteUp(event.target.value)} placeholder="Optional match summary…" />
                </label>
                <label>{correctionMode ? "Correction reason (required)" : "Administrator reason (required)"}
                  <textarea rows={2} minLength={5} maxLength={500} value={adminReportReason} onChange={(event) => setAdminReportReason(event.target.value)} placeholder={correctionMode ? "Explain the correction and why the approved result must change." : "Explain why this report is being submitted or amended."} />
                </label>
                <button type="button" disabled={busy === "admin-report"} onClick={() => void submitAdminMatchReport()}>
                  {busy === "admin-report" ? "SAVING…" : correctionMode ? "SAVE APPROVED REPORT CORRECTION" : adminReportOptions.report ? "SAVE ADMIN REPORT AMENDMENT" : "SUBMIT ADMIN MATCH REPORT"}
                </button>
                {correctionMode && <button type="button" className="reject" disabled={busy === "admin-report"} onClick={() => {setCorrectionMode(false);setSelectedAdminReportFixtureId("");setAdminReportOptions(null);setAdminReportReason("");}}>CANCEL CORRECTION</button>}
              </>}
            </div>
          )}
          <button type="button" disabled={reportableFixturesLoading} onClick={() => void loadReportableFixtures()}>REFRESH COMPLETED FIXTURES</button>
        </section>
        <section className="hub-memberships">
          <div className="hub-section-heading"><span className="hub-kicker">REFEREE MATCH REPORTS · AWAITING REVIEW</span></div>
          {reportsLoading ? <p className="form-note">Loading match reports…</p> : reports.length === 0 ? (
            <p className="form-note">No referee match reports are awaiting review.</p>
          ) : reports.map((report) => (
            <article className="admin-queue-row" key={report.report_id}>
              <div>
                <strong>GW {report.gameweek} · {report.home_team_name} {report.home_score}–{report.away_score} {report.away_team_name}</strong>
                <span>{report.report_source === "referee" ? report.referee_name + (report.referee_email ? " · " + report.referee_email : "") : "Administrator-submitted report"}</span>
                <small>{report.location_name} · {new Date(report.scheduled_at).toLocaleString("en-GB", { dateStyle: "medium", timeStyle: "short" })}</small>
                <small>Submitted {new Date(report.submitted_at).toLocaleString("en-GB", { dateStyle: "medium", timeStyle: "short" })} · Version {report.version}</small>
                {report.disciplinary_events.length > 0 && <small>{report.disciplinary_events.length} disciplinary event(s): {report.disciplinary_events.map((event) => event.card_type.replaceAll("_", " ")).join(", ")}</small>}
                {report.match_write_up && <p className="form-note">{report.match_write_up}</p>}
              </div>
              <div className="admin-sheet-editor">
                <label>
                  Review reason
                  <textarea rows={2} minLength={5} maxLength={500} value={reportReasons[report.report_id] ?? ""} onChange={(event) => setReportReasons((current) => ({ ...current, [report.report_id]: event.target.value }))} placeholder="Record the approval or rejection reason." />
                </label>
                <button type="button" disabled={busy === report.report_id} onClick={() => void reviewReport(report, "approved")}>
                  {busy === report.report_id ? "SAVING…" : "APPROVE & PUBLISH RESULT"}
                </button>
                <button type="button" className="reject" disabled={busy === report.report_id} onClick={() => void reviewReport(report, "rejected")}>
                  RETURN TO REFEREE
                </button>
              </div>
            </article>
          ))}
          <button type="button" disabled={reportsLoading} onClick={() => void loadReports()}>REFRESH MATCH REPORTS</button>
        </section>
        <section className="hub-memberships">
          <div className="hub-section-heading">
            <span className="hub-kicker">APPROVED MATCH REPORTS · CORRECTIONS</span>
            <span className="hub-count">{approvedReports.length}</span>
          </div>
          <p>Approved reports can be amended only by an administrator. Corrections use optimistic version checks and retain the original report, disciplinary reversals, finance adjustments and the administrator's reason.</p>
          {approvedReportsLoading ? <p className="form-note">Loading approved reports…</p> : approvedReports.length === 0 ? (
            <p className="form-note">No approved referee reports are available in your permitted locations.</p>
          ) : approvedReports.map((report) => (
            <article className="admin-queue-row" key={report.report_id}>
              <div>
                <strong>GW {report.gameweek} · {report.home_team_name} {report.home_score}–{report.away_score} {report.away_team_name}</strong>
                <span>{report.location_name} · {report.referee_name} · Version {report.version}</span>
                <small>Approved report · {new Date(report.submitted_at).toLocaleDateString("en-GB",{dateStyle:"medium"})}</small>
                {report.review_reason && <small>Last review: {report.review_reason}</small>}
              </div>
              <button type="button" disabled={adminReportOptionsLoading || busy==="admin-report"} onClick={()=>void loadApprovedReportCorrectionOptions(report.report_id)}>
                {adminReportOptionsLoading && correctionMode ? "LOADING…" : "OPEN CORRECTION"}
              </button>
            </article>
          ))}
          <button type="button" disabled={approvedReportsLoading} onClick={()=>void loadApprovedReports()}>REFRESH APPROVED REPORTS</button>
        </section>
        <section className="hub-memberships">
          <div className="hub-section-heading">
            <span className="hub-kicker">MATCH REPORT PAYOUT OBLIGATIONS</span>
            <select aria-label="Filter referee payouts" value={payoutStatusFilter} onChange={(event) => setPayoutStatusFilter(event.target.value)}>
              <option value="pending_connect">Pending Connect</option>
              <option value="processing">Processing</option>
              <option value="transferred">Transferred</option>
              <option value="failed">Failed</option>
              <option value="cancelled">Cancelled</option>
              <option value="all">All statuses</option>
            </select>
          </div>
          <p>Location-scoped referee match payments. Transfers are test-mode only. A transfer can be sent when Stripe confirms the referee account has transfers enabled; bank-payout enablement is separate and does not block a transfer into the connected Stripe balance; failed transfers can be retried, while processing transfers must be reconciled before another attempt.</p>
          {payoutsLoading ? <p className="form-note">Loading referee payout obligations…</p> : payouts.length === 0 ? (
            <p className="form-note">No referee payout obligations match this status for your permitted locations.</p>
          ) : payouts.map((payout) => (
            <article className="admin-queue-row" key={payout.payout_id}>
              <div>
                <strong>{payout.referee_name} · {payout.status.replaceAll("_", " ").toUpperCase()}</strong>
                <span>{payout.referee_email ?? "Referee account no longer available"}</span>
                <small>{payout.location_name} · GW {payout.gameweek} · Fixture {payout.fixture_number}</small>
                <small>{new Date(payout.scheduled_at).toLocaleString("en-GB", { dateStyle: "medium", timeStyle: "short" })} · Created {new Date(payout.created_at).toLocaleString("en-GB", { dateStyle: "medium", timeStyle: "short" })}</small>
                <small>Gross {formatPence(payout.gross_allocation_pence)} · Deductions {formatPence(payout.deductions_pence)} · Referee net {formatPence(payout.referee_net_pence)} · Open Play top-up {formatPence(payout.open_play_top_up_pence)}</small>
                {payout.stripe_transfer_id && <small>Stripe transfer reference: {payout.stripe_transfer_id}</small>}
                <small>Connect: {payout.connect_status.replaceAll("_"," ")} · Transfers {payout.transfers_enabled ? "enabled" : "disabled"} · Bank payouts {payout.payouts_enabled ? "enabled" : "disabled"} · Attempts {payout.transfer_attempts}</small>
                {payout.failure_reason && <small>Last transfer failure: {payout.failure_reason}</small>}
                {payout.status==="processing" && <small>Transfer processing — do not retry until Stripe reconciliation completes.</small>}
                {payout.transferred_at && <small>Transfer confirmed {new Date(payout.transferred_at).toLocaleString("en-GB", { dateStyle: "medium", timeStyle: "short" })}</small>}
                {(payout.status==="pending_connect"||payout.status==="failed")&&payout.connect_status==="enabled"&&payout.transfers_enabled&&(
                  <button type="button" disabled={busy===`referee-payout:${payout.payout_id}`} onClick={()=>void sendRefereePayout("match_report",payout.payout_id)}>
                    {busy===`referee-payout:${payout.payout_id}`?"SENDING…":payout.status==="failed"?"RETRY REFEREE TRANSFER":"SEND REFEREE PAYMENT"}
                  </button>
                )}
                <button type="button" className="admin-inline-action" onClick={()=>void togglePayoutHistory("match_report",payout.payout_id)}>
                  {payoutHistoryOpen===`match_report:${payout.payout_id}`?"HIDE TRANSFER HISTORY":"VIEW TRANSFER HISTORY"}
                </button>
                {payoutHistoryOpen===`match_report:${payout.payout_id}`&&(
                  <div className="form-note">{(payoutHistory[`match_report:${payout.payout_id}`]??[]).map((attempt)=>(
                    <p key={attempt.attempt_number}>Attempt {attempt.attempt_number} · {attempt.status.toUpperCase()} · {formatPence(attempt.amount_pence)} · {attempt.stripe_transfer_id??"No transfer ID"}{attempt.failure_reason? ` · ${attempt.failure_reason}`:""}</p>
                  ))}</div>
                )}
              </div>
            </article>
          ))}
          <button type="button" disabled={payoutsLoading} onClick={() => void loadPayouts()}>REFRESH PAYOUT OBLIGATIONS</button>
        </section>
        <section className="hub-memberships">
          <div className="hub-section-heading"><span className="hub-kicker">REFEREE MILESTONE REWARDS · CONNECT</span><span className="hub-count">{milestoneRewards.length}</span></div>
          <p>Milestone rewards are separate £50 transfers for each approved 50-game milestone. The same verified Stripe Connect account and transfer safeguards apply.</p>
          {milestoneRewardsLoading ? <p className="form-note">Loading milestone rewards…</p> : milestoneRewards.length===0 ? (
            <p className="form-note">No referee milestone rewards are currently recorded.</p>
          ) : milestoneRewards.map((reward)=>(
            <article className="admin-queue-row" key={reward.reward_id}>
              <div>
                <strong>{reward.referee_name} · {formatPence(reward.amount_pence)} · Milestone {reward.milestone_number}</strong>
                <span>{reward.approved_games} approved games · {reward.status.replaceAll("_"," ").toUpperCase()}</span>
                <small>Connect: {reward.connect_status.replaceAll("_"," ")} · Transfers {reward.transfers_enabled?"enabled":"disabled"} · Bank payouts {reward.payouts_enabled?"enabled":"disabled"} · Attempts {reward.transfer_attempts}</small>
                {reward.failure_reason&&<small>Last transfer failure: {reward.failure_reason}</small>}
                {reward.stripe_transfer_id&&<small>Stripe transfer reference: {reward.stripe_transfer_id}</small>}
                {reward.transferred_at&&<small>Transfer confirmed {new Date(reward.transferred_at).toLocaleString("en-GB",{dateStyle:"medium",timeStyle:"short"})}</small>}
                {reward.status==="processing"&&<small>Transfer processing — do not retry until Stripe reconciliation completes.</small>}
                {(reward.status==="pending_connect"||reward.status==="failed")&&reward.connect_status==="enabled"&&reward.transfers_enabled&&(
                  <button type="button" disabled={busy===`referee-payout:${reward.reward_id}`} onClick={()=>void sendRefereePayout("milestone",reward.reward_id)}>
                    {busy===`referee-payout:${reward.reward_id}`?"SENDING…":reward.status==="failed"?"RETRY MILESTONE TRANSFER":"SEND MILESTONE REWARD"}
                  </button>
                )}
                <button type="button" className="admin-inline-action" onClick={()=>void togglePayoutHistory("milestone",reward.reward_id)}>
                  {payoutHistoryOpen===`milestone:${reward.reward_id}`?"HIDE TRANSFER HISTORY":"VIEW TRANSFER HISTORY"}
                </button>
                {payoutHistoryOpen===`milestone:${reward.reward_id}`&&(
                  <div className="form-note">{(payoutHistory[`milestone:${reward.reward_id}`]??[]).map((attempt)=>(
                    <p key={attempt.attempt_number}>Attempt {attempt.attempt_number} · {attempt.status.toUpperCase()} · {formatPence(attempt.amount_pence)} · {attempt.stripe_transfer_id??"No transfer ID"}{attempt.failure_reason? ` · ${attempt.failure_reason}`:""}</p>
                  ))}</div>
                )}
              </div>
            </article>
          ))}
          <button type="button" disabled={milestoneRewardsLoading} onClick={()=>void loadMilestoneRewards()}>REFRESH MILESTONE REWARDS</button>
        </section>
        <Link className="auth-switch" to="/admin">Back to Admin Dashboard</Link>
      </section>
    </main>
  );
}
