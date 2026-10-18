# APK distribution threat model

Scope: externally distributed Android APK, update URL, signing and installation. This is design review only.

| Threat | Potential consequence | Required mitigation |
|---|---|---|
| Compromised hosting or redirect | Malicious APK served from an apparently valid link | Approved final host, signed manifest and independent artifact digest |
| Debug signing of release | No protected production signing identity | Dedicated protected release key, approved certificate fingerprint |
| APK substitution | Unexpected executable installed | Compare SHA-256 against independently approved manifest |
| Certificate rotation without plan | Upgrade rejection or incompatible install | Documented signing lineage and tested migration |
| Replay of obsolete build | Security fixes undone | Monotonic versionCode, version policy, link revocation |
| Lost or leaked signing key | Unauthorized updates or irrecoverable upgrade path | Restricted custody, rotation/recovery procedure and audit |
| Excessive Android permissions | Privacy exposure and reduced trust | Feature-by-feature necessity review and denial-path tests |
| Stale test evidence | Untested binary distributed | Tie device test evidence to exact APK hash and signing certificate |

## Trust boundaries
HTTPS secures transport to the endpoint but does not independently establish APK publisher identity. APK signing establishes binary provenance relative to a trusted certificate but does not itself establish that a given release is approved. Require both artifact verification and release authorization.

## Non-goals
No keystore generation, APK distribution, signing config edit or production rollout occurs in this PR.
