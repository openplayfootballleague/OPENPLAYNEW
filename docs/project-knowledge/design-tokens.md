# Open Play — design tokens and component rules (Apple-level standard)

**Status:** owner direction of 2026-11-14 ("Apple-level product design").

**Principles:** clarity, deference, depth, consistency and precision.

**Code:**
- Tokens: `src/components/ui/tokens.css`.
- Components: `src/components/ui/op-ui.tsx` and `op-ui.css`.

**Rule:** screens never hand-pick a size, colour, spacing or radius. They use a token, a type style or a shared component.

## Typography

**Fonts:**
- Oswald for display and football titles.
- Inter for everything else.

**Numbers:** statistics, scores, dates, times and money use tabular figures. Classes `.tabular`, `.t-stat` and `.t-score`, and all `op-*` numeric styles, include them.

| Style | Family | Weight | Size / line (mobile) | Size / line (≥768px) | Tracking | Case | Colour | Use |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `t-hero` | Oswald | 600 | 44 / 46 | 72 / 72 | 0 | Upper | text-1 | Public hero headline only |
| `t-display` (`op-page-title`) | Oswald | 600 | 34 / 40 | 44 / 48 | 0 | Upper | text-1 | One page title per screen |
| `t-title-1` (`op-section-title`) | Oswald | 600 | 20–24 / 26–30 | 24–28 / 30–34 | .005em | Upper | text-1 | Section headings |
| `t-title-2` | Oswald | 500 | 18 / 24 | 18 / 24 | .01em | Upper | text-1 | Card titles needing football voice |
| `t-headline` | Inter | 600 | 17 / 24 | 17 / 24 | −.01em | Sentence | text-1 | Tile and row titles |
| `t-body` | Inter | 400 | 16 / 24 | 16 / 24 | −.005em | Sentence | text-1 | Body copy, inputs |
| `t-callout` | Inter | 400 | 15 / 22 | 15 / 22 | −.005em | Sentence | text-2 | Supporting copy |
| `t-subhead` | Inter | 500 | 14 / 20 | 14 / 20 | 0 | Sentence | text-2 | Row metadata, labels |
| `t-footnote` | Inter | 400 | 13 / 18 | 13 / 18 | 0 | Sentence | text-2 | Hints, timestamps |
| `t-caption` | Inter | 600 | 12 / 16 | 12 / 16 | .06em | Upper | text-3 | Column headers, meta labels |
| `t-eyebrow` | Inter | 600 | 13 / 16 | 13 / 16 | .08em | Upper | accent | Context above a page title |
| `t-stat` | Inter | 700 | 28 / 32 | 32 / 36 | −.02em | — | text-1 | Statistic values |
| `t-score` | Inter | 700 | 32 / 36 | 32 / 36 | −.02em | — | text-1 | Match scores |

## Spacing (4-point)

**Scale:** 4, 8, 12, 16, 20, 24, 32, 40, 48, 64, 80 (`--space-1` … `--space-20`).

| Context | Value |
| --- | --- |
| Page gutter | 16 / 24 / 32 at <768, ≥768 and ≥1200 px |
| Page top padding | 24 |
| Title → content | 24 |
| Between sections | 32 / 40 / 48 |
| Section heading → content | 12 |
| Card padding | 16 / 20 |
| Card-to-card gap | 12 / 16 |
| Row padding | 12 × 16, minimum height 56 |
| Form field gap | 8 (label → control) |
| Button groups | 12 |
| Dialog padding | 24 |
| Drawer padding | 24 (body), 16 × 24 (header) |
| Table cells | 12 (16 at row ends) |
| Bottom-nav clearance | 128 plus the safe-area inset |

## Surfaces, colour, radius

**Surfaces:** `bg` #000 → `surface-1` #0e0e10 (sections, header) → `surface-2` #1a1a1d (cards) → `surface-3` #26262a (raised controls, selection).
- Depth comes from surface level, not from borders or shadows.
- Borders (`rgba(255,255,255,.10)`) are used only on outlined controls.

**Text:** text-1 #f5f5f7, text-2 #a1a1a8, text-3 #6e6e76.

**Accent:** Open Play orange #ff6500. Use it only for:
- primary actions;
- active navigation;
- selected states;
- eyebrows;
- one key number per screen at most.

Headings, icons, borders and statistics are neutral by default.

**Status colours:** success #34c759, info/upcoming #64a8ff, warning #ff9f0a, danger #ff453a, each with a 14–16% tint background.

**Radii:**

| Radius | Use |
| --- | --- |
| 8 | Segments |
| 12 | Controls, buttons, inputs, stat tiles |
| 16 | Cards, tiles, lists |
| 24 | Dialogs |
| Pill | Badges |

## Icons

**Library:** Lucide outline only. Stroke 1.75 (2 inside buttons).

**Sizes:**

| Size | Use |
| --- | --- |
| 16 | Inline, metadata, buttons |
| 20 | Rows, chevrons, navigation |
| 24 | Tile leading icons, empty states |

**Icon buttons:** 44 × 44 hit area.

**Colour:**
- Default icons: text-2.
- Chevrons: text-3.
- Active states and one leading tile icon may be orange.

No emoji, no filled icons, no ad-hoc SVGs.

## Controls

| Control | Specification |
| --- | --- |
| Touch targets | Minimum 44 |
| Primary page actions | Height 52 |
| Buttons | Primary (orange), secondary (surface-3), outline, ghost (orange text), light. Radius 12, Inter 600 15 / 20. |
| Inputs and selects | Height 44, surface-2, 1px inner border, 2px orange focus ring |
| Segmented tabs | Track surface-2, selected surface-3, height 36 |

## Motion

| Interaction | Duration |
| --- | --- |
| Hover and press | 120 ms |
| State changes | 180 ms |
| Dialogs and drawers | 260 ms |

- **Easing:** `cubic-bezier(.2,.8,.2,1)`.
- **Press feedback:** scale .98.
- **Allowed animation:** no bouncing and no decorative motion. Only the loading spinner and skeleton animate continuously.
- **Reduced motion:** `prefers-reduced-motion` reduces all durations to 0.

## Components (reuse; do not re-create)

**Layout and headings:** `PageHeader`, `SectionHeading` (optional `link`), `Card`.

**Navigation and actions:** `TileLink`, `Button` and `ButtonLink` (`variant`, `size`), `IconButton`, `SegmentedTabs`, `Pagination`.

**Data display:** `StatusBadge`, `StatTile`/`StatGrid`, `MatchCard`, `TeamRow`, `PlayerRow`, `TeamInitials`, `Avatar`.

**Forms:** `Field`, `SearchField`.

**States:** `LoadingState`, `EmptyState`, `ErrorState`.

**Overlays:** `ConfirmDialog`, `Drawer`.

**Layout classes:** `.op-page`, `.op-section`, `.op-stack`, `.op-cluster`, `.op-grid-2`, `.op-grid-3`, `.op-list`, `.op-row`, `.op-table` (`.op-col-optional` columns hide on phones), `.op-hero`.
