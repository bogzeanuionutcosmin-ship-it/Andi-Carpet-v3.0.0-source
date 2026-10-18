# Pure section asset catalog

`lib/ui/section_asset_catalog.dart` owns the existing category brand asset map and ordered section-label routing. Both declarations were moved byte-for-byte from `icon_badge_catalog.dart`; main imports and re-exports them. There are no Flutter, Firebase or global state dependencies.

`sectionAssetWidget` and `categoryBrandWidget` remain unchanged in the UI part. Their callers in HomePage, Dashboard, Centralizer, Map and admin actions retain the same signatures and behavior. Badge metadata from PR #107/#117 is a separate extraction; retain both import/export and ownership contracts when integrating.

Four characterization tests cover 22 supported labels (including accents, uppercase and whitespace), competing substring precedence, legacy null fallbacks, all four category asset mappings, immutable const semantics and the public main API. This preserves exact-only aliases such as Mesaje/Acasă and existing matching order rather than broadening recognition.

Local: 107 Python tests passed, moved-block byte equivalence verified and git diff-check clean. Flutter tests/build require CI on the final commit; no local Flutter runtime result is claimed. No assets, application behavior, permissions, production data or deployment configuration changed.
