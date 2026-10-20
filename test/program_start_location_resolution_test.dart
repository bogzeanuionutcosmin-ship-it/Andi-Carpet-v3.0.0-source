import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;

void main() {
  test('resolves the same case-insensitive endpoint once and reuses its coordinates', () async {
    final calls = <String>[];

    final result = await app.resolveProgramStartLocations(
      departure: 'Brăila',
      destination: 'BRĂILA',
      geocode: (query) async {
        calls.add(query);
        return <String, dynamic>{'lat': 45.26, 'lon': 27.97};
      },
    );

    expect(calls, <String>['Brăila']);
    expect(result?.departureLatitude, 45.26);
    expect(result?.departureLongitude, 27.97);
    expect(result?.destinationLatitude, 45.26);
    expect(result?.destinationLongitude, 27.97);
  });

  test('geocodes different endpoints in order and preserves each result', () async {
    final calls = <String>[];

    final result = await app.resolveProgramStartLocations(
      departure: 'Brăila',
      destination: 'Galați',
      geocode: (query) async {
        calls.add(query);
        return query == 'Brăila'
            ? <String, dynamic>{'lat': 45.26, 'lon': 27.97}
            : <String, dynamic>{'lat': 45.43, 'lon': 28.01};
      },
    );

    expect(calls, <String>['Brăila', 'Galați']);
    expect(result?.departureLatitude, 45.26);
    expect(result?.destinationLatitude, 45.43);
  });

  test('stops after departure failure and reports unresolved destinations as null', () async {
    final calls = <String>[];
    final departureFailure = await app.resolveProgramStartLocations(
      departure: 'Brăila',
      destination: 'Galați',
      geocode: (query) async {
        calls.add(query);
        return null;
      },
    );
    expect(departureFailure, isNull);
    expect(calls, <String>['Brăila']);

    final destinationFailure = await app.resolveProgramStartLocations(
      departure: 'Brăila',
      destination: 'Galați',
      geocode: (query) async => query == 'Brăila'
          ? <String, dynamic>{'lat': 45.26, 'lon': 27.97}
          : null,
    );
    expect(destinationFailure, isNull);
  });
}
