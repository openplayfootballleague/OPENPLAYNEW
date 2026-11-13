import { useEffect, useMemo, useState, type FormEvent } from "react";
import { getSupabaseClient } from "../lib/supabase/client";

type SeasonOption = {
  id: string;
  name: string;
  league_id: string;
  location_id: string;
  starts_on: string | null;
  ends_on: string | null;
  status: string;
  matchday_weekday: number | null;
  matchday_start_time: string | null;
  match_duration_minutes: number | null;
  matchday_buffer_minutes: number;
  default_venue_id: string | null;
  round_robin_mode: string;
};

type VenueOption = {
  id: string;
  location_id: string;
  name: string;
  is_active: boolean;
};

type LocationOption = { id: string; is_active: boolean };

type PreviewFixture = {
  gameweek: number;
  fixture_number: number;
  home_team_id: string;
  home_team_name: string;
  away_team_id: string;
  away_team_name: string;
  scheduled_at: string;
};

type FixturePreview = {
  season_id: string;
  season_name: string;
  venue_id: string;
  venue_name: string;
  first_matchday_date: string;
  last_matchday_date: string;
  round_count: number;
  fixture_count: number;
  fixtures: PreviewFixture[];
};

type Props = {
  seasons: SeasonOption[];
  venues: VenueOption[];
  locations: LocationOption[];
  fixtures: Array<{ season_id: string }>;
  defaultSeasonId?: string | null;
  onGenerated: () => void | Promise<void>;
};

const WEEKDAYS = [
  { value: 0, label: "Sunday" },
  { value: 1, label: "Monday" },
  { value: 2, label: "Tuesday" },
  { value: 3, label: "Wednesday" },
  { value: 4, label: "Thursday" },
  { value: 5, label: "Friday" },
  { value: 6, label: "Saturday" },
];

function formatDateTime(value: string) {
  return new Intl.DateTimeFormat("en-GB", {
    weekday: "short",
    day: "numeric",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
    timeZone: "Europe/London",
  }).format(new Date(value));
}

