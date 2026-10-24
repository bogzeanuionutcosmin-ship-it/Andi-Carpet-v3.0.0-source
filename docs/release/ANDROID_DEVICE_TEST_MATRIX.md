# Android physical-device acceptance matrix

Status: NOT RUN. This is an executable manual test specification, not a result.

## Environment and prerequisites
Record candidate Git SHA, APK SHA-256, certificate SHA-256, package ID, versionCode, Android version, device model, date, tester, staging Firebase project and redacted evidence URL. Do not use production credentials or real member data.

| ID | Scenario | Expected result |
|---|---|---|
| A01 | Install approved APK on clean supported device | Installation succeeds; package ID and certificate match release manifest |
| A02 | Upgrade from prior approved staging build with identical package and signer | Android accepts upgrade; local state and authentication behave as documented; production lineage remains a separate gate |
| A03 | APK with mismatched certificate | Reject as untrusted / do not recommend uninstalling the existing app |
| A04 | APK hash mismatch after download | Release validation fails; artifact not distributed |
| A05 | Lower versionCode | Downgrade not silently accepted |
| A06 | Offline cold start then reconnect | No destructive state loss; queued writes reconcile safely |
| A07 | Location permission denied / approximate only | Graceful fallback; no crashes or coercion |
| A08 | Background location denied | Background feature disabled gracefully; user sees accurate status |
| A09 | Camera denied | Non-camera workflow remains functional |
| A10 | Notifications denied | Core schedule and decont remain functional |
| A11 | SMS permission denied | No hidden SMS dispatch or forced device-security changes |
| A12 | START/FINAL replay after reconnect | No duplicate intervention and accurate Centralizator/PDF |
| A13 | Overnight work and 80+ records PDF | Chronology, Romanian glyphs and page count verified |
| A14 | Link redirect to unapproved host | Publication blocked until approved |
| A15 | Revoke an obsolete download link | Old link no longer serves untrusted APK |
| A16 | Close Map while location-service or permission lookup is pending; reopen | The disposed map makes no later permission/current-position/stream request; the new map can acquire its own subscription |
| A17 | Real GPS route in foreground, screen off/background, then foreground; repeat with approximate/background permission denied | Record sampling times, accuracy and battery behavior; no duplicate stream or false operational state; document platform limitations |
| A18 | Official STOP with all visits resolved; interrupt network/force-stop before ACK, then relaunch and reconnect | Authoritative closed days and one immutable receipt; any pending journal replay uses original request/revisions and returns the same receipt; no phantom active reservation |
| A19 | START and FINAL network interruption/process death at each boundary; reconnect from two devices | Exactly one logical attempt; canonical committed times survive; active lock agrees with running state; record unresolved recovery paths as FAIL |
| A20 | Photograph a real Romanian receipt, run on-device OCR, correct amount/date/vendor, retry same document | Confirm actual ML recognition, manual correction, duplicate decision, correct selected decont, authoritative expense and PDF totals; retain redacted source image and result |
| A21 | Leave Expenses or switch account while camera/gallery/OCR is pending | No old-page dialog, crash, audit or financial write after disposal; manual entry remains usable after camera denial |
| A22 | Switch editor/outsider/editor while private route and delayed work are pending | Private routes/profile disappear on UID change; callbacks cannot write through the replaced session; record server authorization evidence |
| A23 | Add received money with invalid/non-finite/fractional-ban text, then valid comma amount; deny server save | Invalid input stays unsaved; rejected save preserves totals/history; valid amount reaches server and matching decont PDF exactly once; unknown-ACK cases remain separate ledger gates |
| A24 | Upgrade staging while a STOP intent is pending, preserving secure storage | Same package/signer upgrade retains the original intent; reconnect resolves its receipt without changing identity; do not uninstall to bypass failures |
| A25 | Production signing/provenance and rollback lineage | Requires separately authorized approved package/key/build and evidence; staging debug success cannot satisfy this gate |

## Process-loss and backend evidence

Use only the isolated staging package `com.example.andi_carpeta.staging`. Verify
package, source/APK/certificate hashes and staging project before the test. On an
authorized connected test phone, `adb shell am force-stop com.example.andi_carpeta.staging`
simulates process loss; relaunch from the launcher without clearing app data.
Do not use uninstall, clear-data, downgrade flags or production accounts.

For A18/A19/A24 retain the operation/record IDs, authenticated test UID, graph/day/
visit IDs, original revisions, receipt ID, canonical timestamps, lock state and
server snapshots before/after reconnect. A successful UI toast or cached snapshot
alone is insufficient. Record whether interruption occurred before dispatch,
during commit or after confirmed server commit. If commit timing cannot be
established, label the case inconclusive and repeat. Emulator-injected ACK loss
does not satisfy these physical process-loss cases.

## Result template
`ID | PASS/FAIL/BLOCKED/NOT RUN | build SHA | device | evidence | deviation | issue URL`

Do not mark PASS without a real device and retained evidence. All failures remain release blockers until reviewed. Implementation belongs to the owning feature teams; this track only defines acceptance.
