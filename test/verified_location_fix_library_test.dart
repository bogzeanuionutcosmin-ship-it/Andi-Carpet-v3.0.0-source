import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/map/verified_location_fix.dart';
import 'package:andi_carpeta/models/app_enums.dart';

void main() {
  test('preserves defaults and GPS completeness semantics', () {
    const addressOnly = VerifiedLocationFix(
      id: 'million-test',
      verifiedAddress: 'Adresă verificată',
    );
    const complete = VerifiedLocationFix(
      id: 'million-gps-test',
      latitude: 44.4,
      longitude: 26.1,
      status: LocationStatus.open,
      verifiedAddress: 'Adresă GPS',
      confidence: 'adresă exactă',
      note: 'test',
    );

    expect(addressOnly.latitude, isNull);
    expect(addressOnly.longitude, isNull);
    expect(addressOnly.status, isNull);
    expect(addressOnly.confidence, 'ridicată');
    expect(addressOnly.note, isEmpty);
    expect(addressOnly.source, 'Google Maps / verificare web');
    expect(addressOnly.hasGps, isFalse);
    expect(complete.hasGps, isTrue);
    expect(complete.status, LocationStatus.open);
  });
}
