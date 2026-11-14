// Compares src/lib/supabase/database.types.ts with a canonical schema built by a clean
// migration replay, mirroring `supabase gen types` (every public table, enum and non-trigger,
// non-extension function, whatever its grants). Built by a clean
// migration replay. Run against the isolated CI/local database, never production.
// Usage: PGHOST=... PGPORT=... PGUSER=... [PGDATABASE=...] node scripts/verify-generated-types.mjs
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";

const sql = (query) => execFileSync("psql", ["-X", "-A", "-t", "-F", "\t", "-v", "ON_ERROR_STOP=1", "-c", query], { encoding: "utf8" })
  .split("\n").filter(Boolean).map((line) => line.split("\t"));

// Canonical schema (public).
const dbColumns = new Map();
for (const [table, column] of sql(`select c.table_name, c.column_name from information_schema.columns c
  join information_schema.tables t on t.table_schema=c.table_schema and t.table_name=c.table_name
  where c.table_schema='public' and t.table_type='BASE TABLE'`)) {
  if (!dbColumns.has(table)) dbColumns.set(table, new Set());
  dbColumns.get(table).add(column);
}
const dbFunctions = new Map();
for (const [name, args] of sql(`select p.proname, coalesce(array_to_string(p.proargnames, ','), '') from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prokind='f'
  and p.prorettype <> 'trigger'::regtype
  and not exists (select 1 from pg_depend d where d.objid=p.oid and d.deptype='e')
`)) {
  if (!dbFunctions.has(name)) dbFunctions.set(name, new Set());
  for (const arg of args.split(",").filter((a) => a.startsWith("p_"))) dbFunctions.get(name).add(arg);
}
const dbEnums = new Map();
for (const [name, value] of sql(`select t.typname, e.enumlabel from pg_type t join pg_enum e on e.enumtypid=t.oid
  join pg_namespace n on n.oid=t.typnamespace where n.nspname='public'`)) {
  if (!dbEnums.has(name)) dbEnums.set(name, new Set());
  dbEnums.get(name).add(value);
}

// Generated types (public schema section only).
const types = readFileSync("src/lib/supabase/database.types.ts", "utf8");
const publicStart = types.indexOf("  public: {");
const section = (name) => {
  const start = types.indexOf(`    ${name}: {`, publicStart);
  const next = ["Tables", "Views", "Functions", "Enums", "CompositeTypes"].map((n) => types.indexOf(`    ${n}: {`, start + 1)).filter((i) => i > start);
  return types.slice(start, Math.min(...next, types.length));
};
const entries = (text) => [...text.matchAll(/^ {6}([a-z0-9_]+):(?: \{|\n {8}\|)([\s\S]*?)(?=^ {6}[a-z0-9_]+:(?: \{|\n {8}\|)|\n {4}\})/gm)].map((m) => [m[1], m[2]]);
const typeColumns = new Map(entries(section("Tables")).map(([name, body]) => {
  const row = body.slice(body.indexOf("Row: {"), body.indexOf("Insert: {"));
  return [name, new Set([...row.matchAll(/^ {10}([a-z0-9_]+)\??:/gm)].map((m) => m[1]))];
}));
const typeFunctions = new Map(entries(section("Functions")).map(([name, body]) => {
  const args = body.split("Returns:").slice(0, -1).join(" ");
  return [name, new Set([...args.matchAll(/\b(p_[a-z0-9_]+)\??:/g)].map((m) => m[1]))];
}));
const typeEnums = new Map([...section("Enums").matchAll(/^ {6}([a-z0-9_]+):\s*([^\n]*(?:\n {8}\|[^\n]*)*)/gm)]
  .map((m) => [m[1], new Set([...m[2].matchAll(/"([^"]+)"/g)].map((v) => v[1]))]));

const problems = [];
for (const [table, cols] of dbColumns) {
  if (!typeColumns.has(table)) { problems.push(`table missing from types: ${table}`); continue; }
  for (const col of cols) if (!typeColumns.get(table).has(col)) problems.push(`column missing from types: ${table}.${col}`);
}
for (const [table, cols] of typeColumns) {
  if (!dbColumns.has(table)) { problems.push(`table in types but not in schema: ${table}`); continue; }
  for (const col of cols) if (!dbColumns.get(table).has(col)) problems.push(`column in types but not in schema: ${table}.${col}`);
}
for (const [fn, args] of dbFunctions) {
  if (!typeFunctions.has(fn)) { problems.push(`function missing from types: ${fn}`); continue; }
  for (const arg of args) if (!typeFunctions.get(fn).has(arg)) problems.push(`argument missing from types: ${fn}(${arg})`);
}
for (const [fn] of typeFunctions) if (!dbFunctions.has(fn)) problems.push(`function in types but not in schema: ${fn}`);
for (const [name, values] of dbEnums) {
  const typed = typeEnums.get(name);
  if (!typed) { problems.push(`enum missing from types: ${name}`); continue; }
  for (const v of values) if (!typed.has(v)) problems.push(`enum value missing from types: ${name}.${v}`);
}

if (problems.length) {
  console.error(`Generated types differ from the canonical schema (${problems.length}):\n- ${problems.sort().join("\n- ")}`);
  process.exit(1);
}
console.log(`Generated types match the canonical schema: ${dbColumns.size} tables, ${dbFunctions.size} functions, ${dbEnums.size} enums.`);
