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

const Map<String, String> _bundledBackgroundAssets = bundledBackgroundAssets;
const Map<String, String> _bundledBackgroundLabels = bundledBackgroundLabels;
const Map<String, String> _bundledLogoAssets = bundledLogoAssets;
const Map<String, String> _bundledLogoLabels = bundledLogoLabels;

String _activeLogoAsset(AppSettings settings) =>
    _bundledLogoAssets[settings.brandingLogoId] ?? _bundledLogoAssets['standard']!;

Widget appBrandLogo(AppSettings settings, {double width = 520, double height = 130}) =>
    Image.asset(_activeLogoAsset(settings), width: width, height: height, fit: BoxFit.contain);

