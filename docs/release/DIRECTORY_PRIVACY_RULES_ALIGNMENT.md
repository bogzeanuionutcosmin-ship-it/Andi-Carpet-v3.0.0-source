# Directory privacy: alignment with approved main rules (2026-10-18)

Source of authority: `main:REGULI_DEZVOLTARE_SI_FUNCTIONARE_ChatGPT.md`, sections 43–47. This document records the existing decisions; it does not approve or implement a new feature.

## Approved contract

- Ordinary profile fields, including telephone, contact email, photo, social links and approved performance summaries, default to visible **to authenticated eligible colleagues**. Missing visibility preference means visible.
- Each member may hide **each field individually** in their own profile; explicit `false` must survive updates. Owner and authorized admin retain access through their authorized private read paths.
- Hidden profile / ineligible member restrictions take precedence over any field's default.
- The member-readable `memberDirectory` projection must **physically omit** opted-out values. UI-only hiding is insufficient. Test direct API reads, offline cache and delayed/out-of-order trigger events.
- Per-diem amounts and derived financial details must **never** appear in member-readable directory data; they are owner/admin-only without a public toggle.
- The approved UI uses an eye control beside each ordinary field in Edit Profile, not a mandatory separate privacy settings page.

## Read-only implementation finding

At the time of this review, `functions/member_directory_projection.js` copies each allowlisted field directly from a source profile and excludes hidden/admin profiles. Its allowlist includes `phone` and `photoBase64`, but not `email`, per-diem fields, visibility preferences, or a server-side per-field opt-out filter. This is a **gap against the approved future contract**, not evidence that publishing phone/photo by default violates policy.

The existing offline `audit_directory_privacy.py` reports sensitive field **review markers**, not a privacy breach or an implementation of opt-out. It never authorizes release.

## Required implementation gate (after modularization and approved contracts)

1. Specify stable per-field preference IDs and backward-compatible missing=true / explicit false behavior.
2. Implement authorized server-side projection that omits hidden values, with idempotent trigger updates and stale-event protection.
3. Cover four phone/email preference combinations, owner/admin/colleague direct reads, hidden profiles, old accounts, revocation, cache and delayed events.
4. Preserve per-diem exclusion in all public projections, exports and caches.
5. Validate in an isolated Firebase emulator and staging; require explicit authorization for production rules, migration and deploy.

No production operation or functional change is authorized by this document.
