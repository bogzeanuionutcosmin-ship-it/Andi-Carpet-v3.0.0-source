import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/ui/font_choice_normalization.dart';
import 'package:andi_carpeta/main.dart' as app;

void main() {
  test('preserves every legacy recognized font choice', () {
    const expected = <String, String>{
      'Georgia': 'Serif', 'Serif': 'Serif',
      'Monospace': 'Monospace',
      'Condensed': 'Cursive', 'Cursive': 'Cursive',
      'Roboto': 'Sans', 'Arial': 'Sans', 'Verdana': 'Sans',
      'Tahoma': 'Sans', 'Sans': 'Sans',
      'System': 'System',
    };
    for (final entry in expected.entries) {
      expect(normalizeFontChoice(entry.key), entry.value, reason: entry.key);
      expect(app.normalizeFontChoice(entry.key), entry.value, reason: 'main.dart: ${entry.key}');
    }
  });

  test('trims whitespace and preserves case-sensitive fallback', () {
    expect(normalizeFontChoice('  Georgia  '), 'Serif');
    expect(normalizeFontChoice(' Roboto '), 'Sans');
    expect(normalizeFontChoice(null), 'System');
    expect(normalizeFontChoice(''), 'System');
    expect(normalizeFontChoice(' georgia '), 'System');
    expect(normalizeFontChoice('Arial Narrow'), 'System');
    expect(normalizeFontChoice('Unknown'), 'System');
  });
}
