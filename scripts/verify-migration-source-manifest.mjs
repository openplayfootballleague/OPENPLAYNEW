import { createHash } from "node:crypto";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { basename, join } from "node:path";

const manifestPath = "docs/supabase-migration-source-manifest-2026-11-08.md";
const migrationDirectory = "supabase/migrations";
const expectedForwardOnly = [
  "supabase/migrations/20261108021000_captain_next_required_fixture_and_admin_amendment.sql",
  "supabase/migrations/20261108150000_canonicalize_player_phone.sql",
  "supabase/migrations/20261108160000_enforce_player_ban_and_captain_succession.sql",
  "supabase/migrations/20261109080000_player_age_tiers_and_guardian_consent.sql",
  "supabase/migrations/20261109100000_player_account_retention_and_reactivation.sql",
  "supabase/migrations/20261109110000_competition_identity_and_safe_player_erasure.sql",
  "supabase/migrations/20261109130000_admin_player_retention_holds.sql",
  "supabase/migrations/20261109140000_prevent_signin_bypass_of_retention.sql",
  "supabase/migrations/20261109150000_retry_failed_player_account_erasure.sql",
  "supabase/migrations/20261109160000_audit_location_admin_assignments.sql",
  "supabase/migrations/20261109170000_points_only_league_table_ranking.sql",
  "supabase/migrations/20261109180000_scope_fixture_venue_to_season_location.sql",
  "supabase/migrations/20261109200000_scope_admin_result_statistics_to_location.sql",
  "supabase/migrations/20261109210000_player_account_inactivity_warnings.sql",
  "supabase/migrations/20261109220000_player_season_club_statistics.sql",
  "supabase/migrations/20261109230000_player_led_and_emergency_transfer_workflow.sql",
  "supabase/migrations/20261110120221_referee_application_workflow.sql",
  "supabase/migrations/20261110133643_referee_fixture_assignments.sql",
];

function fail(message) {
  console.error("Migration source manifest verification failed: " + message);
  process.exit(1);
}

if (!existsSync(manifestPath)) fail("missing manifest " + manifestPath);

const manifest = readFileSync(manifestPath, "utf8");
const rowPattern = /^\|\s*(\d{14})\s*\|\s*([^|]+?)\s*\|\s*\`([^ \`]+)\`\s*\|\s*\`([0-9a-f]{40})\`\s*\|$/gm;
const rows = [...manifest.matchAll(rowPattern)].map((match) => ({
  version: match[1],
  name: match[2].trim(),
  path: match[3],
  expectedSha: match[4],
}));

if (rows.length !== 99) fail("expected 99 applied ledger rows, found " + rows.length);

const versions = rows.map((row) => row.version);
const paths = rows.map((row) => row.path);
if (new Set(versions).size !== versions.length) fail("duplicate applied versions in manifest");
if (new Set(paths).size !== paths.length) fail("duplicate source paths in manifest");

for (const row of rows) {
  if (!row.path.startsWith(migrationDirectory + "/")) fail("source path outside migration directory: " + row.path);
  if (basename(row.path).slice(0, 14) !== row.version) fail("version prefix mismatch for " + row.path);
  if (!existsSync(row.path)) fail("missing source file " + row.path);

  const bytes = readFileSync(row.path);
  const header = Buffer.from("blob " + bytes.length + "\0", "utf8");
  const actualSha = createHash("sha1").update(header).update(bytes).digest("hex");
  if (actualSha !== row.expectedSha) fail("Git blob SHA mismatch for " + row.path + ": expected " + row.expectedSha + ", got " + actualSha);
}

const migrationFiles = readdirSync(migrationDirectory)
  .filter((file) => file.endsWith(".sql"))
  .map((file) => join(migrationDirectory, file))
  .sort();
const actualPrefixes = migrationFiles.map((file) => basename(file).slice(0, 14));
if (new Set(actualPrefixes).size !== actualPrefixes.length) fail("duplicate migration version prefixes in supabase/migrations");

const expectedFiles = new Set([...paths, ...expectedForwardOnly]);
const actualFiles = new Set(migrationFiles);
for (const path of expectedFiles) if (!actualFiles.has(path)) fail("expected migration file is missing: " + path);
for (const path of actualFiles) if (!expectedFiles.has(path)) fail("unmanifested migration file found: " + path);

console.log("Verified " + rows.length + " applied migration sources, " + migrationFiles.length + " unique migration files, and " + expectedForwardOnly.length + " declared forward-only migrations.");
