import { useEffect, useMemo, useState } from "react";
import { Link, createFileRoute, useNavigate } from "@tanstack/react-router";
import { getSupabaseClient } from "../lib/supabase/client";

type RefereeStatus = {
  application_id: string | null;
  application_status: "pending" | "approved" | "rejected" | null;
  application_created_at: string | null;
  application_review_reason: string | null;
  membership_status: "active" | "suspended" | null;
  membership_approved_at: string | null;
  reporting_enabled: boolean;
};
type RefereeLocation = { location_id: string; location_name: string; town: string; region: string };
type SheetPlayer = {
  competition_player_id: string;
  player_name: string;
  role: "starter" | "substitute";
  squad_number: number | null;
  is_goalkeeper: boolean;
};
type RefereeFixture = {
  fixture_id: string;
  season_name: string;
  league_name: string;
  location_name: string;
  gameweek: number;
  fixture_number: number;
  scheduled_at: string | null;
  home_team_id: string;
  home_team_name: string;
  away_team_id: string;
  away_team_name: string;
  home_sheet: SheetPlayer[];
  away_sheet: SheetPlayer[];
  report_id: string | null;
  report_status: string | null;
  report_completed_at: string | null;
};
type RefereeAvailability = {
  id: string;
  available_on: string;
  starts_at: string;
  ends_at: string;
  location_id: string;
  location_name: string;
  note: string | null;
};
type RefereeCareerSummary = {
  lifetime_approved_games: number;
  active_season_approved_games: number;
  career_title: string;
  next_milestone: number | null;
  milestone_progress_percent: number;
  milestone_reward_pence: number;
  lifetime_gross_allocations_pence: number;
  lifetime_net_entitlement_pence: number;
  awaiting_payment_pence: number;
  transferred_to_connected_balance_pence: number;
  paid_out_to_bank_pence: number;
};
type RefereeMilestoneReward = { reward_id: string; milestone_games: number; reward_amount_pence: number; status: string; approved_at: string | null; paid_at: string | null; review_reason: string | null; created_at: string };
type RefereePayment = {
  report_id: string;
  fixture_id: string;
  gameweek: number;
  gross_allocation_pence: number;
  minimum_net_pence: number;
  actual_deductions_pence: number | null;
  platform_top_up_pence: number;
  net_entitlement_pence: number | null;
  status: string;
  created_at: string;
};
type GoalEntry = {
  credited_team_id: string;
  scorer_team_id: string;
  scorer_competition_player_id: string;
  is_own_goal: boolean;
};
type IncidentEntry = {
  team_id: string;
  recipient_category: "registered_player" | "substitute_bench" | "supporter";
  competition_player_id: string;
  card_outcome: "yellow" | "second_yellow_red" | "straight_red";
};

const money = (pence: number) => new Intl.NumberFormat("en-GB", { style: "currency", currency: "GBP" }).format(pence / 100);
const dateTime = (value: string | null) => value ? new Date(value).toLocaleString("en-GB", { dateStyle: "medium", timeStyle: "short" }) : "To be confirmed";
const toLocalDateTimeInput = (value: string) => {
  const date = new Date(value);
  date.setMinutes(date.getMinutes() - date.getTimezoneOffset());
  return date.toISOString().slice(0, 16);
};

export const Route = createFileRoute("/referee")({ component: RefereeHubPage });

