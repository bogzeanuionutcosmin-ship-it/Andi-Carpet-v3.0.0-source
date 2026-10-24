# Android permission denial acceptance

Status: NOT RUN. Device tests must use a staging APK and synthetic identities.

| Permission / feature | Denial-path expectation |
|---|---|
| Fine location | App does not crash; clear explanation and safe feature fallback |
| Coarse location | No assumption that precise coordinates exist |
| Background location | No covert tracking; background feature unavailable until explicitly granted |
| Camera | Manual/non-camera flow remains available where applicable |
| Notifications | Core schedule and finance workflows continue without notifications |
| SMS | No silent send, hidden request or forced permission |
| Media/files | Export/import failure is recoverable without data loss |

## Verification steps
Capture permission state before action, request prompt screenshot, result, app logs and any outbound network activity in staging. Test first launch, permission denied, deny-and-don't-ask-again, permission revoked in Settings, and upgrade from an older version.

## Required release evidence
Candidate APK hash, signer fingerprint, device model/OS, exact action, expected/observed behavior, redacted logs and reviewer. Do not infer Android permission safety from manifest declarations alone.

This is a test specification, not a claim that the application already satisfies these behaviors.
