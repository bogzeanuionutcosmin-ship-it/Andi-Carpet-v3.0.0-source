/// Pure sharing cadence and eligibility rules for live-location updates.
///
/// Permission checks, timers, position acquisition, persistence, and lifecycle
/// remain with the Home page.
class LiveLocationSharePolicy {
  final String effectiveMode;
  final bool clearWhenOutsideWork;
  final Duration minimumInterval;
  final bool useHighAccuracy;
  final double movementThresholdMeters;
  final bool heartbeatDue;

  const LiveLocationSharePolicy({
    required this.effectiveMode,
    required this.clearWhenOutsideWork,
    required this.minimumInterval,
    required this.useHighAccuracy,
    required this.movementThresholdMeters,
    required this.heartbeatDue,
  });
}

LiveLocationSharePolicy liveLocationSharePolicy({
  required String personalMode,
  required bool inWork,
  required bool nativeLocationProximityBoost,
  required int preferredIntervalMinutes,
  required DateTime now,
  required DateTime? lastSharedAt,
}) {
  final effectiveMode =
      inWork && personalMode == 'offline' ? 'economic' : personalMode;
  final clearWhenOutsideWork = !inWork && effectiveMode == 'offline';
  final configured = preferredIntervalMinutes.clamp(1, 60).toInt();
  final minimumInterval = nativeLocationProximityBoost && inWork
      ? const Duration(seconds: 20)
      : effectiveMode == 'live'
          ? const Duration(minutes: 1)
          : Duration(
              minutes: inWork ? configured.clamp(1, 3).toInt() : configured,
            );

  return LiveLocationSharePolicy(
    effectiveMode: effectiveMode,
    clearWhenOutsideWork: clearWhenOutsideWork,
    minimumInterval: minimumInterval,
    useHighAccuracy: effectiveMode == 'live' || inWork,
    movementThresholdMeters:
        effectiveMode == 'live' ? 10 : (inWork ? 25 : 150),
    heartbeatDue: lastSharedAt == null ||
        inWork ||
        (effectiveMode == 'live' &&
            now.difference(lastSharedAt) >= const Duration(minutes: 5)),
  );
}
