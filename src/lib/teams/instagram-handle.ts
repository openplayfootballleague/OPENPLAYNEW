const INSTAGRAM_HANDLE = /^@?[A-Za-z0-9._]{1,30}$/;

/** Returns a canonical Instagram username without the optional leading @. */
export function normalizeInstagramHandle(value: string | null | undefined): string | null {
  const input = value?.trim();
  if (!input) return null;
  if (!INSTAGRAM_HANDLE.test(input)) {
    throw new TypeError("Enter a valid Instagram handle (up to 30 letters, numbers, dots or underscores).");
  }
  const handle = input.replace(/^@/, "");
  if (!handle || handle.startsWith(".") || handle.endsWith(".") || handle.includes("..")) {
    throw new TypeError("Enter a valid Instagram handle.");
  }
  return handle;
}
