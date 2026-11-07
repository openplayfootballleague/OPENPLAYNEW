import { readdirSync, readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

const ledger = JSON.parse(
  readFileSync(
    new URL("../../../supabase/migration-ledger.json", import.meta.url),
    "utf8",
  ),
) as {
  project_ref: string;
  migrations: Array<{ version: string; name: string }>;
};

const migrationDirectory = new URL(
  "../../../supabase/migrations/",
  import.meta.url,
);

describe("Supabase migration ledger", () => {
  it("matches every local SQL filename to the applied remote version and name", () => {
    const expected = ledger.migrations
      .map(({ version, name }) => `${version}_${name}.sql`)
      .sort();
    const actual = readdirSync(migrationDirectory)
      .filter((filename) => filename.endsWith(".sql"))
      .sort();

    expect(ledger.project_ref).toBe("ghnrsysvrlgkjmdlwdmp");
    expect(ledger.migrations.length).toBe(32);
    expect(new Set(ledger.migrations.map((item) => item.version)).size).toBe(
      ledger.migrations.length,
    );
    expect(actual).toEqual(expected);
  });
});
