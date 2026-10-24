part of '../main.dart';

enum HomeLocationProximityAction { boost, relax }

/// Preserves the existing 3 km/5 km hysteresis for native location precision.
HomeLocationProximityAction? homeLocationProximityAction({
  required bool isBoosted,
  required double nearestMeters,
}) {
  final shouldBoost = nearestMeters <= 3000;
  final shouldRelax = nearestMeters > 5000 || nearestMeters == double.infinity;
  if (shouldBoost && !isBoosted) return HomeLocationProximityAction.boost;
  if (shouldRelax && isBoosted) return HomeLocationProximityAction.relax;
  return null;
}
