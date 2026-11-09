import { useEffect, useState } from "react";
import { Link, createFileRoute, useNavigate } from "@tanstack/react-router";
import type { Session } from "@supabase/supabase-js";
import { PlayerBottomNavigation } from "../components/player-bottom-navigation";
import { getSupabaseClient } from "../lib/supabase/client";

type RefereeApplication = {
  id: string;
  full_name: string;
  phone: string;
  experience: string;
  qualifications: string;
  availability: string;
  preferred_locations: string[];
  additional_notes: string;
  status: "pending" | "approved" | "rejected";
  submitted_at: string;
  reviewed_at: string | null;
  review_reason: string | null;
};

export const Route = createFileRoute("/apply-referee")({ component: ApplyRefereePage });

function ApplyRefereePage() {
  const navigate = useNavigate();
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);
  const [application, setApplication] = useState<RefereeApplication | null>(null);
  const [fullName, setFullName] = useState("");
  const [phone, setPhone] = useState("");
  const [experience, setExperience] = useState("");
  const [qualifications, setQualifications] = useState("");
  const [availability, setAvailability] = useState("");
  const [locations, setLocations] = useState("");
  const [notes, setNotes] = useState("");
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    const supabase = getSupabaseClient();
    let active = true;

    async function load() {
      const { data: { session: current } } = await supabase.auth.getSession();
      if (!active) return;
      setSession(current);

      if (current) {
        const [{ data: rows, error: applicationError }, { data: profile }] = await Promise.all([
          supabase.rpc("get_my_referee_application"),
          supabase.from("profiles").select("first_name,last_name,phone").eq("id", current.user.id).maybeSingle(),
        ]);
        if (!active) return;
        if (applicationError) setError(applicationError.message);
        else {
          const currentApplication = ((rows ?? []) as unknown as RefereeApplication[])[0] ?? null;
          setApplication(currentApplication);
          if (currentApplication) {
            setFullName(currentApplication.full_name);
            setPhone(currentApplication.phone);
            setExperience(currentApplication.experience);
            setQualifications(currentApplication.qualifications);
            setAvailability(currentApplication.availability);
            setLocations(currentApplication.preferred_locations.join(", "));
            setNotes(currentApplication.additional_notes);
          } else if (profile) {
            setFullName([profile.first_name, profile.last_name].filter(Boolean).join(" "));
            setPhone(profile.phone ?? "");
          }
        }
        const { data: hasRole } = await supabase.rpc("has_referee_role");
        if (active && hasRole) await navigate({ to: "/referee", replace: true });
      }
      if (active) setLoading(false);
    }

    void load();
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, next) => {
      setSession(next);
      if (next) void load();
      else setApplication(null);
    });
    return () => {
      active = false;
      subscription.unsubscribe();
    };
  }, [navigate]);

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    setMessage("");
    if (!session) {
      setError("Sign in to your Open Play account before submitting an application.");
      return;
    }
    if (!session.user.email_confirmed_at) {
      setError("Please verify your email address before applying to become an Open Play referee.");
      return;
    }
    setBusy(true);
    try {
      const preferredLocations = locations.split(",").map((value) => value.trim()).filter(Boolean);
      const { error: submitError } = await getSupabaseClient().rpc("submit_referee_application", {
        p_full_name: fullName.trim(),
        p_phone: phone.trim(),
        p_experience: experience.trim(),
        p_qualifications: qualifications.trim(),
        p_availability: availability.trim(),
        p_preferred_locations: preferredLocations,
        p_additional_notes: notes.trim(),
      });
      if (submitError) throw submitError;
      const { data: rows, error: statusError } = await getSupabaseClient().rpc("get_my_referee_application");
      if (statusError) throw statusError;
      const updated = ((rows ?? []) as unknown as RefereeApplication[])[0] ?? null;
      setApplication(updated);
      setMessage("Your referee application has been submitted. An Open Play administrator will review it before any referee access is granted.");
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Unable to submit your referee application. Please try again.");
    } finally {
      setBusy(false);
    }
  }

  if (loading) {
    return <main className="notice-page player-facing"><section className="notice-panel auth-panel"><p role="status">Loading referee application…</p></section><PlayerBottomNavigation /></main>;
  }

  return (
    <main className="notice-page player-facing">
      <section className="notice-panel auth-panel">
        <Link className="notice-brand" to="/"><img className="open-play-logo" src="/open-play-logo.png" alt="Open Play" /></Link>
        <p className="eyebrow eyebrow-dark">OPEN PLAY OFFICIALS</p>
        <h1>Become a<br /><em>referee.</em></h1>
        <p>Join the team behind the game. Apply to officiate Open Play fixtures and help keep every match fair, organised and enjoyable.</p>

        {!session ? (
          <section className="hub-memberships">
            <p className="form-note">You need an Open Play account to apply. Creating an account does not grant referee access; every application is reviewed by an administrator.</p>
            <Link className="button" to="/sign-up">CREATE AN ACCOUNT ↗</Link>
            <p className="auth-switch">Already have an account? <Link to="/sign-in">Sign in</Link>, then return here.</p>
          </section>
        ) : application?.status === "pending" ? (
          <section className="hub-memberships">
            <p className="join-request-status join-request-status--pending">APPLICATION UNDER REVIEW</p>
            <h2>Thanks for applying, {application.full_name}.</h2>
            <p>Your application was submitted on {new Date(application.submitted_at).toLocaleDateString("en-GB")}. An administrator will review your details. Referee permissions remain locked until approval.</p>
            <p className="form-note">You can continue using any other Open Play workspaces already available to your account.</p>
          </section>
        ) : application?.status === "approved" ? (
          <section className="hub-memberships">
            <p className="join-request-status join-request-status--success">APPLICATION APPROVED</p>
            <h2>You're an Open Play referee.</h2>
            <p>Your referee membership is active.</p>
            <Link className="button" to="/referee">OPEN REFEREE HUB ↗</Link>
          </section>
        ) : (
          <>
            {application?.status === "rejected" && (
              <div className="form-error" role="status">
                <strong>Your previous application was not approved.</strong>
                {application.review_reason && <p>{application.review_reason}</p>}
                <p>You can update your details and submit a new application.</p>
              </div>
            )}
            {!session.user.email_confirmed_at && <p className="form-note">Verify your email address before submitting this application.</p>}
            <form className="auth-form" onSubmit={submit}>
              <label>Full name<input required minLength={2} maxLength={100} value={fullName} onChange={(event) => setFullName(event.target.value)} autoComplete="name" /></label>
              <label>Contact telephone number<input required type="tel" minLength={7} maxLength={30} value={phone} onChange={(event) => setPhone(event.target.value)} autoComplete="tel" /></label>
              <label>Refereeing or football experience<textarea required minLength={10} maxLength={3000} rows={5} value={experience} onChange={(event) => setExperience(event.target.value)} placeholder="Tell us about any refereeing experience, playing experience or relevant background." /></label>
              <label>Qualifications or courses<textarea maxLength={2000} rows={3} value={qualifications} onChange={(event) => setQualifications(event.target.value)} placeholder="For example, FA referee qualification or courses. Enter none if not applicable." /></label>
              <label>Availability<textarea required minLength={3} maxLength={1000} rows={3} value={availability} onChange={(event) => setAvailability(event.target.value)} placeholder="Which evenings, days or times can you usually officiate?" /></label>
              <label>Preferred locations<input value={locations} onChange={(event) => setLocations(event.target.value)} placeholder="Separate locations with commas, e.g. Bideford, Barnstaple" /></label>
              <label>Anything else we should know?<textarea maxLength={2000} rows={3} value={notes} onChange={(event) => setNotes(event.target.value)} /></label>
              {error && <p className="form-error" role="alert">{error}</p>}
              {message && <p className="form-success" role="status">{message}</p>}
              <button className="button" type="submit" disabled={busy || !session.user.email_confirmed_at}>{busy ? "SUBMITTING APPLICATION…" : application ? "RESUBMIT APPLICATION" : "SUBMIT REFEREE APPLICATION"} <span aria-hidden="true">↗</span></button>
            </form>
            <p className="form-note">Submitting an application does not make you a referee. Only an authorised Open Play administrator can approve your application and activate the referee membership.</p>
          </>
        )}
        <Link className="auth-switch" to="/more">Back to More</Link>
      </section>
      <PlayerBottomNavigation />
    </main>
  );
}
