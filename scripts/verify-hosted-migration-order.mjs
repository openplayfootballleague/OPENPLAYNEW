import { execFileSync } from "node:child_process";
import {
  copyFileSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  rmSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const root = process.cwd();
const manifestPath = join(root, "docs/supabase-migration-source-manifest-2026-11-08.md");
const migrationDirectory = join(root, "supabase/migrations");
const manifest = readFileSync(manifestPath, "utf8");
const appliedPaths = [...manifest.matchAll(
  /^\|\s*(\d{14})\s*\|[^|]*\|\s*`(supabase\/migrations\/[^\`]+\.sql)`\s*\|/gm,
)].map((match) => match[2]);

if (appliedPaths.length !== 99 || new Set(appliedPaths).size !== 99) {
  throw new Error(`Expected 99 unique canonical applied migration sources; found ${appliedPaths.length}`);
}

for (const path of appliedPaths) {
  if (!readFileSync(join(root, path))) {
    throw new Error(`Applied migration source is missing: ${path}`);
  }
}

const allMigrations = readdirSync(migrationDirectory)
  .filter((name) => /^\d{14}_.+\.sql$/.test(name))
  .sort();
const appliedSet = new Set(appliedPaths.map((path) => path.split("/").at(-1)));
const pending = allMigrations.filter((name) => !appliedSet.has(name));
if (allMigrations.length !== 109 || pending.length !== 10) {
  throw new Error(`Expected 109 local migrations (99 applied + 10 pending); found ${allMigrations.length} total and ${pending.length} pending`);
}

const latestAppliedVersion = appliedPaths
  .map((path) => path.split("/").at(-1).slice(0, 14))
  .sort()
  .at(-1);
const pendingBeforeLatest = pending.filter((name) => name.slice(0, 14) <= latestAppliedVersion);
if (latestAppliedVersion !== "20261108194831" ||
    pendingBeforeLatest.length !== 3 ||
    pendingBeforeLatest[0] !== "20261108021000_captain_next_required_fixture_and_admin_amendment.sql" ||
    pendingBeforeLatest[1] !== "20261108150000_canonicalize_player_phone.sql" ||
    pendingBeforeLatest[2] !== "20261108160000_enforce_player_ban_and_captain_succession.sql") {
  throw new Error("The pending migration timestamp relationship has changed; review the release-order assumptions before continuing");
}

console.log("Verified applied baseline:", appliedPaths.length, "migrations through", latestAppliedVersion);
console.log("Verified pending migrations:", pending.length);
console.log("Older-than-baseline migrations that require include-all:");
for (const name of pendingBeforeLatest) console.log(" -", name);

const temporaryProject = mkdtempSync(join(tmpdir(), "openplay-hosted-order-"));
try {
  const temporaryMigrations = join(temporaryProject, "supabase", "migrations");
  mkdirSync(temporaryMigrations, { recursive: true });
  copyFileSync(
    join(root, "supabase", "config.toml"),
    join(temporaryProject, "supabase", "config.toml"),
  );
  for (const path of appliedPaths) {
    copyFileSync(join(root, path), join(temporaryProject, path));
  }

  // Recreate the exact current hosted baseline (99 recorded migrations) on the
  // disposable local stack, then ask the pinned CLI to apply all missing files.
  execFileSync(
    "supabase",
    ["db", "reset", "--local", "--no-seed"],
    { cwd: temporaryProject, stdio: "inherit" },
  );

  const databaseUrl = process.env.OPENPLAY_LOCAL_DATABASE_URL ??
    "postgresql://postgres:postgres@127.0.0.1:54322/postgres";
  const help = execFileSync("supabase", ["db", "push", "--help"], {
    cwd: root,
    encoding: "utf8",
  });
  for (const flag of ["--db-url", "--include-all", "--yes"]) {
    if (!help.includes(flag)) {
      throw new Error(`Pinned Supabase CLI does not advertise required flag ${flag}`);
    }
  }

  execFileSync(
    "supabase",
    ["db", "push", "--db-url", databaseUrl, "--include-all", "--yes"],
    { cwd: root, stdio: "inherit" },
  );

  const migrationCount = execFileSync(
    "psql",
    [
      "--dbname", databaseUrl,
      "--set", "ON_ERROR_STOP=1",
      "--tuples-only",
      "--no-align",
      "--command", "select count(*) from supabase_migrations.schema_migrations",
    ],
    {
      cwd: root,
      encoding: "utf8",
      env: { ...process.env, PGPASSWORD: process.env.PGPASSWORD ?? "postgres" },
    },
  ).trim();

  if (Number(migrationCount) !== allMigrations.length) {
    throw new Error(`Hosted-order replay recorded ${migrationCount} migrations; expected ${allMigrations.length}`);
  }

  console.log(
    `Hosted-order replay passed: ${appliedPaths.length} baseline migrations followed by ${pending.length} pending migrations (${migrationCount} total recorded).`,
  );
} finally {
  rmSync(temporaryProject, { recursive: true, force: true });
}
