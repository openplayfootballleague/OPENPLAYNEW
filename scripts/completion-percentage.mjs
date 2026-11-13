// Computes the weighted completion percentage from docs/project-knowledge/completion-register.md.
// Credit: Complete/Accepted = 1, Partially Complete = 0.5, Not Started/Blocked = 0.
import { readFileSync } from "node:fs";

const source = readFileSync("docs/project-knowledge/completion-register.md", "utf8");
const credit = { "Complete": 1, "Accepted": 1, "Partially Complete": 0.5, "Not Started": 0, "Blocked": 0 };
const rows = source.split("\n").filter((line) => /^\| [A-Z]+-\d+ \|/.test(line));
let total = 0, earned = 0;
const counts = {};
for (const line of rows) {
  const cells = line.split("|").slice(1, -1).map((cell) => cell.trim());
  const status = cells[cells.length - 2];
  const weight = Number(cells[cells.length - 1]);
  if (!(status in credit) || !Number.isFinite(weight) || weight <= 0) {
    throw new Error(`Invalid status/weight in row: ${cells[0]} (${status}, ${cells[cells.length - 1]})`);
  }
  total += weight;
  earned += weight * credit[status];
  counts[status] = (counts[status] ?? 0) + 1;
}
const percentage = Math.round((earned / total) * 1000) / 10;
console.log(`Requirements: ${rows.length}; weight ${total}; earned ${earned}`);
console.log(`Status counts: ${Object.entries(counts).map(([s, n]) => `${s} ${n}`).join(", ")}`);
console.log(`Weighted feature completion (implemented, not accepted): ${percentage}%`);
