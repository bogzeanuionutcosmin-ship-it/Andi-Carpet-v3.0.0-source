import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;

void main() {
  group('homeUsesEconomicalLocationTracking', () {
    test('keeps economic sampling only when proximity boost is off', () {
      expect(
        app.homeUsesEconomicalLocationTracking(
          locationMode: 'economic',
          proximityBoost: false,
        ),
        isTrue,
      );
    });

    test('uses responsive sampling when the proximity boost is active', () {
      expect(
        app.homeUsesEconomicalLocationTracking(
          locationMode: 'economic',
          proximityBoost: true,
        ),
        isFalse,
      );
    });

    test('uses responsive sampling for non-economic location modes', () {
      expect(
        app.homeUsesEconomicalLocationTracking(
          locationMode: 'high',
          proximityBoost: false,
        ),
        isFalse,
      );
    });
  });
}
