import 'package:flutter_test/flutter_test.dart';

import 'package:andi_carpeta/main.dart';

void main() {
  test('formatarea datei folosește anul și luna corecte', () {
    final value = formatDate(DateTime(2026, 10, 5));
    expect(value, contains('2026'));
    expect(value, contains('octombrie'));
  });

  test('formatarea datei păstrează anul la schimbarea lunii', () {
    final decembrie = formatDate(DateTime(2025, 12, 31));
    final ianuarie = formatDate(DateTime(2026, 1, 1));
    expect(decembrie, contains('2025'));
    expect(ianuarie, contains('2026'));
    expect(decembrie, isNot(equals(ianuarie)));
  });

  test('funcțiile implicite au identificatori unici și drepturi definite', () {
    final defs = defaultFunctionDefinitions();
    expect(defs, isNotEmpty);
    expect(defs.map((e) => e.id).toSet().length, defs.length);
    expect(defs.firstWhere((e) => e.id == 'admin').permissions, isNotEmpty);
    expect(defs.any((e) => e.id == 'worker'), isFalse);
  });
}
