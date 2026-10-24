# Mission XXI continuation checkpoint — 21 October 2026

Repository: bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source.
Cumulative candidate: Draft/Open PR217, branch
codex/xix-home-locality-label-20261021, base main. Read its LIVE HEAD before work.
Main remains 8452159475ff187867002425fa9c3b8c7e8006aa. No merge/deploy/sign/distribute.
Production readiness is false.

## Latest continuation status (read before historical notes) — 22 October 2026

Last fully validated application-code SHA: `102c735dec6ee0780455e2f54082727930696a43`. A later documentation-only checkpoint commit follows this code; rerun all three required workflows on the live PR HEAD before claiming exact-HEAD green.
PR #217 remains Draft/Open on `main`; main is still
`8452159475ff187867002425fa9c3b8c7e8006aa`. No merge, production deploy,
signing, or distribution occurred.

Exact-SHA CI:
- Validate run `39779968747`: SUCCESS (Flutter, Firestore Emulator,
  Functions, Node, Python, web, and PDF verification).
- Android run `39779968349`: SUCCESS. Debug test APK artifact `12427355158`,
  archive SHA-256 `72dc7173c019a257eeef3d5016766143fa092e5e3efc872ff8b52b62bf1696c5`.
- Native run `39779968375`: SUCCESS. Android Emulator connected flow and Firebase
  Auth/Firestore/Functions Emulator verified a graph with 11 interventions,
  persisted the server receipt, replayed its exact immutable fingerprint after
  injected ACK loss through Android secure storage, and validated PDF/checksums.
  Evidence artifact `12426842940`, archive SHA-256
  `6774436e3aa56a90c854afb5aaae33d746b3bd188f5e57271655bb0af0884dc0`.
- Independent APK, directory, and release-guard checks passed. The isolated
  staging workflow was skipped because staging Firebase project/config variables
  are unavailable. These are emulator results, not live Firebase or handset tests.

The Native retry found an idempotency-test fixture mismatch: it reused the
receipt request ID with a different schedule revision. The test now reconstructs
the exact accepted fingerprint from the server receipt, and all three required
workflows passed on this exact HEAD. The complete `expense_page.dart` and Native
test sources were verified against their full Git blob IDs after a truncated
Git-tree transport attempt; no source truncation remains in the candidate.

New follow-up work adds production-key rejection and source provenance to the
staging builder, GPS cancellation checks after asynchronous platform calls, and
mounted checks after expense-picker/OCR awaits with widget lifecycle regressions.
Physical acceptance remains outstanding for GPS/background/offline, real camera
and OCR, upgrade/rollback, and signing/package provenance. PRs #178, #179, #181,
and #182 were rechecked at the reviewed heads, shown functionally represented by
the candidate, and closed as superseded after these gates passed. Total superseded
closures: 72. PR #33 remains open pending separate status review.

## This session's implementation

- Stable IDs generated for new scheduled visits, preserved by all clone/reorder/
  postpone/transfer projections; exact graph/day/visit scope in records/locks.
- Shared deterministic attempt slots for Dashboard/manual and Home arrival.
- Semantic START/FINAL replay preserves server times; changed outcomes reject.
- Authoritative lock-release verification after FINAL, including unknown ACK.
- Authenticated HTTP official STOP transaction, all-day CAS, final linked results,
  team reservations, closed graph marker and immutable request receipt.
- Firestore direct-close/retarget/late-day and operational Admin bypass protection.
- Actual Home callback -> Functions emulator native STOP and receipt replay tests.
- Facade prompt only for planned work; removed implicit FINAL Undo reopening.
- Seventeen application data models extracted from main's part library into an
  explicit import/export API, preserving constructor defaults and old imports.
- Read-only content inventory of all115 non-ancestor PRs; seven focused semantic
  reviews; no new PR closure. Nine broad comparisons hit300files and are incomplete.

## Validation history (not a current green claim)

Previous fully green baseline:5944943d,429Flutter/200Python/32Firestore.
Implementation7379c56d:437Flutter passed, one old recovery fixture failed due to
additional reservation read; new server suite initially failed package resolution.
Follow-up5ccda329:40Firestore tests passed, one test passed an Admin Timestamp to
Web SDK and was corrected to Date;438Flutter passed, three new negative-ACK tests
exposed an incorrect ID-collision classification. Recovery now preserves the
original uncertainty error when the payload matches but reservation is unconfirmed.
Functions/Node/Python passed both rounds. Final exact-SHA CI must be checked anew.
Local Python204passed; JavaScript syntax and whitespace passed.

