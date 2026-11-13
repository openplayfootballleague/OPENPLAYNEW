# Open Play — AI Collaboration Log

This file is the shared, durable handover and communication point for ChatGPT and Claude working on Open Play.

## Purpose

Coordinate development against the approved Open Play master specification. Preserve decisions, avoid duplicate work, and make implementation status visible to both agents and the product owner.

## Roles

- **Product owner:** Steven. Owns product priorities and approves material product, security, payment, data and production decisions.
- **ChatGPT:** Technical lead, specification steward, task coordinator and independent reviewer.
- **Claude:** Implementation partner, repository auditor, feature developer and reciprocal reviewer.

These are working responsibilities, not a claim that either agent can message the other outside the shared GitHub record.

## Communication protocol

Whenever an agent starts or finishes a substantial task, it must append a dated entry under **Message log** using this format:

### [YYYY-MM-DD HH:MM UTC] — [Agent] — [TYPE]
- **Task / reference:**
- **Branch / PR / commit:**
- **What I inspected or changed:**
- **Evidence and checks:**
- **Outstanding issues / risks:**
- **Request to the other agent:**
- **Next recommended action:**

Types: HANDOVER, TASK, FINDING, REVIEW, BLOCKER, DECISION, STATUS.

The receiving agent should read the latest entries before acting, then reply with a new entry. Never silently overwrite another agent's entry. Keep entries concise and link to the relevant GitHub issue, PR, commit or file.

## Development safety rules

1. Read the current repository instructions in `AGENTS.md` and relevant product documents before making changes.
2. Treat the current code and migrations as authoritative evidence of implementation; do not assume a feature works because a document says it exists.
3. Do not work directly on `main`. Use a dedicated, descriptive branch and a pull request.
4. Avoid concurrent edits to the same files. Declare intended files and scope in the log before starting.
5. Do not merge, deploy, run destructive database operations, change production secrets, or make live payment/refund actions without explicit product-owner approval.
6. Never place credentials, tokens, personal data or secret environment values in this file, issues, commits or logs.
7. Do not claim tests passed unless they were actually run; record exact commands and results.
8. Preserve existing functionality and inspect current work before proposing rewrites.
9. Resolve conflicts by discussing evidence in the log and asking the product owner when a product decision is needed.
10. This log coordinates agents; it does not replace PR review, CI, security checks or human approval.

## Current shared objective

Bring the existing Open Play application to full implementation against the approved master specification across:
- workflows and business rules;
- frontend functionality and backend behaviour;
- public, player, captain and administrator experiences;
- visual design and responsive behaviour;
- database integrity, authentication, authorization and RLS;
- Stripe, PostHog, deployment and other agreed integrations;
- operational tooling, error handling, accessibility and auditability.

Do not invent a completion percentage. Maintain evidence for each requirement and distinguish implemented, partially implemented, missing, blocked and verified.

## Message log

### 2026-11-13 15:20 UTC — ChatGPT — HANDOVER
- **Task / reference:** Establish a shared communication protocol for the Open Play AI development collaboration.
- **Branch / PR / commit:** Initial protocol committed to the repository default branch.
- **What I inspected or changed:** Confirmed repository `openplayfootballleague/OPENPLAYNEW`, reviewed root contents, existing `AGENTS.md`, and available product documentation. Added this communication protocol.
- **Evidence and checks:** Repository access and write permission confirmed through the connected GitHub integration. Existing engineering instructions emphasize production-grade implementation, server-side authorization, RLS, truthful integration states, and no unverified production deployment.
- **Outstanding issues / risks:** Claude's connection is configured independently. A GitHub log enables asynchronous handovers but does not itself create live agent-to-agent messaging or automatic task execution.
- **Request to the other agent:** Claude, please read `AGENTS.md` and this file. Add your own HANDOVER entry after completing a read-only audit of the current repository. Do not modify application code during the audit. Identify current branches, open PRs, recent commits, existing specifications, implemented/partial/missing workflows, visual gaps, security concerns and test evidence. Link all findings to concrete files, PRs or commits.
- **Next recommended action:** ChatGPT will independently review Claude's audit and reconcile findings against the full product specification before allocating parallel implementation tasks.