export function AdminFixtureGenerator({ seasons, venues, locations, fixtures, defaultSeasonId, onGenerated }: Props) {
  const eligibleSeasons = useMemo(() => seasons.filter((season) => ["draft", "registration_open", "active"].includes(season.status)), [seasons]);
  const [seasonId, setSeasonId] = useState(defaultSeasonId && seasons.some((season) => season.id === defaultSeasonId && ["draft", "registration_open", "active"].includes(season.status)) ? defaultSeasonId : eligibleSeasons[0]?.id || "");
  const selectedSeason = useMemo(() => eligibleSeasons.find((season) => season.id === seasonId) || null, [eligibleSeasons, seasonId]);
  const [firstMatchdayDate, setFirstMatchdayDate] = useState("");
  const [weekday, setWeekday] = useState("");
  const [startTime, setStartTime] = useState("");
  const [duration, setDuration] = useState("");
  const [buffer, setBuffer] = useState("0");
  const [venueId, setVenueId] = useState("");
  const [roundRobinMode, setRoundRobinMode] = useState("double");
  const [settingsSaved, setSettingsSaved] = useState(false);
  const [saving, setSaving] = useState(false);
  const [previewing, setPreviewing] = useState(false);
  const [generating, setGenerating] = useState(false);
  const [confirmGenerate, setConfirmGenerate] = useState(false);
  const [preview, setPreview] = useState<FixturePreview | null>(null);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");

  const seasonHasFixtures = fixtures.some((fixture) => fixture.season_id === seasonId);\n\n  const availableVenues = useMemo(() => {
    if (!selectedSeason) return [];
    return venues.filter((venue) =>
      venue.location_id === selectedSeason.location_id &&
      venue.is_active &&
      locations.some((location) => location.id === venue.location_id && location.is_active)
    );
  }, [locations, selectedSeason, venues]);

  useEffect(() => {
    if (!selectedSeason) return;
    setWeekday(selectedSeason.matchday_weekday === null ? "" : String(selectedSeason.matchday_weekday));
    setStartTime(selectedSeason.matchday_start_time?.slice(0, 5) || "");
    setDuration(selectedSeason.match_duration_minutes === null ? "" : String(selectedSeason.match_duration_minutes));
    setBuffer(String(selectedSeason.matchday_buffer_minutes ?? 0));
    setVenueId(selectedSeason.default_venue_id || "");
    setRoundRobinMode(selectedSeason.round_robin_mode || "double");
    if (selectedSeason.starts_on && selectedSeason.matchday_weekday !== null) {\n      const firstDate = new Date(`${selectedSeason.starts_on}T12:00:00`);\n      const offset = (selectedSeason.matchday_weekday - firstDate.getDay() + 7) % 7;\n      firstDate.setDate(firstDate.getDate() + offset);\n      setFirstMatchdayDate(`${firstDate.getFullYear()}-${String(firstDate.getMonth() + 1).padStart(2, "0")}-${String(firstDate.getDate()).padStart(2, "0")}`);\n    } else {\n      setFirstMatchdayDate(selectedSeason.starts_on || "");\n    }
    setPreview(null);
    setConfirmGenerate(false);
    setError("");
    setSettingsSaved(Boolean(selectedSeason.matchday_weekday !== null && selectedSeason.matchday_start_time && selectedSeason.match_duration_minutes !== null && selectedSeason.default_venue_id));
  }, [seasonId]);

  async function saveSettings(event: FormEvent) {
    event.preventDefault();
    if (!selectedSeason) return;
    setSaving(true);
    setError("");
    setNotice("");
    setPreview(null);
    setConfirmGenerate(false);
    try {
      const result = await getSupabaseClient().rpc("admin_update_season_matchday_settings", {
        p_season_id: seasonId,
        p_matchday_weekday: weekday === "" ? null : Number(weekday),
        p_matchday_start_time: startTime || null,
        p_match_duration_minutes: duration === "" ? null : Number(duration),
        p_matchday_buffer_minutes: Number(buffer || 0),
        p_default_venue_id: venueId || null,
        p_round_robin_mode: roundRobinMode,
      });
      if (result.error) throw result.error;
      await onGenerated();
      setSettingsSaved(true);
      setNotice("Season matchday settings saved. Preview the schedule before generating fixtures.");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Season settings could not be saved.");
    } finally {
      setSaving(false);
    }
  }

  async function previewSchedule() {
    if (!settingsSaved) {
      setError("Save the matchday settings before previewing the schedule.");
      return;
    }
    if (!seasonId || !firstMatchdayDate) {
      setError("Choose a season and the first matchday date.");
      return;
    }
    setPreviewing(true);
    setError("");
    setNotice("");
    setPreview(null);
    setConfirmGenerate(false);
    try {
      const result = await getSupabaseClient().rpc("admin_preview_round_robin_fixtures", {
        p_season_id: seasonId,
        p_first_matchday_date: firstMatchdayDate,
      });
      if (result.error) throw result.error;
      setPreview(result.data as unknown as FixturePreview);
    } catch (err) {
      setError(err instanceof Error ? err.message : "The fixture schedule could not be previewed.");
    } finally {
      setPreviewing(false);
    }
  }

  async function generateFixtures() {
    if (!preview || !confirmGenerate) return;
    setGenerating(true);
    setError("");
    setNotice("");
    try {
      const result = await getSupabaseClient().rpc("admin_generate_round_robin_fixtures", {
        p_season_id: seasonId,
        p_first_matchday_date: firstMatchdayDate,
      });
      if (result.error) throw result.error;
      const summary = result.data as { fixture_count?: number; round_count?: number; last_matchday_date?: string } | null;
      setPreview(null);
      setConfirmGenerate(false);
      await onGenerated();
      setNotice(`Created ${summary?.fixture_count ?? preview.fixture_count} fixtures across ${summary?.round_count ?? preview.round_count} gameweeks. The fixtures are ready for administrative review.`);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Fixtures could not be generated.");
    } finally {
      setGenerating(false);
    }
  }

  if (!eligibleSeasons.length) {
    return <section className="admin-fixture-generator"><h3>Round-robin fixture generator</h3><p className="form-note">Create a season before generating fixtures.</p></section>;
  }

  return (
    <section className="admin-fixture-generator">
      <div className="admin-section-heading">
        <div><h3>Round-robin fixture generator</h3><p>Configure the season matchday, preview the complete schedule, then generate fixtures once approved.</p></div>
      </div>
      {seasonHasFixtures && <p className="form-note">Fixtures already exist for this season. Existing fixtures are never overwritten, and matchday settings are locked.</p>}\n      <form className="admin-setup-form admin-fixture-generator-form" onSubmit={saveSettings}>
        <label>Season
          <select value={seasonId} onChange={(event) => { setSeasonId(event.target.value); setPreview(null); setConfirmGenerate(false); setSettingsSaved(false); setNotice(""); setError(""); }} required>
            {eligibleSeasons.map((season) => <option key={season.id} value={season.id}>{season.name}</option>)}
          </select>
        </label>
        <label>Matchday
          <select value={weekday} onChange={(event) => { setWeekday(event.target.value); setPreview(null); setSettingsSaved(false); }} required>
            <option value="">Choose day</option>
            {WEEKDAYS.map((day) => <option key={day.value} value={day.value}>{day.label}</option>)}
          </select>
        </label>
        <label>First matchday date
          <input type="date" value={firstMatchdayDate} onChange={(event) => { setFirstMatchdayDate(event.target.value); setPreview(null); setConfirmGenerate(false); }} required />
        </label>
        <label>First kick-off
          <input type="time" value={startTime} onChange={(event) => { setStartTime(event.target.value); setPreview(null); setSettingsSaved(false); }} required />
        </label>
        <label>Match duration (minutes)
          <input type="number" min="5" max="120" value={duration} onChange={(event) => { setDuration(event.target.value); setPreview(null); setSettingsSaved(false); }} required />
        </label>
        <label>Interval between matches (minutes)
          <input type="number" min="0" max="30" value={buffer} onChange={(event) => { setBuffer(event.target.value); setPreview(null); setSettingsSaved(false); }} required />
        </label>
        <label>Venue
          <select value={venueId} onChange={(event) => { setVenueId(event.target.value); setPreview(null); setSettingsSaved(false); }} required>
            <option value="">Choose active venue</option>
            {availableVenues.map((venue) => <option key={venue.id} value={venue.id}>{venue.name}</option>)}
          </select>
        </label>
        <label>Round-robin format
          <select value={roundRobinMode} onChange={(event) => { setRoundRobinMode(event.target.value); setPreview(null); setSettingsSaved(false); }}>
            <option value="double">Double round-robin (home and away)</option>
            <option value="single">Single round-robin</option>
          </select>
        </label>
        <div className="admin-fixture-generator-actions">
          <button type="submit" disabled={saving || seasonHasFixtures}>{saving ? "Saving…" : "Save matchday settings"}</button>
          <button type="button" className="button-secondary" onClick={previewSchedule} disabled={previewing || saving || seasonHasFixtures || !settingsSaved || !weekday || !startTime || !duration || !venueId || !firstMatchdayDate}>{previewing ? "Building preview…" : "Preview schedule"}</button>
        </div>
      </form>
      {error && <p className="form-error" role="alert">{error}</p>}
      {notice && <p className="form-success" role="status">{notice}</p>}
      {preview && (
        <div className="admin-fixture-preview">
          <div className="admin-fixture-preview-summary">
            <strong>{preview.season_name}</strong>
            <span>{preview.venue_name}</span>
            <span>{preview.round_count} gameweeks</span>
            <span>{preview.fixture_count} fixtures</span>
            <span>{preview.first_matchday_date} – {preview.last_matchday_date}</span>
          </div>
          <div className="admin-fixture-preview-table-wrap">
            <table className="admin-fixture-preview-table">
              <thead><tr><th>Week</th><th>Fixture</th><th>Kick-off</th><th>Home</th><th>Away</th></tr></thead>
              <tbody>
                {preview.fixtures.map((fixture) => <tr key={`${fixture.gameweek}-${fixture.fixture_number}`}>
                  <td>{fixture.gameweek}</td>
                  <td>{fixture.fixture_number}</td>
                  <td>{formatDateTime(fixture.scheduled_at)}</td>
                  <td>{fixture.home_team_name}</td>
                  <td>{fixture.away_team_name}</td>
                </tr>)}
              </tbody>
            </table>
          </div>
          <label className="admin-fixture-generator-confirm">
            <input type="checkbox" checked={confirmGenerate} onChange={(event) => setConfirmGenerate(event.target.checked)} />
            I have reviewed this schedule. Generate these fixtures for this season.
          </label>
          <button type="button" onClick={generateFixtures} disabled={!confirmGenerate || generating}>{generating ? "Generating…" : `Generate ${preview.fixture_count} fixtures`}</button>
        </div>
      )}
    </section>
  );
}