## Exact next action

Continue from the live PR #217 HEAD. Re-run Validate, Android, and Native on the documentation checkpoint SHA before code changes. Then review PR #33 status and the remaining non-ancestor content inventory,
then continue the unclosed feature and critical acceptance packages. Do not infer
package completion from green CI. Obtain approved staging Firebase project/config
and a physical Android handset for staging, GPS/background/offline, camera/OCR,
upgrade, signer provenance, and rollback acceptance. Original audit criteria
remain the source of truth; no 13/13 or 6/6 completion is claimed.

## Gaps retained explicitly

Legacy visits have no stable attribution; require explicit reviewed reconciliation
before official closure, without silent production migration. New closed-graph
reopening and closed-state/receipt backup restore need server operations. Durable
arbitrary offline command journaling and crash-at-every-step validation remain.
Member server STOP currently requires stored effectivePermissions or Admin.
Large Finance/Vision branches need semantic integration; their missing path names
alone do not establish missing behavior. Original audit and feature acceptance
remain authoritative; do not invent13package closure or sixcritical PASS counts.
Staging project/config/provider credentials and physical Android GPS/background/
camera/OCR/offline/upgrade/signing/rollback evidence are not available here.
Existing APK is emulator-only; do not label it a phone staging release.

Local working tree is /workspace/scratch/ee2401192265/andi-carpet. Its git HEAD is
older than API-published commits; local modified files include earlier published
changes. Do not reset or republish them blindly. Compare file blob hashes with
current remote tree and update the existing branch with an expected-SHA lease.


## Staging preparation added after model boundary

An isolated staging Android builder/workflow now validates a separate public
Firebase Android JSON, uses package com.example.andi_carpeta.staging, debug test
signing, records package/certificate/APK hash/source provenance and restores
source config after failure. Runtime staging initialization rejects missing or
production config; every Functions URL derives from the selected project.
No staging project JSON/approved ID was supplied, so the conditional staging job
is expected to skip. Do not label an emulator build a staging phone APK.
See docs/release/STAGING_ANDROID_BUILD.md. Test physical/backend rollout remains
external; do not ask for credentials while other work remains executable.


## Legacy permission safety and unused retention

Static review reconfirmed that the old automatic badge migration deleted all
function definitions and reset member assignments when badge_v2 was absent.
Replaced with a server-read-only migration guard and a visible Admin message;
permission snapshot recalculation also waits for the verified marker. No legacy
role or grant is silently cleared, no completion marker is fabricated. Unit tests
exercise denied mutation/cache/pending paths; Native verifies real emulator
profiles and definitions remain equal before/after the production guard call.
Seven write-only Home string caches and their duplicate decode/encode loops
were removed after repository-wide use inspection; active core persistence
comparison caches and permission serializers remain. No measured memory-saving
number or completion of all Home modularization is claimed.


## Necessary non-ancestor integration: AuthGate PR33

Compared source PR33 at a5f43ef9ce0bfedaf59766aafe18732fef7f8f47 against its
base377f1fd5e73ae78a0df5cab58b09770c873cd167. Its UID/generation/profile and
root-navigator isolation was missing from the candidate. Imported AuthGate/root
changes and the actual-Home injected lifecycle regression fixtures. Reconciled
nine Home conflicts manually, preserving emulator platform-effect suppression,
HomeLiveLocationResources, transactional schedule/record writers, stable IDs,
server STOP and removed write-only caches. Added session ownership guards to
new persistence entry points and record transaction retries. Tests use real
production widgets with injected SDK fixtures; new Native acceptance also switches
the actual Firebase Auth default user editor->outsider->editor while a private
root route is mounted. Historical PR33 report is labelled as historical.
No PR33 closure until current candidate gates and a fresh head check.


## Financial input and rejected-save defects

The received-money dialog still accepted NaN/Infinity/scientific/fractional-ban
input and mutated original finance/settlement histories before awaiting save.
Extracted a controller-owning, scrollable dialog with the shared integer-bani
parser, plus a separate draft persistence helper. Failed writes preserve original
history/balances. Undated legacy totals are blocked for explicit reconciliation
rather than erased by the first history entry. Home validates financial totals
and entries before persistence; rules reject non-finite/negative aggregate totals
for members and Admin. Finance/settlements were excluded from the permissive
Admin catch-all so those checks cannot be bypassed. This is NOT a complete
server-authoritative financial ledger or durable uncertain-ACK journal.
Native now enters invalid NaN then valid12,34 in the actual Home Decont money
card, verifies real settlement persistence/listener and uses the reloaded
settlement in the decont PDF. New exact-SHA validation is required.

