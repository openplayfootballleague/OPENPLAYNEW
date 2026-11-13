# Open Play — AI and Contributor Protocol

## Mission
Deliver the complete Open Play platform in this knowledge base. Work independently within a workstream while preserving one coherent product.

## Before coding
- Read this directory and the relevant workstream specification.
- Inspect current branches, open PRs, migrations, routes, RPCs, tests and existing components.
- Search for an existing implementation before creating a duplicate.
- Check stacked PR dependencies and their base/head SHAs.
- ChatGPT conversations are not automatically visible to Claude. Durable project decisions belong in GitHub.

## Collaboration
1. Use focused branches and PRs; state dependencies and intended base branch.
2. Coordinate overlapping work through PR descriptions/comments and these documents.
3. Extend an existing implementation when appropriate instead of creating a competing version.
4. Do not assume uncommitted local work from another agent is visible.
5. Preserve owner-approved rules. Do not invent pricing, permissions, eligibility, scoring, roles or UX.
6. Keep unrelated refactors out of feature PRs.
7. Update the relevant spec when an owner-approved decision changes.
8. At handover, state what changed, what remains, exact verification SHA/run, blockers and next task.

## Development objective
Build all agreed feature areas before formal comprehensive E2E acceptance. Keep targeted tests and regression checks running throughout. Do not spend the entire development cycle repeatedly testing isolated areas while major agreed features remain missing.

## PR requirements
Every PR must describe: user outcome; exact scope; specification sections met; dependencies; schema/RPC/permission impact; privacy/security implications; tests and exact-head CI evidence; limitations/manual checks; and whether any hosted resource, provider configuration, deployment or live data changed. Keep draft until implementation and evidence are review-ready. Green CI alone is not a reason to merge.

## Owner approval boundary
Without explicit owner approval, do not merge or deploy; apply hosted/production migrations; change production secrets, auth, RLS or provider configuration; create live Stripe resources or move money; send real email/SMS/push/announcements; provision global or finance admins; enter live financial records; or provision paid infrastructure.

Local development, isolated CI databases, safe test fixtures and read-only inspection are permitted.

## Completion language
Distinguish: not started, in progress, implemented, automated-tested, manually verified, owner-accepted and deployed. Never claim full completion from a route existing or CI passing.
