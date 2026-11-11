import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, apikey, x-client-info, content-type",
  "Access-Control-Max-Age": "86400",
  "Vary": "Origin",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "GET") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse({ error: "Gallery service is not configured." }, 503);
  }

  const requestedLocationId = new URL(request.url).searchParams.get("location_id");
  if (requestedLocationId && !uuidPattern.test(requestedLocationId)) {
    return jsonResponse({ error: "Invalid location." }, 400);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: activeLocations, error: locationsError } = await admin
    .from("locations")
    .select("id, name, town, region")
    .eq("is_active", true)
    .order("name", { ascending: true });

  if (locationsError) {
    console.error("public-gallery: active location lookup failed", locationsError.code);
    return jsonResponse({ error: "Gallery is temporarily unavailable." }, 500);
  }

  const locations = activeLocations ?? [];
  const visibleLocations = requestedLocationId
    ? locations.filter((location) => location.id === requestedLocationId)
    : locations;

  if (requestedLocationId && visibleLocations.length === 0) {
    return jsonResponse({ error: "Gallery location not found." }, 404);
  }

  const locationIds = visibleLocations.map((location) => location.id);
  if (locationIds.length === 0) {
    return jsonResponse({ locations: [], items: [] });
  }

  const { data: publishedItems, error: itemsError } = await admin
    .from("gallery_items")
    .select("id, location_id, object_path, caption, published_at")
    .eq("is_published", true)
    .not("published_at", "is", null)
    .in("location_id", locationIds)
    .order("published_at", { ascending: false })
    .limit(48);

  if (itemsError) {
    console.error("public-gallery: published item lookup failed", itemsError.code);
    return jsonResponse({ error: "Gallery is temporarily unavailable." }, 500);
  }

  const locationById = new Map(visibleLocations.map((location) => [location.id, location]));
  const items = await Promise.all((publishedItems ?? []).map(async (item) => {
    const location = locationById.get(item.location_id);
    if (!location) return null;

    const { data: signed, error: signedError } = await admin.storage
      .from("open-play-gallery")
      .createSignedUrl(item.object_path, 300);

    if (signedError || !signed?.signedUrl) {
      console.error("public-gallery: signed image URL creation failed", signedError?.name ?? "unknown");
      return null;
    }

    return {
      id: item.id,
      location_id: item.location_id,
      location_name: location.name,
      town: location.town,
      caption: item.caption,
      published_at: item.published_at,
      image_url: signed.signedUrl,
    };
  }));

  return jsonResponse({
    locations: visibleLocations,
    items: items.filter((item) => item !== null),
  });
});
