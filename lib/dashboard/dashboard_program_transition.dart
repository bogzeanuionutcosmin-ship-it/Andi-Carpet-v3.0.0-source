part of '../main.dart';

/// Builds the copied schedules transitioned by Dashboard's graph-wide START.
/// Scope and result order match the existing teamId + graphId selection.
List<WorkSchedule> dashboardSchedulesForGraphStart({
  required Iterable<WorkSchedule> schedules,
  required WorkSchedule selectedSchedule,
  required String departureName,
  required double departureLatitude,
  required double departureLongitude,
  required String returnName,
  required double returnLatitude,
  required double returnLongitude,
}) {
  final sameGraph = schedules
      .where((schedule) =>
          schedule.graphId == selectedSchedule.graphId &&
          schedule.teamId == selectedSchedule.teamId)
      .map(_copyDashboardSchedule)
      .toList();

  for (final schedule in sameGraph) {
    schedule.started = true;
    schedule.paused = false;
    schedule.closed = false;
    schedule.departureName = departureName;
    schedule.departureLatitude = departureLatitude;
    schedule.departureLongitude = departureLongitude;
    schedule.returnName = returnName;
    schedule.returnLatitude = returnLatitude;
    schedule.returnLongitude = returnLongitude;
  }
  return sameGraph;
}

/// Builds the copied schedule transitioned by Dashboard's single-graph STOP.
WorkSchedule dashboardScheduleForGraphStop(WorkSchedule schedule) {
  final updated = _copyDashboardSchedule(schedule);
  updated.started = false;
  updated.paused = false;
  return updated;
}

WorkSchedule _copyDashboardSchedule(WorkSchedule schedule) => WorkSchedule(
  id: schedule.id,
  teamId: schedule.teamId,
  graphId: schedule.graphId,
  graphName: schedule.graphName,
  date: schedule.date,
  items: schedule.items
      .map((item) => ScheduleItem(
            interventionId: item.interventionId,
            locationId: item.locationId,
            locationNameSnapshot: item.locationNameSnapshot,
            addressSnapshot: item.addressSnapshot,
            typeSnapshot: item.typeSnapshot,
            categoryIdSnapshot: item.categoryIdSnapshot,
            order: item.order,
            transferred: item.transferred,
            facadePlanned: item.facadePlanned,
          ))
      .toList(),
  active: schedule.active,
  closed: schedule.closed,
  started: schedule.started,
  paused: schedule.paused,
  postponed: schedule.postponed,
  autoProposed: schedule.autoProposed,
  planAlertAt: schedule.planAlertAt,
  planAlertReason: schedule.planAlertReason,
  lastRecalculatedAt: schedule.lastRecalculatedAt,
  recalculationCount: schedule.recalculationCount,
  learningExplanation: schedule.learningExplanation,
  learningConfidence: schedule.learningConfidence,
  learningSamples: schedule.learningSamples,
  departureName: schedule.departureName,
  departureLatitude: schedule.departureLatitude,
  departureLongitude: schedule.departureLongitude,
  returnName: schedule.returnName,
  returnLatitude: schedule.returnLatitude,
  returnLongitude: schedule.returnLongitude,
  updatedAt: schedule.updatedAt,
  persisted: schedule.persisted,
  writeToken: schedule.writeToken,
);
