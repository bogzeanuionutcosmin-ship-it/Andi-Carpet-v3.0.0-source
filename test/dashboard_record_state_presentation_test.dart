import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/dashboard/record_state_presentation.dart';
import '../lib/models/app_enums_permissions.dart';

void main() {
  group('Dashboard record state presentation', () {
    test('maps null and every status to the existing color and icon', () {
      final cases = <({WorkAttemptStatus? status, Color color, IconData icon})>[
        (
          status: null,
          color: Colors.blueGrey,
          icon: Icons.radio_button_unchecked,
        ),
        (
          status: WorkAttemptStatus.completed,
          color: Colors.green,
          icon: Icons.check,
        ),
        (
          status: WorkAttemptStatus.running,
          color: Colors.blue,
          icon: Icons.cleaning_services,
        ),
        (
          status: WorkAttemptStatus.waitingAccess,
          color: Colors.orange,
          icon: Icons.hourglass_top,
        ),
        (
          status: WorkAttemptStatus.refused,
          color: Colors.red,
          icon: Icons.block,
        ),
        (
          status: WorkAttemptStatus.notCompleted,
          color: Colors.deepOrange,
          icon: Icons.warning_amber_rounded,
        ),
      ];

      for (final item in cases) {
        expect(
          dashboardRecordStateColor(item.status),
          item.color,
          reason: 'color for ${item.status}',
        );
        expect(
          dashboardRecordStateIcon(item.status),
          item.icon,
          reason: 'icon for ${item.status}',
        );
      }
    });

    test('preserves exact text for null and each status', () {
      final start = DateTime(2026, 10, 20, 8, 5);
      final finish = DateTime(2026, 10, 20, 10, 12);

      final cases = <({WorkAttemptStatus? status, String expected})>[
        (status: null, expected: 'Neîncepută'),
        (
          status: WorkAttemptStatus.completed,
          expected: 'Finalizată · 1h 30 min · 08:05–10:12',
        ),
        (
          status: WorkAttemptStatus.running,
          expected: 'Pe sală din 08:05 · așteptare 0h 01 min',
        ),
        (
          status: WorkAttemptStatus.waitingAccess,
          expected: 'Așteptare acces din 08:05',
        ),
        (status: WorkAttemptStatus.refused, expected: 'Refuzată · motiv'),
        (
          status: WorkAttemptStatus.notCompleted,
          expected: 'Nerealizată · motiv',
        ),
      ];

      for (final item in cases) {
        expect(
          dashboardRecordStateText(
            status: item.status,
            refusalReason: 'motiv',
            duration: const Duration(minutes: 90),
            startedAt: start,
            finishedAt: finish,
            waitingStartedAt: start,
            waitingDuration: const Duration(minutes: 1),
          ),
          item.expected,
          reason: 'text for ${item.status}',
        );
      }
    });

    test('preserves null and boundary values in the status text', () {
      expect(
        dashboardRecordStateText(
          status: WorkAttemptStatus.completed,
        ),
        'Finalizată · -- · --:--–--:--',
      );
      expect(
        dashboardRecordStateText(
          status: WorkAttemptStatus.running,
          waitingDuration: Duration.zero,
        ),
        'Pe sală din --:-- · așteptare 0h 00 min',
      );
      expect(
        dashboardRecordStateText(
          status: WorkAttemptStatus.running,
        ),
        'Pe sală din --:--',
      );
      expect(
        dashboardRecordStateText(
          status: WorkAttemptStatus.waitingAccess,
        ),
        'Așteptare acces din --:--',
      );
    });

    test('omits blank reasons and preserves the raw nonblank reason', () {
      for (final reason in <String?>[null, '', '   ']) {
        expect(
          dashboardRecordStateText(
            status: WorkAttemptStatus.refused,
            refusalReason: reason,
          ),
          'Refuzată',
        );
        expect(
          dashboardRecordStateText(
            status: WorkAttemptStatus.notCompleted,
            refusalReason: reason,
          ),
          'Nerealizată',
        );
      }

      expect(
        dashboardRecordStateText(
          status: WorkAttemptStatus.refused,
          refusalReason: '  acces refuzat  ',
        ),
        'Refuzată ·   acces refuzat  ',
      );
      expect(
        dashboardRecordStateText(
          status: WorkAttemptStatus.notCompleted,
          refusalReason: '  locația închisă  ',
        ),
        'Nerealizată ·   locația închisă  ',
      );
    });
  });
}
