# Standalone enum library compatibility

The eleven app enums and their deterministic label/color/icon extensions now live in an independently importable `lib/models/app_enums_permissions.dart`. Only the `part of` directive changed to a Material import; declarations and bodies retain their exact source text. `main.dart` imports and re-exports the library, retaining the existing API for parts and callers importing main.

The separate permission/status label part remains unchanged. No permissions, roles, authorization checks, serialized enum names/indices, Firestore rules or product behavior are changed.

Four Flutter characterization tests cover all enum names/indices, all 39 permission labels, role/function labels and icons, location labels/colors, public enum/extension exports and dependent label helpers. Python ownership checks ensure main no longer owns the enum part.

Local validation: 107 Python tests passed; byte-for-byte declaration comparison passed. Flutter execution and builds require CI on the final commit; they were not executed locally. Review and combined regression validation remain required. No merge, deployment, production operations or automatic release are authorized.
