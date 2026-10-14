import 'package:flutter_test/flutter_test.dart';

import 'package:andi_carpeta/main.dart';

void main() {
  test('formatarea datei folosește anul și luna corecte', () {
    final value = formatDate(DateTime(2026, 10, 5));
    expect(value, contains('2026'));
    expect(value, contains('octombrie'));
  });

  test('funcțiile implicite au identificatori unici și drepturi definite', () {
    final defs = defaultFunctionDefinitions();
    expect(defs, isNotEmpty);
    expect(defs.map((e) => e.id).toSet().length, defs.length);
    expect(defs.firstWhere((e) => e.id == 'admin').permissions, isNotEmpty);
  });
}
