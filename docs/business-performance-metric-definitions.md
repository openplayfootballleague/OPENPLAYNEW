# Business Performance metric definitions

## Sources of truth

- Team charges, receipts, refunds, credits, fines and outstanding balances come from the append-only Supabase finance ledger.
- Player-card receipts, refunds and Stripe fees come from verified player payment records.
- Recorded operating costs come from the immutable `finance_operating_costs` ledger.
- Upcoming team payment forecast comes only from unpaid team fixture obligations already created for future fixtures.
- PostHog is not used for finance or operational figures.

## Measures

| Measure | Definition | Interpretation |
| --- | --- | --- |
| Upcoming team payment forecast | Sum of `due` and `grace_period` team fixture obligations whose snapshotted fixture time is in the future and within the selected date range | Not a forecast of player fees or uncreated future fixtures |
| Team charges | Ledger entries with type `charge` | Amount billed, not cash received |
| Team receipts | Ledger entries with type `payment` | Cash received through the team ledger |
| Team refunds | Ledger entries with type `refund` | Cash returned; also increases the team's ledger balance due under the existing ledger policy |
| Team credits | Ledger entries with type `credit` | Non-cash balance adjustments; excluded from receipts and operating surplus |
| Team fines | Ledger entries with type `fine` | Amount charged, not cash received |
| Outstanding team balance | Sum of each team's positive ledger balance, without offsetting another team's credit balance | Current amount owed under the ledger's established balance semantics |
| Player-card gross | Paid, partially refunded and refunded player checkout amounts before refunds and fees | Gross checkout amount, not net proceeds |
| Player-card refunds | Refunded amount recorded against player-card payments | Cash returned to players |
| Player-card Stripe fees | Stripe fee recorded for player-card payments | Payment processing cost |
| Player-card net proceeds | Recorded Stripe net amount less player-card refunds | Net player-card cash proceeds after refunds and fees |
| Recorded operating costs | Immutable operating-cost entries assigned to the selected location, league or season and date range | Only costs actually entered into the finance system |
| Recorded operating surplus | Team receipts less team refunds, plus player-card net proceeds, less recorded operating costs | A recorded cash-operating measure, not statutory profit |

## Cost recording

Operating costs are immutable entries. Each record has a category, signed amount in integer pence, description, incurred date, optional location/league/season context, optional reference and notes, creator and audit record. Direct client table access is revoked; finance-authorised RPCs validate context and create the entry. Negative amounts are allowed only for the explicit adjustment/reversal category; corrections are separate audited entries rather than edits or deletion.

## Scope and limitations

Location, league and season filters are enforced server-side. A location view includes costs assigned to that location, including its league- and season-level costs. A league view includes league- and season-level costs. A season view includes only that season's costs. Global costs are included only in an unfiltered all-location view.

The report excludes unrecorded costs, tax, sponsorship income not entered into the ledger and other off-ledger items. The forecast covers only existing future team obligations and must not be presented as guaranteed revenue. No-data is not proof of zero business activity.
