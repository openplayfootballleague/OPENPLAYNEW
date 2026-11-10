# Referee matchday foundation — 10 November 2026

## Implemented in this branch

- Referee applications are stored separately from `user_roles`; referee approval cannot grant platform administrator privileges.
- Admin-only application review creates or reactivates a distinct referee membership; the admin workspace exposes applicant identity, application evidence and reasoned decisions.
- Approved referees can record dated availability against active locations.
- Admin-only fixture allocation and removal preserve assignment history and enforce one active official per fixture.
- Referee fixture retrieval is restricted to the referee's own assignment and the earliest active gameweek in that season.
- Referee report submission checks active membership, active assignment, both locked/submitted team sheets, match completion time and the 24-hour submission window.
- Goalscorers and player/bench disciplinary incidents are validated against the submitted team sheets. Supporter incidents cannot be assigned a player identity.
- Fixed fine amounts are enforced in the database: £5 yellow, £15 second-yellow/red total and £30 straight red.
- Report versions are retained. Admin review can approve, return or reject a submitted report. Approval posts a single team fine ledger entry per incident and creates the referee entitlement.
- Approval publishes the fixture result, reconciles active goalscorer records, posts team fine ledger entries, records straight-red strikes against permanent competition identities and creates one £22 gross referee entitlement with a £20 minimum net guarantee.
- Three straight-red strikes mark a competition identity inactive pending administrator return approval. The team-sheet database guard blocks future scheduled team-sheet selection until the reasoned admin return decision.
- Referee tables have RLS enabled and direct client table grants revoked. Access is through role- and assignment-checked RPCs.

## UI delivered in this branch

- Referee application and approved-member Hub route at `/referee`, including the five-tab navigation, assigned match centre, both team sheets, score/goals/cards form, draft/submission controls, availability and entitlement history.
- Admin referee workspace at `/admin-referees`, linked from the main admin navigation, including application decisions, location-scoped availability, fixture allocation/reassignment/removal and report review.

## Deliberately not claimed complete

- The new referee and admin routes are implemented but still require browser/device and role-based manual acceptance.
- Allocation/assignment notifications are not yet dispatched.
- Admin report correction, unpublish and soft-delete reconciliation are not yet implemented.
- Own goals are recorded in the report, but are not attributed to player goal statistics until the owner-confirmed own-goal attribution rule is decided.
- Appearance tracking remains unchanged; the owner decision between submitted team sheet and actual participation remains open.
- Referee payment entitlements are created on approval, but Stripe Connect onboarding, transfer, payout, fee reconciliation and portal balances are not yet wired.
- The global referee-reporting feature toggle is not yet connected.
- No production migrations, live payments, deployment or merge has been performed.

## Verification gates

The migration must pass a clean full migration replay from the reconciled branch baseline. The SQL regression test asserts RLS, direct-grant revocation, role separation, assignment uniqueness, deadline and team-sheet validation, approval side effects and entitlement uniqueness. CI results must be green before this slice is promoted from draft.
