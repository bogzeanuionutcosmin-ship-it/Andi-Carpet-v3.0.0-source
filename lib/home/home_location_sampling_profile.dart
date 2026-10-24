part of '../main.dart';

/// Preserves Home's existing economical GPS sampling decision.
bool homeUsesEconomicalLocationTracking({
  required String locationMode,
  required bool proximityBoost,
}) =>
    locationMode == 'economic' && !proximityBoost;
