// Computes weighted completion from docs/project-knowledge/completion-register.md.
// Credit: Complete/Accepted = 1, Partially Complete = 0.5, Not Started/Blocked = 0.
// Stages are reported separately and never combined:
//   Feature implementation = every row except INT-, INF-, SEC-
//   Integration            = INT- rows
//   Security & infra       = SEC- and INF- rows
//   Formal acceptance      = weight of Accepted rows across all rows
import { readFileSync } from "node:fs";

const source = readFileSync("docs/project-knowledge/completion-register.md", "utf8");
const credit = { "Complete": 1, "Accepted": 1, "Partially Complete": 0.5, "Not Started": 0, "Blocked": 0 };
const rows = source.split("\n").filter((line) => /^\| [A-Z]+-\d+ \|/.test(line)).map((line) => {
  const cells = line.split("|").slice(1, -1).map((cell) => cell.trim());
  const status = cells[cells.length - 2];
  const weight = Number(cells[cells.length - 1]);
  if (!(status in credit) || !Number.isFinite(weight) || weight <= 0) {
    throw new Error(`Invalid status/weight in row: ${cells[0]} (${status}, ${cells[cells.length - 1]})`);
  }
  return { id: cells[0], prefix: cells[0].split("-")[0], status, weight };
});
const stage = (row) => row.prefix === "INT" ? "Integration" : (row.prefix === "INF" || row.prefix === "SEC") ? "Security & infrastructure" : "Feature implementation";
const pct = (n, d) => (d === 0 ? 0 : Math.round((n / d) * 1000) / 10);
const summary = {};
for (const row of rows) {
  const key = stage(row);
  summary[key] ??= { rows: 0, weight: 0, earned: 0, counts: {} };
  summary[key].rows += 1;
  summary[key].weight += row.weight;
  summary[key].earned += row.weight * credit[row.status];
  summary[key].counts[row.status] = (summary[key].counts[row.status] ?? 0) + 1;
}
for (const key of ["Feature implementation", "Integration", "Security & infrastructure"]) {
  const s = summary[key];
  if (!s) continue;
  const counts = Object.entries(s.counts).map(([k, n]) => `${k} ${n}`).join(", ");
  console.log(`${key}: ${pct(s.earned, s.weight)}% (${s.rows} requirements, weight ${s.weight}; ${counts})`);
}
const total = rows.reduce((sum, row) => sum + row.weight, 0);
const accepted = rows.filter((row) => row.status === "Accepted").reduce((sum, row) => sum + row.weight, 0);
console.log(`Formal acceptance: ${pct(accepted, total)}% (${rows.filter((r) => r.status === "Accepted").length} of ${rows.length} requirements accepted)`);
