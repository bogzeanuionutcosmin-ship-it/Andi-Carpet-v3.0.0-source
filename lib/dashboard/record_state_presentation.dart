import 'package:flutter/material.dart';

import '../models/app_enums_permissions.dart';
import '../utils/date_formatters.dart';

/// Pure Dashboard presentation mapping for a work attempt.
///
/// Callers adapt their domain record into these values so this library does not
/// depend on the main application's part-only CentralizerRecord model.
String dashboardRecordStateText({
  required WorkAttemptStatus? status,
  String? refusalReason,
  Duration? duration,
  DateTime? startedAt,
  DateTime? finishedAt,
  DateTime? waitingStartedAt,
  Duration? waitingDuration,
}) {
  if (status == null) return 'Neîncepută';
  switch (status) {
    case WorkAttemptStatus.completed:
      return 'Finalizată · ${durationText(duration)} · ${timeText(startedAt)}–${timeText(finishedAt)}';
    case WorkAttemptStatus.running:
      return 'Pe sală din ${timeText(startedAt)}${waitingDuration == null ? '' : ' · așteptare ${durationText(waitingDuration)}'}';
    case WorkAttemptStatus.waitingAccess:
      return 'Așteptare acces din ${timeText(waitingStartedAt)}';
    case WorkAttemptStatus.refused:
      return 'Refuzată${(refusalReason ?? '').trim().isEmpty ? '' : ' · $refusalReason'}';
    case WorkAttemptStatus.notCompleted:
      return 'Nerealizată${(refusalReason ?? '').trim().isEmpty ? '' : ' · $refusalReason'}';
  }
}

Color dashboardRecordStateColor(WorkAttemptStatus? status) {
  if (status == null) return Colors.blueGrey;
  return switch (status) {
    WorkAttemptStatus.completed => Colors.green,
    WorkAttemptStatus.running => Colors.blue,
    WorkAttemptStatus.waitingAccess => Colors.orange,
    WorkAttemptStatus.refused => Colors.red,
    WorkAttemptStatus.notCompleted => Colors.deepOrange,
  };
}

IconData dashboardRecordStateIcon(WorkAttemptStatus? status) {
  if (status == null) return Icons.radio_button_unchecked;
  return switch (status) {
    WorkAttemptStatus.completed => Icons.check,
    WorkAttemptStatus.running => Icons.cleaning_services,
    WorkAttemptStatus.waitingAccess => Icons.hourglass_top,
    WorkAttemptStatus.refused => Icons.block,
    WorkAttemptStatus.notCompleted => Icons.warning_amber_rounded,
  };
}
