import { readFileSync } from "node:fs";

const workflow = readFileSync(".github/workflows/ci.yml", "utf8");
const lines = workflow.split(/\r?\n/);
const errors = [];
const expectedMigrations = [
  "referee_application_workflow",
  "referee_fixture_assignments",
  "referee_match_reports",
  "referee_approved_report_corrections",
  "team_weekly_payment_workflow",
  "weather_gameweek_postponements",
  "admin_disciplinary_return_queue",
  "referee_approved_report_correction_options",
  "referee_connect_payouts",
  "referee_payout_transfer_outbox",
  "secure_messaging_platform",
  "player_self_service_statistics",
  "optional_goal_attribution",
  "admin_league_admin_role_management",
  "future_season_membership_transitions",
];
let checked = 0;
const foundMigrations = [];

for (let index = 0; index < lines.length; index += 1) {
  const command = lines[index].match(/supabase migration new ([a-z0-9_]+)(.*)$/);
  if (!command) continue;

  const name = command[1];
  foundMigrations.push(name);
  const suffix = command[2].trim();
  const next = lines[index + 1]?.trim() ?? "";
  const after = lines[index + 2]?.trim() ?? "";

  if (suffix.length > 0) {
    errors.push(`Migration ${name} redirects draft SQL into the CLI. The CLI creates the file; it does not populate it from stdin.`);
    continue;
  }
  if (!next.startsWith("migration_file=") || !next.includes(`*_${name}.sql`)) {
    errors.push(`Migration ${name} does not locate its generated file immediately after creation.`);
    continue;
  }
  if (after !== `cp supabase/drafts/${name}.sql "$migration_file"`) {
    errors.push(`Migration ${name} does not copy its canonical SQL draft into the generated file.`);
    continue;
  }
  checked += 1;
}

if (checked === 0) errors.push("No Supabase CLI migration-generation steps were found.");
for (const name of expectedMigrations) if (!foundMigrations.includes(name)) errors.push(`Missing migration-generation step: ${name}`);
for (const name of foundMigrations) if (!expectedMigrations.includes(name)) errors.push(`Unexpected migration-generation step: ${name}`);
if (errors.length > 0) {
  for (const error of errors) console.error(`::error::${error}`);
  process.exit(1);
}
console.log(`Verified canonical SQL draft copying for ${checked} generated migrations.`);
