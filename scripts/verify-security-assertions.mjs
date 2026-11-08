import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const sourcePath = "supabase/tests/security_privilege_assertions.sql";
const source = readFileSync(sourcePath, "utf8").trim().replace(/;\\s*$/, "");

if (!source.toLowerCase().startsWith("select")) {
  throw new Error(`Expected a SELECT assertion query in ${sourcePath}`);
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

  SELECT
    string_agg(key, ', ' ORDER BY key),
    count(*)::integer
  INTO failed_assertions, assertion_count
  FROM jsonb_each(to_jsonb(assertion_results))
  WHERE value IS DISTINCT FROM 'true'::jsonb;

  IF failed_assertions IS NOT NULL THEN
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
    "supabase",
    ["db", "query", "--local", "--file", sqlPath],
    { stdio: "inherit" },
  );
} finally {
  rmSync(directory, { recursive: true, force: true });
}
