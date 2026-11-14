/** Routes that render their own workspace header instead of the global player-facing header. */
const OWN_HEADER_PREFIXES = ["/admin", "/finance", "/referee"];

export function showsGlobalHeader(pathname: string): boolean {
  if (pathname === "/") return false; // Marketing Home keeps its hero header (PUB-01 redesign pending).
  return !OWN_HEADER_PREFIXES.some((prefix) => pathname === prefix || pathname.startsWith(prefix + "/") || pathname.startsWith(prefix + "-") || pathname.startsWith(prefix + "."));
}

export const LOCATION_CHANGE_EVENT = "open-play:location-change";
export const COMPETITION_STORAGE_KEY = "open-play:player-competition-context";

export function readStoredLocationId(): string {
  try {
    const saved = JSON.parse(window.localStorage.getItem(COMPETITION_STORAGE_KEY) ?? "{}") as { locationId?: unknown };
    return typeof saved.locationId === "string" ? saved.locationId : "";
  } catch {
    return "";
  }
}

export function formatUnreadCount(count: number): string {
  return count > 9 ? "9+" : String(count);
}
