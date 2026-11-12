import { useEffect, useState, type FormEvent } from "react";
import { PlayerBottomNavigation } from "../components/player-bottom-navigation";
import { PlayerCompetitionSelector, usePlayerCompetitionContext } from "../lib/competition/player-context";
import { Link, createFileRoute } from "@tanstack/react-router";
import type { Session } from "@supabase/supabase-js";
import { getSupabaseClient } from "../lib/supabase/client";
import { getTeamRequestDisplay, type TeamRequestStatus } from "../lib/team-request-status";
import { useOpenPlayAnalytics } from "../components/analytics-provider";

type TeamOption = { id: string; name: string; season_id: string };
type PlayerState = {
  registration_status: "registered" | "pending_review" | "rejected";
  is_banned: boolean;
  full_name: string;
  phone: string | null;
};
type TeamRegistrationTerms = {
  season_id: string;
  season_name: string;
  competition_id: string;
  competition_name: string;
  weekly_fee_pence: number;
  gameweek_count: number;
  full_season_total_pence: number;
};
type TeamStatus = "new" | "returning" | "";
type WhatsappMode = "same" | "different" | "none" | "";
type DeclarationKey = "authority" | "accuracy" | "payment" | "age" | "rules";

const declarations: { key: DeclarationKey; text: string }[] = [
  { key: "authority", text: "I confirm that I am authorised to register this team and act as its captain." },
  { key: "accuracy", text: "I confirm that the information supplied is accurate and I will keep Open Play updated if anything changes." },
  { key: "payment", text: "I accept responsibility for ensuring the full team fixture payment is paid at least 24 hours before kick-off and for collecting payments from players." },
  { key: "age", text: "I confirm that every player representing this team will be aged 16 or over." },
  { key: "rules", text: "I confirm that the team agrees to follow the applicable Open Play league rules and competition requirements." },
];

const formatMoney = (pence: number) =>
  new Intl.NumberFormat("en-GB", { style: "currency", currency: "GBP" }).format(pence / 100);

const validPhone = (value: string) => /^\+?[0-9][0-9 ()-]{6,18}$/.test(value.trim());
const validInstagramUrl = (value: string) => {
  try {
    const url = new URL(value);
    return ["instagram.com", "www.instagram.com"].includes(url.hostname.toLowerCase())
      && /^\/[A-Za-z0-9._]+\/?$/.test(url.pathname);
  } catch {
    return false;
  }
};

const errorText = (cause: unknown, fallback: string) =>
  cause && typeof cause === "object" && "message" in cause && typeof cause.message === "string"
    ? cause.message
    : fallback;

export const Route = createFileRoute("/join")({ component: JoinPage });

