import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;
import 'package:andi_carpeta/ui/section_asset_catalog.dart';

void main() {
  test('supported section labels keep exact bundled asset routing', () {
    const expected = <String, String>{
      'Acasă': 'tab_dashboard',
      'Acasa': 'tab_dashboard',
      'Dashboard': 'tab_dashboard',
      'Echipe': 'teams',
      'Membri': 'members',
      'Chat live': 'chat_live',
      'Mesaje': 'chat_live',
      'Contacte locații': 'chat_live',
      'Grafic de lucru': 'tab_grafic',
      'Hartă': 'tab_harta',
      'Locații': 'tab_harta',
      'Centralizator': 'tab_centralizator',
      'Execuții': 'tab_centralizator',
      'Executii': 'tab_centralizator',
      'Decont': 'tab_decont',
      'Financiar': 'tab_decont',
      'Documente': 'tab_documente',
      'Rapoarte': 'tab_centralizator',
      'Funcții': 'security',
      'Functii': 'security',
      'Drepturi': 'security',
      'Securitate': 'security',
    };
    for (final entry in expected.entries) {
      final asset = 'assets/ui/${entry.value}.png';
      expect(sectionAssetForLabel(entry.key), asset, reason: entry.key);
      expect(sectionAssetForLabel('  ${entry.key.toUpperCase()}  '), asset);
      expect(app.sectionAssetForLabel(entry.key), asset);
    }
  });

  test('ordered substring checks retain their existing precedence', () {
    const cases = <String, String>{
      'Dashboard Echipe': 'tab_dashboard',
      'Membri Echipe': 'teams',
      'Chat Membri': 'members',
      'Contacte Grafic': 'chat_live',
      'Grafic Hartă': 'tab_grafic',
      'Locații Centralizator': 'tab_harta',
      'Execuții Decont': 'tab_centralizator',
      'Financiar Documente': 'tab_decont',
      'Documente Rapoarte': 'tab_documente',
      'Rapoarte Drepturi': 'tab_centralizator',
    };
    for (final entry in cases.entries) {
      expect(sectionAssetForLabel(entry.key), 'assets/ui/${entry.value}.png');
    }
  });

  test('unknown labels and legacy exact-only aliases retain null fallback', () {
    for (final label in <String>[
      '', 'Necunoscut', 'Program', 'Raport', 'Acasă principală',
      'Mesaje personale', 'Setări',
    ]) {
      expect(sectionAssetForLabel(label), isNull, reason: label);
    }
  });

  test('category catalog retains every identifier, asset and const API', () {
    const expected = <String, String>{
      'million': 'assets/ui/cat_million.png',
      'magic': 'assets/ui/cat_magic.png',
      'horeca': 'assets/ui/cat_horeca.png',
      'cazari': 'assets/ui/cat_cazari.png',
    };
    const publicCatalog = app.categoryBrandAssets;
    expect(categoryBrandAssets, expected);
    expect(publicCatalog, same(categoryBrandAssets));
    expect(categoryBrandAssets['MILLION'], isNull);
    expect(categoryBrandAssets['other'], isNull);
    expect(() => categoryBrandAssets['other'] = 'changed', throwsUnsupportedError);
  });
}
