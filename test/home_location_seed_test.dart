import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/home/seed_operational_locations.dart';
import 'package:andi_carpeta/models/app_enums.dart';

void main() {
  test('returns the complete Magic and Million catalog in stable order', () {
    final locations = seedOperationalLocations();

    expect(locations, hasLength(103));
    expect(locations.map((location) => location.id).toSet(), hasLength(103));
    expect(
      locations.where((location) => location.type == LocationType.magic),
      hasLength(36),
    );
    expect(
      locations.where((location) => location.type == LocationType.million),
      hasLength(67),
    );
    expect(locations.first.id, 'magic01');
    expect(locations[35].id, 'magic36');
    expect(locations[36].id, 'million01');
    expect(locations.last.id, 'million67');
  });

  test('returns fresh mutable locations for each initialization', () {
    final first = seedOperationalLocations();
    final second = seedOperationalLocations();

    expect(identical(first, second), isFalse);
    expect(identical(first.first, second.first), isFalse);
    expect(identical(first[36].contacts, second[36].contacts), isFalse);
    first.first.name = 'changed only in first result';
    expect(second.first.name, 'MAGIC Alexandria');
  });
}
