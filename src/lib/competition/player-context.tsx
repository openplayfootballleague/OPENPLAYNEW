import { useEffect, useState } from "react";
import { getSupabaseClient } from "../supabase/client";

export type PlayerLocationOption = {
  id: string;
  name: string;
  town: string;
  region: string;
};

export type PlayerSeasonOption = {
  id: string;
  name: string;
  league_id: string;
  league_name: string;
  location_id: string;
  location_name: string;
  status: "registration_open" | "active" | "completed";
  starts_on: string | null;
};

export type PlayerCompetitionContext = {
  locations: PlayerLocationOption[];
  seasons: PlayerSeasonOption[];
  selectedLocationId: string;
  selectedSeasonId: string;
  loading: boolean;
  error: string;
  setLocation: (locationId: string) => void;
  setSeason: (seasonId: string) => void;
};

const STORAGE_KEY = "open-play:player-competition-context";

export function getPreferredPlayerSeason(options: PlayerSeasonOption[]) {
  return options.find((season) => season.status === "registration_open")
    ?? options.find((season) => season.status === "active")
    ?? options[0]
    ?? null;
}

export function usePlayerCompetitionContext(): PlayerCompetitionContext {
  const [locations, setLocations] = useState<PlayerLocationOption[]>([]);
  const [seasons, setSeasons] = useState<PlayerSeasonOption[]>([]);
  const [selectedLocationId, setSelectedLocationId] = useState("");
  const [selectedSeasonId, setSelectedSeasonId] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    let alive = true;

    async function load() {
      const supabase = getSupabaseClient();
      const { data: locationRows, error: locationError } = await supabase
        .from("locations")
        .select("id,name,town,region")
        .eq("is_active", true)
        .order("name");

      if (!alive) return;
      if (locationError) {
        setError(locationError.message);
        setLoading(false);
        return;
      }

      const activeLocations = (locationRows ?? []) as PlayerLocationOption[];
      setLocations(activeLocations);
      if (activeLocations.length === 0) {
        setLoading(false);
        return;
      }

      const { data: leagueRows, error: leagueError } = await supabase
        .from("leagues")
        .select("id,location_id,name")
        .eq("is_published", true)
        .in("location_id", activeLocations.map((location) => location.id));

      if (!alive) return;
      if (leagueError) {
        setError(leagueError.message);
        setLoading(false);
        return;
      }

      const leagues = leagueRows ?? [];
      const leagueById = new Map(leagues.map((league) => [league.id, league]));
      let seasonOptions: PlayerSeasonOption[] = [];

      if (leagues.length > 0) {
        const { data: seasonRows, error: seasonError } = await supabase
          .from("seasons")
          .select("id,name,league_id,status,starts_on")
          .eq("is_public", true)
          .in("status", ["registration_open", "active", "completed"])
          .in("league_id", leagues.map((league) => league.id))
          .order("starts_on", { ascending: false, nullsFirst: false });

        if (!alive) return;
        if (seasonError) {
          setError(seasonError.message);
          setLoading(false);
          return;
        }

        seasonOptions = (seasonRows ?? []).flatMap((season) => {
          const league = leagueById.get(season.league_id);
          const location = activeLocations.find((item) => item.id === league?.location_id);
          if (!league || !location) return [];
          return [{
            id: season.id,
            name: season.name,
            league_id: league.id,
            league_name: league.name,
            location_id: location.id,
            location_name: location.name,
            status: season.status as PlayerSeasonOption["status"],
            starts_on: season.starts_on,
          }];
        });
      }

      if (!alive) return;
      setSeasons(seasonOptions);

      let saved: { locationId?: string; seasonId?: string } = {};
      try {
        saved = JSON.parse(window.localStorage.getItem(STORAGE_KEY) ?? "{}") as typeof saved;
      } catch {
        saved = {};
      }

      const locationId = activeLocations.some((item) => item.id === saved.locationId)
        ? saved.locationId!
        : activeLocations[0].id;
      const availableSeasons = seasonOptions.filter((season) => season.location_id === locationId);
      const seasonId = availableSeasons.some((season) => season.id === saved.seasonId)
        ? saved.seasonId!
        : getPreferredPlayerSeason(availableSeasons)?.id ?? "";

      setSelectedLocationId(locationId);
      setSelectedSeasonId(seasonId);
      setLoading(false);
    }

    void load();
    return () => {
      alive = false;
    };
  }, []);

  function persist(locationId: string, seasonId: string) {
    try {
      window.localStorage.setItem(STORAGE_KEY, JSON.stringify({ locationId, seasonId }));
    } catch {
      // Storage can be unavailable in private browsing; the in-memory selection still works.
    }
  }

  function setLocation(locationId: string) {
    if (!locations.some((location) => location.id === locationId)) return;
    const available = seasons.filter((season) => season.location_id === locationId);
    const nextSeason = getPreferredPlayerSeason(available)?.id ?? "";
    setSelectedLocationId(locationId);
    setSelectedSeasonId(nextSeason);
    persist(locationId, nextSeason);
  }

  function setSeason(seasonId: string) {
    if (!seasons.some((season) => season.id === seasonId && season.location_id === selectedLocationId)) return;
    setSelectedSeasonId(seasonId);
    persist(selectedLocationId, seasonId);
  }

  return { locations, seasons, selectedLocationId, selectedSeasonId, loading, error, setLocation, setSeason };
}

export function PlayerCompetitionSelector({ context }: { context: PlayerCompetitionContext }) {
  if (context.loading) return null;

  if (context.locations.length === 0) {
    return <>{context.error && <p className="form-error" role="alert">{context.error}</p>}<p className="player-competition-empty" role="status">Location and season selection will appear when the first Open Play location is published.</p></>;
  }

  const availableSeasons = context.seasons.filter((season) => season.location_id === context.selectedLocationId);

  return (
    <section className="player-competition-context" aria-label="Competition selection">
      <div className="player-competition-context-heading">
        <span className="hub-kicker">YOUR OPEN PLAY</span>
        <strong>Choose your location and season</strong>
      </div>
      <div className="player-competition-context-fields">
        <label>
          <span className="player-context-label"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M20 10c0 5-8 11-8 11S4 15 4 10a8 8 0 1 1 16 0Z"/><circle cx="12" cy="10" r="2.5"/></svg>Location</span>
          <select value={context.selectedLocationId} onChange={(event) => context.setLocation(event.target.value)}>
            {context.locations.map((location) => (
              <option key={location.id} value={location.id}>{location.name} · {location.town}</option>
            ))}
          </select>
        </label>
        <label>
          <span className="player-context-label"><svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3" y="4" width="18" height="17" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/></svg>Season</span>
          <select value={context.selectedSeasonId} disabled={availableSeasons.length === 0} onChange={(event) => context.setSeason(event.target.value)}>
            {availableSeasons.length === 0
              ? <option value="">No public seasons available</option>
              : availableSeasons.map((season) => (
                <option key={season.id} value={season.id}>{season.name} · {season.league_name}</option>
              ))}
          </select>
        </label>
      </div>
      {context.error && <p className="form-error" role="alert">{context.error}</p>}
    </section>
  );
}
