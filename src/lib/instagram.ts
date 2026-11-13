const INSTAGRAM_HANDLE_PATTERN = /^[A-Za-z0-9._]{1,30}$/;
const INSTAGRAM_PROFILE_PATH_PATTERN = /^\/([A-Za-z0-9._]{1,30})\/?$/;
const INSTAGRAM_HOSTS = new Set(["instagram.com", "www.instagram.com"]);

export function normaliseInstagramHandle(value: string): string | null {
  const handle = value.trim().replace(/^@/, "");
  if (!handle) return null;
  if (!INSTAGRAM_HANDLE_PATTERN.test(handle)) {
    throw new Error("Enter an Instagram handle using up to 30 letters, numbers, dots or underscores.");
  }
  return handle;
}

/** Accept only a direct HTTPS Instagram profile URL; return its canonical form. */
export function normaliseInstagramProfileUrl(value: string): string | null {
  const raw = value.trim();
  if (!raw) return null;

  let parsed: URL;
  try {
    parsed = new URL(raw);
  } catch {
    throw new Error("Enter a valid Instagram profile URL.");
  }

  if (
    parsed.protocol !== "https:"
    || !INSTAGRAM_HOSTS.has(parsed.hostname.toLowerCase())
    || parsed.port
    || parsed.username
    || parsed.password
    || parsed.search
    || parsed.hash
  ) {
    throw new Error("Instagram links must use HTTPS and point directly to an instagram.com profile.");
  }

  const match = parsed.pathname.match(INSTAGRAM_PROFILE_PATH_PATTERN);
  if (!match) {
    throw new Error("Enter a direct Instagram profile URL, not a post, reel or other page.");
  }

  return `https://www.instagram.com/${match[1]}/`;
}

export function isValidInstagramProfileUrl(value: string | null | undefined): value is string {
  if (!value) return false;
  try {
    return normaliseInstagramProfileUrl(value) === value;
  } catch {
    return false;
  }
}
