# Post-XIII — Android/iOS evidence requirements

Status: TEST PLAN ONLY. `production_ready=false`.

## Existing XIII implementation
`createNativeHistoryXiiiJournal()` deliberately throws
`native_v2_platform_release_blocked`. Android attempts to load a separately
packaged `libandi_finance_sqlite3.so`; iOS resolves Apple's SQLite library.
Linux/Windows/macOS AOT subprocess tests do not prove mobile app durability.
No mobile activation or native dependency is authorized by this plan.

## Device matrix for a future isolated test harness
| Gate | Android | iOS | Required evidence |
|---|---|---|---|
| Native SQLite | Packaged ABI and provenance, engine version | Link and app entitlement review | Actual device loader and runtime readback |
| App-private storage | Files directory, symlink/backup policy | Container/Data Protection class | Readback after restart, no cloud-sync assumption |
| Keys | Keystore-backed custody and loss semantics | Keychain class, locked-device semantics | Hardware/OS-backed lifecycle and rotation |
| Interruption | Force-stop, process death, storage-full | Background termination, locked device, storage-full | Same pending ID/digest after restart; no automatic resend |
| Concurrency | Independent OS processes, SQLite lock retention | Independent supported process contexts | Actual process contention, not two async tasks |
| Backup | Restore/reinstall/OS backup exclusion | iCloud restore/device transfer policy | Explicit fail-closed rollback detection |
| Crash durability | Power cut on real test device | Power cut on real test device | Distinguish process kill from power-loss guarantee |

Every row requires exact OS/device model, build hash, SQLite version,
filesystem, test command, failure injection, observed pending evidence,
and reviewer sign-off. Unmeasured rows remain BLOCKED. Never infer device
results from macOS runner or Android compile-only success.