Native b4ec6b81 failed before packaging: the pinned comparison no longer compiled
against Home's added canContinue writer argument, so only2of4behavioral witnesses
ran. Moved the new guard test outside the pinned test selection and added an
API-signature-only adapter to the historical writer during the RED experiment.
The historical function bodies remain unchanged and all four named behavioral
failures are still mandatory, followed by restoration and GREEN rerun. This is
not a native application success/failure and produces no application evidence.


## Final server state regressions

Linked START now requires the server schedule to be started, unpaused and not
postponed. A new emulator regression denies all three stale UI states without
creating either a record or lock, then verifies a valid START/FINAL pair.
Official graph STOP still accepts fully resolved interventions after Dashboard's
separate program STOP sets started=false; closing readiness is based on actual
final linked results, not an invented all-days-started requirement. Added a
server transaction regression for that preserved UI behavior.

Nine more content-reviewed PRs were closed, retaining branches:105,122,138,139,
148,154,174,177,183. Total previous+this continuation closures66;107PRs remained
open including217at that observation (106other PRs). PR33is integrated but still
open pending final Native acceptance. No app-release package closure is implied.

Verified intermediate head7deaab921143ecb911294e93ae75aac7fe04f8f3:
Validate39676136019SUCCESS(472Flutter,206Python,42Firestore); Android39676135799
SUCCESS with APK metadata checked and artifact uploaded. Native39676136043
attempt1failed dependency resolution from Gradle Plugin Portal before packaging;
attempt2is compiling. The final server-state follow-up changes rules/closure
logic/tests only; run all3again on its new exactHEAD. Do not claim a Native PASS
or stage/physical validation from the intermediate APK.

## Durable STOP follow-up and latest validation

Candidate31ac615be3e0b99afe697891d07081415ccb5727passed Validate39677718957
(472Flutter,206Python,44Firestore) and Android39677718911. Android artifact
12382584953archive SHA256f399db73d3835c1e71ae2bb759d5dd08fc286fcb725efd44e318ac6328caa47c.
Native39677719006compiled debug/release successfully but failed BEFORE emulator
boot: sdkmanager could not unpack the Android36Google APIs system-image ZIP
(unknown archive). No connected assertions ran; artifact12383127906is partial
compilation evidence only. The next code commit triggers a fresh runner for all
three workflows. Do not count this Native result as acceptance.

Home official graph STOP now journals its exact request in secure storage before
dispatch, scoped by project/UID/team/graph. Reconstructed instances replay original
revisions after uncertain ACK/process loss. Confirmed receipt or explicit server
rejection retires intent; storage failure blocks dispatch, corrupt data fails
closed. HTTP checks current session after token lookup and before every retry.
New tests cover reconstructed instances, scope isolation, rejection versus unknown
ACK, failed storage, corruption, concurrency and session replacement. Native adds
actual Android storage plus a real server receipt with deliberately injected lost
ACK, followed by reconstruction and receipt replay. This is NOT physical crash
proof or a complete START/FINAL/financial/background journal.

Content review additionally verified and closed redundant PR184andPR185, keeping
branches. Original clone/projection regressions are byte-identical in31ac; consuming
Program paths preserve and extend their behavior. Total closures68. PR33still
awaits Native acceptance. Record final exact HEAD/CI in PR217metadata after the
next run. Continue fixing the first real Native failure; do not confuse partial
artifacts or build success with application validation.

## Local continuation — 2026-10-23

Local cumulative branch `codex/rule10-profile-stats-20261023` is based on
`2aa1869c437a05bbd3a1ec68a4d73aaa1c75d17a`. Current cumulative code head before
this documentation-only update: `5b61708` (`Add durable Dashboard schedule
transition journal`). Changes since the base add Profile live-stat queries, PDF
total/deduplication checks, Mapbox geometry caching, durable received-money,
Dashboard record and expense-save journals, OCR date/amount/ambiguous-document
handling, collision-safe journal keys, plus durable Program START/STOP intents.
The Program journal persists a complete batch and stable write receipts before
dispatch; exact replay is an idempotent no-op, while changed baselines fail
closed. Expense retry messaging checks that its operation is journaled.

