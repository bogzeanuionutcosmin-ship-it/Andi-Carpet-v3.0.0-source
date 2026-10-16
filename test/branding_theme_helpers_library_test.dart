import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/models/app_data_models.dart';
import 'package:andi_carpeta/ui/branding_theme_helpers.dart';

void main() {
  test('font aliases and platform families keep their existing mappings', () {
    expect(normalizeFontChoice(' Georgia '), 'Serif');
    expect(normalizeFontChoice('Condensed'), 'Cursive');
    expect(normalizeFontChoice('Roboto'), 'Sans');
    expect(normalizeFontChoice(' unknown '), 'System');
    expect(normalizeFontChoice(null), 'System');
    expect(resolvedFontFamily('Sans'), kIsWeb ? 'Arial' : 'sans-serif');
    expect(resolvedFontFamily('Serif'), kIsWeb ? 'Georgia' : 'serif');
    expect(resolvedFontFamily('Monospace'), kIsWeb ? 'Courier New' : 'monospace');
    expect(resolvedFontFamily('Cursive'), kIsWeb ? 'Comic Sans MS' : 'cursive');
    expect(resolvedFontFamily('System'), isNull);
  });

  test('bundled branding catalogs and logo fallback remain stable', () {
    expect(bundledBackgroundAssets['default'], 'assets/themes/fundal_1.jpg');
    expect(bundledBackgroundLabels['default'], 'Default');
    expect(bundledLogoAssets['winter'], 'assets/logos/winter.jpg');
    expect(bundledLogoLabels['winter'], 'Winter');

    final settings = AppSettings()..brandingLogoId = 'winter';
    expect(activeLogoAsset(settings), 'assets/logos/winter.jpg');
    settings.brandingLogoId = 'missing';
    expect(activeLogoAsset(settings), 'assets/logos/standard.jpg');
  });

  test('logo widget retains requested dimensions and selected asset', () {
    final settings = AppSettings()..brandingLogoId = 'rain';
    final logo = appBrandLogo(settings, width: 240, height: 60) as Image;
    expect(logo.width, 240);
    expect(logo.height, 60);
    expect((logo.image as AssetImage).assetName, 'assets/logos/rain.jpg');
    expect(logo.fit, BoxFit.contain);
  });
}
