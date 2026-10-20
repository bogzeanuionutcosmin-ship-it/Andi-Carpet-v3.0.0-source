# Android physical-device acceptance matrix

Status: NOT RUN. This is an executable manual test specification, not a result.

## Environment and prerequisites
Record candidate Git SHA, APK SHA-256, certificate SHA-256, package ID, versionCode, Android version, device model, date, tester, staging Firebase project and redacted evidence URL. Do not use production credentials or real member data.

| ID | Scenario | Expected result |
|---|---|---|
| A01 | Install approved APK on clean supported device | Installation succeeds; package ID and certificate match release manifest |
| A02 | Upgrade from prior approved production-compatible certificate | Android accepts upgrade; data and authentication behave as documented |
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

## Result template
`ID | PASS/FAIL/BLOCKED/NOT RUN | build SHA | device | evidence | deviation | issue URL`

Do not mark PASS without a real device and retained evidence. All failures remain release blockers until reviewed. Implementation belongs to the owning feature teams; this track only defines acceptance.
