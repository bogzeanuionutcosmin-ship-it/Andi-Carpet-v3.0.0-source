import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;
import 'package:andi_carpeta/ui/icon_badge_catalog.dart' as catalog;

void main() {
  test('keeps the icon and badge catalog values and labels', () {
    expect(catalog.appIconChoices, hasLength(13));
    expect(catalog.iconForKey('car'), Icons.directions_car);
    expect(catalog.iconForKey('unknown'), Icons.badge_outlined);
    expect(catalog.iconLabel('cleaning'), 'Aspirator / curățenie');
    expect(catalog.iconLabel('custom'), 'custom');

    expect(catalog.badgeAssetChoices['badge_machine'],
        catalog.badgeAssetChoices['badge_worker']);
    expect(catalog.badgeLabel('badge_machine'), 'Lucrător');
    expect(catalog.availableBadgeKeys, isNot(contains('badge_machine')));
    expect(catalog.badgeLabel('custom'), 'custom');
    expect(catalog.categoryBrandAssets, contains('million'));
  });

  test('keeps section label matching and the main library exports', () {
    const assets = <String, String>{
      ' Acasă ': 'assets/ui/tab_dashboard.png',
      'Echipe active': 'assets/ui/teams.png',
      'Membri': 'assets/ui/members.png',
      'Chat live': 'assets/ui/chat_live.png',
      'Contacte': 'assets/ui/chat_live.png',
      'Grafic': 'assets/ui/tab_grafic.png',
      'Hartă': 'assets/ui/tab_harta.png',
      'Locații': 'assets/ui/tab_harta.png',
      'Centralizator': 'assets/ui/tab_centralizator.png',
      'Execuții': 'assets/ui/tab_centralizator.png',
      'Decont': 'assets/ui/tab_decont.png',
      'Documente': 'assets/ui/tab_documente.png',
      'Rapoarte': 'assets/ui/tab_centralizator.png',
      'Drepturi': 'assets/ui/security.png',
    };
    for (final entry in assets.entries) {
      expect(catalog.sectionAssetForLabel(entry.key), entry.value);
    }
    expect(catalog.sectionAssetForLabel('necunoscut'), isNull);
    expect(app.iconForKey('car'), catalog.iconForKey('car'));
    expect(app.badgeLabel('badge_admin'), catalog.badgeLabel('badge_admin'));
    expect(app.appIconChoices, same(catalog.appIconChoices));
  });
}
