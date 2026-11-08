# Player profile field permissions — decision workbook

Status: inventory created; permission decisions are intentionally not hard-coded until Open Play confirms them.

## Confirmed navigation rule

- Visitors and signed-in account holders who are not registered players see the public Home page.
- Registered players and active captains have the public Home page replaced entirely by the Player Hub.
- Active captain membership adds the Match Day / Club area; it does not replace the Player Hub.
- Direct access to the Player Hub is restricted to registered players and active captains. The public Home remains the landing page for visitors and ordinary account holders.

## Existing profile data inventory

The development database currently stores these fields.

| Field | Current table | Current Player Hub editing | Proposed permission category | Decision |
|---|---|---:|---|---|
| First name | profiles | Yes | Player + Admin | Confirm |
| Last name | profiles | Yes | Player + Admin | Confirm |
| Display name | profiles | Yes | Player + Admin | Confirm |
| Email address | players / Auth account | No | Player request; admin-controlled verification | Confirm |
| Mobile number | profiles and players | Yes (profile copy) | Player + Admin | Confirm |
| Date of birth | profiles and players | No | Restricted; likely admin-controlled after registration | Confirm |
| Profile picture | profiles.avatar_path | Yes (upload) | Player + Admin moderation | Confirm |
| Preferred playing position | profiles | Yes | Player + Admin | Confirm |
| Emergency contact name | profiles | No | Player + Admin, private | Confirm |
| Emergency contact phone | profiles | No | Player + Admin, private | Confirm |
| Player registration status | players | No | Admin / system only | System rule |
| Banned flag, date and reason | players | No | Admin / system only; restricted visibility | System rule |
| Genuine-player verification | players | No | Admin / system only | System rule |
| Account ID / player ID | Auth / players | No | System managed, immutable | System rule |
| Team membership and captain status | team_memberships | No | Approval workflow / admin / authorised captain actions | System rule |
| Squad number | team_memberships | No | Captain/admin within season rules | Confirm |
| Statistics and match records | fixture records | No | System / authorised admin corrections | System rule |

## Important data integrity rules

1. The permanent account ID and player ID must never be editable by the player.
2. The canonical email address must stay aligned with Supabase Auth. Changing it must use the verified Auth email-change flow, not a direct profile-table update.
3. Registration status, ban state, verification state, captain privileges and team membership are not profile fields and must never be changed through the ordinary profile editor.
4. Date of birth, phone and emergency contact information are personal data. Access must be restricted to the player and explicitly authorised administrators; captains should not receive them by default.
5. Profile edits that affect identity or eligibility should be audited. Admin corrections should record actor, before/after values and reason.
6. Historical team memberships, season registrations and match statistics must not be rewritten by profile edits.

## Existing implementation gap

The current Player Hub editor exposes first name, last name, display name, phone and preferred position, plus profile-picture upload. The database already has date of birth and emergency-contact fields, but they are not currently exposed in the editor. Email changes are not implemented as a profile-table edit.

## Decisions still required

Review the personal identity/contact group first, then proceed to football details, team/season data, privacy, notifications and account security. For every field decide:
- who can view it;
- who can edit it (player, admin, both or system);
- whether player changes take effect immediately or require approval;
- whether it is visible to captains;
- whether the change is audited.

Do not implement unconfirmed edit permissions merely because a database column is currently updatable.
