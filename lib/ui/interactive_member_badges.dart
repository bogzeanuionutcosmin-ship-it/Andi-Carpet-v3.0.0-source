part of '../main.dart';

class _InteractiveBadgeIcon extends StatefulWidget {
  final String asset;
  final double size;
  final Color? color;
  const _InteractiveBadgeIcon({required this.asset, required this.size, this.color});

  @override
  State<_InteractiveBadgeIcon> createState() => _InteractiveBadgeIconState();
}

class _InteractiveBadgeIconState extends State<_InteractiveBadgeIcon> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;
  bool _pinned = false;

  double get _previewSize => math.max(74, widget.size * 2.15);

  void _showPreview({required bool pinned}) {
    _pinned = pinned;
    if (_entry == null) {
      _entry = OverlayEntry(builder: (context) {
        return Positioned.fill(
          child: Stack(
            children: [
              if (_pinned)
                GestureDetector(behavior: HitTestBehavior.translucent, onTap: _hidePreview),
              CompositedTransformFollower(
                link: _link,
                showWhenUnlinked: false,
                targetAnchor: Alignment.topCenter,
                followerAnchor: Alignment.bottomCenter,
                offset: const Offset(0, -10),
                child: Material(
                  color: Colors.transparent,
                  child: IgnorePointer(
                    ignoring: !_pinned,
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 120),
                      scale: 1,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .84),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: (widget.color ?? Colors.white).withValues(alpha: .32), width: 1.2),
                          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 14, spreadRadius: 1)],
                        ),
                        child: _badgeGraphic(widget.asset, size: _previewSize, color: widget.color),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      });
      Overlay.of(context, rootOverlay: true).insert(_entry!);
    } else {
      _entry!.markNeedsBuild();
    }
  }

  void _hidePreview() {
    _pinned = false;
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    _hidePreview();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _showPreview(pinned: false),
      onExit: (_) {
        if (!_pinned) _hidePreview();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_entry == null) {
            _showPreview(pinned: true);
          } else {
            _hidePreview();
          }
        },
        child: CompositedTransformTarget(
          link: _link,
          child: _badgeGraphic(widget.asset, size: widget.size, color: widget.color),
        ),
      ),
    );
  }
}

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

