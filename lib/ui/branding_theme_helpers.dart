part of '../main.dart';

String _normalizeFontChoice(String? raw) => normalizeFontChoice(raw);

String? _resolvedFontFamily(String choice) => switch (_normalizeFontChoice(choice)) {
  // Pe Web folosim familii Windows/browser reale; numele generice CSS nu sunt
  // interpretate mereu ca fontFamily de motorul Flutter Web.
  'Sans' => kIsWeb ? 'Arial' : 'sans-serif',
  'Serif' => kIsWeb ? 'Georgia' : 'serif',
  'Monospace' => kIsWeb ? 'Courier New' : 'monospace',
  'Cursive' => kIsWeb ? 'Comic Sans MS' : 'cursive',
  _ => null,
};

const Map<String, String> _bundledBackgroundAssets = <String, String>{
  'default': 'assets/themes/fundal_1.jpg',
  'salarii_intarziate': 'assets/themes/salarii_intarziate.jpg',
  'zi_de_salariu': 'assets/themes/zi_de_salariu.jpg',
  'christmas_village': 'assets/themes/christmas_village.jpg',
  'foam_party': 'assets/themes/foam_party.jpg',
  'neon_night': 'assets/themes/neon_night.jpg',
  'easter_garden': 'assets/themes/easter_garden.jpg',
};

const Map<String, String> _bundledBackgroundLabels = <String, String>{
  'default': 'Default',
  'salarii_intarziate': 'Salarii întârziate',
  'zi_de_salariu': 'Zi de salariu',
  'christmas_village': 'Christmas Village',
  'foam_party': 'Foam Party',
  'neon_night': 'Neon Night',
  'easter_garden': 'Easter Garden',
};

const Map<String, String> _bundledLogoAssets = <String, String>{
  'standard': 'assets/logos/standard.jpg',
  'rain': 'assets/logos/rain.jpg',
  'winter': 'assets/logos/winter.jpg',
  'easter': 'assets/logos/easter.jpg',
  'christmas': 'assets/logos/christmas.jpg',
};

const Map<String, String> _bundledLogoLabels = <String, String>{
  'standard': 'Standard',
  'rain': 'Rain / Sad',
  'winter': 'Winter',
  'easter': 'Easter',
  'christmas': 'Christmas',
};

String _activeLogoAsset(AppSettings settings) =>
    _bundledLogoAssets[settings.brandingLogoId] ?? _bundledLogoAssets['standard']!;

Widget appBrandLogo(AppSettings settings, {double width = 520, double height = 130}) =>
    Image.asset(_activeLogoAsset(settings), width: width, height: height, fit: BoxFit.contain);

