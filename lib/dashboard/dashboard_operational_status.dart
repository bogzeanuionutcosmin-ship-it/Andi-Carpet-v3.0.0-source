part of '../main.dart';

enum DashboardOperationalStatus {
  running,
  waitingAccess,
  paused,
  postponed,
  duringWorkWindow,
  outsideWorkWindow,
}

/// Selects the existing team status by its established priority order.
DashboardOperationalStatus dashboardTeamOperationalStatus({
  required bool hasRunningRecord,
  required bool waitingForAccess,
  required bool schedulePaused,
  required bool schedulePostponed,
  required bool scheduleStarted,
  required bool insideWorkWindow,
}) {
  if (hasRunningRecord) return DashboardOperationalStatus.running;
  if (waitingForAccess) return DashboardOperationalStatus.waitingAccess;
  if (schedulePaused) return DashboardOperationalStatus.paused;
  if (schedulePostponed) return DashboardOperationalStatus.postponed;
  if (scheduleStarted && insideWorkWindow) {
    return DashboardOperationalStatus.duringWorkWindow;
  }
  return DashboardOperationalStatus.outsideWorkWindow;
}
