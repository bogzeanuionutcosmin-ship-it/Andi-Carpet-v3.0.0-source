# Staging financial authorization matrix

Status: NOT RUN. All test accounts, amounts and teams must be synthetic.

| Scenario | Expected enforcement |
|---|---|
| Anonymous account reads team finance | Denied |
| Inactive account reads or mutates finance | Denied |
| Member reads permitted own-team finance | Only if explicitly allowed by current role policy |
| Member writes another team's finance | Denied without partial mutation |
| Authorized manager updates permitted team | Accepted with correct audit attribution |
| Manager changes own authorization scope | Denied unless separately authorized |
| Duplicate settlement request | No double accounting or duplicate audit event |
| Offline retry after timeout | Idempotent final result |
| Concurrent authorized updates | Conflict behavior documented, totals consistent |
| Malformed amount or negative edge case | Validated against approved financial rules |

## Evidence protocol
Use isolated staging Firebase project and checked-out combined candidate SHA. Record user role, team membership, before/after Firestore state, expected result, actual result, audit event and redacted test logs. Security must be enforced server-side; a hidden UI control is not authorization.

## Boundaries
This document does not assert that current code implements every expected outcome. Luna owns finance implementation and its tests. Do not run these cases against production data.
