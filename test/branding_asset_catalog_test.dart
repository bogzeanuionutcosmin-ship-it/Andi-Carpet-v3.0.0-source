import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/ui/branding_asset_catalog.dart';
import 'package:andi_carpeta/main.dart' as app;

void main() {
  test('bundled backgrounds retain exact identifiers, assets and labels', () {
    expect(bundledBackgroundAssets, {
      'default': 'assets/themes/fundal_1.jpg',
      'salarii_intarziate': 'assets/themes/salarii_intarziate.jpg',
      'zi_de_salariu': 'assets/themes/zi_de_salariu.jpg',
      'christmas_village': 'assets/themes/christmas_village.jpg',
      'foam_party': 'assets/themes/foam_party.jpg',
      'neon_night': 'assets/themes/neon_night.jpg',
      'easter_garden': 'assets/themes/easter_garden.jpg',
    });
    expect(bundledBackgroundLabels, {
      'default': 'Default',
      'salarii_intarziate': 'Salarii întârziate',
      'zi_de_salariu': 'Zi de salariu',
      'christmas_village': 'Christmas Village',
      'foam_party': 'Foam Party',
      'neon_night': 'Neon Night',
      'easter_garden': 'Easter Garden',
    });
    expect(bundledBackgroundAssets.keys.toList(), bundledBackgroundLabels.keys.toList());
    expect(app.bundledBackgroundAssets, bundledBackgroundAssets);
    expect(app.bundledBackgroundLabels, bundledBackgroundLabels);
  });

  test('bundled logos retain exact identifiers, assets and labels', () {
    expect(bundledLogoAssets, {
      'standard': 'assets/logos/standard.jpg',
      'rain': 'assets/logos/rain.jpg',
      'winter': 'assets/logos/winter.jpg',
      'easter': 'assets/logos/easter.jpg',
      'christmas': 'assets/logos/christmas.jpg',
    });
    expect(bundledLogoLabels, {
      'standard': 'Standard',
      'rain': 'Rain / Sad',
      'winter': 'Winter',
      'easter': 'Easter',
      'christmas': 'Christmas',
    });
    expect(bundledLogoAssets.keys.toList(), bundledLogoLabels.keys.toList());
    expect(app.bundledLogoAssets, bundledLogoAssets);
    expect(app.bundledLogoLabels, bundledLogoLabels);
    expect(bundledLogoAssets['unknown'] ?? bundledLogoAssets['standard'], 'assets/logos/standard.jpg');
  });
}
