import { useEffect, useState, type FormEvent } from "react";
import { getSupabaseClient } from "../lib/supabase";

type LocationOption = {
  id: string;
  name: string;
  town: string | null;
  region: string | null;
  address: string | null;
  is_active: boolean;
};

type VenueOption = {
  id: string;
  location_id: string;
  location_name: string;
  name: string;
  address: string | null;
  operating_days: number[];
  opens_at: string | null;
  closes_at: string | null;
  is_active: boolean;
};

type Props = {
  locations: LocationOption[];
  venues: VenueOption[];
  defaultLocationId?: string;
  onSaved: () => void | Promise<void>;
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

function formatOperatingDays(days: number[]) {
  if (!days.length) return "Any day (no day restriction)";
  return WEEKDAYS.filter((day) => days.includes(day.value)).map((day) => day.label.slice(0, 3)).join(", ");
}

function formatOperatingHours(opensAt: string | null, closesAt: string | null) {
  if (!opensAt || !closesAt) return "Hours not restricted";
  return `${opensAt.slice(0, 5)}–${closesAt.slice(0, 5)}`;
}

export function AdminVenueManager({ locations, venues, defaultLocationId, onSaved }: Props) {
  const [editingId, setEditingId] = useState<string | null>(null);
  const [locationId, setLocationId] = useState(defaultLocationId || locations[0]?.id || "");
  const [name, setName] = useState("");
  const [address, setAddress] = useState("");
  const [operatingDays, setOperatingDays] = useState<number[]>([]);
  const [opensAt, setOpensAt] = useState("");
  const [closesAt, setClosesAt] = useState("");
  const [isActive, setIsActive] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");

  useEffect(() => {
    if (!editingId) setLocationId(defaultLocationId || locations[0]?.id || "");
  }, [defaultLocationId, editingId, locations]);

  function resetForm() {
    setEditingId(null);
    setLocationId(defaultLocationId || locations[0]?.id || "");
    setName("");
    setAddress("");
    setOperatingDays([]);
    setOpensAt("");
    setClosesAt("");
    setIsActive(false);
    setError("");
  }

  function editVenue(venue: VenueOption) {
    setEditingId(venue.id);
    setLocationId(venue.location_id);
    setName(venue.name);
    setAddress(venue.address || "");
    setOperatingDays(venue.operating_days || []);
    setOpensAt(venue.opens_at?.slice(0, 5) || "");
    setClosesAt(venue.closes_at?.slice(0, 5) || "");
    setIsActive(venue.is_active);
    setError("");
    setNotice("");
  }

  function toggleDay(day: number) {
    setOperatingDays((current) =>
      current.includes(day) ? current.filter((value) => value !== day) : [...current, day].sort((a, b) => a - b),
    );
  }

  async function submitVenue(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSaving(true);
    setError("");
    setNotice("");
    try {
      if (!locationId) throw new Error("Choose a location for this venue.");
      if (!name.trim()) throw new Error("Enter a venue name.");
      if (Boolean(opensAt) !== Boolean(closesAt)) throw new Error("Enter both opening and closing times, or leave both blank.");
      if (opensAt && closesAt && opensAt >= closesAt) throw new Error("Closing time must be later than opening time.");

      const args = {
        p_name: name.trim(),
        p_address: address.trim() || null,
        p_operating_days: operatingDays,
        p_opens_at: opensAt || null,
        p_closes_at: closesAt || null,
        p_is_active: isActive,
      };
      const result = editingId
        ? await getSupabaseClient().rpc("admin_update_venue", { p_venue_id: editingId, ...args })
        : await getSupabaseClient().rpc("admin_create_venue", { p_location_id: locationId, ...args });
      if (result.error) throw result.error;

      setNotice(editingId ? "Venue details updated." : "Venue added.");
      resetForm();
      await onSaved();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Venue could not be saved.");
    } finally {
      setSaving(false);
    }
  }

  if (!locations.length) {
    return <section className="admin-panel admin-venue-manager"><h3>Venues</h3><p className="form-note">No locations are assigned to this administrator.</p></section>;
  }

  return (
    <section className="admin-panel admin-venue-manager">
      <div className="admin-panel-heading"><div><h3>Venues and operating hours</h3><p>Manage multiple venues at each location and define when fixtures can be scheduled.</p></div></div>
      <form className="admin-venue-form" onSubmit={submitVenue}>
        <div className="admin-form-grid">
          <label>Location<select value={locationId} onChange={(event) => setLocationId(event.target.value)} disabled={Boolean(editingId)} required>{locations.map((location) => <option key={location.id} value={location.id}>{location.name}</option>)}</select></label>
          <label>Venue name<input value={name} onChange={(event) => setName(event.target.value)} maxLength={120} required placeholder="e.g. Sandymere Astro"/></label>
          <label className="admin-venue-address">Venue address<input value={address} onChange={(event) => setAddress(event.target.value)} maxLength={255} placeholder="Optional venue-specific address"/></label>
        </div>
        <fieldset className="admin-venue-days">
          <legend>Operating days</legend>
          <div>{WEEKDAYS.map((day) => <label key={day.value}><input type="checkbox" checked={operatingDays.includes(day.value)} onChange={() => toggleDay(day.value)}/><span>{day.label}</span></label>)}</div>
          <small>Leave every day unchecked to allow scheduling on any day.</small>
        </fieldset>
        <div className="admin-form-grid admin-venue-hours">
          <label>Opens at<input type="time" value={opensAt} onChange={(event) => setOpensAt(event.target.value)}/></label>
          <label>Closes at<input type="time" value={closesAt} onChange={(event) => setClosesAt(event.target.value)}/></label>
          <label className="admin-venue-active"><input type="checkbox" checked={isActive} onChange={(event) => setIsActive(event.target.checked)}/><span>Active for fixture scheduling</span></label>
        </div>
        <p className="form-note">Times are interpreted in UK local time (Europe/London). A scheduled fixture must fall within the selected venue's configured operating days and hours.</p>
        {error && <p className="form-error" role="alert">{error}</p>}
        {notice && <p className="form-success" role="status">{notice}</p>}
        <div className="admin-venue-actions"><button type="submit" disabled={saving}>{saving ? "Saving…" : editingId ? "Save venue changes" : "Add venue"}</button>{editingId && <button type="button" className="button-secondary" onClick={resetForm} disabled={saving}>Cancel edit</button>}</div>
      </form>
      <div className="admin-venue-list">
        {venues.length ? venues.map((venue) => <article key={venue.id}>
          <div><strong>{venue.name}</strong><span>{venue.location_name}{venue.address ? ` · ${venue.address}` : ""}</span><span>{formatOperatingDays(venue.operating_days)} · {formatOperatingHours(venue.opens_at, venue.closes_at)}</span></div>
          <span className={venue.is_active ? "admin-status-active" : "admin-status-inactive"}>{venue.is_active ? "Active" : "Inactive"}</span>
          <button type="button" className="button-secondary" onClick={() => editVenue(venue)}>Edit</button>
        </article>) : <p className="form-note">No venues are configured for these locations.</p>}
      </div>
    </section>
  );
}
