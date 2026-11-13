import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

describe("duplicate fixture migration history", () => {
  it("keeps both recorded admin_fixture_management versions byte-for-byte identical", () => {
    const first = readFileSync(
      new URL(
        "../../../supabase/migrations/20261107224311_admin_fixture_management.sql",
        import.meta.url,
      ),
    );
    const second = readFileSync(
      new URL(
        "../../../supabase/migrations/20261107224351_admin_fixture_management.sql",
        import.meta.url,
      ),
    );

    expect(second.equals(first)).toBe(true);
  });
});
