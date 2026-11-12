# Open Play — Player-Facing Visual Design Master Specification

**Status:** Authoritative product requirement, added 8 November 2026  
**Scope:** All player-facing application screens, existing and future.  
**Explicit exclusion:** Admin Dashboard retains its separately approved management-dashboard design. It still uses the exact official Open Play logo wherever Open Play branding is shown.

This document consolidates the user's approved Player Hub visual authority, global typography and iconography rules, extensible icon registry, team-badge upload/processing requirements, and global official-logo behaviour. It supplements the functional master prompt; it does not replace it.

## 1. Design authority and preservation

The user's finalised Player Hub/Home screenshot is the primary visual reference and design authority for the entire player-facing application. Preserve its approved layout and appearance; do not independently redesign the Player Hub. Apply its visual language consistently to every player-facing page.

This is an app-wide design-system requirement, not a request to restyle isolated screens. Preserve all existing functionality, permissions, roles, workflows, database structures and business logic. Do not remove features to simplify screens, invent placeholder functionality or expose private data to improve presentation.

## 2. Visual identity and tokens

The player-facing application must feel premium, modern, dark, cinematic, sport-focused, professional, clean and uncluttered.

| Token | Value |
|---|---|
| Primary background | #000000 |
| Secondary background | #101010 |
| Card background | #171717 |
| Elevated card | #1D1D1D |
| Open Play orange | #FF6500 (approximate brand UI accent; never recolour logo asset) |
| Primary text | #FFFFFF |
| Secondary text | #BDBDBD |
| Muted text | #777777 |
| Borders/dividers | #303030 |
| Success | Restrained green |
| Warning | Amber |
| Error | Restrained red |

Orange is the defining accent for active navigation, important labels/headings, primary actions, selected tabs, interactive icons, key statistics, match highlights, progress and selected states. Keep the interface predominantly black, charcoal, white and orange. Avoid unnecessary palettes, gradients, decorative effects and generic SaaS styling.

## 3. Permanent typography pairing

Only these two font families are approved for player-facing UI:

- **Display: Oswald** — weights 400, 500, 600, 700. Use for page titles, section headings, competition/gameweek/matchday headings, large statistics, short uppercase labels and category headings.
- **Interface: Inter** — weights 400, 500, 600, 700. Use for player/team names, paragraphs, descriptions, supporting text, fixture details, navigation, buttons, forms, notifications, tables and settings.

Starting hierarchy: page title Oswald 28–32px/700; section heading Oswald 21–24px/600; card heading Inter 17–19px/700; category label Oswald 13–15px/600; body Inter 14–16px/400; supporting Inter 12–14px/400; buttons Inter 14–16px/600; navigation Inter 11–13px/500; large stats Oswald 28–36px/600. Adjust responsively.

Load shared font assets centrally and define global CSS variables (for example `--font-display: 'Oswald', sans-serif` and `--font-interface: 'Inter', sans-serif`). Load actual weights, avoid synthetic bolding where possible, and use suitable sans-serif fallbacks. No additional font family without approval. Do not use Oswald for long paragraphs or Inter in place of prominent display headings.

## 4. Shared application shell

All player-facing pages share one consistent compact black header, content system and bottom navigation. The header uses the exact official OP asset and OPEN PLAY wordmark, consistent sizing/spacing/alignment and appropriate account/location controls. The main content uses consistent horizontal margins, content widths, vertical rhythm and card treatment.

Bottom navigation follows the Player Hub screenshot: fixed where appropriate, black background, subtle upper divider, orange outline icons, small clean labels, consistent sizes/spacing, clear orange active indicator and safe-area support. Navigation destinations and visibility continue to obey existing account-state and role rules.

The entire official logo area in the global header is a clickable Home shortcut to the Player Hub. It must have an accessible label such as “Open Play Home”, a suitable pressed/hover state and work across mobile, tablet and desktop. The Home route must retain its existing authorization/role behaviour; do not grant access by bypassing guards.

## 5. Official logo — non-negotiable

The user's supplied orange connected OP symbol is the one definitive official logo. Use the exact original asset everywhere Open Play is branded, including global header, all player-facing pages, splash/loading/confirmation screens and Admin Dashboard branding. Never recreate, redraw, approximate, regenerate, substitute, stretch, distort or recolour it. Do not use AI-generated alternatives, generic lettering, old variants or text in place of the asset.

Store/reference the approved asset centrally and reuse it proportionally. Preserve shape, colour and artwork, with transparent-background presentation where supported. Do not invent a new logo asset if the exact supplied file is unavailable; identify the missing source asset as a blocker.

## 6. Cards, controls, spacing and icon styling

