export type PublicGalleryLocation = {
  id: string;
  name: string;
  town: string;
  region: string | null;
};

export type PublicGalleryItem = {
  id: string;
  location_id: string;
  location_name: string;
  town: string;
  caption: string;
  published_at: string;
  image_url: string;
};

export type PublicGalleryResponse = {
  locations: PublicGalleryLocation[];
  items: PublicGalleryItem[];
};

export type PublicGalleryGroup = {
  location: PublicGalleryLocation;
  items: PublicGalleryItem[];
};

export function groupGalleryItems(
  locations: PublicGalleryLocation[],
  items: PublicGalleryItem[],
  selectedLocationId = "all",
): PublicGalleryGroup[] {
  const visibleLocations =
    selectedLocationId === "all"
      ? locations
      : locations.filter((location) => location.id === selectedLocationId);

  return visibleLocations
    .map((location) => ({
      location,
      items: items.filter((item) => item.location_id === location.id),
    }))
    .filter((group) => group.items.length > 0);
}
