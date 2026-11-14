import { describe, expect, it } from "vitest";
import { onlinePaymentsEnabled } from "./online-payments";

describe("online card payments flag (D6)", () => {
  it("is enabled only when the owner flag is explicitly true", () => {
    expect(onlinePaymentsEnabled({ enabled: true }, null)).toBe(true);
    expect(onlinePaymentsEnabled({ enabled: false }, null)).toBe(false);
    expect(onlinePaymentsEnabled(null, null)).toBe(false);
    expect(onlinePaymentsEnabled({ enabled: true }, new Error("read failed"))).toBe(false);
  });
});
