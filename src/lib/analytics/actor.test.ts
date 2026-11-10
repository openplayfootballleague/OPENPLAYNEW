import { describe, expect, it, vi } from "vitest";
import { resolveAnalyticsActorSafely } from "./actor";

describe("analytics actor resolution", () => {
  it("does not call the resolver when Supabase is not configured", async () => {
    const resolve = vi.fn(async () => "anonymous" as const);

    await expect(resolveAnalyticsActorSafely(false, resolve)).resolves.toBe("unknown");
    expect(resolve).not.toHaveBeenCalled();
  });

  it("returns the resolved actor when the lookup succeeds", async () => {
    const resolve = vi.fn(async () => "player" as const);

    await expect(resolveAnalyticsActorSafely(true, resolve)).resolves.toBe("player");
    expect(resolve).toHaveBeenCalledOnce();
  });

  it("fails closed when an auth or database lookup rejects", async () => {
    const resolve = vi.fn(async (): Promise<"player"> => {
      throw new Error("temporary Supabase network failure");
    });

    await expect(resolveAnalyticsActorSafely(true, resolve)).resolves.toBe("unknown");
  });
});
