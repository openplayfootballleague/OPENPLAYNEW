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

const adminSource = readFileSync("src/routes/admin.tsx", "utf8");
const adminNav = adminSource.match(/<nav className="admin-workspace-nav"[^>]*>([\s\S]*?)<\/nav>/)?.[1] ?? "";
const adminNavNumbers = [...adminNav.matchAll(/>\s*(\d{2})\s+/g)].map((match) => Number(match[1]));
assert.deepEqual([...new Set(adminNavNumbers)], Array.from({ length: 15 }, (_, index) => index + 1), "Admin workspace navigation must contain exactly 15 numbered sections; the Communications label is shared by its enabled/disabled render branches");
assert.ok(adminNav.includes("12 Analytics &amp; Reports"), "Analytics & Reports must remain a first-class admin section");
assert.ok(!adminNav.includes("Guardian Consents") && !adminNav.includes("Player Retention"), "Guardian consent and retention workspaces must be nested, not extra top-level sections");
const playerApprovalsSection = adminSource.match(/<section id="admin-player-approvals"[\s\S]*?<\/section>/)?.[0] ?? "";
assert.ok(playerApprovalsSection.includes('to="/admin/guardian-consents"'), "Guardian consent review must be accessible within Player Approvals");
const settingsSection = adminSource.match(/<section id="admin-settings"[\s\S]*?<\/section>/)?.[0] ?? "";
assert.ok(settingsSection.includes('to="/admin/retention"'), "Player retention must be accessible within Settings & Feature Management");

const finance = readFileSync("src/routes/finance.tsx", "utf8");
const requiredSession = readFileSync("src/lib/auth/use-required-session.ts", "utf8");
assert.ok(finance.includes("useRequiredSession()") && finance.includes('authStatus==="authenticated"'), "Finance workspace must wait for a verified signed-in session before loading protected finance RPCs");
assert.ok(requiredSession.includes("authEventSeen") && requiredSession.includes("subscription.unsubscribe()"), "Required-session guard must handle auth changes and clean up its subscription");

const passwordRecovery = readFileSync("src/routes/reset-password.tsx", "utf8");
assert.ok(passwordRecovery.includes("resetPasswordForEmail") && passwordRecovery.includes("If an account exists for that address"), "Expired password-reset links must offer a non-enumerating fresh reset request");
assert.ok(passwordRecovery.includes("auth.signOut()") && passwordRecovery.includes("setUpdated(true)"), "Password reset completion must sign out and require a fresh sign-in");
