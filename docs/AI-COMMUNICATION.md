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
