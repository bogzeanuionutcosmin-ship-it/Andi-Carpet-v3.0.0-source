import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../models/app_data_models.dart';

String normalizeFontChoice(String? raw) {
  final value = (raw ?? 'System').trim();
  if (value == 'Georgia' || value == 'Serif') return 'Serif';
  if (value == 'Monospace') return 'Monospace';
  if (value == 'Condensed' || value == 'Cursive') return 'Cursive';
  if (const {'Roboto','Arial','Verdana','Tahoma','Sans'}.contains(value)) return 'Sans';
  return 'System';
}

String? resolvedFontFamily(String choice) => switch (normalizeFontChoice(choice)) {
  // Pe Web folosim familii Windows/browser reale; numele generice CSS nu sunt
  // interpretate mereu ca fontFamily de motorul Flutter Web.
  'Sans' => kIsWeb ? 'Arial' : 'sans-serif',
  'Serif' => kIsWeb ? 'Georgia' : 'serif',
  'Monospace' => kIsWeb ? 'Courier New' : 'monospace',
  'Cursive' => kIsWeb ? 'Comic Sans MS' : 'cursive',
  _ => null,
};

const Map<String, String> bundledBackgroundAssets = <String, String>{
  'default': 'assets/themes/fundal_1.jpg',
  'salarii_intarziate': 'assets/themes/salarii_intarziate.jpg',
  'zi_de_salariu': 'assets/themes/zi_de_salariu.jpg',
  'christmas_village': 'assets/themes/christmas_village.jpg',
  'foam_party': 'assets/themes/foam_party.jpg',
  'neon_night': 'assets/themes/neon_night.jpg',
  'easter_garden': 'assets/themes/easter_garden.jpg',
};

const Map<String, String> bundledBackgroundLabels = <String, String>{
  'default': 'Default',
  'salarii_intarziate': 'Salarii întârziate',
  'zi_de_salariu': 'Zi de salariu',
  'christmas_village': 'Christmas Village',
  'foam_party': 'Foam Party',
  'neon_night': 'Neon Night',
  'easter_garden': 'Easter Garden',
};

const Map<String, String> bundledLogoAssets = <String, String>{
  'standard': 'assets/logos/standard.jpg',
  'rain': 'assets/logos/rain.jpg',
  'winter': 'assets/logos/winter.jpg',
  'easter': 'assets/logos/easter.jpg',
  'christmas': 'assets/logos/christmas.jpg',
};

const Map<String, String> bundledLogoLabels = <String, String>{
  'standard': 'Standard',
  'rain': 'Rain / Sad',
  'winter': 'Winter',
  'easter': 'Easter',
  'christmas': 'Christmas',
};

String activeLogoAsset(AppSettings settings) =>
    bundledLogoAssets[settings.brandingLogoId] ?? bundledLogoAssets['standard']!;

Widget appBrandLogo(AppSettings settings, {double width = 520, double height = 130}) =>
    Image.asset(activeLogoAsset(settings), width: width, height: height, fit: BoxFit.contain);

