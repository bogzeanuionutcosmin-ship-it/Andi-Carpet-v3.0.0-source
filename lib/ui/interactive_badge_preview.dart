import 'dart:math' as math;

import 'package:flutter/material.dart';

typedef BadgeGraphicBuilder = Widget Function(
  String asset, {
  required double size,
  Color? color,
});

class InteractiveBadgePreview extends StatefulWidget {
  final String asset;
  final double size;
  final Color? color;
  final BadgeGraphicBuilder badgeGraphic;

  const InteractiveBadgePreview({
    required this.asset,
    required this.size,
    required this.badgeGraphic,
    this.color,
    super.key,
  });

  @override
  State<InteractiveBadgePreview> createState() => _InteractiveBadgePreviewState();
}

class _InteractiveBadgePreviewState extends State<InteractiveBadgePreview> {
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
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _hidePreview,
                ),
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
                          border: Border.all(
                            color: (widget.color ?? Colors.white)
                                .withValues(alpha: .32),
                            width: 1.2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black54,
                              blurRadius: 14,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: widget.badgeGraphic(
                          widget.asset,
                          size: _previewSize,
                          color: widget.color,
                        ),
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
  Widget build(BuildContext context) => MouseRegion(
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
            child: widget.badgeGraphic(
              widget.asset,
              size: widget.size,
              color: widget.color,
            ),
          ),
        ),
      );
}
