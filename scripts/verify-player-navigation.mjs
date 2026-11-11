import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const navigation = readFileSync("src/components/player-bottom-navigation.tsx", "utf8");
assert.ok(navigation.includes('id: "home", to: mode === "player" ? "/player" : "/"'), "Viewer Home must open public Home and registered-player Home must open Player Hub");
assert.ok(navigation.includes('id: "match-centre", to: "/match-centre"') && navigation.includes('id: "teams", to: "/teams"'), "Viewer and registered-player navigation must include Match Centre and Teams");
assert.ok(navigation.includes('id: "club", to: "/captain", hash: "#captain-club"') && navigation.includes('id: "matchday", to: "/captain", hash: "#captain-matchday"'), "Captain navigation must expose Club and Matchday as distinct destinations");
assert.ok(navigation.includes('id: "home", to: "/player"') && navigation.includes('id: "more", to: "/more"'), "Captain navigation must retain Player Hub Home and More");
assert.ok(navigation.includes('registration_status !== "registered"') && navigation.includes('.eq("is_captain", true)') && navigation.includes('setMode((captainRows ?? []).length > 0 ? "captain" : "player")'), "Navigation must derive viewer, registered-player and captain states from authorised account data");
const captainNavBlock = navigation.match(/const items: NavigationItem\[\] = mode === "captain"\s*\?\s*\[([\s\S]*?)\]\s*:\s*\[([\s\S]*?)\];/);
assert.ok(captainNavBlock, "Account-specific navigation arrays must be present");
for (const [index, block] of captainNavBlock.slice(1).entries()) {
  assert.equal((block.match(/\{ id:/g) ?? []).length, 4, index === 0 ? "Captain navigation must contain exactly four tabs" : "Viewer/player navigation must contain exactly four tabs");
}
assert.ok(navigation.includes('pathname === "/" || pathname === "/player"'), "Home must be active on public Home and Player Hub only");

const more = readFileSync("src/routes/more.tsx", "utf8");
for (const destination of ['to="/teams"', 'to="/join"', 'to="/gallery"', 'to="/match-centre"']) {
  assert.ok(more.includes(destination), `More page is missing public destination ${destination}`);
}
assert.ok(more.includes('access.player && <Link') && more.includes('to="/player"'), "Player Hub must only appear for an approved registered player");
assert.ok(more.includes('access.captain && <Link') && more.includes('to="/captain"'), "Captain Hub must only appear for an active captain");
assert.ok(more.includes('access.admin && <Link') && more.includes('to="/admin"'), "Admin Dashboard must only appear after the admin access check");
assert.ok(more.includes('access.finance && <Link') && more.includes('to="/finance"'), "Finance Workspace must only appear after the finance access check");
assert.ok(more.includes('get_admin_context_preference') && more.includes('get_finance_options'), "More page must resolve protected workspace access from server-authorized RPCs");
assert.ok(more.includes('Your account has basic-view access'), "Viewer accounts must receive the restricted basic-view explanation");
const refereeNavigation = readFileSync("src/components/referee-bottom-navigation.tsx", "utf8");
const refereeTabs = [
  'to: "/referee" as const, label: "Home"',
  'to: "/match-centre" as const, label: "Match Centre"',
  'to: "/referee/matchday" as const, label: "Matchday"',
  'to: "/more" as const, label: "More"',
];
for (const tab of refereeTabs) assert.ok(refereeNavigation.includes(tab), "Approved referee navigation is missing " + tab);
assert.equal((refereeNavigation.match(/to: "[^"]*" as const, label:/g) ?? []).length, 4, "Referee navigation must contain exactly four tabs");
assert.ok(refereeNavigation.includes('portal.membership?.status === "active"') && refereeNavigation.includes('!pathname.startsWith("/referee")') && refereeNavigation.includes("<PlayerBottomNavigation />"), "Only active referees inside the referee portal may switch from account-aware player navigation");
for (const route of ["index.tsx","player.tsx","captain.tsx","join.tsx","match-centre.tsx","teams.tsx","more.tsx","referee.tsx","referee/matchday.tsx"]) {
  const source = readFileSync("src/routes/" + route, "utf8");
  assert.ok(source.includes("<RefereeBottomNavigation"), route + " must use role-aware navigation");
}
const captainPage = readFileSync("src/routes/captain.tsx", "utf8");
assert.ok(captainPage.includes('id="captain-club"') && captainPage.includes('id="captain-matchday"') && captainPage.includes(">MATCHDAY</span>"), "Captain Club and Matchday tabs must land on clearly labelled workspaces");

const joinPage = readFileSync("src/routes/join.tsx", "utf8");
assert.ok(joinPage.includes('if(!player||player.registration_status!=="registered"||player.is_banned)'), "Unregistered viewer accounts must not submit team join or registration requests");
const registrationPage = readFileSync("src/routes/register-player.tsx", "utf8");
assert.ok(registrationPage.includes("Under-16s can browse public Open Play information but cannot register as players or join teams."), "Under-16 registration must explain the basic-view restriction");
assert.ok(registrationPage.includes("disabled={busy||isUnderSixteen||waitingGuardianReview}"), "Under-16 player registration submission must be disabled in the interface");

const globalStyles = readFileSync("src/styles.css", "utf8");
assert.ok(globalStyles.includes('font-family: "Inter", sans-serif;') && globalStyles.includes('font-family: "Oswald", sans-serif;'), "The global Open Play typography must use Inter for body copy and Oswald for display headings");
assert.ok(!globalStyles.includes("DM Sans") && !globalStyles.includes("Barlow Condensed"), "Legacy font families must not override the approved Inter/Oswald visual system");

console.log("Open Play account-aware four-tab navigation and global typography assertions passed.");

const playerHub = readFileSync("src/routes/player.tsx", "utf8");
assert.ok(playerHub.includes('if(player?.is_banned){void navigate({to:"/register-player",replace:true});return;}'), "Banned players must be redirected away from Player Hub to the restricted registration-status screen");

const playerHubDiscipline = readFileSync("src/routes/player.tsx", "utf8");
assert.ok(playerHubDiscipline.includes("disciplinary_strikes,disciplinary_inactive"), "Player Hub must load the server-owned disciplinary strike and inactive fields");
assert.ok(playerHubDiscipline.includes("player.disciplinary_inactive&&") && playerHubDiscipline.includes("Disciplinary restriction"), "Player Hub must explain when a disciplinary restriction blocks future team-sheet selection");
assert.ok(playerHubDiscipline.includes("You can still use your Player Hub and view your existing league history"), "Disciplinary restrictions must not incorrectly hide account access or historic league information");

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

const sessionGuard = readFileSync("src/lib/auth/use-required-session.ts", "utf8");
assert.ok(sessionGuard.includes(".catch(() => {") && sessionGuard.includes("setAuthenticated(false)"), "Required-session guard must recover from a rejected session lookup");
assert.ok(adminSource.includes("useRequiredSession") && adminSource.includes('if(authStatus!=="authenticated")return;'), "Admin workspace data requests must wait for a verified session");
assert.ok(adminSource.includes('if(authStatus!=="authenticated")return;void load();') && adminSource.includes('navigate({to:"/sign-in",replace:true})'), "Unauthenticated admin visits must redirect to sign in and avoid protected data loads");


const finance = readFileSync("src/routes/finance.tsx", "utf8");
const requiredSession = readFileSync("src/lib/auth/use-required-session.ts", "utf8");
assert.ok(finance.includes("useRequiredSession()") && finance.includes('authStatus==="authenticated"'), "Finance workspace must wait for a verified signed-in session before loading protected finance RPCs");
assert.ok(requiredSession.includes("authEventSeen") && requiredSession.includes("subscription.unsubscribe()"), "Required-session guard must handle auth changes and clean up its subscription");

const passwordRecovery = readFileSync("src/routes/reset-password.tsx", "utf8");
assert.ok(passwordRecovery.includes("resetPasswordForEmail") && passwordRecovery.includes("If an account exists for that address"), "Expired password-reset links must offer a non-enumerating fresh reset request");
assert.ok(passwordRecovery.includes("auth.signOut()") && passwordRecovery.includes("setUpdated(true)"), "Password reset completion must sign out and require a fresh sign-in");

const adminStats = readFileSync("src/routes/admin.tsx", "utf8");
const matchCentreSource = readFileSync("src/routes/match-centre.tsx", "utf8");
const standingsSource = readFileSync("src/lib/competition/standings.ts", "utf8");
assert.ok(standingsSource.includes("getJointFirstTeams") && standingsSource.includes("leaders.length > 1 ? leaders : []"), "Tied first-place teams must be detected without goal-difference tie-breaks");
assert.ok(adminStats.includes("Final required:") && adminStats.includes("Schedule a final to decide the season winner"), "Admin season statistics must flag a tied first place and prompt a final");
assert.ok(matchCentreSource.includes("Final required between") && matchCentreSource.includes("jointFirstTeams.length>1"), "Public Match Centre must disclose when a tied first place requires a final");


const playerStatsSource = readFileSync("src/routes/player.tsx", "utf8");
assert.ok(playerStatsSource.includes('rpc("get_my_player_statistics"') && playerStatsSource.includes("playerStats.season.stats") && playerStatsSource.includes("playerStats.career"), "Player Hub must load and display the authenticated player's verified season and career statistics");
assert.ok(playerStatsSource.includes("Assists and Man of the Match awards are not yet included"), "Player Hub must disclose statistics that are not yet supported by audited matchday capture");
const playerStatsMigration = readFileSync("supabase/migrations/20261111201000_player_self_service_statistics.sql", "utf8");
assert.ok(playerStatsMigration.includes("auth.uid()") && playerStatsMigration.includes("r.confirmed_at is not null") && playerStatsMigration.includes("ts.is_locked is true") && playerStatsMigration.includes("g.voided_at is null"), "Player statistics must be limited to the signed-in player, locked appearances, confirmed results and non-voided goals");
assert.ok(playerStatsMigration.includes("revoke all on function public.get_my_player_statistics(uuid) from public, anon;") && playerStatsMigration.includes("grant execute on function public.get_my_player_statistics(uuid) to authenticated;"), "Player statistics RPC must be unavailable to anonymous users");