Cards use charcoal backgrounds (#171717 / #1D1D1D), subtle #303030 borders, consistent rounded corners (typically 14–18px), 16–20px padding, clear internal hierarchy, white primary text, grey supporting text and orange accents. Use primary, secondary, compact and full-width cards according to content importance; do not force identical dimensions.

Buttons: primary orange with legible dark text, secondary charcoal/bordered with white text, destructive restrained red and confirmation where appropriate. Keep consistent heights (typically 48–54px), padding, radii, typography, icon placement and interaction states. Interactive cards have clear affordances, intended full-surface clickability, consistent chevrons where appropriate and pressed/selected feedback.

Starting spacing: mobile margins 16–20px; card radius 14–18px; card padding 16–20px; section spacing 20–28px; button height 48–54px; nav icon 23–26px; nav label 11–13px; body 14–16px. Maintain rhythm and avoid overflow, touching cards, excessive gaps and unnecessary nested containers.

## 7. Extensible Lucide iconography

Use **Lucide outline icons** as the standard player-facing icon family. Do not mix unrelated icon packs, emoji, cartoon fills or randomly sourced SVGs. Icons should have clean geometric forms, consistent stroke weight, rounded ends where supported and orange as the primary colour; white for secondary emphasis, muted grey for inactive states, and restrained green/amber/red for statuses.

Starting sizes: navigation 24px; card icons 26–30px; small controls 16–20px; page-heading icons 22–26px; status icons 16–20px. Maintain alignment, spacing, touch targets and accessible labels for icon-only controls. Status must never rely on colour alone. Do not suggest an action that is unavailable.

The initial icon vocabulary is not exhaustive or restrictive. The shared icon registry must be extensible. For each new screen/feature/workflow, choose the clearest suitable icon based on meaning and context; reuse an existing icon only when it is genuinely appropriate. Add new Lucide icons centrally, with established styling and responsive review. Avoid ambiguous reuse for unrelated concepts; add text labels where needed. If Lucide has no suitable icon, use a documented custom SVG as an exception, matching outline/stroke/colour treatment. Official branding, team badges and player photos are identity assets, never interface icons.

Starting semantic mapping: Home House; Match Centre Trophy/football; Teams Shield; Join User Plus; More Menu; Fixtures Calendar Days; Results Trophy; League Table Chart No Axes Column Increasing; My Team Shield; Profile User Round; Notifications Bell; Settings Settings; Location Map Pin; Search Search; Squad Users Round; Captain Shield Check; Goals Goal/football equivalent; Assists Footprints; Appearances Calendar Check; Edit Pencil; Save Save; Back Chevron Left; Forward Chevron Right; Expand Chevron Down; Close X; Filter Sliders Horizontal; Verified Badge Check; Success Circle Check; Warning Triangle Alert; Error Circle Alert. Select the closest suitable Lucide equivalent where a dedicated football symbol does not exist.

## 8. Photography and identity assets

Use genuine Open Play football photography where available and appropriate. Preserve original photographs and player identity; do not recreate people/scenes or substitute genuine player photos with generated avatars. Apply restrained dark overlays only where needed for legibility. A neutral consistent silhouette is acceptable only when no player photograph exists. Do not use random generic stock imagery when genuine Open Play photography is available.

Team badges are individual identity assets, not generic interface icons. Preserve uploaded badge artwork and proportions.

## 9. Team badge upload and background processing

Authorised upload workflows:
1. Team registration: registering captain/authorised representative can upload, preview, replace or remove a badge before submission.
2. Admin team editing: authorised admins can upload, replace or remove a badge.

Validate image format, file size and dimensions; provide clear preview, success and error feedback. Preserve the original uploaded image exactly as submitted. Store original and processed transparent badge as separate assets associated with the correct team. Prefer PNG or another alpha-capable format for the processed image.

Every badge must undergo automatic background removal before publication. Processing must preserve original artwork, lettering, colours, shapes, internal details, proportions and genuine transparent areas. Do not remove all white/light pixels: white artwork may be part of the logo. If processing cannot confidently distinguish background from artwork, flag for administrator review and do not publish a damaged badge. If processing fails, retain the original and report the issue; never silently publish an incorrect processed image.

Workflow: validate -> securely store original -> background removal -> generate transparent output -> quality/confidence check -> approve or queue admin review -> associate approved output to team -> publish. Replacements follow the same pipeline; preserve prior assets under a defined retention policy and invalidate/update caches so old badges do not persist. Admins must be able to inspect original and processed assets.

Use the approved processed badge consistently wherever team identity appears: team directory/profile, Player Hub, Match Centre, fixtures/results/live matches, tables, match cards, player profiles showing affiliation, registration confirmation, notifications and future player-facing surfaces. Admin screens should display the processed badge and permit original review/editing. Preserve aspect ratio; centre artwork; consistent max dimensions and clear space; no distortion, artificial white boxes or invented backgrounds.

This specification does not authorise destructive processing or automatic publication without quality checks. Any third-party background-removal service, credentials, cost or data transfer must be assessed before integration; do not transmit user uploads to an unapproved external service.

## 10. Page-level application

All pages retain their existing function and permissions while adopting shared visual tokens/components.

- **Player Hub/Home:** preserve approved screenshot's branding/header, welcome banner/photo treatment, orange label, large welcome heading, statistics, two-column navigation cards, Next Match card and bottom navigation. No independent redesign.
- **Match Centre:** distinct fixtures/live/completed sections; cards show badges, team names, date/time, gameweek, competition and status.
- **Teams/team profiles:** charcoal directory cards; badge, team name, competition, position/status; profile sections for identity, captain, squad, season, fixtures, results and statistics.
- **Player profiles:** professional player presentation with genuine photo, name, team/competition/position and verified season stats (appearances, goals, assists). Never expose email, phone, DOB, emergency contact or private settings publicly.
- **Fixtures/results:** organise by date, gameweek, competition and status; scores prominent; distinguish win/loss/draw.
- **League tables:** readable headings, team names, consistent rows, subtle dividers, positions and restrained orange highlights; mobile readable.
- **Join/registration:** dark form cards/inputs, clear labels, orange actions and accessible validation; no generic white form pages.
- **Notifications:** consistent cards, clear unread/read/announcement/team/league/match distinctions, restrained orange for unread/important.
- **Profile/settings:** structured cards/lists, recognisable icons, clear descriptions, edit/save states.

## 11. Responsive design and interface states

Support iPhone, Android phones, iPad, Android tablets and desktop. Mobile uses readable single-column layouts and approved two-column cards where appropriate, accessible navigation, safe areas and touch-friendly controls. Tablet uses space intelligently without simply stretching mobile cards. Desktop uses spacious but constrained content widths, not oversized cards. No horizontal overflow.

Empty, loading, error and success states must use the same dark visual language. Empty states include concise help and a real next action. Loading uses restrained skeletons/indicators. Errors are clear and actionable. Success feedback is consistent. Do not invent data or actions.

## 12. Implementation and acceptance criteria

Before broad styling work: inventory all player-facing routes/components; locate shared header/navigation/cards/buttons/forms/tables/tokens; compare each against approved screenshot; record inconsistencies. Implement centrally via shared tokens/components rather than isolated page overrides.

Preserve business logic, database, auth, role/permission checks, navigation rules, workflows, genuine data and all existing features. Admin Dashboard is explicitly outside the player-facing restyle.

Review every player-facing route individually and as one journey. Acceptance checks:
- Approved Player Hub composition remains intact.
- All player-facing pages share palette, Oswald/Inter, Lucide styling, card/button/input/table/status treatments, spacing, header and bottom navigation.
- Exact original OP asset appears consistently; global header logo routes to Player Hub.
- Existing role/account-state visibility and access guards are unchanged.
- Public player profiles expose no private account/contact/emergency data.
- Team badges preserve original asset and only approved transparent processed asset is published; low-confidence processing is queued for review.
- Mobile/tablet/desktop layouts have no horizontal overflow and controls are accessible.
- Empty/loading/error/success states are coherent.
- Existing functionality and workflows still work.
- Admin Dashboard visual design remains unchanged apart from correct official logo branding.

A visual audit or screenshot alone is not proof of functionality. Record route-by-route results, viewport sizes, tests, regressions and any blocked checks. Do not claim completion until implementation and verification are complete.


## Future-season membership states — 12 November 2026

Preserve the approved Player Hub composition. Future-season information is an additional state within the existing team/membership area, not a redesign of the Home layout.

- Use the concise status **Approved future membership** for a player whose upcoming-season place is approved but not yet active.
- Use **Future captaincy approved** for an approved team applicant whose captain role is reserved for the upcoming season.
- Explain the activation dependency in plain language and name the previous season whose fixtures/results are still outstanding.
- Use **Membership conflict** only when an approved future membership is held because another incompatible club membership remains active in the same area/season.
- A future captain with pending player requests sees a **Future Squad Requests** panel in Player Hub. Each request shows the player's name, future team, season, activation dependency, and explicit Approve/Decline actions.
- This panel is restricted to future-season membership decisions. It must not expose current-season team sheets, matchday controls, payments, transfers or other Captain Hub permissions.
- When the previous season's non-cancelled fixtures are all completed and results confirmed, the membership/captaincy status changes to active and the ordinary Captain Hub becomes available. Keep the existing fixed bottom navigation and role-based navigation rules unchanged.
