# Open Play — Design System and Experience

## Brand
- Use the latest owner-supplied Open Play logo asset, including the orange OP mark. Never redraw, approximate, regenerate or replace the official logo.
- Dark/black foundation with orange accent.
- Oswald for headings; Inter for body and interface text.
- Modern, confident grassroots-football identity: bold and cinematic without sacrificing usability.

## Visual rules
Use centralised design tokens and consistent neutral surfaces. Orange is for key actions, selected states and brand emphasis. Maintain readable contrast in all states; do not use low-contrast orange text on dark surfaces. Avoid unrelated one-off palettes.

## Layout and navigation
Mobile-first and iPad-friendly. The mobile bottom navigation follows the account-state rule in `product-master-specification.md` (Navigation and account states): four persistent tabs, plus a five-tab transitional bar only for signed-in users without a team. The bar must never wrap at 390 px. Admin desktop uses a left sidebar; tablet must remain usable. No clipped controls or horizontal page overflow. Fixed navigation must respect safe areas and never obscure content.

## Imagery
Public hero imagery is cinematic and appropriate to the page. Use approved authentic football imagery where available. The established social creative direction is gritty, cinematic, blurred football action photography. Imagery must never replace the official logo.

## Interaction
Every control must perform its advertised action. Provide hover, pressed, selected, disabled and conspicuous keyboard-focus states. Honour reduced-motion preferences. Forms need inline validation and recoverable input preservation. Consequential/destructive actions require clear confirmation and audit reason where applicable.

## Accessibility
Accessibility is part of implementation: semantic structure, labels, keyboard navigation, visible focus, reduced motion, accessible names/state announcements, contrast, touch targets and screen-reader review of critical journeys. Do not claim WCAG 2.2 AA without a complete evidence-based audit.

## Reuse
Reuse shared components and tokens across public, player, captain, referee and admin surfaces. Cover mobile, tablet and desktop in visual tests.

## Shared component library (implemented 2026-11-14)
- **Code:** `src/components/ui/op-ui.tsx`, styled by `src/components/ui/op-ui.css` (loaded last in `__root.tsx`) and tested in `op-ui.test.ts`.
- **Components:**
  - layout and headings: `PageHeader`, `SectionHeading`, `Card`, `TileLink`;
  - controls: `Button`, `ButtonLink`, `SearchField`, `ConfirmDialog` (native `<dialog>`), `Pagination`;
  - status and data: `StatusBadge` (active/upcoming/warning/danger/neutral/accent), `StatTile`, `StatGrid`, `TeamInitials`;
  - states: `LoadingState`, `EmptyState`, `ErrorState`.
- **Icons:** Lucide (`lucide-react` pinned at 1.64.0) for navigation, header and cards. No new inline SVG icons.
- **Page titles:** white, uppercase, Oswald. A second title line is never orange. The only orange display lines are hero lines shown as orange in a reference image (IMG_0581, IMG_0562).
- **Status colours:** green = active/success, blue = upcoming/planned, orange = Open Play emphasis or warning, red = errors.
- **Surfaces:** player-facing screens use dark surfaces only. The remaining light rules in `styles.css` are overridden for player-facing screens. Admin surfaces are restyled in the admin workstream.
