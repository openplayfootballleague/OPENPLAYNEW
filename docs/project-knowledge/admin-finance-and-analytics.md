# Open Play — Admin, Finance and Analytics

## Admin information architecture
Left sidebar sections:
1. Overview / Needs Attention
2. Locations & Leagues
3. Seasons
4. Teams
5. Players
6. Approvals
7. Fixtures
8. Team Sheets
9. Results & Match Events
10. Statistics
11. Gallery
12. Finance
13. Feature Management
14. Settings

Player Applications and Team Applications must both be available in the approval workflow. Needs Attention surfaces actionable outstanding tasks.

## Admin UX and scope
Searchable registers, filters, safe inline editing, contextual side panels, mobile/iPad support and audit history. Every query and mutation is scoped to the actor's authorised location, competition and role. Team registration requires fee acceptance and approval. Recruitment and announcements are explicit toggles. Fixture generation requires review. Google Sheets import is retired.

## Finance
Finance access is a separate permission boundary and is enforced server-side. Distinguish team charges/receipts, refunds/credits, fines, outstanding balances, future unpaid team-fee obligations already created for future fixtures, player-card gross/refunds/Stripe fees/net proceeds, recorded operating costs and recorded operating surplus.

Do not call a ledger summary a full profit-and-loss statement unless accounting inputs and treatment support that claim. Forecast only unpaid team obligations already created for future fixtures; do not infer uncreated player fees or guaranteed revenue.

Operating costs are immutable audit entries with location/league/season context, date, category, description, optional reference/notes and required audit reason. Correct with signed adjustments/reversals, not destructive edits. Exclude free-text descriptions, notes and payment references from analytics exports.

## Stripe / referee payouts
Use Stripe and Stripe Connect for approved payment/payout workflows. Owner decision D6: no new online card payment flow goes live without explicit owner approval. Referee Connect work continues behind feature gates, in test mode only. Verify webhook signatures, idempotency, recipient ownership and persisted provider state. Do not create live charges, connected accounts, transfers or webhooks without owner approval. Clarify gross/net amount, fees and minimum-net semantics before payout acceptance. A discussed £22 gross and £20 minimum-net are not interchangeable assumptions.

## Analytics
Current design/code baseline has ten Analytics & Reports tabs; preserve approved labels and scope. Reporting concepts include overview, App Usage, User Growth, Engagement & Retention, Feature Performance, Registration & Conversion, competition/location performance and finance/business performance. Metrics require definitions, source, scope, refresh and access controls. Show unavailable/insufficient-data, not misleading zeroes. Registration queues are not conversion metrics; define cohorts, stages and denominators. PostHog is not financial truth.

## PostHog privacy
Use OPENPLAYNEW project. Explicit consent before tracking; respect GPC and withdrawal. Use an explicit event allowlist and data minimisation. No DOB, email, phone, private messages, financial references or sensitive profile data. No session recording or invasive autocapture as a shortcut. Never load/send before consent and required actor/visitor gating. Operational and financial truth remains in Supabase.

## Notifications
In-app centre is durable. Optional email/SMS/push respects preferences and consent. Critical account/security events retain protected handling. Generic push lock-screen content. No real outbound sends or provider configuration without approval.

## Acceptance
Verify role access, audit, financial reconciliation/definitions, no misleading forecasts, export privacy and formula-injection protection, consent/GPC/network behaviour and no private-data leakage.
