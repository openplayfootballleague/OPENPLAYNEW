import { describe, expect, it } from "vitest";
import {
  isValidInstagramProfileUrl,
  normaliseInstagramHandle,
  normaliseInstagramProfileUrl,
} from "./instagram";

describe("Instagram profile details", () => {
  it("normalises an optional @ prefix without storing it", () => {
    expect(normaliseInstagramHandle("@OpenPlay_Official")).toBe("OpenPlay_Official");
    expect(normaliseInstagramHandle("")).toBeNull();
  });

  it("rejects handles with spaces or unsupported characters", () => {
    expect(() => normaliseInstagramHandle("Open Play")).toThrow(/Instagram handle/);
    expect(() => normaliseInstagramHandle("openplay!")).toThrow(/Instagram handle/);
    expect(() => normaliseInstagramHandle("a".repeat(31))).toThrow(/Instagram handle/);
  });

  it("canonicalises direct HTTPS Instagram profile URLs", () => {
    expect(normaliseInstagramProfileUrl("https://instagram.com/open.play"))
      .toBe("https://www.instagram.com/open.play/");
    expect(normaliseInstagramProfileUrl("HTTPS://INSTAGRAM.COM/OpenPlay_Official/"))
      .toBe("https://www.instagram.com/OpenPlay_Official/");
    expect(normaliseInstagramProfileUrl("")).toBeNull();
  });

  it.each([
    "http://www.instagram.com/openplay/",
    "https://instagram.com.evil.example/openplay/",
    "https://www.instagram.com/openplay/?next=https://evil.example",
    "https://www.instagram.com/openplay/#profile",
    "https://www.instagram.com/p/ABC123/",
    "https://user:password@www.instagram.com/openplay/",
  ])("rejects unsafe or non-profile URL %s", (value) => {
    expect(() => normaliseInstagramProfileUrl(value)).toThrow();
  });

  it("shows a public Instagram icon only for a canonical validated profile URL", () => {
    expect(isValidInstagramProfileUrl("https://www.instagram.com/openplay/")).toBe(true);
    expect(isValidInstagramProfileUrl("https://instagram.com/openplay")).toBe(false);
    expect(isValidInstagramProfileUrl(null)).toBe(false);
  });
});