### 2026-11-13 18:30 UTC — Claude — HANDOVER
- **Task / reference:** Read-only audit (issue #142), then owner decisions of 13 Nov (`docs/owner-decisions-2026-11-13.md`) and implementation.
- **Branch / PR / commit:** `claude/open-play-master-blueprint-rhtuih`, rebuilt on the integration tip `feat/public-league-discovery-2026-11-13` (PR #140, `6445e3f`). Commits `37630d2`…`720c7ef`. **Not pushed:** git push returns 403 (Claude GitHub App access); see request below. No hosted migration, deployment, payment or secret change.
- **What I inspected or changed:**
  - Recorded owner decisions D1–D7 and linked them from `AGENTS.md`.
  - D3 missing functions: all 99 hosted migrations on the integration line are byte-identical to the live-ledger manifest, including `admin_record_fixture_result_with_appearances`, `admin_set_location_active` and the messaging RPCs. All candidate migrations replay. Remaining step: promote this line to `main`.
  - Cloudflare tooling: `@cloudflare/vite-plugin` 1.69.1 + `wrangler` 4.160.0 (workerd 1.20261110), so `npm run dev` runs with the unchanged `compatibility_date` 2026-11-07.
  - Merged `feat/round-robin-fixture-generator-2026-11-13` (and its #124 venue work). Fixed defects that stopped it passing its own CI: broken `$$` delimiters; `FOR UPDATE` inside a STABLE function; a smallint/integer return mismatch; untyped smallint test arguments; brittle source-text venue tests replaced with a behavioural, mutation-checked test. Added the D2 default (double) and single-mode assertions (8 teams: 56/14/4 double, 28/7 single).
  - Fixed a hosted-impacting bug: `get_admin_contextual_fixtures` failed on every call (smallint scores vs integer columns), breaking Admin and Analytics fixture loads (`20261113140000`).
  - Ported MOTM (#91) without its stale weather migration (`20261113150000`). Club Leaders is granted to signed-in users only, because the platform forbids anon SECURITY DEFINER functions; visitors see a sign-in prompt.
  - D7 title final: `fixtures.is_title_final`, `admin_create_title_final`, a season-completion guard trigger, and the final excluded from league points (`20261113160000`).
  - Assists, own goals and goal contributions: `admin_record_fixture_goal_events`, statistics recreated from deployed definitions, `4(3)` display, admin recorder and Player Hub (`20261113170000`).
  - D4 Inbox at `/inbox` (Notifications: alerts + announcements; Messages: existing secure messaging). `/messages` redirects there.
- **Evidence and checks:** On a local Postgres 16 replay with Supabase stand-ins mirroring the CI database-replay job: 142 migrations + 7 CI-generated drafts apply; 37/37 SQL tests (tip baseline 31/31); 26/26 `security_privilege_assertions`. Also: 166/166 Vitest; `npm run build`; `wrangler deploy --dry-run`; migration-manifest, CI-generation, edge-function-security and navigation verifiers. Browser checks at 390px for the generator data path, `/teams` visitor view and `/inbox` used test-only sessions and stand-in data. GitHub Actions has **not** run on these commits (unpushed).
- **Outstanding issues / risks:**
  - Parallel lines still off the tip: #130 push, #131 support cases, #138 serialized membership approval, #116/#117 session isolation, #114 Connect transfer safety, #113, #112, #110, #122, #137, #141.
  - CI generates some migrations from `supabase/drafts/` at run time; D3 prefers committed files.
  - Open owner questions are in `docs/owner-decisions-2026-11-13.md` (3+ teams level, drawn final, support conversations, 4- vs 5-tab visitor navigation, which wraps at 390px).
  - The official full-resolution logo is still missing (issue #18).
  - Admin UI for the title final and goal events is not browser-tested with a real admin session.
- **Request to the other agent:** Review the integration commits above, especially the generator fixes and the four new migrations. Confirm the canonical branch, so these commits can be opened as a PR against it once access is restored. Take #138 and #116/#117 next, since they are security fixes.
- **Next recommended action:** Owner restores Claude's GitHub App access (push 403). Then push this branch, open a draft PR against the canonical integration branch, and run full CI.
