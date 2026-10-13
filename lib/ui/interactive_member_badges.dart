part of '../main.dart';

Widget functionKeyWidget(String key, {double size = 32, Color? color}) {
  final asset = badgeAssetChoices[key];
  if (asset != null) {
    return _InteractiveBadgeIcon(asset: asset, size: size, color: color ?? sectionAccent(badgeLabel(key)));
  }
  return Icon(iconForKey(key), size: size, color: color);
}

List<String> effectiveBadgeKeysForFunctionIds(List<FunctionDefinition> defs, Iterable<String> ids) {
  final out = <String>[];
  for (final id in ids) {
    final def = functionById(defs, id);
    if (def == null || !def.active) continue;
    for (final badge in def.badgeKeys) {
      if (!out.contains(badge)) out.add(badge);
      if (out.length >= 3) return out;
    }
  }
  return out;
}

Widget badgeStripWidget(Iterable<String> keys, {double size = 32, Color? color}) {
  final list = keys.where((e) => e.trim().isNotEmpty).take(3).toList();
  if (list.isEmpty) return const SizedBox.shrink();
  return Wrap(
    spacing: 8,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: list.map((key) => functionKeyWidget(key, size: size, color: color)).toList(),
  );
}

Widget memberBadgeStripWidget(List<FunctionDefinition> defs, Iterable<String> functionIds, {double size = 32}) {
  final widgets = <Widget>[];
  final seen = <String>{};
  for (final id in functionIds) {
    final def = functionById(defs, id);
    if (def == null || !def.active) continue;
    for (final badge in def.badgeKeys) {
      final normalized = badge == 'badge_machine' ? 'badge_worker' : badge;
      if (normalized == 'badge_coordinator' || !seen.add(normalized)) continue;
      widgets.add(functionKeyWidget(normalized, size: size, color: def.color));
      if (widgets.length >= 3) break;
    }
    if (widgets.length >= 3) break;
  }
  if (widgets.isEmpty) return const SizedBox.shrink();
  return Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: widgets);
}

