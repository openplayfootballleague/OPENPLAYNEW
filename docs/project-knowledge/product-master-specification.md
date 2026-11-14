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

Owner specification (2026-11-14, section 5) is authoritative. Screenshots that show other tab sets are
superseded on navigation only.

| Account state | Bottom navigation |
| --- | --- |
| Visitor, signed-in account, player (with or without a club), captain | **Home, Match Centre, Teams, Join Open Play, More** (5). Home is the Player Hub for approved players. |
| Registration screens (`/sign-up`, `/register-player`, team registration wizard) | **Home, Match Centre, Join Open Play, More** (4), with Join Open Play highlighted |
| Captain extras | Captain Hub (Club and Matchday) is reached from the Player Hub and More. There is no extra or replacement bar. |
| Administrator and referee | Their own authorised workspace layouts |

- Join Open Play is not removed from player navigation. Teams is for browsing; Join Open Play handles
  registration and participation.
- The bar must never wrap, clip or overlap content, at any width.
- Navigation is presentation only. Every destination enforces its own permissions on the server.
- Screen, route, permission and interaction register: `screen-register.md`.

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
