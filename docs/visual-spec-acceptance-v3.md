# Open Play — visual specification implementation and acceptance register

Source: Open Play Master Platform Development Prompt v3.0 (7 November 2026), approved reference screenshots, and recorded visual requirements. This is a **traceability register**, not a claim to reproduce the original prompt verbatim. The full verbatim prompt and exact approved screenshots must be attached/compared before final visual sign-off.

## Binding visual requirements

| ID | Requirement | Implementation status | Acceptance evidence needed |
|---|---|---|---|
| V01 | Latest approved connected orange OP logo, not a generic text replacement | **Open**: temporary OP monogram in homepage | Compare approved logo asset and replace all placeholders |
| V02 | Cinematic dark football imagery with visible action, charcoal/black surfaces and orange accents | **Partial**: homepage hero and dark player surfaces | Compare approved images for every page; validate photography/licensing |
| V03 | Oswald headings and Inter body text | **Implemented in CSS** | Inspect computed fonts in browser |
| V04 | Exactly four fixed viewer tabs: Home, Match Centre, Join Open Play, More | **Implemented for viewer layout** | Verify iPhone/iPad safe areas, links, active state |
| V05 | Player and captain navigation must adapt to account state; player hub replaces Home; captain gets Club/Matchday actions | **Open** | Verify each role with authenticated test accounts |
| V06 | Player Hub must match approved screenshot and be team-specific | **Partial**: shared dark styling only | Pixel/layout comparison to approved reference |
| V07 | Captain Hub distinct squad, approvals, team sheet and matchday hierarchy | **Partial**: shared dark styling only | Compare full mobile flow |
| V08 | Match Centre league selector, fixtures/results/table/stats and cinematic league header | **Partial** | Screenshot each tab, empty/populated states |
| V09 | Admin uses **light working surfaces**, charcoal sidebar, orange actions, readable registers, side panels and inline editing | **Open**: existing light admin retained | Full desktop/iPad admin visual acceptance |
| V10 | No horizontal page overflow; responsive mobile, iPad and desktop; locked viewport per approved requirements | **Partial** | 375px, 390px, 768px, 1024px, 1440px acceptance |
| V11 | No sample teams, players, fixtures or scores on a new empty deployment | **Not evaluated** | Inspect all screens with empty database |
| V12 | Consistent cards, forms, buttons, iconography, hierarchy, error/loading/empty states | **Partial** | Route-by-route visual review |
| V13 | Branding and nav consistent across registration, login, password recovery, Teams, messages, finance and admin | **Open** | Screenshot audit every route |
| V14 | No production deployment until build, responsive screenshot review and user visual approval | **Gate** | CI + screenshots + approval |

## Routes requiring visual acceptance

- `/` — public cinematic homepage
- `/match-centre` — match centre
- `/teams` — teams directory
- `/join` — player/team joining
- `/register-player`, `/sign-up`, `/sign-in`, `/reset-password` — onboarding and auth
- `/player` — Player Hub
- `/captain` — Captain Hub
- `/admin`, `/admin-help`, `/finance` — operations
- `/messages` — messaging
- `/more` — viewer navigation destination

## Release decision

**Not visually accepted.** A passing build proves compilation, not pixel-accurate conformance. The current PR must not be treated as the complete v3.0 visual implementation. In particular, the approved logo, authenticated role navigation, admin design, and screenshot comparisons remain outstanding.
