import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const navigation = readFileSync("src/components/player-bottom-navigation.tsx", "utf8");
const expected = [
  'to: "/" as const, label: "Home"',
  'to: "/match-centre" as const, label: "Match Centre"',
  'to: "/join" as const, label: "Join Open Play"',
  'to: "/more" as const, label: "More"',
];
for (const item of expected) assert.ok(navigation.includes(item), `Missing required bottom navigation item: ${item}`);
assert.equal((navigation.match(/to: "[^"]+" as const, label:/g) ?? []).length, 4, "Bottom navigation must contain exactly four tabs");

const more = readFileSync("src/routes/more.tsx", "utf8");
for (const destination of ['to="/teams"', 'to="/gallery"', 'to="/player"', 'to="/captain"', 'to="/admin"', 'to="/finance"']) {
  assert.ok(more.includes(destination), `More page is missing destination ${destination}`);
}
assert.ok(readFileSync("src/routes/index.tsx", "utf8").includes("<PlayerBottomNavigation />"), "Public home must render the bottom navigation");
console.log("Open Play four-tab navigation assertions passed.");