function RefereeHubPage() {
  const navigate = useNavigate();
  const supabase = getSupabaseClient() as any;
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [status, setStatus] = useState<RefereeStatus | null>(null);
  const [locations, setLocations] = useState<RefereeLocation[]>([]);
  const [fixtures, setFixtures] = useState<RefereeFixture[]>([]);
  const [availability, setAvailability] = useState<RefereeAvailability[]>([]);
  const [payments, setPayments] = useState<RefereePayment[]>([]);
  const [careerSummary, setCareerSummary] = useState<RefereeCareerSummary | null>(null);
  const [milestoneRewards, setMilestoneRewards] = useState<RefereeMilestoneReward[]>([]);
  const [activeTab, setActiveTab] = useState<"Home" | "Match Centre" | "Teams" | "Matchday" | "More">("Home");
  const [selectedFixtureId, setSelectedFixtureId] = useState("");
  const [applicationExperience, setApplicationExperience] = useState("");
  const [applicationQualifications, setApplicationQualifications] = useState("");
  const [applicationAvailability, setApplicationAvailability] = useState("");
  const [applicationPhone, setApplicationPhone] = useState("");
  const [preferredLocations, setPreferredLocations] = useState<string[]>([]);
  const [availableOn, setAvailableOn] = useState("");
  const [availabilityStart, setAvailabilityStart] = useState("18:00");
  const [availabilityEnd, setAvailabilityEnd] = useState("22:00");
  const [availabilityLocation, setAvailabilityLocation] = useState("");
  const [availabilityNote, setAvailabilityNote] = useState("");
  const [completedAt, setCompletedAt] = useState("");
  const [homeScore, setHomeScore] = useState("0");
  const [awayScore, setAwayScore] = useState("0");
  const [matchSummary, setMatchSummary] = useState("");
  const [reportReviewReason, setReportReviewReason] = useState("");
  const [goals, setGoals] = useState<GoalEntry[]>([]);
  const [incidents, setIncidents] = useState<IncidentEntry[]>([]);

  const selectedFixture = fixtures.find((fixture) => fixture.fixture_id === selectedFixtureId) ?? null;
  const allTeams = useMemo(() => {
    const rows = fixtures.flatMap((fixture) => [
      { id: fixture.home_team_id, name: fixture.home_team_name },
      { id: fixture.away_team_id, name: fixture.away_team_name },
    ]);
    return [...new Map(rows.map((team) => [team.id, team])).values()];
  }, [fixtures]);

  async function loadHub() {
    setLoading(true);
    setError("");
    const { data: sessionData, error: sessionError } = await supabase.auth.getSession();
    if (sessionError || !sessionData.session) {
      setLoading(false);
      await navigate({ to: "/sign-in", replace: true });
      return;
    }
    const [{ data: statusRows, error: statusError }, { data: locationRows, error: locationError }] = await Promise.all([
      supabase.rpc("referee_get_my_status"),
      supabase.rpc("referee_get_active_locations"),
    ]);
    if (statusError || locationError) {
      setError(statusError?.message ?? locationError?.message ?? "Unable to load referee membership.");
      setLoading(false);
      return;
    }
    const currentStatus = (statusRows?.[0] ?? null) as RefereeStatus | null;
    setStatus(currentStatus);
    const availableLocations = (locationRows ?? []) as RefereeLocation[];
    setLocations(availableLocations);
    if (currentStatus?.membership_status === "active") {
      const [{ data: fixtureRows, error: fixtureError }, { data: availabilityRows, error: availabilityError }, { data: paymentRows, error: paymentError }, { data: careerRows, error: careerError }, { data: rewardRows, error: rewardError }] = await Promise.all([
        supabase.rpc("referee_get_assigned_fixtures"),
        supabase.rpc("referee_get_availability"),
        supabase.rpc("referee_get_payment_entitlements"),
        supabase.rpc("referee_get_career_summary"),
        supabase.rpc("referee_get_milestone_rewards"),
      ]);
      if (fixtureError || availabilityError || paymentError || careerError || rewardError) {
        setError(fixtureError?.message ?? availabilityError?.message ?? paymentError?.message ?? careerError?.message ?? rewardError?.message ?? "Unable to load referee matchday data.");
      } else {
        const nextFixtures = (fixtureRows ?? []) as RefereeFixture[];
        setFixtures(nextFixtures);
        setAvailability((availabilityRows ?? []) as RefereeAvailability[]);
        setPayments((paymentRows ?? []) as RefereePayment[]);
        setCareerSummary((careerRows?.[0] ?? null) as RefereeCareerSummary | null);
        setMilestoneRewards((rewardRows ?? []) as RefereeMilestoneReward[]);
        setSelectedFixtureId((current) => nextFixtures.some((fixture) => fixture.fixture_id === current) ? current : nextFixtures[0]?.fixture_id ?? "");
      }
    }
    setLoading(false);
  }

  useEffect(() => {
    void loadHub();
  }, []);

  useEffect(() => {
    if (!selectedFixture) {
      setCompletedAt("");
      setGoals([]);
      setIncidents([]);
      setHomeScore("0");
      setAwayScore("0");
      setMatchSummary("");
      return;
    }
    const fixtureForReport = selectedFixture;
    async function loadReport() {
      const { data, error: reportError } = await supabase.rpc("referee_get_match_report", { p_fixture_id: fixtureForReport.fixture_id });
      if (reportError) {
        setError(reportError.message);
        return;
      }
      if (!data) {
        setCompletedAt("");
        setGoals([]);
        setIncidents([]);
        setHomeScore("0");
        setAwayScore("0");
        setMatchSummary("");
        setReportReviewReason("");
        return;
      }
      setCompletedAt(data.completed_at ? toLocalDateTimeInput(data.completed_at) : "");
      setHomeScore(String(data.home_score ?? 0));
      setAwayScore(String(data.away_score ?? 0));
      setMatchSummary(data.match_summary ?? "");
      setReportReviewReason(data.review_reason ?? "");
      setGoals((data.goals ?? []).map((goal: any) => ({
        credited_team_id: goal.credited_team_id,
        scorer_team_id: goal.scorer_team_id ?? "",
        scorer_competition_player_id: goal.scorer_competition_player_id ?? "",
        is_own_goal: Boolean(goal.is_own_goal),
      })));
      setIncidents((data.incidents ?? []).map((incident: any) => ({
        team_id: incident.team_id,
        recipient_category: incident.recipient_category,
        competition_player_id: incident.competition_player_id ?? "",
        card_outcome: incident.card_outcome,
      })));
    }
    void loadReport();
  }, [selectedFixtureId, fixtures]);

  async function submitApplication(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSaving(true); setError(""); setNotice("");
    try {
      const { error: saveError } = await supabase.rpc("referee_submit_application", {
        p_experience_summary: applicationExperience.trim(),
        p_qualifications: applicationQualifications.trim() || null,
        p_availability_notes: applicationAvailability.trim() || null,
        p_contact_phone: applicationPhone.trim() || null,
        p_preferred_location_ids: preferredLocations,
      });
      if (saveError) throw saveError;
      setNotice("Your referee application has been submitted for administrator review.");
      await loadHub();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Unable to submit your application.");
    } finally { setSaving(false); }
  }

  async function saveAvailability(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSaving(true); setError(""); setNotice("");
    try {
      const { error: saveError } = await supabase.rpc("referee_save_availability", {
        p_available_on: availableOn,
        p_starts_at: availabilityStart,
        p_ends_at: availabilityEnd,
        p_location_id: availabilityLocation,
        p_note: availabilityNote.trim() || null,
      });
      if (saveError) throw saveError;
      setNotice("Availability saved. It is visible to administrators but does not create a fixture assignment.");
      setAvailabilityNote("");
      await loadHub();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Unable to save availability.");
    } finally { setSaving(false); }
  }

  function playerOptions(teamId: string, category: IncidentEntry["recipient_category"] | "goal") {
    if (!selectedFixture) return [];
    const sheet = teamId === selectedFixture.home_team_id ? selectedFixture.home_sheet : selectedFixture.away_sheet;
    if (category === "goal") return sheet;
    if (category === "registered_player") return sheet.filter((player) => player.role === "starter");
    if (category === "substitute_bench") return sheet.filter((player) => player.role === "substitute");
    return [];
  }

  function addGoal() {
    if (!selectedFixture) return;
    setGoals((current) => [...current, {
      credited_team_id: selectedFixture.home_team_id,
      scorer_team_id: selectedFixture.home_team_id,
      scorer_competition_player_id: selectedFixture.home_sheet[0]?.competition_player_id ?? "",
      is_own_goal: false,
    }]);
  }

  function updateGoal(index: number, patch: Partial<GoalEntry>) {
    setGoals((current) => current.map((goal, i) => i === index ? { ...goal, ...patch } : goal));
  }

  function addIncident() {
    if (!selectedFixture) return;
    const firstStarter = selectedFixture.home_sheet.find((player) => player.role === "starter");
    setIncidents((current) => [...current, {
      team_id: selectedFixture.home_team_id,
      recipient_category: "registered_player",
      competition_player_id: firstStarter?.competition_player_id ?? "",
      card_outcome: "yellow",
    }]);
  }

  function updateIncident(index: number, patch: Partial<IncidentEntry>) {
    setIncidents((current) => current.map((incident, i) => i === index ? { ...incident, ...patch } : incident));
  }

  async function saveReport(submit: boolean) {
    if (!selectedFixture) return;
    if (!completedAt) { setError("Enter the actual match completion time."); return; }
    setSaving(true); setError(""); setNotice("");
    try {
      const { error: saveError } = await supabase.rpc("referee_save_match_report", {
        p_fixture_id: selectedFixture.fixture_id,
        p_completed_at: new Date(completedAt).toISOString(),
        p_home_score: Number(homeScore),
        p_away_score: Number(awayScore),
        p_match_summary: matchSummary.trim() || null,
        p_goals: goals.map((goal) => ({
          credited_team_id: goal.credited_team_id,
          scorer_team_id: goal.scorer_team_id || null,
          scorer_competition_player_id: goal.scorer_competition_player_id || null,
          is_own_goal: goal.is_own_goal,
        })),
        p_incidents: incidents.map((incident) => ({
          team_id: incident.team_id,
          recipient_category: incident.recipient_category,
          competition_player_id: incident.competition_player_id || null,
          card_outcome: incident.card_outcome,
        })),
        p_submit: submit,
      });
      if (saveError) throw saveError;
      setNotice(submit ? "Match report submitted for administrator approval." : "Match report draft saved.");
      await loadHub();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Unable to save the match report.");
    } finally { setSaving(false); }
  }

  if (loading) return <main className="referee-page"><section className="referee-panel"><p>Loading referee hub…</p></section></main>;

  if (status && !status.reporting_enabled) return <main className="referee-page"><section className="referee-panel"><Link to="/" className="referee-brand">OPEN PLAY <span>OFFICIALS</span></Link><p className="eyebrow">REFEREE REPORTING</p><h1>Temporarily<br/><em>unavailable.</em></h1><p className="referee-muted">Referee applications and matchday reporting are currently switched off by Open Play. Your membership and historical payment records remain preserved.</p><Link to="/" className="referee-back-link">Return to Open Play</Link></section></main>;

  if (status?.membership_status !== "active") {
    const pending = status?.application_status === "pending";
    return <main className="referee-page">
      <section className="referee-panel referee-onboarding">
        <Link to="/" className="referee-brand">OPEN PLAY <span>OFFICIALS</span></Link>
        <p className="eyebrow">REFEREE MEMBERSHIP</p>
        <h1>Become an<br/><em>official.</em></h1>
        {error && <p className="form-error" role="alert">{error}</p>}
        {notice && <p className="form-success" role="status">{notice}</p>}
        {pending ? <div className="referee-status-card"><strong>Application under review</strong><p>Your application is awaiting an administrator decision. Referee access and fixture assignments remain locked until approval.</p></div>
          : <form className="referee-form" onSubmit={submitApplication}>
            {status?.application_status === "rejected" && <div className="referee-status-card"><strong>Previous application not approved</strong><p>{status.application_review_reason ?? "You may submit a new application for review."}</p></div>}
            <label>Refereeing experience<textarea required minLength={10} maxLength={3000} value={applicationExperience} onChange={(event) => setApplicationExperience(event.target.value)} placeholder="Tell us about your experience, competitions and level…" /></label>
            <label>Qualifications<input value={applicationQualifications} onChange={(event) => setApplicationQualifications(event.target.value)} placeholder="e.g. FA qualification (optional)" /></label>
            <label>Availability notes<textarea value={applicationAvailability} onChange={(event) => setApplicationAvailability(event.target.value)} placeholder="Days, times and locations you can usually cover…" /></label>
            <label>Contact phone<input type="tel" value={applicationPhone} onChange={(event) => setApplicationPhone(event.target.value)} placeholder="Contact number (optional)" /></label>
            <fieldset><legend>Preferred locations</legend>{locations.map((location) => <label className="referee-checkbox" key={location.location_id}><input type="checkbox" checked={preferredLocations.includes(location.location_id)} onChange={(event) => setPreferredLocations((current) => event.target.checked ? [...current, location.location_id] : current.filter((id) => id !== location.location_id))}/><span>{location.location_name} · {location.town}</span></label>)}</fieldset>
            <button className="referee-primary" disabled={saving}>{saving ? "Submitting…" : "Submit referee application"}</button>
          </form>}
        <Link to="/" className="referee-back-link">Return to Open Play</Link>
      </section>
    </main>;
  }

  return <main className="referee-app">
    <header className="referee-header">
      <Link to="/" className="referee-brand">OPEN PLAY <span>OFFICIALS</span></Link>
      <div><span className="referee-kicker">APPROVED REFEREE</span><strong>Referee Hub</strong></div>
    </header>
    {error && <p className="referee-alert referee-alert-error" role="alert">{error}</p>}
    {notice && <p className="referee-alert referee-alert-success" role="status">{notice}</p>}
    <section className="referee-content">
      {activeTab === "Home" && <div className="referee-hero">
        <p className="eyebrow">OFFICIALS · OPEN PLAY</p><h1>Matchday<br/><em>starts here.</em></h1>
        <p>Your assigned fixtures, match reports, career earnings and availability in one place.</p>
        <div className="referee-career-card">
          <span className="referee-career-label">CAREER RANK</span><strong>{careerSummary?.career_title ?? "Rookie Official"}</strong>
          <p>{careerSummary?.lifetime_approved_games ?? 0} approved games across your Open Play career</p>
          <div className="referee-progress-track"><span style={{ width: `${careerSummary?.milestone_progress_percent ?? 0}%` }} /></div>
          <small>{careerSummary?.next_milestone ? `${careerSummary.next_milestone - (careerSummary.lifetime_approved_games ?? 0)} games to ${careerSummary.next_milestone} · £50 reward subject to admin confirmation` : "500-game career milestone achieved"}</small>
        </div>
        <div className="referee-stat-grid">
          <article><span>Lifetime approved games</span><strong>{careerSummary?.lifetime_approved_games ?? 0}</strong></article>
          <article><span>Active-season games</span><strong>{careerSummary?.active_season_approved_games ?? 0}</strong></article>
          <article><span>Assigned fixtures</span><strong>{fixtures.length}</strong></article>
          <article><span>Reports awaiting review</span><strong>{fixtures.filter((fixture) => fixture.report_status === "submitted").length}</strong></article>
          <article><span>Lifetime gross allocations</span><strong>{money(Number(careerSummary?.lifetime_gross_allocations_pence ?? 0))}</strong></article>
        </div>
        <button className="referee-primary" onClick={() => setActiveTab("Matchday")}>Open matchday reporting</button>
      </div>}
      {activeTab === "Match Centre" && <section className="referee-section"><p className="eyebrow">YOUR SCHEDULE</p><h1>Match Centre</h1>{fixtures.length === 0 ? <p>No fixtures are currently assigned to you in the active gameweek.</p> : fixtures.map((fixture) => <button className="referee-fixture-card" key={fixture.fixture_id} onClick={() => { setSelectedFixtureId(fixture.fixture_id); setActiveTab("Matchday"); }}><span>GAMEWEEK {fixture.gameweek} · {fixture.location_name}</span><strong>{fixture.home_team_name} <i>v</i> {fixture.away_team_name}</strong><small>{dateTime(fixture.scheduled_at)} · {fixture.league_name}</small><em>{fixture.report_status ?? "Report not started"}</em></button>)}</section>}
      {activeTab === "Teams" && <section className="referee-section"><p className="eyebrow">COMPETITION DIRECTORY</p><h1>Teams</h1><div className="referee-team-grid">{allTeams.map((team) => <article key={team.id}><strong>{team.name}</strong><span>Registered Open Play club</span></article>)}</div><p className="referee-muted">Player information is shown only in the context of your assigned matchday team sheets.</p></section>}
      {activeTab === "Matchday" && <section className="referee-section"><p className="eyebrow">OFFICIAL MATCH REPORT</p><h1>Matchday</h1>
        {fixtures.length === 0 ? <p>You have no assigned fixtures in the current active gameweek.</p> : <>
          <label className="referee-field">Assigned fixture<select value={selectedFixtureId} onChange={(event) => setSelectedFixtureId(event.target.value)}>{fixtures.map((fixture) => <option key={fixture.fixture_id} value={fixture.fixture_id}>GW{fixture.gameweek} · {fixture.home_team_name} v {fixture.away_team_name}</option>)}</select></label>
          {selectedFixture && <>
            <div className="referee-match-meta"><span>{selectedFixture.league_name} · Gameweek {selectedFixture.gameweek}</span><strong>{dateTime(selectedFixture.scheduled_at)}</strong></div>
            {reportReviewReason && <div className="referee-status-card"><strong>Administrator feedback</strong><p>{reportReviewReason}</p><p>You can correct this report and submit it again for review.</p></div>}
            <div className="referee-sheets">
              {[{ id: selectedFixture.home_team_id, name: selectedFixture.home_team_name, players: selectedFixture.home_sheet }, { id: selectedFixture.away_team_id, name: selectedFixture.away_team_name, players: selectedFixture.away_sheet }].map((team) => <article key={team.id}><h3>{team.name}</h3>{team.players.length === 0 ? <p>Team sheet not submitted</p> : team.players.map((player) => <div className="referee-sheet-player" key={player.competition_player_id}><b>{player.squad_number ?? "—"}</b><span>{player.player_name}</span><small>{player.is_goalkeeper ? "GK" : player.role === "substitute" ? "SUB" : "START"}</small></div>)}</article>)}
            </div>
            <label className="referee-field">Actual match completion time<input type="datetime-local" value={completedAt} onChange={(event) => setCompletedAt(event.target.value)} required /></label>
            <div className="referee-score-row"><label>{selectedFixture.home_team_name}<input type="number" min="0" max="99" required value={homeScore} onChange={(event) => setHomeScore(event.target.value)} /></label><span>–</span><label>{selectedFixture.away_team_name}<input type="number" min="0" max="99" required value={awayScore} onChange={(event) => setAwayScore(event.target.value)} /></label></div>
            <div className="referee-editor-heading"><h2>Goalscorers</h2><button type="button" onClick={addGoal}>+ Add goal</button></div>
            {goals.map((goal, index) => <div className="referee-event-row" key={index}>
              <label>Team credited<select value={goal.credited_team_id} onChange={(event) => updateGoal(index, { credited_team_id: event.target.value })}><option value={selectedFixture.home_team_id}>{selectedFixture.home_team_name}</option><option value={selectedFixture.away_team_id}>{selectedFixture.away_team_name}</option></select></label>
              <label>Scorer's team<select value={goal.scorer_team_id} onChange={(event) => { const teamId = event.target.value; updateGoal(index, { scorer_team_id: teamId, scorer_competition_player_id: playerOptions(teamId, "goal")[0]?.competition_player_id ?? "" }); }}><option value={selectedFixture.home_team_id}>{selectedFixture.home_team_name}</option><option value={selectedFixture.away_team_id}>{selectedFixture.away_team_name}</option></select></label>
              <label>Scorer<select value={goal.scorer_competition_player_id} onChange={(event) => updateGoal(index, { scorer_competition_player_id: event.target.value })}><option value="">Select player</option>{playerOptions(goal.scorer_team_id, "goal").map((player) => <option key={player.competition_player_id} value={player.competition_player_id}>#{player.squad_number ?? "—"} {player.player_name}</option>)}</select></label>
              <label className="referee-checkbox"><input type="checkbox" checked={goal.is_own_goal} onChange={(event) => { const own = event.target.checked; const scorerTeam = own ? (goal.credited_team_id === selectedFixture.home_team_id ? selectedFixture.away_team_id : selectedFixture.home_team_id) : goal.credited_team_id; updateGoal(index, { is_own_goal: own, scorer_team_id: scorerTeam, scorer_competition_player_id: playerOptions(scorerTeam, "goal")[0]?.competition_player_id ?? "" }); }}/><span>Own goal</span></label>
              <button type="button" className="referee-remove" onClick={() => setGoals((current) => current.filter((_, i) => i !== index))}>Remove</button>
            </div>)}
            <div className="referee-editor-heading"><h2>Disciplinary incidents</h2><button type="button" onClick={addIncident}>+ Add incident</button></div>
            {incidents.map((incident, index) => <div className="referee-event-row" key={index}>
              <label>Team<select value={incident.team_id} onChange={(event) => { const teamId = event.target.value; updateIncident(index, { team_id: teamId, competition_player_id: playerOptions(teamId, incident.recipient_category)[0]?.competition_player_id ?? "" }); }}><option value={selectedFixture.home_team_id}>{selectedFixture.home_team_name}</option><option value={selectedFixture.away_team_id}>{selectedFixture.away_team_name}</option></select></label>
              <label>Recipient<select value={incident.recipient_category} onChange={(event) => { const category = event.target.value as IncidentEntry["recipient_category"]; updateIncident(index, { recipient_category: category, competition_player_id: playerOptions(incident.team_id, category)[0]?.competition_player_id ?? "" }); }}><option value="registered_player">Starting player</option><option value="substitute_bench">Substitute / bench</option><option value="supporter">Supporter</option></select></label>
              {incident.recipient_category !== "supporter" && <label>Player<select value={incident.competition_player_id} onChange={(event) => updateIncident(index, { competition_player_id: event.target.value })}><option value="">Select player</option>{playerOptions(incident.team_id, incident.recipient_category).map((player) => <option key={player.competition_player_id} value={player.competition_player_id}>#{player.squad_number ?? "—"} {player.player_name}</option>)}</select></label>}
              <label>Card<select value={incident.card_outcome} onChange={(event) => updateIncident(index, { card_outcome: event.target.value as IncidentEntry["card_outcome"] })}><option value="yellow">Yellow · £5</option><option value="second_yellow_red">Second yellow + red · £15 total</option><option value="straight_red">Straight red · £30</option></select></label>
              <button type="button" className="referee-remove" onClick={() => setIncidents((current) => current.filter((_, i) => i !== index))}>Remove</button>
            </div>)}
            <label className="referee-field">Match summary<textarea rows={4} value={matchSummary} onChange={(event) => setMatchSummary(event.target.value)} placeholder="Optional match write-up…" /></label>
            <div className="referee-report-actions"><button className="referee-secondary" disabled={saving} onClick={() => void saveReport(false)}>Save draft</button><button className="referee-primary" disabled={saving} onClick={() => void saveReport(true)}>{saving ? "Saving…" : "Submit for admin approval"}</button></div>
          </>}
        </>}
      </section>}
      {activeTab === "More" && <section className="referee-section"><p className="eyebrow">PROFILE · AVAILABILITY · EARNINGS</p><h1>More</h1>
        <section className="referee-subsection"><h2>Submit availability</h2><p className="referee-muted">Availability helps administrators schedule officials. It never assigns a fixture automatically.</p><form className="referee-form" onSubmit={saveAvailability}>
          <label>Date<input type="date" required value={availableOn} onChange={(event) => setAvailableOn(event.target.value)} /></label>
          <div className="referee-inline-fields"><label>From<input type="time" required value={availabilityStart} onChange={(event) => setAvailabilityStart(event.target.value)} /></label><label>Until<input type="time" required value={availabilityEnd} onChange={(event) => setAvailabilityEnd(event.target.value)} /></label></div>
          <label>Preferred location<select required value={availabilityLocation} onChange={(event) => setAvailabilityLocation(event.target.value)}><option value="">Choose location</option>{locations.map((location) => <option key={location.location_id} value={location.location_id}>{location.location_name}</option>)}</select></label>
          <label>Note (optional)<input value={availabilityNote} onChange={(event) => setAvailabilityNote(event.target.value)} /></label>
          <button className="referee-primary" disabled={saving}>Save availability</button>
        </form>
        <div className="referee-availability-list">{availability.map((slot) => <article key={slot.id}><strong>{new Date(slot.available_on + "T00:00:00").toLocaleDateString("en-GB", { dateStyle: "medium" })}</strong><span>{slot.starts_at.slice(0,5)}–{slot.ends_at.slice(0,5)} · {slot.location_name}</span></article>)}</div></section>
        <section className="referee-subsection"><h2>Payments and earnings</h2>
          <div className="referee-finance-summary">
            <article><span>Net entitlement</span><strong>{money(Number(careerSummary?.lifetime_net_entitlement_pence ?? 0))}</strong></article>
            <article><span>Awaiting payment</span><strong>{money(Number(careerSummary?.awaiting_payment_pence ?? 0))}</strong></article>
            <article><span>Transferred to Stripe balance</span><strong>{money(Number(careerSummary?.transferred_to_connected_balance_pence ?? 0))}</strong></article>
            <article><span>Paid out to bank</span><strong>{money(Number(careerSummary?.paid_out_to_bank_pence ?? 0))}</strong></article>
          </div>
          {payments.length === 0 ? <p className="referee-muted">No approved report allocations yet.</p> : payments.map((payment) => <article className="referee-payment-row" key={payment.report_id}><div><strong>Gameweek {payment.gameweek}</strong><span>{payment.status.replaceAll("_"," ")}</span></div><div><b>{payment.net_entitlement_pence === null ? "Fee reconciliation pending" : money(payment.net_entitlement_pence)}</b><small>£22 gross · £20 minimum net</small></div></article>)}
          <h3>Career milestone rewards</h3>
          {milestoneRewards.length === 0 ? <p className="referee-muted">No milestone rewards unlocked yet. The first reward unlocks at 50 approved games.</p> : milestoneRewards.map((reward) => <article className="referee-payment-row" key={reward.reward_id}><div><strong>{reward.milestone_games}-game milestone</strong><span>{reward.status.replaceAll("_"," ")}</span></div><div><b>{money(reward.reward_amount_pence)}</b><small>{reward.paid_at ? `Paid ${dateTime(reward.paid_at)}` : reward.approved_at ? `Approved ${dateTime(reward.approved_at)} · awaiting payment` : "Awaiting administrator confirmation"}</small></div></article>)}
        </section>
      </section>}
    </section>
    <nav className="referee-bottom-nav" aria-label="Referee navigation">
      {(["Home","Match Centre","Teams","Matchday","More"] as const).map((tab) => <button key={tab} className={activeTab === tab ? "is-active" : ""} onClick={() => setActiveTab(tab)}><span>{tab === "Home" ? "⌂" : tab === "Match Centre" ? "▤" : tab === "Teams" ? "♧" : tab === "Matchday" ? "⚑" : "⋯"}</span>{tab}</button>)}
    </nav>
  </main>;
}
