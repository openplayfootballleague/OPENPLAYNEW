# Open Play — Competition and Match Operations

## Structure
Support multiple locations, leagues, seasons and formats. Competition settings are data-driven. Season publication and recruitment are explicit states; never infer recruitment from a date, countdown or team count.

## Fixture generator
Support single and double round-robin, configurable team count and scheduling inputs, deterministic reviewable output, and validation for duplicate/missing pairings, self-fixtures and uneven rounds. Fixtures require authorised review before publication.

Established Bideford eight-team home-and-away configuration:
- 8 teams, 14 gameweeks, 4 matches each gameweek.
- 56 total matches and 28 unique pairings, each played home and away.
This is a known configuration, not a universal default for every competition.

## Table and tie-break rules
Win/draw/loss points are configurable. Do not automatically apply goal difference or head-to-head. If two teams finish level in first place, they play a final to determine the champion. Do not invent other tie-breakers; unresolved ties require an explicit competition rule or owner decision.

## Matchday and postponements
Distinguish scheduled, postponed, abandoned, completed and result-published states. Record postponement reason and decision. Weather postponements must preserve original fixture history. Rescheduling preserves team, venue, season and audit context. Notifications use approved idempotent workflows.

## Results and events
Validate result/event against fixture, competition, match state and actor permissions. Publish only through authorised workflow. Corrections after publication are audited. Public surfaces show published results only.

## Statistics
Outfield player stats include appearances, goals, assists, goals per game, Man of the Match awards and goal contributions. Show current-season and career totals where data exists. Goals per game = goals / appearances; handle zero appearances safely. Appearance display format is starts(sub appearances), e.g. 4(3). Derive stats from authoritative submitted team sheets and published results/events, not spreadsheets or client values.

## Man of the Match
Captains may nominate themselves only when included on their team's submitted team sheet and meeting exactly the same eligibility rules as any other player. Enforce team and player eligibility.

## Format extensibility
Do not hard-code only 6-a-side. Team sheets, roster limits, match rules, fixture generation and stats must use competition configuration. The approved 7-a-side team sheet is 7 starters including goalkeeper and up to 4 substitutes.

## Acceptance
Test 8-team double round-robin totals/pairings, single round-robin and edge cases, points/tie rules, team-sheet limits/eligibility, former-player history, postponement/reschedule audit, published results, derived stats and role boundaries.
