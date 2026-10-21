part of '../main.dart';

/// Removes the matching schedule item and returns an isolated, renumbered list.
///
/// The match intentionally uses both location ID and the item's current order,
/// matching ProgramPage's existing removal behavior.
List<ScheduleItem> removeProgramScheduleItem(
  Iterable<ScheduleItem> sourceItems, {
  required String locationId,
  required int order,
}) {
  final remaining = sourceItems
      .where((item) => item.locationId != locationId || item.order != order)
      .map(
        (item) => ScheduleItem(
          interventionId: item.interventionId,
          locationId: item.locationId,
          locationNameSnapshot: item.locationNameSnapshot,
          addressSnapshot: item.addressSnapshot,
          typeSnapshot: item.typeSnapshot,
          categoryIdSnapshot: item.categoryIdSnapshot,
          order: item.order,
          transferred: item.transferred,
          facadePlanned: item.facadePlanned,
        ),
      )
      .toList();

  for (var index = 0; index < remaining.length; index++) {
    remaining[index].order = index + 1;
  }
  return remaining;
}
