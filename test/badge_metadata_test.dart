import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;
import 'package:andi_carpeta/ui/badge_metadata.dart';

void main() {
  test('badge keys have unique identifiers and valid asset mappings', () {
    expect(availableBadgeKeys.toSet().length, availableBadgeKeys.length);
    for (final key in availableBadgeKeys) {
      expect(badgeAssetChoices.containsKey(key), isTrue);
      expect(badgeAssetChoices[key], startsWith('assets/badges/'));
      expect(badgeLabel(key), isNotEmpty);
    }
  });

  test('legacy machine badge retains worker asset and label', () {
    expect(badgeAssetChoices['badge_machine'], badgeAssetChoices['badge_worker']);
    expect(badgeLabel('badge_machine'), 'Lucrător');
    expect(availableBadgeKeys.contains('badge_machine'), isFalse);
  });

  test('unknown badge label retains input and public main API remains available', () {
    expect(badgeLabel('custom_badge'), 'custom_badge');
    expect(app.badgeLabel('badge_admin'), badgeLabel('badge_admin'));
    expect(app.badgeAssetChoices['badge_driver'], badgeAssetChoices['badge_driver']);
    expect(app.availableBadgeKeys, availableBadgeKeys);
  });
}
