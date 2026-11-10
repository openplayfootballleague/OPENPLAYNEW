import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const sourcePath = "supabase/tests/security_privilege_assertions.sql";
const rawSource = readFileSync(sourcePath, "utf8").trim();
const source = rawSource
  .replace(/^(?:\s*--.*(?:\r?\n|$))+/, "")
  .trim()
  .replace(/;\s*$/, "");

if (!source.toLowerCase().startsWith("select")) {
  throw new Error(`Expected a SELECT assertion query in ${sourcePath} after leading comments`);
}

const sql = `
DO $verify_security_assertions$
DECLARE
  assertion_results record;
  failed_assertions text;
  assertion_count integer;
BEGIN
  SELECT * INTO assertion_results FROM (
${source}
  ) AS assertions;

  SELECT string_agg(key, ', ' ORDER BY key)
  INTO failed_assertions
  FROM jsonb_each(to_jsonb(assertion_results))
  WHERE value IS DISTINCT FROM 'true'::jsonb;

  SELECT count(*)::integer
  INTO assertion_count
  FROM jsonb_each(to_jsonb(assertion_results));

  IF failed_assertions IS NOT NULL THEN
    RAISE NOTICE 'Failed assertions: %', failed_assertions;
    RAISE NOTICE 'Contextual readers: %',
      (SELECT string_agg(p.proname || ' anon=' || has_function_privilege('anon',p.oid,'EXECUTE')::text
        || ' auth=' || has_function_privilege('authenticated',p.oid,'EXECUTE')::text
        || ' location_guard=' || (pg_get_functiondef(p.oid) ILIKE '%assert_admin_location_context(v_location)%')::text, '; ')
       FROM pg_proc p WHERE p.oid IN (
        'public.get_admin_dashboard_contextual(uuid,uuid,uuid)'::regprocedure,
        'public.get_admin_player_register_contextual(text,text,integer,integer,uuid,uuid,uuid)'::regprocedure,
        'public.get_admin_team_sheets_contextual(uuid,uuid,uuid)'::regprocedure,
        'public.admin_get_transfer_requests_contextual(text,uuid,uuid,uuid)'::regprocedure,
        'public.get_admin_contextual_fixtures(uuid,uuid,uuid)'::regprocedure
       ));
    RAISE NOTICE 'Legacy RPC grants: %',
      (SELECT string_agg(p.proname || ' anon=' || has_function_privilege('anon',p.oid,'EXECUTE')::text
        || ' auth=' || has_function_privilege('authenticated',p.oid,'EXECUTE')::text, '; ')
       FROM pg_proc p WHERE p.oid IN (
        'public.get_admin_dashboard()'::regprocedure,
        'public.get_admin_player_register(text,text,integer,integer)'::regprocedure,
        'public.get_admin_team_sheets()'::regprocedure,
        'public.admin_get_transfer_requests(text)'::regprocedure
       ));
    RAISE NOTICE 'Location mutations: %',
      (SELECT string_agg(p.proname || ' anon=' || has_function_privilege('anon',p.oid,'EXECUTE')::text
        || ' location_guard=' || (pg_get_functiondef(p.oid) ILIKE '%can_administer_location%')::text, '; ')
       FROM pg_proc p WHERE p.oid IN (
        'public.admin_create_league(uuid,text,competition_format,text)'::regprocedure,
        'public.admin_create_season(uuid,text,integer,date,date,timestamp with time zone,timestamp with time zone)'::regprocedure,
        'public.admin_create_season_team(uuid,text,text,text)'::regprocedure,
        'public.admin_create_fixture(uuid,integer,integer,uuid,uuid,timestamp with time zone,uuid,text)'::regprocedure,
        'public.admin_record_fixture_result_with_appearances(uuid,integer,integer,uuid[],uuid[],uuid[],uuid[],text)'::regprocedure,
        'public.admin_set_fixture_status(uuid,fixture_status,text)'::regprocedure,
        'public.admin_transition_season(uuid,season_status)'::regprocedure,
        'public.resolve_team_membership_request(uuid,text)'::regprocedure,
        'public.resolve_team_registration(uuid,text,text)'::regprocedure
       ));
    RAISE EXCEPTION 'Security assertions failed: %', failed_assertions;
  END IF;

  RAISE NOTICE 'All % database security assertions passed', assertion_count;
END
$verify_security_assertions$;
`;

const directory = mkdtempSync(join(tmpdir(), "openplay-security-"));
const sqlPath = join(directory, "assertions.sql");

try {
  writeFileSync(sqlPath, sql, "utf8");
  execFileSync(
    "psql",
    [
      "--host", "127.0.0.1",
      "--port", "54322",
      "--username", "postgres",
      "--dbname", "postgres",
      "--set", "ON_ERROR_STOP=1",
      "--file", sqlPath,
    ],
    {
      stdio: "inherit",
      env: { ...process.env, PGPASSWORD: process.env.PGPASSWORD ?? "postgres" },
    },
  );
} finally {
  rmSync(directory, { recursive: true, force: true });
}
