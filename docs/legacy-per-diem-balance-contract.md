# Legacy per-diem carryover contract

The Expenses carryover is a legacy informational balance across all trips for one
beneficiary-distributor pair. It includes only confirmed entries with a valid
declared amount and an actual received amount.

For an ordinary distribution, the contribution is:

`declared amount in bani - actual received amount in bani`

A supplementary distribution is cash toward an earlier debt, not a second
entitlement. Its contribution is:

`0 - actual received amount in bani`

Pending entries, entries without an actual receipt, malformed amounts, and
entries for another beneficiary or distributor contribute nothing. Disputed
differences are not automatically reconciled by this calculation.

The parser and standalone ledger have separate contracts. The legacy parser
accepts up to 100,000,000 lei and returns bani, while the standalone ledger
validates amounts up to 100,000,000 bani (1,000,000 lei). This document and the
boundary test record that difference; they do not define an adapter or make the
two calculators interchangeable.
