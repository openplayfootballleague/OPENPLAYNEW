const INSTAGRAM_PROFILE = /^https:\/\/(?:www\.)?instagram\.com\/([A-Za-z0-9._]{1,30})\/?$/i;

/** Accept only a direct HTTPS Instagram profile URL; never accept arbitrary destinations. */
export function normalizeInstagramProfileUrl(value: string | null | undefined): string | null {
  const input = value?.trim();
  if (!input) return null;
  const match = INSTAGRAM_PROFILE.exec(input);
  if (!match || match[1].startsWith(".") || match[1].endsWith(".") || match[1].includes("..")) {
    throw new TypeError("Enter a valid Instagram profile link, such as https://www.instagram.com/yourteam/.");
  }
  return `https://www.instagram.com/${match[1]}/`;
}
