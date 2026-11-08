import { describe, expect, it } from "vitest";
import { normalizeInstagramHandle } from "./instagram-handle";

describe("Instagram team handle validation", () => {
  it("normalises an optional @ prefix", () => {
    expect(normalizeInstagramHandle("@Open.Play_01")).toBe("Open.Play_01");
    expect(normalizeInstagramHandle("OpenPlay")).toBe("OpenPlay");
  });
  it("accepts a maximum-length username with an optional @ prefix", () => {
    const username = "a".repeat(30);
    expect(normalizeInstagramHandle(username)).toBe(username);
    expect(normalizeInstagramHandle(`@${username}`)).toBe(username);
  });
  it("treats an omitted handle as no handle", () => {
    expect(normalizeInstagramHandle("")).toBeNull();
    expect(normalizeInstagramHandle(null)).toBeNull();
  });
  it.each(["@.team", "team.", "a..b", "bad handle", "https://instagram.com/team", "@".repeat(31), "a".repeat(31)])(
    "rejects invalid handle %s", value => {
      expect(() => normalizeInstagramHandle(value)).toThrow(TypeError);
    }
  );
});
