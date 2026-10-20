import 'package:flutter_test/flutter_test.dart';

import 'package:andi_carpeta/utils/work_date_policy.dart';

void main() {
  test('operational date rolls over at the existing 23:30 boundary', () {
    expect(operationalWorkDate(DateTime(2026, 10, 15, 23, 29)),
        DateTime(2026, 10, 15));
    expect(operationalWorkDate(DateTime(2026, 10, 15, 23, 30)),
        DateTime(2026, 10, 16));
    expect(operationalWorkDate(DateTime(2026, 10, 16, 0, 20)),
        DateTime(2026, 10, 16));
  });

  test('standard work window keeps inclusive start and end boundaries', () {
    final workDate = DateTime(2026, 10, 16);
    final start = workWindowStart(workDate);
    final end = workWindowEnd(workDate);

    expect(start, DateTime(2026, 10, 15, 23, 30));
    expect(end, DateTime(2026, 10, 16, 9, 30));
    expect(isInsideWorkWindow(start, workDate), isTrue);
    expect(isInsideWorkWindow(end, workDate), isTrue);
    expect(isInsideWorkWindow(start.subtract(const Duration(microseconds: 1)), workDate), isFalse);
    expect(isInsideWorkWindow(end.add(const Duration(microseconds: 1)), workDate), isFalse);
  });
}
