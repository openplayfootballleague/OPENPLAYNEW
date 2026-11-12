import { describe, expect, it } from "vitest";
import { normalizeInstagramProfileUrl } from "./instagram";

describe("Instagram team profile URL validation", () => {
  it("accepts direct HTTPS profile URLs and canonicalises the host", () => {
    expect(normalizeInstagramProfileUrl("https://instagram.com/YourTeam")).toBe("https://www.instagram.com/YourTeam/");
    expect(normalizeInstagramProfileUrl("HTTPS://WWW.INSTAGRAM.COM/your.team_01/")).toBe("https://www.instagram.com/your.team_01/");
  });
  it("treats omitted optional links as absent", () => {
    expect(normalizeInstagramProfileUrl("")).toBeNull();
    expect(normalizeInstagramProfileUrl(null)).toBeNull();
  });
  it.each([
    "http://www.instagram.com/team",
    "https://instagram.com.evil.example/team",
    "https://example.com/team",
    "javascript:alert(1)",
    "https://www.instagram.com/team/?next=https://evil.example",
    "https://www.instagram.com/p/shortcode/",
    "https://www.instagram.com/../admin/",
    "https://www.instagram.com/a..b/",
  ])("rejects unsafe or non-profile URL %s", value => {
    expect(() => normalizeInstagramProfileUrl(value)).toThrow(TypeError);
  });
});
