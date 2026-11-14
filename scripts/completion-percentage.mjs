// Computes weighted completion from docs/project-knowledge/completion-register.md.
// Credit: Complete/Accepted = 1, Partially Complete = 0.5, Not Started/Blocked = 0.
// Functional and Visual columns (Done = 1, Partial = 0.5, None = 0) are reported separately.
// A row may only be Complete when Functional is Done and Visual is Done or n/a.
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
  const functional = cells[cells.length - 4];
  const visual = cells[cells.length - 3];
  if (!["Done", "Partial", "None"].includes(functional) || !["Done", "Partial", "None", "n/a"].includes(visual)) {
    throw new Error(`Invalid functional/visual cells in row: ${cells[0]} (${functional}, ${visual})`);
  }
  if (status === "Complete" && (functional !== "Done" || !["Done", "n/a"].includes(visual))) {
    throw new Error(`${cells[0]} is marked Complete but is not functionally and visually complete`);
  }
  return { id: cells[0], prefix: cells[0].split("-")[0], status, weight, functional, visual };
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
const dimension = { Done: 1, Partial: 0.5, None: 0 };
const featureRows = rows.filter((row) => stage(row) === "Feature implementation");
const weighted = (list, key) => pct(list.reduce((sum, row) => sum + row.weight * dimension[row[key]], 0), list.reduce((sum, row) => sum + row.weight, 0));
const visualRows = featureRows.filter((row) => row.visual !== "n/a");
console.log(`Feature functional completion: ${weighted(featureRows, "functional")}% (${featureRows.length} rows)`);
console.log(`Feature visual completion: ${weighted(visualRows, "visual")}% (${visualRows.length} rows with a screen)`);
const total = rows.reduce((sum, row) => sum + row.weight, 0);
const accepted = rows.filter((row) => row.status === "Accepted").reduce((sum, row) => sum + row.weight, 0);
console.log(`Formal acceptance: ${pct(accepted, total)}% (${rows.filter((r) => r.status === "Accepted").length} of ${rows.length} requirements accepted)`);
