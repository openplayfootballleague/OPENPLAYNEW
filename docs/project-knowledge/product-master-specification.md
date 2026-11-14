# Open Play — Product Master Specification

**Baseline:** owner-approved Master Prompt v3.0, 7 November 2026, plus subsequent explicit owner decisions.

## Vision
Open Play is a scalable, multi-location football league operating platform. It includes public discovery, player accounts, captain tools, referee workflows, league administration, competition operations, communications, payments, finance and reporting. It is not merely a fixtures/results website.

## Surfaces
- **Public:** home, location/league/season/team discovery, published fixtures/results and registration entry points. Public pages expose only intentionally published data.
- **Player:** Player Hub with own-team context, fixtures to season end, results, league table, My Team, My Profile and notifications.
- **Captain:** team/club management, squad, membership requests, team sheets and matchday actions.
- **Referee:** assigned fixtures, match reporting and authorised payment workflow.
- **Admin:** organisation, locations, leagues, seasons, applications, teams, players, fixtures, team sheets, results/events, stats, gallery, finance, feature management and settings.

## Navigation and account states
This is the single navigation rule. Other documents refer here. The evidence is the owner's reference
images in `docs/reference-assets/visual-references/`, reconciled on 2026-11-14.

| Account state | Persistent or transitional | Bottom navigation | Evidence |
| --- | --- | --- | --- |
| Visitor (signed out) | Persistent | **Home, Match Centre, Join Open Play, More** (4) | IMG_0581; Blueprint four-tab rule |
| Signed in with no active team (account only, or registered player without a team) | **Transitional onboarding**: shown only until the player joins a team | Home, Match Centre, Teams, Join Open Play, More (5); must fit at 390 px without wrapping | IMG_0582, IMG_0583 |
| Registered player in an active team | Persistent | **Player Hub (Home), Match Centre, Teams, More** (4) | IMG_0572–IMG_0576, IMG_0579, IMG_0580 |
| Captain | Persistent | Player navigation; captain-only Club and Matchday destinations are reached from Player Hub and More. **No reference image exists, so the owner must confirm** whether they replace Match Centre and Teams. | Captain workflow spec |
| Team registration wizard (IMG_0568–IMG_0571) | Transitional | Uses the signed-in-no-team navigation with the canonical icons and labels; the wizard images' title-case variant is not adopted | — |

- Join Open Play is never a persistent tab for a player who belongs to a team.
- Navigation is presentation only. Every destination enforces its own permissions on the server.
- Referee and administrator workspaces have their own authorised navigation.
- Do not add tabs without owner approval.

## Registration
1. Player registration is Phase 1 and DOB is mandatory.
2. Phase 2 allows joining an existing team or submitting a team application.
3. Team applications capture captain details and require acceptance of the applicable team fee.
4. Application submission alone does not confer captain status. Captain role follows approval and authorised assignment.
5. Captains approve or decline join requests.
6. Account creation alone never creates a player or grants team, captain, referee, admin or finance privileges.
7. Prevent duplicate/conflicting memberships server-side and transactionally.

## Profile and privacy
Only profile picture is editable in the standard player edit-profile workflow. Other registered fields remain read-only unless an explicit correction process is approved. DOB, private contact details and private membership information are never public by default.

## Product scope
Public pages; registration and profiles; teams and memberships; captain workflows; fixtures and postponements; team sheets; referee matchday; results and events; player/team statistics; notifications and announcements; controlled messaging; gallery; payments/refunds/fines/balances; admin dashboards and audit; finance; analytics; support; privacy/settings.

## Quality
Mobile and iPad friendly, no horizontal overflow, clear loading/empty/error/success states, real persistence, accessible controls and server-enforced permissions. No fake data or fake success. The original viewport/zoom requirement must be balanced with accessibility; do not obstruct assistive zoom.

## Completeness
A feature is complete only when correct behaviour, permissions, validation, persistence, error/empty states, responsive UX, relevant audit/security, tests and limitations are addressed. A route or button alone is not completion.