function JoinPage() {
  const competition = usePlayerCompetitionContext();
  const capture = useOpenPlayAnalytics();
  const [session, setSession] = useState<Session | null>(null);
  const [player, setPlayer] = useState<PlayerState | null>(null);
  const [loading, setLoading] = useState(true);
  const [mode, setMode] = useState<"join" | "register">("join");
  const [teams, setTeams] = useState<TeamOption[]>([]);
  const [myRequests, setMyRequests] = useState<TeamRequestStatus[]>([]);
  const [teamId, setTeamId] = useState("");
  const [teamName, setTeamName] = useState("");
  const [preferredKitColour, setPreferredKitColour] = useState("");
  const [instagramUrl, setInstagramUrl] = useState("");
  const [teamStatus, setTeamStatus] = useState<TeamStatus>("");
  const [crestFile, setCrestFile] = useState<File | null>(null);
  const [whatsappMode, setWhatsappMode] = useState<WhatsappMode>("");
  const [whatsappNumber, setWhatsappNumber] = useState("");
  const [terms, setTerms] = useState<TeamRegistrationTerms | null>(null);
  const [termsLoading, setTermsLoading] = useState(false);
  const [termsError, setTermsError] = useState("");
  const [registrationStep, setRegistrationStep] = useState(1);
  const [feeAccepted, setFeeAccepted] = useState(false);
  const [declarationAccepted, setDeclarationAccepted] = useState<Record<DeclarationKey, boolean>>({
    authority: false,
    accuracy: false,
    payment: false,
    age: false,
    rules: false,
  });
  const [additionalInformation, setAdditionalInformation] = useState("");
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);
  const [recruitmentEnabled, setRecruitmentEnabled] = useState<boolean | null>(null);

  async function refreshMyRequests() {
    const { data, error: requestError } = await getSupabaseClient().rpc("get_my_team_request_statuses");
    if (requestError) throw requestError;
    setMyRequests(data ?? []);
  }

  useEffect(() => {
    const supabase = getSupabaseClient();
    let alive = true;

    async function load() {
      const { data: { session: current } } = await supabase.auth.getSession();
      const { data: recruitmentStatus, error: recruitmentError } = await supabase.rpc("get_public_team_recruitment_status");
      if (!alive) return;
      setRecruitmentEnabled(recruitmentError ? false : recruitmentStatus === true);
      if (recruitmentError) setError("Unable to check team recruitment availability. Please try again shortly.");
      setSession(current);

      if (current) {
        const { data: playerData, error: playerError } = await supabase
          .from("players")
          .select("registration_status,is_banned,full_name,phone")
          .eq("user_id", current.user.id)
          .maybeSingle();
        if (!alive) return;
        if (playerError) setError(playerError.message);
        setPlayer(playerData);
        try {
          await refreshMyRequests();
        } catch (cause) {
          if (alive) setError(errorText(cause, "Unable to load your team request history."));
        }
      }

      if (alive) setLoading(false);
    }

    void load();
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, next) => {
      setSession(next);
      if (!next) {
        setPlayer(null);
        setTeams([]);
        setMyRequests([]);
      }
    });

    return () => {
      alive = false;
      subscription.unsubscribe();
    };
  }, []);

  useEffect(() => {
    let alive = true;
    async function loadTeams() {
      setTeams([]);
      setTeamId("");
      if (!competition.selectedSeasonId) return;
      const { data, error: queryError } = await getSupabaseClient()
        .from("season_teams")
        .select("id,name,season_id")
        .eq("season_id", competition.selectedSeasonId)
        .eq("registration_status", "approved")
        .order("name");
      if (!alive) return;
      if (queryError) setError(queryError.message);
      else setTeams(data ?? []);
    }
    void loadTeams();
    return () => { alive = false; };
  }, [competition.selectedSeasonId]);

  useEffect(() => {
    let alive = true;
    setRegistrationStep(1);
    setFeeAccepted(false);
    setDeclarationAccepted({ authority: false, accuracy: false, payment: false, age: false, rules: false });
    setTerms(null);
    setTermsError("");

    async function loadTerms() {
      if (mode !== "register" || !competition.selectedSeasonId) {
        setTermsLoading(false);
        return;
      }
      setTermsLoading(true);
      const { data, error: termsQueryError } = await getSupabaseClient()
        .rpc("get_team_registration_terms", { p_season_id: competition.selectedSeasonId })
        .maybeSingle();
      if (!alive) return;
      if (termsQueryError) {
        setTermsError(termsQueryError.message);
        setTerms(null);
      } else {
        setTerms(data);
      }
      setTermsLoading(false);
    }

    void loadTerms();
    return () => { alive = false; };
  }, [mode, competition.selectedSeasonId, session?.user.id]);

  async function submitJoin(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    setMessage("");
    setBusy(true);
    try {
      if (!teamId) throw new Error("Choose a team first.");
      const { error: rpcError } = await getSupabaseClient().rpc("request_team_membership", { p_season_team_id: teamId });
      if (rpcError) throw rpcError;
      capture("player_join_request_submitted", { feature: "team_membership", outcome: "success", season_id: competition.selectedSeasonId });
      setMessage("Your request has been sent. You will become a team member only after the captain approves it.");
      try { await refreshMyRequests(); } catch { /* The request itself has already succeeded. */ }
    } catch (cause) {
      capture("workflow_error", { feature: "team_membership", error_code: "unexpected_error", outcome: "failure" });
      setError(errorText(cause, "Unable to send your team request."));
    } finally {
      setBusy(false);
    }
  }

  function handleNextStep() {
    setError("");
    if (registrationStep === 1) {
      if (!teamName.trim()) return setError("Enter your team name.");
      if (!teamStatus) return setError("Choose whether this is a new or returning team.");
      if (instagramUrl.trim() && !validInstagramUrl(instagramUrl.trim())) {
        return setError("Enter a full Instagram profile link, or leave the field blank.");
      }
      if (crestFile) {
        const allowedTypes = ["image/png", "image/jpeg", "image/svg+xml"];
        if (!allowedTypes.includes(crestFile.type)) return setError("Upload a PNG, JPG or SVG team crest.");
        if (crestFile.size > 5 * 1024 * 1024) return setError("Your team crest must be 5 MB or smaller.");
      }
    }
    if (registrationStep === 2) {
      if (!whatsappMode) return setError("Choose how the captain can be contacted on WhatsApp.");
      if (whatsappMode === "different" && !validPhone(whatsappNumber)) {
        return setError("Enter a valid WhatsApp number.");
      }
      if (!player?.phone) return setError("Add a mobile number to your player profile before continuing.");
    }
    if (registrationStep === 3) {
      if (!terms) return setError(termsError || "The season fee details are not available yet.");
      if (!feeAccepted) return setError("You must accept the weekly team fee and full-season total.");
      if (!Object.values(declarationAccepted).every(Boolean)) {
        return setError("Please accept every team registration declaration.");
      }
    }
    setRegistrationStep((step) => Math.min(4, step + 1));
  }

  async function submitTeam(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    setMessage("");
    setBusy(true);
    let uploadedBadgePath: string | null = null;

    try {
      if (!session || !competition.selectedSeasonId || !terms) {
        throw new Error("There is no open season with confirmed registration terms available.");
      }

      if (crestFile) {
        const extension = crestFile.name.split(".").pop()?.toLowerCase() ?? "";
        if (!["png", "jpg", "jpeg", "svg"].includes(extension)) {
          throw new Error("Upload a PNG, JPG or SVG team crest.");
        }
        uploadedBadgePath = session.user.id + "/" + crypto.randomUUID() + "." + extension;
        const { error: uploadError } = await getSupabaseClient()
          .storage.from("team-crests")
          .upload(uploadedBadgePath, crestFile, { upsert: false, contentType: crestFile.type });
        if (uploadError) throw uploadError;
      }

      const { data, error: rpcError } = await getSupabaseClient().rpc("register_team", {
        p_season_id: competition.selectedSeasonId,
        p_team_name: teamName.trim(),
        p_preferred_kit_colour: preferredKitColour.trim() || null,
        p_instagram_url: instagramUrl.trim() || null,
        p_team_status: teamStatus,
        p_badge_path: uploadedBadgePath,
        p_captain_whatsapp: whatsappMode === "different" ? whatsappNumber.trim() : null,
        p_captain_whatsapp_same_as_mobile: whatsappMode === "same",
        p_captain_no_whatsapp: whatsappMode === "none",
        p_weekly_fee_accepted_pence: terms.weekly_fee_pence,
        p_full_season_total_accepted_pence: terms.full_season_total_pence,
        p_gameweek_count_accepted: terms.gameweek_count,
        p_fee_accepted: feeAccepted,
        p_declaration_authority: declarationAccepted.authority,
        p_declaration_accuracy: declarationAccepted.accuracy,
        p_declaration_payment: declarationAccepted.payment,
        p_declaration_age: declarationAccepted.age,
        p_declaration_rules: declarationAccepted.rules,
        p_additional_information: additionalInformation.trim() || null,
      });
      if (rpcError) throw rpcError;

      capture("team_registration_submitted", { feature: "team_registration", outcome: "success", season_id: competition.selectedSeasonId });
      setMessage("Your application for " + data.name + " has been submitted for administrator approval. You will become its captain only after approval.");
      try { await refreshMyRequests(); } catch { /* The application itself has already succeeded. */ }

      setTeamName("");
      setPreferredKitColour("");
      setInstagramUrl("");
      setTeamStatus("");
      setCrestFile(null);
      setWhatsappMode("");
      setWhatsappNumber("");
      setFeeAccepted(false);
      setDeclarationAccepted({ authority: false, accuracy: false, payment: false, age: false, rules: false });
      setAdditionalInformation("");
      setRegistrationStep(1);
    } catch (cause) {
      if (uploadedBadgePath) {
        await getSupabaseClient().storage.from("team-crests").remove([uploadedBadgePath]);
      }
      capture("workflow_error", { feature: "team_registration", error_code: "unexpected_error", outcome: "failure" });
      setError(errorText(cause, "Unable to submit team registration."));
    } finally {
      setBusy(false);
    }
  }

  function handleRegistrationSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (registrationStep < 4) {
      handleNextStep();
      return;
    }
    void submitTeam(event);
  }

  const selectedSeason = competition.seasons.find((season) => season.id === competition.selectedSeasonId);
  const registrationOpen = selectedSeason?.status === "registration_open";
  const declarationsComplete = Object.values(declarationAccepted).every(Boolean);

  if (loading) return <main className="notice-page player-facing"><section className="notice-panel"><p>Checking your account…</p></section></main>;

  if (!session) return (
    <main className="notice-page player-facing">
      <section className="notice-panel">
        <Link className="notice-brand" to="/player"><img className="open-play-logo" src="/open-play-logo.png" alt="Open Play" /></Link>
        <p className="eyebrow eyebrow-dark">GET INVOLVED</p>
        <h1>Find your<br /><em>place to play.</em></h1>
        <p>Create an account or sign in before joining a team or submitting a team application.</p>
        <div className="auth-form">
          <Link className="button" to="/sign-up">CREATE ACCOUNT <span>↗</span></Link>
          <Link className="auth-switch" to="/sign-in">Already have an account? Sign in</Link>
        </div>
      </section>
    </main>
  );

  if (!player || player.registration_status !== "registered" || player.is_banned) return (
    <main className="notice-page player-facing">
      <section className="notice-panel">
        <Link className="notice-brand" to="/player"><img className="open-play-logo" src="/open-play-logo.png" alt="Open Play" /></Link>
        <p className="eyebrow eyebrow-dark">PLAYER REGISTRATION</p>
        <h1>Register<br /><em>to play.</em></h1>
        <p>{player?.registration_status === "pending_review"
          ? "Your player registration is awaiting an identity review. You can join or register a team after approval."
          : player?.is_banned
            ? "Your account cannot submit team requests. Please contact Open Play support."
            : "You need an approved player profile before you can join an existing team or register a new one."}</p>
        <Link className="button" to="/register-player">PLAYER REGISTRATION <span>↗</span></Link>
      </section>
    </main>
  );

  return (
    <main className="notice-page player-facing">
      <section className="notice-panel auth-panel join-open-play-panel">
        <Link className="notice-brand" to="/player"><img className="open-play-logo" src="/open-play-logo.png" alt="Open Play" /></Link>
        <p className="eyebrow eyebrow-dark">GET INVOLVED</p>
        <h1>Find your<br /><em>place to play.</em></h1>
        <p>Signed in as <strong>{session.user.email}</strong>. Your player registration is approved.</p>

        {myRequests.length > 0 && (
          <section className="join-request-list" aria-labelledby="join-request-heading">
            <div className="join-request-heading">
              <div><p className="eyebrow eyebrow-dark">YOUR TEAM ACTIVITY</p><h2 id="join-request-heading">Requests &amp; memberships</h2></div>
              <span>{myRequests.length} records</span>
            </div>
            {myRequests.map((item) => {
              const display = getTeamRequestDisplay(item);
              return (
                <article className="join-request-item" key={item.membership_id}>
                  <div className="join-request-item-top">
                    <div><strong>{item.team_name}</strong><span>{item.season_name}</span></div>
                    <span className={"join-request-status join-request-status--" + display.tone}>{display.label}</span>
                  </div>
                  <p>{display.description}</p>
                </article>
              );
            })}
          </section>
        )}

        <PlayerCompetitionSelector context={competition} />
        {competition.error && <p className="form-error" role="alert">{competition.error}</p>}
        {error && <p className="form-error" role="alert">{error}</p>}
        {message && <p className="form-note" role="status">{message}</p>}

        {recruitmentEnabled && (
          <div className="auth-mode-switch">
            <button type="button" className={mode === "join" ? "active" : ""} onClick={() => { setMode("join"); setError(""); setMessage(""); }}>JOIN A TEAM</button>
            <button type="button" className={mode === "register" ? "active" : ""} onClick={() => { capture("team_registration_started", { feature: "team_registration" }); setMode("register"); setError(""); setMessage(""); }}>REGISTER A TEAM</button>
          </div>
        )}

        {competition.loading || recruitmentEnabled === null
          ? <p className="form-note">Checking recruitment availability…</p>
          : !recruitmentEnabled
            ? <p className="form-note">Team recruitment is temporarily paused by Open Play. You can still view public fixtures, results and league tables. Please check back later.</p>
            : !registrationOpen
              ? <p className="form-note">There is no public season currently accepting registrations for this location. Choose another location or check back when registration opens.</p>
              : <>
                <p className="form-note">Registration is open for {selectedSeason?.name}.</p>
                {mode === "join" ? (
                  <form className="auth-form" onSubmit={submitJoin}>
                    <label>Team
                      <select required value={teamId} onChange={(event) => setTeamId(event.target.value)}>
                        <option value="">Choose a team</option>
                        {teams.map((team) => <option key={team.id} value={team.id}>{team.name}</option>)}
                      </select>
                    </label>
                    {teams.length === 0 && <p className="form-note">No approved teams are currently listed for this season.</p>}
                    <button className="button" type="submit" disabled={busy || !teamId}>{busy ? "SENDING REQUEST…" : "REQUEST TO JOIN"} <span>↗</span></button>
                  </form>
                ) : (
                  <form className="auth-form team-registration-form" onSubmit={handleRegistrationSubmit}>
                    <div className="team-registration-progress">
                      <span>STEP {registrationStep} OF 4</span>
                      <div className="team-registration-progress-track"><span style={{ width: (registrationStep * 25) + "%" }} /></div>
                    </div>

                    {registrationStep === 1 && (
                      <section className="team-registration-step" aria-labelledby="team-registration-step-one">
                        <p className="eyebrow eyebrow-dark">01 / TEAM DETAILS</p>
                        <h2 id="team-registration-step-one">BUILD YOUR TEAM</h2>
                        <label>Team name<input required maxLength={80} value={teamName} onChange={(event) => setTeamName(event.target.value)} placeholder="Enter your team name" /></label>
                        <label>Preferred kit colour<input maxLength={40} value={preferredKitColour} onChange={(event) => setPreferredKitColour(event.target.value)} placeholder="e.g. Orange and black" /></label>
                        <label>Team Instagram link <span className="field-optional">OPTIONAL</span><input type="url" value={instagramUrl} onChange={(event) => setInstagramUrl(event.target.value)} placeholder="https://www.instagram.com/yourteam" /></label>
                        <label>Team crest <span className="field-optional">OPTIONAL</span>
                          <input type="file" accept="image/png,image/jpeg,image/svg+xml" onChange={(event) => setCrestFile(event.currentTarget.files?.[0] ?? null)} />
                        </label>
                        <p className="form-note">PNG, JPG or SVG · Maximum 5 MB. You can add or change your crest later.</p>
                        {crestFile && <div className="team-selected-file"><span>{crestFile.name}</span><button type="button" onClick={() => setCrestFile(null)}>Remove</button></div>}
                        <fieldset className="team-registration-choice">
                          <legend>Is this a new or returning team?</legend>
                          <label><input type="radio" name="team-status" value="new" checked={teamStatus === "new"} onChange={() => setTeamStatus("new")} /> New team</label>
                          <label><input type="radio" name="team-status" value="returning" checked={teamStatus === "returning"} onChange={() => setTeamStatus("returning")} /> Returning team</label>
                        </fieldset>
                      </section>
                    )}

                    {registrationStep === 2 && (
                      <section className="team-registration-step" aria-labelledby="team-registration-step-two">
                        <p className="eyebrow eyebrow-dark">02 / CAPTAIN DETAILS</p>
                        <h2 id="team-registration-step-two">WHO'S LEADING?</h2>
                        <p className="form-note">Your player profile supplies the captain's name and mobile number, so these details stay consistent with your registered account.</p>
                        <div className="team-captain-details">
                          <div><span>CAPTAIN NAME</span><strong>{player.full_name}</strong></div>
                          <div><span>MOBILE NUMBER</span><strong>{player.phone || "Add a mobile number to your player profile"}</strong></div>
                          <div><span>ACCOUNT EMAIL</span><strong>{session.user.email}</strong></div>
                        </div>
                        <fieldset className="team-registration-choice">
                          <legend>WhatsApp contact number</legend>
                          <label><input type="radio" name="whatsapp-mode" value="same" checked={whatsappMode === "same"} onChange={() => setWhatsappMode("same")} /> Same as my mobile number</label>
                          <label><input type="radio" name="whatsapp-mode" value="different" checked={whatsappMode === "different"} onChange={() => setWhatsappMode("different")} /> Use a different WhatsApp number</label>
                          <label><input type="radio" name="whatsapp-mode" value="none" checked={whatsappMode === "none"} onChange={() => setWhatsappMode("none")} /> I don't use WhatsApp</label>
                        </fieldset>
                        {whatsappMode === "different" && (
                          <label>WhatsApp number<input type="tel" value={whatsappNumber} onChange={(event) => setWhatsappNumber(event.target.value)} placeholder="+44 7700 900000" /></label>
                        )}
                      </section>
                    )}

                    {registrationStep === 3 && (
                      <section className="team-registration-step" aria-labelledby="team-registration-step-three">
                        <p className="eyebrow eyebrow-dark">03 / FEES &amp; DECLARATIONS</p>
                        <h2 id="team-registration-step-three">FINAL CHECK</h2>
                        {termsLoading
                          ? <p className="form-note">Loading the current season fee…</p>
                          : termsError
                            ? <p className="form-error" role="alert">{termsError}</p>
                            : terms && (
                              <>
                                <div className="team-fee-summary">
                                  <p className="eyebrow eyebrow-dark">{terms.competition_name} · {terms.season_name}</p>
                                  <div className="team-fee-summary-grid">
                                    <div><span>WEEKLY TEAM FEE</span><strong>{formatMoney(terms.weekly_fee_pence)}</strong></div>
                                    <div><span>GAMEWEEKS</span><strong>{terms.gameweek_count}</strong></div>
                                    <div className="team-fee-total"><span>FULL-SEASON TOTAL</span><strong>{formatMoney(terms.full_season_total_pence)}</strong></div>
                                  </div>
                                  <p className="form-note">The total reflects the configured team fee across all {terms.gameweek_count} gameweeks.</p>
                                </div>
                                <label className="team-declaration team-fee-acceptance">
                                  <input type="checkbox" checked={feeAccepted} onChange={(event) => setFeeAccepted(event.target.checked)} />
                                  <span>I accept the weekly team fee of <strong>{formatMoney(terms.weekly_fee_pence)}</strong> and the full-season total of <strong>{formatMoney(terms.full_season_total_pence)}</strong> for this competition.</span>
                                </label>
                                <div className="team-declarations">
                                  <p className="eyebrow eyebrow-dark">TEAM DECLARATIONS</p>
                                  {declarations.map((declaration) => (
                                    <label className="team-declaration" key={declaration.key}>
                                      <input
                                        type="checkbox"
                                        checked={declarationAccepted[declaration.key]}
                                        onChange={(event) => setDeclarationAccepted((current) => ({ ...current, [declaration.key]: event.target.checked }))}
                                      />
                                      <span>{declaration.text}</span>
                                    </label>
                                  ))}
                                </div>
                              </>
                            )}
                      </section>
                    )}

                    {registrationStep === 4 && (
                      <section className="team-registration-step" aria-labelledby="team-registration-step-four">
                        <p className="eyebrow eyebrow-dark">04 / LAST DETAILS</p>
                        <h2 id="team-registration-step-four">ANYTHING ELSE?</h2>
                        <p className="form-note">Declarations are complete. Add anything else the Open Play team should know about your application. This is optional.</p>
                        <label>Additional information <span className="field-optional">OPTIONAL</span>
                          <textarea rows={5} maxLength={2000} value={additionalInformation} onChange={(event) => setAdditionalInformation(event.target.value)} placeholder="Anything else we should know?" />
                        </label>
                        <div className="team-registration-review">
                          <p className="eyebrow eyebrow-dark">APPLICATION SUMMARY</p>
                          <div><span>TEAM</span><strong>{teamName || "—"}</strong></div>
                          <div><span>CAPTAIN</span><strong>{player.full_name}</strong></div>
                          <div><span>SEASON</span><strong>{terms?.season_name || selectedSeason?.name || "—"}</strong></div>
                          <div><span>FEE ACCEPTED</span><strong>{terms ? formatMoney(terms.weekly_fee_pence) + " / week · " + formatMoney(terms.full_season_total_pence) + " total" : "—"}</strong></div>
                        </div>
                        <p className="form-note">Your application will be reviewed by an Open Play administrator. Your captain access will only activate after approval.</p>
                      </section>
                    )}

                    <div className="team-registration-actions">
                      {registrationStep > 1 && <button className="team-back-button" type="button" disabled={busy} onClick={() => { setError(""); setRegistrationStep((step) => Math.max(1, step - 1)); }}>BACK</button>}
                      {registrationStep < 4
                        ? <button className="button" type="submit" disabled={busy || (registrationStep === 3 && (!terms || termsLoading || !feeAccepted || !declarationsComplete))}>
                            CONTINUE <span>↗</span>
                          </button>
                        : <button className="button" type="submit" disabled={busy || !terms}>
                            {busy ? "SUBMITTING…" : "SUBMIT TEAM APPLICATION"} <span>↗</span>
                          </button>}
                    </div>
                  </form>
                )}
              </>}

        <Link className="auth-switch" to="/player">Back to Player Hub</Link>
      </section>
      <PlayerBottomNavigation variant="join" />
    </main>
  );
}
