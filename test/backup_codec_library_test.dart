import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/admin/backup_codec.dart';

void main() {
  test('encodes and decodes nested Firestore timestamps and geopoints', () {
    final timestamp = Timestamp.fromDate(DateTime.utc(2026, 10, 14, 9, 30));
    const point = GeoPoint(44.4268, 26.1025);
    final input = <Object, dynamic>{
      'created': timestamp,
      'locations': [
        {'position': point},
      ],
      'values': [1, 'text', null],
    };

    final encoded = encodeBackupValue(input) as Map<String, dynamic>;
    expect(encoded.keys, contains('created'));
    expect(encoded['created'], {
      '__type': 'timestamp',
      'value': timestamp.toDate().toIso8601String(),
    });
    expect(encoded['locations'], [
      {
        'position': {'__type': 'geopoint', 'lat': 44.4268, 'lng': 26.1025},
      },
    ]);
    expect(encoded['values'], [1, 'text', null]);

    final decoded = decodeBackupValue(encoded) as Map<String, dynamic>;
    expect(decoded['created'], timestamp);
    final decodedLocations = decoded['locations'] as List;
    final decodedLocation = decodedLocations.single as Map<String, dynamic>;
    final decodedPoint = (decodedLocation['position'] as GeoPoint);
    expect(decodedPoint.latitude, 44.4268);
    expect(decodedPoint.longitude, 26.1025);
    expect(decoded['values'], [1, 'text', null]);
  });

  test('keeps unrecognized values and marker maps on the existing recursive path', () {
    final value = {
      'date': DateTime.utc(2026, 10, 14),
      'marker': {'__type': 'other', 'value': 4},
    };

    final encoded = encodeBackupValue(value) as Map<String, dynamic>;
    expect(encoded['date'], value['date']);
    expect(decodeBackupValue(encoded), value);
  });
}
