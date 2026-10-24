part of '../main.dart';

/// Selects only schedules eligible for the existing Home operational scan.
/// Keeps the caller's same-day rule and preserves the input order.
List<T> homeActiveSchedulesForWorkDate<T>({
  required Iterable<T> schedules,
  required String teamId,
  required DateTime workDate,
  required String Function(T) teamIdOf,
  required DateTime Function(T) dateOf,
  required bool Function(T) isStarted,
  required bool Function(T) isClosed,
  required bool Function(T) isPaused,
  required bool Function(T) isPostponed,
  required bool Function(DateTime, DateTime) sameDay,
}) {
  return schedules
      .where((schedule) =>
          teamIdOf(schedule) == teamId &&
          sameDay(dateOf(schedule), workDate) &&
          isStarted(schedule) &&
          !isClosed(schedule) &&
          !isPaused(schedule) &&
          !isPostponed(schedule))
      .toList();
}
