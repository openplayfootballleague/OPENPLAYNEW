# Analytics & Reports — User Growth metric definitions

The User Growth tab uses the permission-checked `public.get_admin_user_growth` RPC. It returns daily aggregate counts only; it does not return player names, email addresses, phone numbers, dates of birth, Auth IDs or message content.

## Metrics

| Metric | Source | Definition |
|---|---|---|
| Account signups | `public.profiles.created_at` | Profiles created on each Europe/London calendar day. This metric is shown only to a global administrator in the all-locations view. |
| Player registrations | `public.players.created_at` | Distinct player records created on each day. In a location, league or season view, only players with a membership record in that selected competition context are included. |
| Team applications | `public.season_teams.created_at` | Season-team application records created on each day, regardless of their current approval outcome. |
| Team approvals | `public.season_teams.approved_at` | Season-team records currently approved, grouped by the recorded approval timestamp. |

## Scope and privacy

- Global administrators may request platform-wide totals or filter to a location, league or season.
- A platform-wide account signup count is returned only when no location, league or season filter is selected. Scoped views return a null account-signup value, not a misleading zero.
- A league/location administrator must have an explicit assignment to the selected location. An unassigned location is rejected by the RPC.
- Player counts in scoped views are distinct people associated with the selected competition through their team membership history. They are aggregate counts, not a roster.
- The function has a fixed empty search path, fully qualified database references, an explicit administrator check, and execution is granted only to authenticated users.
- Date boundaries use Europe/London calendar days. An omitted range defaults to the latest 30 days; the maximum supported range is 366 inclusive days. Every day is returned, including zero-activity days.

## Deliberate limitations

This report does not claim to measure anonymous website visitors, repeat visitors, active users, retention cohorts, conversion rates or feature adoption. Those require a sufficiently complete, consented PostHog event history and are reported separately. A profile row is an account signup, not proof of player registration. A team application is not an approved team. Team approval counts use the actual approval timestamp.

The report is not a financial statement. Charges, receipts, refunds, outstanding balances, costs and operating surplus remain governed by the finance ledger and the Business Performance report.
