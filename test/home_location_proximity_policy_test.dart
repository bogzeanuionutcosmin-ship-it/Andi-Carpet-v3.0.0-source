import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;

void main() {
  test('enables precision at or inside the existing three-kilometre boundary', () {
    expect(
      app.homeLocationProximityAction(isBoosted: false, nearestMeters: 3000),
      app.HomeLocationProximityAction.boost,
    );
    expect(
      app.homeLocationProximityAction(isBoosted: false, nearestMeters: 2999.9),
      app.HomeLocationProximityAction.boost,
    );
  });

  test('keeps current mode in the five-kilometre hysteresis band', () {
    expect(
      app.homeLocationProximityAction(isBoosted: false, nearestMeters: 4000),
      isNull,
    );
    expect(
      app.homeLocationProximityAction(isBoosted: true, nearestMeters: 5000),
      isNull,
    );
  });

  test('returns to economical precision only beyond five kilometres', () {
    expect(
      app.homeLocationProximityAction(isBoosted: true, nearestMeters: 5000.1),
      app.HomeLocationProximityAction.relax,
    );
    expect(
      app.homeLocationProximityAction(isBoosted: true, nearestMeters: double.infinity),
      app.HomeLocationProximityAction.relax,
    );
  });

  test('does not request a mode change when already in the target state', () {
    expect(
      app.homeLocationProximityAction(isBoosted: true, nearestMeters: 2500),
      isNull,
    );
    expect(
      app.homeLocationProximityAction(isBoosted: false, nearestMeters: 7000),
      isNull,
    );
  });
}
