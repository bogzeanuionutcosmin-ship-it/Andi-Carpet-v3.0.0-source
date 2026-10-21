import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;

void main() {
  group('nearestEligibleHomeArrivalCandidate', () {
    test('selects the nearest candidate inside the accuracy-adjusted radius', () {
      final result = app.nearestEligibleHomeArrivalCandidate<String>(
        candidates: const [
          app.HomeArrivalCandidate(value: 'farther', meters: 200),
          app.HomeArrivalCandidate(value: 'nearest', meters: 120),
        ],
        accuracyMeters: 20,
      );

      expect(result?.value, 'nearest');
      expect(result?.meters, 120);
    });

    test('includes an arrival exactly on the 250 meter certainty boundary', () {
      final result = app.nearestEligibleHomeArrivalCandidate<String>(
        candidates: const [app.HomeArrivalCandidate(value: 'edge', meters: 240)],
        accuracyMeters: 10,
      );

      expect(result?.value, 'edge');
    });

    test('rejects candidates when GPS uncertainty puts them outside the radius', () {
      final result = app.nearestEligibleHomeArrivalCandidate<String>(
        candidates: const [
          app.HomeArrivalCandidate(value: 'uncertain', meters: 240.01),
        ],
        accuracyMeters: 10,
      );

      expect(result, isNull);
    });

    test('returns null when there are no candidates', () {
      expect(
        app.nearestEligibleHomeArrivalCandidate<String>(
          candidates: const [],
          accuracyMeters: 5,
        ),
        isNull,
      );
    });
  });
}
