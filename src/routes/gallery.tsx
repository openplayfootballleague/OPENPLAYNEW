import { useEffect, useMemo, useRef, useState } from "react";
import { createFileRoute, Link } from "@tanstack/react-router";
import { groupGalleryItems, type PublicGalleryResponse } from "../lib/gallery";
import { getSupabaseClient } from "../lib/supabase/client";
import { useOpenPlayAnalytics } from "../components/analytics-provider";

export const Route = createFileRoute("/gallery")({
  component: GalleryPage,
});

function GalleryPage() {
  const capture = useOpenPlayAnalytics();
  const [gallery, setGallery] = useState<PublicGalleryResponse>({ locations: [], items: [] });
  const [selectedLocationId, setSelectedLocationId] = useState("all");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [loadedSuccessfully, setLoadedSuccessfully] = useState(false);
  const galleryViewCaptured = useRef(false);

  useEffect(() => {
    let active = true;

    async function loadGallery() {
      try {
        const { data, error: invokeError } =
          await getSupabaseClient().functions.invoke<PublicGalleryResponse>("public-gallery", {
            method: "GET",
          });

        if (invokeError) throw invokeError;
        if (active) {
          setGallery(data ?? { locations: [], items: [] });
          setLoadedSuccessfully(true);
        }
      } catch {
        if (active) {
          setError("The gallery is temporarily unavailable. Please try again shortly.");
          capture("data_load_failed", { feature: "gallery", error_code: "network_error", outcome: "failure" });
        }
      } finally {
        if (active) setLoading(false);
      }
    }

    void loadGallery();
    return () => {
      active = false;
    };
  }, [capture]);

  useEffect(() => {
    if (!loadedSuccessfully || galleryViewCaptured.current) return;
    if (capture("gallery_viewed", { feature: "gallery" })) galleryViewCaptured.current = true;
  }, [capture, loadedSuccessfully]);

  const groups = useMemo(
    () => groupGalleryItems(gallery.locations, gallery.items, selectedLocationId),
    [gallery, selectedLocationId],
  );

  return (
    <main className="public-gallery-page">
      <header className="public-gallery-header">
        <Link className="wordmark" to="/" aria-label="Open Play home">
          <img className="open-play-logo" src="/open-play-logo.png" alt="Open Play" />
        </Link>
        <nav aria-label="Main navigation">
          <Link to="/match-centre">Match centre</Link>
          <Link to="/teams">Leagues</Link>
          <Link to="/join">Join</Link>
        </nav>
      </header>

      <section className="public-gallery-hero" aria-labelledby="gallery-title">
        <p className="eyebrow">OPEN PLAY / THE GALLERY</p>
        <h1 id="gallery-title">The game.<br /><em>Through your eyes.</em></h1>
        <p>Matchday moments, team celebrations and the people who make Open Play.</p>
      </section>

      <section className="public-gallery-content">
        <div className="public-gallery-toolbar">
          <div>
            <p className="eyebrow eyebrow-dark">THE PHOTO WALL</p>
            <h2>Matchday moments</h2>
            <p>Official photos published by Open Play.</p>
          </div>
          <label className="public-gallery-filter">
            <span>LOCATION</span>
            <select
              aria-label="Filter gallery by location"
              value={selectedLocationId}
              onChange={(event) => setSelectedLocationId(event.target.value)}
              disabled={gallery.locations.length < 2}
            >
              <option value="all">All locations</option>
              {gallery.locations.map((location) => (
                <option key={location.id} value={location.id}>
                  {location.town}
                </option>
              ))}
            </select>
          </label>
        </div>

        {loading ? (
          <div className="public-gallery-state" role="status">Loading the gallery…</div>
        ) : error ? (
          <div className="public-gallery-state" role="alert">{error}</div>
        ) : groups.length === 0 ? (
          <div className="public-gallery-state">
            <h3>No published photos yet.</h3>
            <p>Check back after the next Open Play matchday.</p>
          </div>
        ) : (
          <div className="public-gallery-groups">
            {groups.map((group) => (
              <section className="public-gallery-group" key={group.location.id}>
                <div className="public-gallery-group-heading">
                  <div>
                    <p className="eyebrow eyebrow-dark">{group.location.region ?? "OPEN PLAY"}</p>
                    <h3>{group.location.name}</h3>
                  </div>
                  <span>{group.items.length} {group.items.length === 1 ? "photo" : "photos"}</span>
                </div>
                <div className="public-gallery-grid">
                  {group.items.map((item) => (
                    <article className="public-gallery-card" key={item.id}>
                      <img
                        src={item.image_url}
                        alt={item.caption || "Open Play matchday photograph"}
                        loading="lazy"
                      />
                      <div className="public-gallery-card-copy">
                        <p>{item.caption || "Open Play matchday"}</p>
                        <time dateTime={item.published_at}>
                          {new Date(item.published_at).toLocaleDateString("en-GB", {
                            day: "numeric",
                            month: "short",
                            year: "numeric",
                          })}
                        </time>
                      </div>
                    </article>
                  ))}
                </div>
              </section>
            ))}
          </div>
        )}
      </section>

      <footer className="public-gallery-footer">
        <Link to="/">OPEN PLAY</Link>
        <span>PLAY HARD. RESPECT ALWAYS.</span>
      </footer>
    </main>
  );
}
