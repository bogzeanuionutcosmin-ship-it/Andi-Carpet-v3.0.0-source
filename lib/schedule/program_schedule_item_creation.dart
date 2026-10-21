part of '../main.dart';

/// Maps selected locations to the schedule snapshots persisted by Program.
///
/// Selection filtering remains with the page; this projection preserves the
/// selected order and the existing facade-planned checkbox values.
List<ScheduleItem> createProgramScheduleItems({
  required Iterable<Location> locations,
  required int firstOrder,
  required Set<String> facadePlannedLocationIds,
}) {
  var order = firstOrder;
  return locations
      .map(
        (location) => ScheduleItem(
          interventionId: newInterventionId(),
          locationId: location.id,
          locationNameSnapshot: location.name,
          addressSnapshot: location.address,
          typeSnapshot: location.type,
          categoryIdSnapshot: location.categoryId,
          order: order++,
          facadePlanned:
              facadePlannedLocationIds.contains(location.id),
        ),
      )
      .toList();
}
