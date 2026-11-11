import { describe, expect, it } from "vitest";
import { groupGalleryItems, type PublicGalleryItem, type PublicGalleryLocation } from "./gallery";

const locations: PublicGalleryLocation[] = [
  { id: "bideford", name: "Open Play Bideford", town: "Bideford", region: "North Devon" },
  { id: "barnstaple", name: "Open Play Barnstaple", town: "Barnstaple", region: "North Devon" },
];

const items: PublicGalleryItem[] = [
  { id: "1", location_id: "bideford", location_name: "Open Play Bideford", town: "Bideford", caption: "Friday night", published_at: "2026-11-01T20:00:00Z", image_url: "https://example.test/1" },
  { id: "2", location_id: "bideford", location_name: "Open Play Bideford", town: "Bideford", caption: "Matchday", published_at: "2026-11-02T20:00:00Z", image_url: "https://example.test/2" },
  { id: "3", location_id: "barnstaple", location_name: "Open Play Barnstaple", town: "Barnstaple", caption: "Opening night", published_at: "2026-11-03T20:00:00Z", image_url: "https://example.test/3" },
];

describe("groupGalleryItems", () => {
  it("groups published items by their active location", () => {
    const groups = groupGalleryItems(locations, items);
    expect(groups.map((group) => [group.location.id, group.items.length])).toEqual([
      ["bideford", 2],
      ["barnstaple", 1],
    ]);
  });

  it("filters to the selected location without mixing galleries", () => {
    const groups = groupGalleryItems(locations, items, "barnstaple");
    expect(groups).toHaveLength(1);
    expect(groups[0].location.id).toBe("barnstaple");
    expect(groups[0].items.map((item) => item.id)).toEqual(["3"]);
  });

  it("returns no groups when the selected location has no published images", () => {
    expect(groupGalleryItems(locations, [], "bideford")).toEqual([]);
  });

  it("does not return items for locations absent from the active-location list", () => {
    const groups = groupGalleryItems(locations, [
      { ...items[0], location_id: "inactive-location" },
    ]);
    expect(groups).toEqual([]);
  });
});
