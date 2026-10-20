part of '../main.dart';

enum DashboardStartRecordAction {
  start,
  alreadyRunning,
  blockedByOtherLocation,
}

class DashboardStartRecordDecision<T> {
  const DashboardStartRecordDecision({
    required this.action,
    this.activeRecord,
    this.baseRecord,
  });

  final DashboardStartRecordAction action;
  final T? activeRecord;
  final T? baseRecord;
}

/// Preserves Dashboard's team-running guard and unfinished-record reuse order.
DashboardStartRecordDecision<T> dashboardStartRecordDecision<T>({
  required Iterable<T> records,
  required String teamId,
  required String locationId,
  required String Function(T) teamIdOf,
  required String Function(T) locationIdOf,
  required WorkAttemptStatus Function(T) statusOf,
  required WorkAttemptStatus isRunning,
  required DateTime? Function(T) finishedAtOf,
  required DateTime Function(T) eventTimeOf,
}) {
  final running = records
      .where((record) =>
          teamIdOf(record) == teamId &&
          statusOf(record) == isRunning &&
          finishedAtOf(record) == null)
      .toList();
  if (running.isNotEmpty) {
    final active = running.first;
    return DashboardStartRecordDecision<T>(
      action: locationIdOf(active) == locationId
          ? DashboardStartRecordAction.alreadyRunning
          : DashboardStartRecordAction.blockedByOtherLocation,
      activeRecord: active,
    );
  }

  final unfinished = records
      .where((record) =>
          teamIdOf(record) == teamId &&
          locationIdOf(record) == locationId &&
          finishedAtOf(record) == null)
      .toList()
    ..sort((a, b) => eventTimeOf(a).compareTo(eventTimeOf(b)));
  return DashboardStartRecordDecision<T>(
    action: DashboardStartRecordAction.start,
    baseRecord: unfinished.isEmpty ? null : unfinished.last,
  );
}
