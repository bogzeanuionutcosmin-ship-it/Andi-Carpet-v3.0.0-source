part of '../main.dart';

/// Returns copied schedule items in their new order, or null when the
/// ReorderableListView indexes are invalid or represent no effective move.
List<ScheduleItem>? reorderScheduleItems(
  List<ScheduleItem> sourceItems,
  int oldIndex,
  int newIndex,
) {
  if (oldIndex < 0 ||
      oldIndex >= sourceItems.length ||
      newIndex < 0 ||
      newIndex > sourceItems.length) {
    return null;
  }

  if (newIndex > oldIndex) newIndex--;
  if (newIndex == oldIndex) return null;

  final reordered = sourceItems
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
  final moved = reordered.removeAt(oldIndex);
  reordered.insert(newIndex, moved);

  for (var index = 0; index < reordered.length; index++) {
    reordered[index].order = index + 1;
  }
  return reordered;
}
