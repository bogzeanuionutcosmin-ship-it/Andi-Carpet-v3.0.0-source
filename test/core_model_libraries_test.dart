import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/models/app_data_models.dart';
import 'package:andi_carpeta/models/app_enums_permissions.dart';
import 'package:andi_carpeta/utils/graph_names.dart';
import 'package:andi_carpeta/utils/operational_dates.dart';
import 'package:andi_carpeta/learning/duration_estimates.dart';
import 'package:andi_carpeta/main.dart' as legacy;

CentralizerRecord completedRecord(int day, int minutes, {bool kept = true}) {
  final start = DateTime(2026, 10, day, 1);
  return CentralizerRecord(
    id: 'record-$day', teamId: 'team', locationId: 'location',
    type: LocationType.magic, locationNameSnapshot: 'Location', addressSnapshot: 'Address',
    startedAt: start, finishedAt: start.add(Duration(minutes: minutes)),
    status: WorkAttemptStatus.completed, keptForLearning: kept,
  );
}

void main() {
  test('core types and helpers keep the main import compatibility', () {
    final AppUser user = legacy.AppUser(id: 'u', name: 'User', role: UserRole.member);
    final legacy.AppSettings settings = AppSettings();
    final legacy.LearnedDurationEstimate estimate = LearnedDurationEstimate(
      duration: const Duration(minutes: 10), explanation: 'Known', confidence: .5,
      samples: 3, basis: 'Known',
    );
    expect(user.function, UserFunction.worker);
    expect(settings.learning['duration']!.enabled, isTrue);
    expect(estimate.samples, 3);
    expect(legacy.graphDefaultName(DateTime(2026, 1, 1)), graphDefaultName(DateTime(2026, 1, 1)));
    expect(legacy.formatDate(DateTime(2026, 10, 5)), formatDate(DateTime(2026, 10, 5)));
  });

  test('schedule and location constructor defaults and collection identity are preserved', () {
    final items = <ScheduleItem>[];
    final schedule = WorkSchedule(id: 's', teamId: 'team', date: DateTime(2026, 1, 2), items: items);
    expect(schedule.graphId, 's');
    expect(schedule.graphName, 'Grafic 01/2026');
    expect(schedule.items, same(items));
    expect(schedule.started, isFalse);
    expect(schedule.active, isTrue);
    final location = Location(id: 'l', name: 'Room', address: 'Address', type: LocationType.other);
    expect(location.categoryId, 'cazari');
    expect(location.selectableForProgram, isTrue);
    location.status = LocationStatus.temporarilyClosed;
    expect(location.selectableForProgram, isFalse);
    final first = AppSettings();
    final second = AppSettings();
    first.learning['duration']!.enabled = false;
    first.customBackgrounds['custom'] = {'name': 'Custom'};
    expect(second.learning['duration']!.enabled, isTrue);
    expect(second.customBackgrounds, isEmpty);
  });

  test('operational date changes exactly at 23:30 across month and year boundaries', () {
    expect(operationalWorkDate(DateTime(2026, 12, 31, 23, 29, 59)), DateTime(2026, 12, 31));
    expect(operationalWorkDate(DateTime(2026, 12, 31, 23, 30)), DateTime(2027, 1, 1));
    expect(operationalWorkDate(DateTime(2024, 2, 29, 23, 30)), DateTime(2024, 3, 1));
    expect(operationalWorkDate(DateTime(2026, 10, 13, 0)), DateTime(2026, 10, 13));
  });

  test('work window is inclusive and retains the previous night', () {
    final day = DateTime(2027, 1, 1);
    final start = DateTime(2026, 12, 31, 23, 30);
    final end = DateTime(2027, 1, 1, 9, 30);
    expect(workWindowStart(day), start);
    expect(workWindowEnd(day), end);
    expect(isInsideWorkWindow(start, day), isTrue);
    expect(isInsideWorkWindow(end, day), isTrue);
    expect(isInsideWorkWindow(start.subtract(const Duration(microseconds: 1)), day), isFalse);
    expect(isInsideWorkWindow(end.add(const Duration(microseconds: 1)), day), isFalse);
  });

  test('record dates retain timestamp precedence and the three-hour grace', () {
    final record = completedRecord(13, 30);
    final day = DateTime(2026, 10, 13);
    record.startedAt = DateTime(2026, 10, 13, 12, 30);
    record.finishedAt = DateTime(2026, 10, 14, 1);
    expect(recordBelongsToWorkDate(record, day), isTrue);
    expect(recordEventTime(record), record.finishedAt);
    record.startedAt = record.startedAt!.add(const Duration(microseconds: 1));
    expect(recordBelongsToWorkDate(record, day), isFalse);
    record.startedAt = null;
    record.finishedAt = null;
    expect(recordBelongsToWorkDate(record, day), isFalse);
    expect(recordEventTime(record), DateTime(1900));
  });

  test('display formatting retains nulls, Romanian dates and absolute durations', () {
    expect(formatDate(DateTime(2026, 10, 5)), 'luni-5-octombrie-2026');
    expect(formatMonth(DateTime(2026, 1, 1)), 'ianuarie-2026');
    expect(timeText(null), '--:--');
    expect(timeText(DateTime(2026, 10, 5, 1, 2)), '01:02');
    expect(durationText(null), '--');
    expect(durationText(const Duration(minutes: -65)), '1h 05 min');
  });

  test('duration learning needs three valid prior samples and honors disabled learning', () {
    final target = DateTime(2026, 10, 31);
    final settings = AppSettings();
    final history = [completedRecord(1, 20), completedRecord(2, 30), completedRecord(3, 40)];
    expect(learnedDurationEstimate(history.take(2).toList(), 'location', settings, targetDate: target), isNull);
    final extra = [completedRecord(4, 0), completedRecord(5, 1441), completedRecord(6, 999, kept: false)];
    final estimate = learnedDurationEstimate([...history, ...extra], 'location', settings, targetDate: target)!;
    expect(estimate.duration, const Duration(minutes: 30));
    expect(estimate.samples, 3);
    expect(estimate.basis, 'aceeași lună');
    expect(learnedAverageDuration(history, 'location', settings, targetDate: target), estimate.duration);
    settings.learning['duration']!.enabled = false;
    expect(learnedDurationEstimate(history, 'location', settings, targetDate: target), isNull);
  });

  test('automatic duration mode retains its trimming and manual mode keeps all samples', () {
    final settings = AppSettings();
    final history = [completedRecord(1, 10), completedRecord(2, 20), completedRecord(3, 30),
      completedRecord(4, 40), completedRecord(5, 90)];
    final target = DateTime(2026, 10, 31);
    final manual = learnedDurationEstimate(history, 'location', settings, targetDate: target)!;
    expect(manual.duration, const Duration(minutes: 38));
    expect(manual.samples, 5);
    settings.learning['duration']!.mode = LearningMode.automatic;
    final automatic = learnedDurationEstimate(history, 'location', settings, targetDate: target)!;
    expect(automatic.duration, const Duration(minutes: 30));
    expect(automatic.samples, 3);
    expect(automatic.confidence, inInclusiveRange(0, 1));
  });
}
