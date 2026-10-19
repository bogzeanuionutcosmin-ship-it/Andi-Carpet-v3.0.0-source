import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/centralizer/manual_execution_defaults.dart';

void main() {
  test('midnight defaults keep the selected date on the start day', () {
    final defaults = createManualExecutionDefaults(DateTime(2026, 10, 19, 0, 15));

    expect(defaults.date, DateTime(2026, 10, 18));
    expect(defaults.startTime, '23:15');
    expect(defaults.finishTime, '00:15');
  });

  test('ordinary defaults keep the selected date and one-hour interval', () {
    final defaults = createManualExecutionDefaults(DateTime(2026, 10, 19, 15, 30));

    expect(defaults.date, DateTime(2026, 10, 19));
    expect(defaults.startTime, '14:30');
    expect(defaults.finishTime, '15:30');
  });
}
