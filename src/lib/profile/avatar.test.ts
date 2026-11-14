import { describe, expect, it } from "vitest";
import { avatarExtension, validateAvatarFile } from "./avatar";

describe("profile picture rules", () => {
  it("accepts JPEG, PNG and WebP up to 5 MB", () => {
    expect(validateAvatarFile({ type: "image/png", size: 5 * 1024 * 1024 })).toBeNull();
    expect(validateAvatarFile({ type: "image/webp", size: 1 })).toBeNull();
  });

  it("rejects other types (including SVG) and oversized files", () => {
    expect(validateAvatarFile({ type: "image/svg+xml", size: 10 })).toMatch(/JPG, PNG or WebP/);
    expect(validateAvatarFile({ type: "image/jpeg", size: 5 * 1024 * 1024 + 1 })).toMatch(/5 MB/);
  });

  it("derives the stored extension from the content type", () => {
    expect([avatarExtension("image/jpeg"), avatarExtension("image/png"), avatarExtension("image/webp")]).toEqual(["jpg", "png", "webp"]);
  });
});
