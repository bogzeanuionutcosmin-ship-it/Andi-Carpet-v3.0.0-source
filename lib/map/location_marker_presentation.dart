import 'package:flutter/material.dart';

/// Renders a map marker from values resolved by the map page.
///
/// Status, category, and work-state decisions remain in the caller.
class LocationMapMarker extends StatelessWidget {
  final Color color;
  final IconData icon;
  final double opacity;
  final Color? workBadgeColor;

  const LocationMapMarker({
    super.key,
    required this.color,
    required this.icon,
    required this.opacity,
    required this.workBadgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: opacity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(blurRadius: 5, color: Colors.black26),
              ],
            ),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(icon, color: Colors.white),
            ),
          ),
        ),
        if (workBadgeColor != null)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                color: workBadgeColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
