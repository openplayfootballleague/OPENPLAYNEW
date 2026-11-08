import { createHash } from "node:crypto";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { basename, join } from "node:path";

const manifestPath = "docs/supabase-migration-source-manifest-2026-11-08.md";
const migrationDirectory = "supabase/migrations";
const expectedForwardOnly = [
  "supabase/migrations/20261108014200_finance_balance_semantics.sql",
  "supabase/migrations/20261108030000_scope_rls_to_global_admins.sql",
  "supabase/migrations/20261108031000_revoke_unscoped_admin_rpcs.sql",
  "supabase/migrations/20261108032000_fix_captain_membership_approval_scope.sql",
  "supabase/migrations/20261109000000_correct_membership_location_and_finance_authorization.sql",
];

function fail(message) {
  console.error(`Migration source manifest verification failed: ${message}`);
  process.exit(1);
}

if (!existsSync(manifestPath)) fail(`missing manifest ${manifestPath}`);

const manifest = readFileSync(manifestPath, "utf8");
const rowPattern = /^\|\s*(\d{14})\s*\|\s*([^|]+?)\s*\|\s*`([^ `]+)`\s*\|\s*`([0-9a-f]{40})`\s*\|$/gm;
const rows = [...manifest.matchAll(rowPattern)].map((match) => ({
  version: match[1],
  name: match[2].trim(),
  path: match[3],
  expectedSha: match[4],
}));

if (rows.length !== 98) fail(`expected 98 applied ledger rows, found ${rows.length}`);

const versions = rows.map((row) => row.version);
const paths = rows.map((row) => row.path);
if (new Set(versions).size !== versions.length) fail("duplicate applied versions in manifest");
if (new Set(paths).size !== paths.length) fail("duplicate source paths in manifest");

for (const row of rows) {
  if (!row.path.startsWith(`${migrationDirectory}/`)) fail(`source path outside migration directory: ${row.path}`);
  if (basename(row.path).slice(0, 14) !== row.version) fail(`version prefix mismatch for ${row.path}`);
  if (!existsSync(row.path)) fail(`missing source file ${row.path}`);

  const bytes = readFileSync(row.path);
  const header = Buffer.from(`blob ${bytes.length}\0`, "utf8");
  const actualSha = createHash("sha1").update(header).update(bytes).digest("hex");
  if (actualSha !== row.expectedSha) fail(`Git blob SHA mismatch for ${row.path}: expected ${row.expectedSha}, got ${actualSha}`);
}

const migrationFiles = readdirSync(migrationDirectory)
  .filter((file) => file.endsWith(".sql"))
  .map((file) => join(migrationDirectory, file))
  .sort();
const actualPrefixes = migrationFiles.map((file) => basename(file).slice(0, 14));
if (new Set(actualPrefixes).size !== actualPrefixes.length) fail("duplicate migration version prefixes in supabase/migrations");

const expectedFiles = new Set([...paths, ...expectedForwardOnly]);
const actualFiles = new Set(migrationFiles);
for (const path of expectedFiles) if (!actualFiles.has(path)) fail(`expected migration file is missing: ${path}`);
for (const path of actualFiles) if (!expectedFiles.has(path)) fail(`unmanifested migration file found: ${path}`);

console.log(`Verified ${rows.length} applied migration sources, ${migrationFiles.length} unique migration files, and ${expectedForwardOnly.length} declared forward-only migrations.`);
