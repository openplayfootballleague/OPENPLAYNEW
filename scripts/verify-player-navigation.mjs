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
assert.equal((navigation.match(/to: "[^"]*" as const, label:/g) ?? []).length, 4, "Bottom navigation must contain exactly four tabs");
assert.ok(navigation.includes("useRouterState") && navigation.includes("pathname === \"/player\""), "Home tab must be active on both public Home and the registered Player Hub, not every route");

const more = readFileSync("src/routes/more.tsx", "utf8");
for (const destination of ['to="/teams"', 'to="/gallery"', 'to="/player"', 'to="/captain"', 'to="/admin"', 'to="/finance"']) {
  assert.ok(more.includes(destination), `More page is missing destination ${destination}`);
}
assert.ok(readFileSync("src/routes/index.tsx", "utf8").includes("<PlayerBottomNavigation />"), "Public home must render the bottom navigation");
console.log("Open Play four-tab navigation assertions passed.");

const playerHub = readFileSync("src/routes/player.tsx", "utf8");
assert.ok(playerHub.includes('if(player?.is_banned){void navigate({to:"/register-player",replace:true});return;}'), "Banned players must be redirected away from Player Hub to the restricted registration-status screen");

const publicHome = readFileSync("src/routes/index.tsx", "utf8");
assert.ok(publicHome.includes("let requestSequence = 0;") && publicHome.includes("sequence !== requestSequence"), "Public Home auth lookups must ignore stale responses after account changes");
assert.ok(publicHome.includes(".catch(() => {") && publicHome.includes("setCheckingAccess(false)"), "Public Home must recover from a failed session lookup instead of remaining on an endless loading screen");
assert.ok(publicHome.includes('player?.is_banned) {\n          await navigate({ to: "/register-player", replace: true });'), "Banned accounts must not be routed into Player Hub from public Home");

const matchCentre = readFileSync("src/routes/match-centre.tsx", "utf8");
const standings = readFileSync("src/lib/competition/standings.ts", "utf8");
assert.ok(matchCentre.includes("Teams level on points share the same position"), "The public league table must disclose Open Play's no-tiebreaker rule");
assert.ok(standings.includes("b.points-a.points || a.name.localeCompare(b.name)"), "League ranking must use points only, with name used solely for stable display order");
assert.ok(standings.includes("if (standing.points !== previousPoints) position=index+1;"), "Teams level on points must share the same league position");
