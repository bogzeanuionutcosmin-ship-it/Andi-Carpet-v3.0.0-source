import 'package:flutter_test/flutter_test.dart';

import '../lib/map/map_work_badge_state.dart';

enum _Status { waitingAccess, running, completed, refused, notCompleted }

class _Item {
  final String locationId;
  final int order;

  const _Item(this.locationId, this.order);
}

class _Schedule {
  final String teamId;
  final List<_Item> items;

  const _Schedule(this.teamId, this.items);
}

class _Record {
  final String locationId;
  final String teamId;
  final _Status status;
  final bool completed;

  const _Record(this.locationId, this.teamId, this.status, {this.completed = false});
}

MapWorkBadgeState? _state(
  List<_Schedule> schedules,
  String target,
  List<_Record> records,
) =>
    mapWorkBadgeState(
      schedules,
      targetLocationId: target,
      itemsOf: (schedule) => schedule.items,
      orderOf: (item) => item.order,
      teamIdOf: (schedule) => schedule.teamId,
      locationIdOf: (item) => item.locationId,
      recordsFor: (locationId, teamId) => records.where((record) =>
          record.locationId == locationId && record.teamId == teamId),
      completedOf: (record) => record.completed,
      statusOf: (record) => record.status,
      runningStatus: _Status.running,
      waitingStatus: _Status.waitingAccess,
      refusedStatus: _Status.refused,
      notCompletedStatus: _Status.notCompleted,
    );

void main() {
  test('returns no state when the location is not assigned', () {
    expect(_state([const _Schedule('team-a', [_Item('other', 1)])], 'target', []),
        isNull);
    expect(_state([], 'target', []), isNull);
  });

  test('completed requires every assignment for the location to be done', () {
    final schedules = [
      const _Schedule('team-a', [_Item('target', 1)]),
      const _Schedule('team-b', [_Item('target', 1)]),
    ];

    expect(
      _state(schedules, 'target', [
        const _Record('target', 'team-a', _Status.completed, completed: true),
        const _Record('target', 'team-b', _Status.completed, completed: true),
      ]),
      MapWorkBadgeState.completed,
    );
    expect(
      _state(schedules, 'target', [
        const _Record('target', 'team-a', _Status.completed, completed: true),
      ]),
      MapWorkBadgeState.nextOrRunning,
    );
  });

  test('a running/waiting target is orange even with earlier assignments', () {
    final schedules = [
      const _Schedule('team-a', [_Item('target', 1)]),
    ];

    expect(
      _state(schedules, 'target', [
        const _Record('target', 'team-a', _Status.running),
      ]),
      MapWorkBadgeState.nextOrRunning,
    );
    expect(
      _state(schedules, 'target', [
        const _Record('target', 'team-a', _Status.waitingAccess),
      ]),
      MapWorkBadgeState.nextOrRunning,
    );
  });

  test('the first ordered non-cancelled item is orange and cancelled items skip', () {
    final schedules = [
      const _Schedule('team-a', [
        _Item('target', 3),
        _Item('cancelled', 1),
        _Item('earlier', 2),
      ]),
    ];

    expect(
      _state(schedules, 'target', [
        const _Record('cancelled', 'team-a', _Status.refused),
        const _Record('earlier', 'team-a', _Status.running),
      ]),
      MapWorkBadgeState.notCompleted,
    );
    expect(
      _state(schedules, 'earlier', [
        const _Record('cancelled', 'team-a', _Status.refused),
      ]),
      MapWorkBadgeState.nextOrRunning,
    );
  });

  test('an assigned target without done, running, or next status is red', () {
    expect(
      _state(
        [const _Schedule('team-a', [_Item('target', 1)])],
        'target',
        const [_Record('target', 'team-a', _Status.notCompleted)],
      ),
      MapWorkBadgeState.notCompleted,
    );
  });
}
