# Analytics & Reports — Registration & Conversion definitions

The Registration & Conversion view uses the aggregate-only, permission-checked `public.get_admin_registration_conversion` RPC. It returns daily cohort counts only; no player names, email addresses, phone numbers, dates of birth, Auth IDs or message content are returned.

## Cohort rules

- Each daily bucket is based on the record's original creation date in the Europe/London timezone.
- Team applications are grouped by application creation day and split by their current state: approved, rejected or pending. The resolved approval rate is approved / (approved + rejected); pending applications are excluded from the denominator and displayed separately.
- Membership requests are grouped by request creation day and split by their current state. Accepted includes active or left memberships with a recorded joined_at timestamp, preserving the fact that a player was accepted even if they later left. The resolved acceptance rate is accepted / (accepted + rejected); pending requests are excluded and displayed separately.
- Player registration states (registered, pending review, rejected) are available only to a global administrator with no location, league or season filter. Player registrations awaiting review have no competition membership, so assigning them to a location would be misleading and could disclose platform-wide identity workflow totals.

## Scope and privacy

- Global administrators may view all competition cohorts or filter to a location, league or season.
- Location administrators must have an explicit assignment to the selected location; unassigned locations are rejected.
- A scoped view never returns platform-wide player-registration totals; those fields are null, not zero.
- The function returns daily zero-activity buckets, uses inclusive date boundaries, defaults to the latest 30 Europe/London days and rejects ranges longer than 366 inclusive days.
- The function has a fixed empty search path, fully qualified references, explicit administrator checks and authenticated-only execution.

## Interpretation limits

These are current-state conversion outcomes for records created during the selected period, not a prediction of eventual approval. Pending records remain unresolved and are not counted as failures. Team approval and membership acceptance rates use resolved outcomes only. Account signups are not included as player registrations; signup-to-player conversion is not shown here because the account cohort and location-scoped player workflow do not share a complete, privacy-safe denominator in every reporting context.

Financial outcomes remain sourced from the finance ledger. Product usage remains sourced from consented PostHog events.
