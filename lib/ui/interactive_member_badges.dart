import 'package:flutter/material.dart';

import '../models/default_categories_functions.dart';
import '../models/location_status_and_functions.dart';
import 'icon_badge_catalog.dart';
import 'interactive_badge_preview.dart' as badge_preview;
import 'section_visual_helpers.dart';

Widget functionKeyWidget(String key, {double size = 32, Color? color}) {
  final asset = badgeAssetChoices[key];
  if (asset != null) {
    return _InteractiveBadgeIcon(
      asset: asset,
      size: size,
      color: color ?? sectionAccent(badgeLabel(key)),
    );
  }
  return Icon(iconForKey(key), size: size, color: color);
}

List<String> effectiveBadgeKeysForFunctionIds(
    List<FunctionDefinition> defs, Iterable<String> ids) {
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
  final list = keys.where((key) => key.trim().isNotEmpty).take(3).toList();
  if (list.isEmpty) return const SizedBox.shrink();
  return Wrap(
    spacing: 8,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: list.map((key) => functionKeyWidget(key, size: size, color: color)).toList(),
  );
}

Widget memberBadgeStripWidget(
    List<FunctionDefinition> defs, Iterable<String> functionIds,
    {double size = 32}) {
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
  return Wrap(
    spacing: 8,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: widgets,
  );
}

class _InteractiveBadgeIcon extends StatelessWidget {
  final String asset;
  final double size;
  final Color? color;

  const _InteractiveBadgeIcon({required this.asset, required this.size, this.color});

  @override
  Widget build(BuildContext context) => badge_preview.InteractiveBadgePreview(
        asset: asset,
        size: size,
        color: color,
        badgeGraphic: badgeGraphic,
      );
}