On exact code head `5b61708`, `python3 -m unittest discover -s test -p
'*test.py' -q` passed all 207 tests; `git diff --check 2aa1869..HEAD` passed;
`node --check` passed for `functions/index.js`, `functions/graph_closure.js`,
and `tests/firestore/program_schedule.test.cjs`. Focused Dart tests and a
Firestore Emulator lost-ACK test were added for Program schedule journaling but
were not executed. Flutter, Dart, Firebase CLI and `node_modules` are not
available in this environment, so no Flutter analyze/test, Emulator, Android,
Native, staging or physical-device result exists for this local candidate.

Public PR #217 remains Draft/Open at its verified head `2aa1869`; this local
continuation has not been CI-accepted or published. An attempt to publish the
cumulative branch was rejected by automatic review because it would expose
repository contents to an unverified external GitHub destination; no alternate
publication path was attempted. Staging credentials/configuration,
device/signing/rollback acceptance, legacy intervention reconciliation, closed
graph reopening policy, and Flutter/Emulator execution remain outstanding. No
package or critical-count completion is claimed. Do not merge, deploy or
distribute an APK based on this checkpoint.

### Recovery verification — 2026-10-23

Recovered branch `codex/rule10-profile-stats-20261023`; code commit
`5b61708c28fed53fc965f6ee2d4ec3131441dd8c` is present and descends from the
public PR base `2aa1869c437a05bbd3a1ec68a4d73aaa1c75d17a`. The current branch
tip is `53568e5b7de7c671896c170b51970bd72690bb8f`, a documentation-only child
of that code commit. Local cumulative diff against the PR base touches 32 files
(2,634 insertions, 196 deletions); worktree is clean. PR #217 was re-read and
remains Draft/Open at `2aa1869`; no local changes are present in that public
head. `git fsck --connectivity-only HEAD`, the 207 Python tests, `git diff
--check`, and Node syntax checks for the Functions and schedule Emulator test
sources pass on the recovered candidate. Flutter, Dart, Firebase CLI and
`node_modules` are absent, so Flutter/Firestore/Android/Native validation could
not be run. A local Git bundle and binary patch against the exact PR base are
provided separately; they are recovery artifacts, not publication or CI
acceptance.

### Follow-up source review — 2026-10-23

Post-recovery review found and fixed regressions that source-contract tests alone
did not compile: Dashboard schedule intent decoding now validates each write
against its enclosing START/STOP transition; the expense retry catch retains its
intent in scope; the Native Dashboard fixture uses the new callback contract;
and the Mapbox cache expiry test now asserts the exact five-minute boundary
consistently with the implementation.

Manager confirmation now has a separate transactional path from create-only
expense retry. It compares the reviewed expense identity/financial fields,
writes only `confirmed` and `updatedAt`, and preserves server metadata. Firestore
rules restrict non-admin expense updates to assigned managers confirming an
existing unconfirmed expense. Create replay accepts a later confirmed state
without downgrading it. Finance/settlement and expense transaction retries
recheck the active Home session after each awaited read and before writes or
accepting a replay.

New local commits after recovery: `d64ae33` (fix schedule/expense/native
integration callsites), `97e9639` (restore manager confirmation with rule and
transaction coverage), and `38dfeb6` (session fencing and corrected cache test).
The current code head is `38dfeb6cb89e4fa9829c133aa46cafbcb719e4d2`; the full
local diff against PR base now covers 36 files. Latest local checks: 207 Python
source contracts passed, 8 Node projection tests passed, Functions and changed
Firestore test scripts pass `node --check`, `git diff --check` passes, and
constructor callsites were searched. New Flutter unit/widget tests and changed
Firestore authorization tests were added but not executed because Flutter,
Dart, Firebase CLI and `node_modules` are unavailable. Android and Native E2E
remain unrun on these local commits.

Publication was retried only against the existing `origin` branch after the
connected GitHub API confirmed repository ID `1411102708` and `push: true`.
The automatic publication review again rejected the push because it would publish
the complete local branch to the public GitHub repository and required explicit
authorization for that exact publication. No alternate write mechanism was
used. Recovery bundle and binary patch must be regenerated against this tip;
they do not count as publication, CI, or feature acceptance.
